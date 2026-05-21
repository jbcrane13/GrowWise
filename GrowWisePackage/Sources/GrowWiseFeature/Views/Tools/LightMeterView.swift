import GrowWiseServices
import SwiftUI
#if canImport(AVFoundation) && os(iOS)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Camera-based light meter utility. Estimates ambient lux and shows a qualitative bucket.
public struct LightMeterView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var meter = LightMeterService()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                #if canImport(AVFoundation) && os(iOS)
                if meter.permission == .denied {
                    permissionDeniedView
                } else if let session = meter.captureSession(), meter.isRunning {
                    CameraPreview(session: session)
                        .ignoresSafeArea()
                    readoutOverlay
                } else if let error = meter.lastError {
                    errorView(error: error)
                } else {
                    loadingView
                }
                #else
                unsupportedPlatformView
                #endif
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Light Meter")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("lightmeter_button_done")
                }
            }
            .task {
                await meter.start()
            }
            .onDisappear {
                meter.stop()
            }
            .accessibilityIdentifier("lightmeter_screen")
        }
    }

    // MARK: - Readout overlay

    private var readoutOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text(luxText)
                    .font(.system(size: 72, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityIdentifier("lightmeter_label_lux")
                Text("lux")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(meter.bucket?.displayName ?? "Measuring…")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                    .accessibilityIdentifier("lightmeter_label_bucket")
                if let subtitle = meter.bucket?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private var luxText: String {
        guard let lux = meter.lux else { return "—" }
        if lux >= 10000 {
            return String(format: "%.0fk", lux / 1000)
        }
        return String(format: "%.0f", lux)
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Text("Camera Access Needed")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("The light meter uses the camera to estimate ambient light. Enable camera access in Settings to use it.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            #if canImport(UIKit)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CultivationTheme.Colors.accentCoral)
            .accessibilityIdentifier("lightmeter_button_settings")
            #endif
        }
        .padding()
    }

    // MARK: - Error state

    private func errorView(error: LightMeterError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(CultivationTheme.Colors.statusAlert)
            Text("Couldn't Start Light Meter")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text(errorMessage(for: error))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await meter.start() }
            }
            .buttonStyle(.borderedProminent)
            .tint(CultivationTheme.Colors.accentCoral)
            .accessibilityIdentifier("lightmeter_button_retry")
        }
        .padding()
        .accessibilityIdentifier("lightmeter_error_view")
    }

    private func errorMessage(for error: LightMeterError) -> String {
        switch error {
        case .noDevice:
            "No back camera was found on this device."

        case .configurationFailed:
            "The camera couldn't be configured. Close other camera apps and try again."

        case .permissionDenied:
            "Camera access is required to estimate light."
        }
    }

    // MARK: - Loading / unsupported

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Warming up the camera…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
    }

    private var unsupportedPlatformView: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.gen3.slash")
                .font(.system(size: 48))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Text("Light Meter requires iOS")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
        .padding()
    }
}

#if canImport(AVFoundation) && os(iOS)
/// SwiftUI wrapper around `AVCaptureVideoPreviewLayer`.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#endif
