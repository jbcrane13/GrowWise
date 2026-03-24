import CoreML
import Foundation
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

    public init(
        primaryLabel: String,
        confidence: Float,
        severity: Severity,
        recommendation: String,
        alternatives: [PlantClassificationCandidate]
    ) {
        self.primaryLabel = primaryLabel
        self.confidence = confidence
        self.severity = severity
        self.recommendation = recommendation
        self.alternatives = alternatives
    }
}

public enum PlantDiagnosticError: Error, LocalizedError {
    case invalidImage
    case noClassification

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected image is invalid for diagnosis."

        case .noClassification:
            "No diagnosis could be produced from the image."
        }
    }
}

@MainActor
@Observable
public final class PlantDiagnosticService {
    public private(set) var isAnalyzing = false
    public private(set) var lastDiagnosis: PlantDiagnosis?
    public private(set) var lastError: String?

    public init() {}

    public func setSampleDiagnosis() {
        lastDiagnosis = summarize([
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.81),
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.42),
        ])
    }

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

        let lowercased = primary.label.lowercased()
        let severity: PlantDiagnosis.Severity = if lowercased.contains("healthy") {
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

        let recommendation = switch severity {
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

        return PlantDiagnosis(
            primaryLabel: primary.label,
            confidence: primary.confidence,
            severity: severity,
            recommendation: recommendation,
            alternatives: Array(candidates.dropFirst().prefix(3))
        )
    }

    private func classify(image: PlatformImage) async throws -> [PlantClassificationCandidate] {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { throw PlantDiagnosticError.invalidImage }
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PlantDiagnosticError.invalidImage
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
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
