#if canImport(UIKit)
import Foundation
import GrowWiseModels
import os
import UIKit
import Vision

private let logger = Logger(subsystem: "com.growwise", category: "SeedScannerService")

// MARK: - SeedScanResult

public struct SeedScanResult: Sendable {
    public let rawText: String
    public let suggestedVariety: String?
    public let suggestedBrand: String?
    public let suggestedDepth: Double?
    public let suggestedSpacing: Double?
    public let suggestedDaysToGermination: Int?
    public let suggestedDaysToHarvest: Int?
    public let suggestedSun: SunExposure?

    public init(
        rawText: String,
        suggestedVariety: String? = nil,
        suggestedBrand: String? = nil,
        suggestedDepth: Double? = nil,
        suggestedSpacing: Double? = nil,
        suggestedDaysToGermination: Int? = nil,
        suggestedDaysToHarvest: Int? = nil,
        suggestedSun: SunExposure? = nil
    ) {
        self.rawText = rawText
        self.suggestedVariety = suggestedVariety
        self.suggestedBrand = suggestedBrand
        self.suggestedDepth = suggestedDepth
        self.suggestedSpacing = suggestedSpacing
        self.suggestedDaysToGermination = suggestedDaysToGermination
        self.suggestedDaysToHarvest = suggestedDaysToHarvest
        self.suggestedSun = suggestedSun
    }
}

// MARK: - SeedScannerService

@MainActor
@Observable
public final class SeedScannerService {
    public init() {}

    // MARK: - Public API

    public func recognizeText(from image: UIImage) async throws -> SeedScanResult {
        guard let cgImage = image.cgImage else {
            logger.error("Failed to get CGImage from UIImage")
            throw SeedScannerError.invalidImage
        }

        let recognizedText = try await performOCR(on: cgImage)
        logger.info("OCR recognized \(recognizedText.count) characters")
        return parsePacketText(recognizedText)
    }

    /// Parses seed packet text into structured fields. Public and nonisolated for testability.
    public nonisolated func parsePacketText(_ text: String) -> SeedScanResult {
        let lines = text.components(separatedBy: .newlines)
        let lowered = text.lowercased()

        let sun = parseSunExposure(lowered)
        let depth = parseDepth(lowered)
        let spacing = parseSpacing(lowered)
        let germination = parseDaysToGermination(lowered)
        let harvest = parseDaysToHarvest(lowered)
        let brand = parseBrand(lines)
        let variety = parseVariety(lines, brand: brand)

        return SeedScanResult(
            rawText: text,
            suggestedVariety: variety,
            suggestedBrand: brand,
            suggestedDepth: depth,
            suggestedSpacing: spacing,
            suggestedDaysToGermination: germination,
            suggestedDaysToHarvest: harvest,
            suggestedSun: sun
        )
    }

    // MARK: - OCR

    private nonisolated func performOCR(on cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsers

    private nonisolated func parseSunExposure(_ text: String) -> SunExposure? {
        if text.contains("full sun") {
            return .fullSun
        } else if text.contains("partial shade") || text.contains("part shade") {
            return .partialShade
        } else if text.contains("partial sun") || text.contains("part sun") {
            return .partialSun
        } else if text.contains("full shade") {
            return .fullShade
        }
        return nil
    }

    private nonisolated func parseDepth(_ text: String) -> Double? {
        // Match patterns like "depth: 1/4 inch", "1/2\" deep", "1/4 in. deep", "plant 1/2 inch deep"
        // swiftlint:disable:next line_length
        let fractionPattern = #"(?:depth[:\s]*|plant\s+)?((\d+)\s*/\s*(\d+))\s*(?:inch|in\.?|\")\s*(?:deep)?"#
        if let match = text.range(of: fractionPattern, options: .regularExpression) {
            let matched = String(text[match])
            if let fractionResult = extractFraction(from: matched) {
                return fractionResult
            }
        }

        // Match decimal patterns like "depth: 0.25 inch"
        let decimalPattern = #"(?:depth[:\s]*|plant\s+)?(\d+\.?\d*)\s*(?:inch|in\.?|\")\s*(?:deep)?"#
        if let match = text.range(of: decimalPattern, options: .regularExpression) {
            let matched = String(text[match])
            if let number = extractDecimal(from: matched) {
                return number
            }
        }

        return nil
    }

    private nonisolated func parseSpacing(_ text: String) -> Double? {
        // Match patterns like "space 12 inches apart", "thin to 12 inches", "spacing: 12 inches"
        let pattern = #"(?:space|spacing|thin to)[:\s]*(\d+\.?\d*)\s*(?:inch|in\.?|\")"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matched = String(text[match])
            return extractDecimal(from: matched)
        }
        return nil
    }

    private nonisolated func parseDaysToGermination(_ text: String) -> Int? {
        // "germination: 7 days" or "7-14 days to germination" or "germination 7 days"
        let patterns = [
            #"germination[:\s]*(\d+)[\s-]*(?:\d+\s*)?days?"#,
            #"(\d+)[\s-]*(?:\d+\s*)?days?\s*(?:to\s*)?germination"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                return extractFirstInt(from: matched)
            }
        }
        return nil
    }

    private nonisolated func parseDaysToHarvest(_ text: String) -> Int? {
        // "harvest: 75 days", "60 days to maturity", "days to harvest: 75"
        let patterns = [
            #"(?:harvest|maturity)[:\s]*(\d+)\s*days?"#,
            #"(\d+)\s*days?\s*(?:to\s*)?(?:harvest|maturity)"#,
            #"days?\s*to\s*(?:harvest|maturity)[:\s]*(\d+)"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                return extractFirstInt(from: matched)
            }
        }
        return nil
    }

    private nonisolated func parseBrand(_ lines: [String]) -> String? {
        // First non-empty line that is ≤30 chars and doesn't contain "seed" (case-insensitive)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.count <= 30 else { continue }
            guard !trimmed.lowercased().contains("seed") else { continue }
            return trimmed
        }
        return nil
    }

    private nonisolated func parseVariety(_ lines: [String], brand: String?) -> String? {
        // Second prominent line after brand, 3-50 chars
        var foundBrand = brand == nil
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if !foundBrand {
                if trimmed == brand {
                    foundBrand = true
                }
                continue
            }

            // Must be between 3-50 characters
            guard trimmed.count >= 3, trimmed.count <= 50 else { continue }
            // Skip lines that look like instructions rather than variety names
            let lowered = trimmed.lowercased()
            if lowered.contains("depth") || lowered.contains("space") || lowered.contains("thin to")
                || lowered.contains("germination") || lowered.contains("harvest")
                || lowered.contains("maturity") || lowered.contains("days")
            {
                continue
            }
            return trimmed
        }
        return nil
    }

    // MARK: - Helpers

    private nonisolated func extractFraction(from text: String) -> Double? {
        let pattern = #"(\d+)\s*/\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let numeratorRange = Range(match.range(at: 1), in: text),
              let denominatorRange = Range(match.range(at: 2), in: text),
              let numerator = Double(text[numeratorRange]),
              let denominator = Double(text[denominatorRange]),
              denominator > 0
        else {
            return nil
        }
        return numerator / denominator
    }

    private nonisolated func extractDecimal(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Double(text[range])
    }

    private nonisolated func extractFirstInt(from text: String) -> Int? {
        let pattern = #"(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[range])
    }
}

// MARK: - Errors

public enum SeedScannerError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "Could not process the image. Please try a different photo."

        case .recognitionFailed:
            "Text recognition failed. Please try again with a clearer image."
        }
    }
}

#endif
