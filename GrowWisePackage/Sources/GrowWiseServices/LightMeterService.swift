import Foundation
import Observation
import os
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif

private let logger = Logger(subsystem: "com.growwise", category: "LightMeterService")

/// Qualitative light buckets aligned with `SunlightLevel` in models.
public enum LightMeterBucket: String, Sendable, CaseIterable {
    case deepShade
    case shade
    case brightIndirect
    case directSun

    public var displayName: String {
        switch self {
        case .deepShade: "Deep shade"
        case .shade: "Shade"
        case .brightIndirect: "Bright indirect"
        case .directSun: "Direct sun"
        }
    }

    public var subtitle: String {
        switch self {
        case .deepShade: "Suits low-light foliage (pothos, snake plant)."
        case .shade: "Good for ferns and most houseplants away from a window."
        case .brightIndirect: "Most flowering houseplants thrive here."
        case .directSun: "Full-sun plants (tomatoes, peppers, succulents)."
        }
    }

    /// Bucket from a lux reading. Thresholds chosen to roughly match horticultural categories.
    public static func bucket(forLux lux: Double) -> LightMeterBucket {
        switch lux {
        case ..<500: .deepShade
        case 500 ..< 2500: .shade
        case 2500 ..< 10000: .brightIndirect
        default: .directSun
        }
    }
}

public enum LightMeterPermission: Sendable {
    case notDetermined
    case granted
    case denied
}

public enum LightMeterError: Error, Sendable {
    case noDevice
    case configurationFailed
    case permissionDenied
}

/// Estimates ambient illuminance (lux) from the device camera's exposure metering.
///
/// Uses the standard ISO 2720 exposure equation: `EV100 = log2((N²/t) × (100/S))`
/// and approximates lux as `2.5 × 2^EV100` (reflected-light meter with K=12.5).
/// Readings are smoothed with a fixed-size moving average to reduce jitter.
@MainActor
@Observable
public final class LightMeterService {
    // Public observed state
    public private(set) var permission: LightMeterPermission = .notDetermined
    public private(set) var isRunning = false
    public private(set) var lux: Double?
    public private(set) var bucket: LightMeterBucket?
    public private(set) var lastError: LightMeterError?

    /// Calibration constant for reflected-light meter (ISO 2720, K=12.5).
    /// Lux ≈ luxCalibration × 2^EV100. 2.5 is the conventional value used by light-meter apps.
    nonisolated static let luxCalibration: Double = 2.5

    /// Smoothing window (samples).
    nonisolated static let smoothingWindow = 8

    #if canImport(AVFoundation) && os(iOS)
    // session and device are always read/written on @MainActor; sessionQueue is used only
    // for blocking AVFoundation configuration calls that must not run on the main thread.
    @ObservationIgnored
    private var session: AVCaptureSession?
    @ObservationIgnored
    private var device: AVCaptureDevice?
    @ObservationIgnored
    private let sessionQueue = DispatchQueue(label: "com.growwise.lightmeter.session")
    @ObservationIgnored
    private var sampleTask: Task<Void, Never>?
    @ObservationIgnored
    private var samples: [Double] = []
    #endif

    public init() {}

    // Cleanup relies on callers invoking `stop()` (the view does this in `.onDisappear`).
    // We deliberately don't define a deinit: in Swift 6 the implicit `deinit` is
    // nonisolated and cannot access `@MainActor` properties.

    // MARK: - Public API

    /// Requests camera access (if needed) and starts metering.
    public func start() async {
        #if canImport(AVFoundation) && os(iOS)
        guard !isRunning else { return }
        lastError = nil
        let granted = await ensurePermission()
        guard granted else {
            permission = .denied
            lastError = .permissionDenied
            return
        }
        permission = .granted
        do {
            try await configureAndStartSession()
            isRunning = true
            startSampling()
        } catch let error as LightMeterError {
            lastError = error
            logger.error("Light meter start failed: \(String(describing: error), privacy: .public)")
        } catch {
            lastError = .configurationFailed
            logger.error("Light meter start failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Stops metering and tears down the session.
    public func stop() {
        #if canImport(AVFoundation) && os(iOS)
        sampleTask?.cancel()
        sampleTask = nil
        samples.removeAll(keepingCapacity: true)
        let session = self.session
        sessionQueue.async {
            if let session, session.isRunning {
                session.stopRunning()
            }
        }
        self.session = nil
        self.device = nil
        isRunning = false
        lux = nil
        bucket = nil
        #endif
    }

    // Provides a SwiftUI-bindable preview layer source. `nil` until the session is configured.
    #if canImport(AVFoundation) && os(iOS)
    public func captureSession() -> AVCaptureSession? {
        session
    }
    #endif

    // MARK: - Permission

    #if canImport(AVFoundation) && os(iOS)
    private func ensurePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true

        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)

        case .denied, .restricted:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Session

    private func configureAndStartSession() async throws {
        // AVCaptureSession/AVCaptureDevice are not Sendable; wrap in an @unchecked Sendable
        // carrier so the checked continuation can transport them back to @MainActor.
        struct SessionPair: @unchecked Sendable {
            let session: AVCaptureSession
            let device: AVCaptureDevice
        }
        let pair: SessionPair = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SessionPair, Error>) in
            sessionQueue.async {
                let session = AVCaptureSession()
                session.beginConfiguration()
                session.sessionPreset = .medium
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    session.commitConfiguration()
                    continuation.resume(throwing: LightMeterError.noDevice)
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if session.canAddInput(input) {
                        session.addInput(input)
                    } else {
                        session.commitConfiguration()
                        continuation.resume(throwing: LightMeterError.configurationFailed)
                        return
                    }
                    // Continuous auto-exposure so the device's reported ISO + duration
                    // track the ambient scene.
                    try device.lockForConfiguration()
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.unlockForConfiguration()

                    session.commitConfiguration()
                    session.startRunning()
                    continuation.resume(returning: SessionPair(session: session, device: device))
                } catch {
                    session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
        // Back on @MainActor — assign both properties here, not inside the sessionQueue block.
        self.session = pair.session
        self.device = pair.device
    }

    // MARK: - Sampling

    private func startSampling() {
        sampleTask?.cancel()
        sampleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let sample = await self.readSample() {
                    self.publish(sample: sample)
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // ~10 Hz
            }
        }
    }

    private func readSample() async -> Double? {
        // Capture device reference on @MainActor; the block below only reads immutable
        // exposure properties that are safe to call from any thread per AVFoundation docs.
        guard let device = self.device else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            sessionQueue.async {
                let aperture = Double(device.lensAperture)
                let durationSec = CMTimeGetSeconds(device.exposureDuration)
                let iso = Double(device.iso)
                guard aperture > 0, durationSec > 0, iso > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let lux = LightMeterService.lux(aperture: aperture, exposureSeconds: durationSec, iso: iso)
                continuation.resume(returning: lux)
            }
        }
    }

    private func publish(sample: Double) {
        samples.append(sample)
        if samples.count > Self.smoothingWindow {
            samples.removeFirst(samples.count - Self.smoothingWindow)
        }
        let avg = samples.reduce(0, +) / Double(samples.count)
        lux = avg
        bucket = LightMeterBucket.bucket(forLux: avg)
    }
    #endif

    // MARK: - Pure math (exposed for tests)

    /// Computes EV at ISO 100 from camera exposure parameters.
    /// `EV100 = log2((N²/t) × (100/S))`
    public nonisolated static func ev100(aperture: Double, exposureSeconds: Double, iso: Double) -> Double {
        let numerator = (aperture * aperture) / exposureSeconds
        return log2(numerator * (100.0 / iso))
    }

    /// Approximates lux from camera exposure parameters.
    /// `lux ≈ 2.5 × 2^EV100`
    public nonisolated static func lux(aperture: Double, exposureSeconds: Double, iso: Double) -> Double {
        luxCalibration * pow(2.0, ev100(aperture: aperture, exposureSeconds: exposureSeconds, iso: iso))
    }
}
