import CoreML
import Foundation
import GrowWiseModels
import Observation
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct PlantClassificationCandidate: Sendable, Equatable {
    public let label: String
    public let confidence: Float

    public init(label: String, confidence: Float) {
        self.label = label
        self.confidence = confidence
    }
}

public struct PlantDiagnosis: Sendable, Equatable {
    public enum Severity: String, Sendable, Equatable {
        case healthy
        case mild
        case moderate
        case severe
        case unknown
    }

    public let primaryLabel: String
    public let confidence: Float
    public let severity: Severity
    public let recommendation: String
    public let alternatives: [PlantClassificationCandidate]
    public let condition: PlantCondition?

    public init(
        primaryLabel: String,
        confidence: Float,
        severity: Severity,
        recommendation: String,
        alternatives: [PlantClassificationCandidate],
        condition: PlantCondition? = nil
    ) {
        self.primaryLabel = primaryLabel
        self.confidence = confidence
        self.severity = severity
        self.recommendation = recommendation
        self.alternatives = alternatives
        self.condition = condition
    }
}

public enum PlantDiagnosticError: Error, LocalizedError {
    case invalidImage
    case noClassification
    case diagnosisLimitReached(remaining: Int, tier: SubscriptionTier)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected image is invalid for diagnosis."

        case .noClassification:
            "No diagnosis could be produced from the image."

        case let .diagnosisLimitReached(remaining, tier):
            "You have reached your monthly diagnosis limit (\(tier.aiDiagnosesPerMonth) per month on the \(tier.displayName) plan). Upgrade for unlimited diagnoses. Remaining: \(remaining)."
        }
    }
}

// MARK: - Diagnosis Limit Constants

private enum DiagnosisLimits {
    static let freeTierMonthlyLimit = 3
}

@MainActor
@Observable
public final class PlantDiagnosticService {
    public private(set) var isAnalyzing = false
    public private(set) var lastDiagnosis: PlantDiagnosis?
    public private(set) var lastError: String?

    /// Cached custom CoreML model, loaded once on first use.
    private var customModel: VNCoreMLModel?
    private var didAttemptModelLoad = false

    public init() {}

    // MARK: - Subscription Tier Enforcement

    /// Whether the given user can perform another diagnosis this month.
    public func canDiagnose(user: User) -> Bool {
        remainingDiagnoses(user: user) != 0
    }

    /// Number of diagnoses remaining this month. Returns -1 for unlimited (premium/pro).
    public func remainingDiagnoses(user: User) -> Int {
        let tier = user.subscriptionTier
        let limit = tier.aiDiagnosesPerMonth
        // Unlimited tiers
        if limit < 0 { return -1 }

        let used = diagnosesUsedThisMonth(user: user)
        return max(limit - used, 0)
    }

    /// Diagnoses used in the current calendar month, accounting for monthly reset.
    private func diagnosesUsedThisMonth(user: User) -> Int {
        guard let lastReset = user.lastDiagnosisReset else {
            // Never reset — all recorded uses are from the current period
            return user.aiDiagnosesUsed
        }
        let calendar = Calendar.current
        if calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
            return user.aiDiagnosesUsed
        }
        // Different month — counter effectively resets to 0
        return 0
    }

    // MARK: - Sample / Demo

    public func setSampleDiagnosis() {
        lastDiagnosis = summarize([
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.81),
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.42),
        ])
    }

    // MARK: - Diagnosis

    /// Run a full diagnosis, enforcing the user's subscription limits.
    /// Increments `user.aiDiagnosesUsed` and updates `user.lastDiagnosisReset` on success.
    public func diagnose(image: PlatformImage, user: User) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        // Enforce tier limits
        let remaining = remainingDiagnoses(user: user)
        if remaining == 0 {
            lastError = PlantDiagnosticError.diagnosisLimitReached(
                remaining: 0, tier: user.subscriptionTier
            ).localizedDescription
            return
        }

        do {
            let candidates = try await classify(image: image)
            let diagnosis = summarize(candidates)
            lastDiagnosis = diagnosis

            // Track usage
            let calendar = Calendar.current
            if let lastReset = user.lastDiagnosisReset,
               !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month)
            {
                // New month — reset counter
                user.aiDiagnosesUsed = 1
                user.lastDiagnosisReset = Date()
            } else {
                user.aiDiagnosesUsed += 1
                if user.lastDiagnosisReset == nil {
                    user.lastDiagnosisReset = Date()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Legacy diagnose without user — no tier enforcement.
    public func diagnose(image: PlatformImage) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        do {
            let candidates = try await classify(image: image)
            let diagnosis = summarize(candidates)
            lastDiagnosis = diagnosis
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Summarize

    public func summarize(_ candidates: [PlantClassificationCandidate]) -> PlantDiagnosis {
        guard let primary = candidates.first else {
            return PlantDiagnosis(
                primaryLabel: "Unknown",
                confidence: 0,
                severity: .unknown,
                recommendation: "Retake photo in brighter light and focus on affected leaf area.",
                alternatives: []
            )
        }

        // Look up knowledge base for detailed info
        let knownCondition = PlantDiseaseKnowledge.condition(for: primary.label)

        let lowercased = primary.label.lowercased()
        let severity: PlantDiagnosis.Severity = if let knownCondition, primary.confidence >= 0.45 {
            // Use the knowledge base severity when we have a confident match
            knownCondition.severity
        } else if lowercased.contains("healthy") {
            .healthy
        } else if primary.confidence >= 0.85 {
            .severe
        } else if primary.confidence >= 0.65 {
            .moderate
        } else if primary.confidence >= 0.45 {
            .mild
        } else {
            .unknown
        }

        let recommendation: String
        if let knownCondition, primary.confidence >= 0.45 {
            // Build a rich recommendation from the knowledge base
            let treatmentSummary = knownCondition.treatments.prefix(2).joined(separator: " ")
            recommendation = "\(knownCondition.commonName) detected. \(treatmentSummary)"
        } else {
            recommendation = switch severity {
            case .healthy:
                "No obvious disease detected. Continue normal care and weekly inspection."

            case .mild:
                "Possible early issue. Isolate affected leaves and monitor for 48 hours."

            case .moderate:
                "Likely disease or stress. Remove affected tissue and apply targeted treatment."

            case .severe:
                "High-confidence issue. Quarantine plant, inspect nearby plants, and begin treatment now."

            case .unknown:
                "Low-confidence result. Retake photo and capture both leaf top and underside."
            }
        }

        return PlantDiagnosis(
            primaryLabel: primary.label,
            confidence: primary.confidence,
            severity: severity,
            recommendation: recommendation,
            alternatives: Array(candidates.dropFirst().prefix(3)),
            condition: knownCondition
        )
    }

    // MARK: - CoreML Model Loading

    /// Attempt to load a custom PlantDiseaseClassifier CoreML model from the app bundle.
    /// Returns nil if the model is not bundled (graceful fallback to generic Vision classifier).
    private func loadCustomModel() -> VNCoreMLModel? {
        // Try main bundle first
        let bundles = [Bundle.main] + Bundle.allBundles

        for bundle in bundles {
            if let modelURL = bundle.url(forResource: "PlantDiseaseClassifier", withExtension: "mlmodelc") {
                do {
                    let mlModel = try MLModel(contentsOf: modelURL)
                    return try VNCoreMLModel(for: mlModel)
                } catch {
                    // Model found but failed to load — log and try next bundle
                    continue
                }
            }
        }

        return nil
    }

    /// Returns the cached custom model, or attempts to load it once.
    private func resolveCustomModel() -> VNCoreMLModel? {
        if didAttemptModelLoad { return customModel }
        didAttemptModelLoad = true
        customModel = loadCustomModel()
        return customModel
    }

    // MARK: - Classification

    private func classify(image: PlatformImage) async throws -> [PlantClassificationCandidate] {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { throw PlantDiagnosticError.invalidImage }
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PlantDiagnosticError.invalidImage
        }
        #endif

        // Try custom model first, fall back to generic Vision classifier
        if let vnModel = resolveCustomModel() {
            return try await classifyWithCustomModel(cgImage: cgImage, model: vnModel)
        }

        return try await classifyWithVision(cgImage: cgImage)
    }

    /// Classify using the custom CoreML model via VNCoreMLRequest.
    private func classifyWithCustomModel(
        cgImage: CGImage,
        model: VNCoreMLModel
    ) async throws -> [PlantClassificationCandidate] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNClassificationObservation] ?? []
                let mapped = observations.prefix(5).map {
                    PlantClassificationCandidate(label: $0.identifier, confidence: $0.confidence)
                }

                if mapped.isEmpty {
                    continuation.resume(throwing: PlantDiagnosticError.noClassification)
                } else {
                    continuation.resume(returning: mapped)
                }
            }

            request.imageCropAndScaleOption = .centerCrop

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Classify using the generic Vision VNClassifyImageRequest (fallback).
    private func classifyWithVision(cgImage: CGImage) async throws -> [PlantClassificationCandidate] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNClassificationObservation] ?? []
                let mapped = observations.prefix(5).map {
                    PlantClassificationCandidate(label: $0.identifier, confidence: $0.confidence)
                }

                if mapped.isEmpty {
                    continuation.resume(throwing: PlantDiagnosticError.noClassification)
                } else {
                    continuation.resume(returning: mapped)
                }
            }

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
