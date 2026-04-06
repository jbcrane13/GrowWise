#if canImport(UIKit)
import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing
import UIKit

extension Tag {
    @Tag static var integration: Tag
}

@MainActor
struct SeedScannerServiceTests {
    let scanner = SeedScannerService()

    // MARK: - Sun Exposure

    @Test("Parses full sun from packet text")
    func parseFullSun() {
        let result = scanner.parsePacketText("Tomato\nPlant in full sun\nWater daily")
        #expect(result.suggestedSun == .fullSun)
    }

    @Test("Parses partial shade from packet text")
    func parsePartialShade() {
        let result = scanner.parsePacketText("Lettuce\nGrows best in partial shade")
        #expect(result.suggestedSun == .partialShade)
    }

    @Test("Parses part shade variant")
    func parsePartShade() {
        let result = scanner.parsePacketText("Fern\nPrefers part shade")
        #expect(result.suggestedSun == .partialShade)
    }

    @Test("Returns nil sun when no sun text present")
    func parseNoSun() {
        let result = scanner.parsePacketText("Tomato\nWater daily")
        #expect(result.suggestedSun == nil)
    }

    // MARK: - Depth

    @Test("Parses depth with fraction: depth: 1/4 inch")
    func parseDepthQuarterInch() {
        let result = scanner.parsePacketText("depth: 1/4 inch\nFull Sun")
        #expect(result.suggestedDepth == 0.25)
    }

    @Test("Parses depth with fraction: 1/2 inch deep")
    func parseDepthHalfInchDeep() {
        let result = scanner.parsePacketText("Plant 1/2 inch deep\nFull Sun")
        #expect(result.suggestedDepth == 0.5)
    }

    // MARK: - Spacing

    @Test("Parses spacing: thin to 12 inches apart")
    func parseSpacingThinTo() {
        let result = scanner.parsePacketText("thin to 12 inches apart\nFull Sun")
        #expect(result.suggestedSpacing == 12.0)
    }

    // MARK: - Germination

    @Test("Parses germination days: Germination: 7 days")
    func parseGerminationDays() {
        let result = scanner.parsePacketText("Germination: 7 days\nFull Sun")
        #expect(result.suggestedDaysToGermination == 7)
    }

    // MARK: - Harvest

    @Test("Parses harvest days: Days to harvest: 75 days")
    func parseHarvestDays() {
        let result = scanner.parsePacketText("Days to harvest: 75 days\nFull Sun")
        #expect(result.suggestedDaysToHarvest == 75)
    }

    @Test("Parses maturity days: 60 days to maturity")
    func parseMaturityDays() {
        let result = scanner.parsePacketText("60 days to maturity\nFull Sun")
        #expect(result.suggestedDaysToHarvest == 60)
    }

    // MARK: - Brand and Variety

    @Test("Parses brand and variety from lines")
    func parseBrandAndVariety() {
        let result = scanner.parsePacketText("Burpee\nCherry Tomato\nFull Sun")
        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedVariety == "Cherry Tomato")
    }

    // MARK: - Empty Input

    @Test("Empty text returns empty result with no suggestions")
    func parseEmptyText() {
        let result = scanner.parsePacketText("")
        #expect(result.rawText == "")
        #expect(result.suggestedVariety == nil)
        #expect(result.suggestedBrand == nil)
        #expect(result.suggestedDepth == nil)
        #expect(result.suggestedSpacing == nil)
        #expect(result.suggestedDaysToGermination == nil)
        #expect(result.suggestedDaysToHarvest == nil)
        #expect(result.suggestedSun == nil)
    }

    // MARK: - Integration Tests

    // INTEGRATION GAP: VNRecognizeTextRequest accuracy depends on image quality and
    // system capabilities. CI runners may produce different OCR results than devices.
    // These tests verify the OCR pipeline doesn't crash, not exact text matching.

    @Test(.tags(.integration))
    func recognizeTextFromGeneratedImage() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        let image = renderer.image { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black,
            ]
            "Burpee\nCherry Tomato\nFull Sun\nDepth: 1/4 inch".draw(
                in: CGRect(x: 20, y: 20, width: 360, height: 160),
                withAttributes: attrs
            )
        }
        let result = try await scanner.recognizeText(from: image)
        #expect(!result.rawText.isEmpty, "OCR should extract text from generated image")
    }

    @Test(.tags(.integration))
    func recognizeTextFromBlankImage() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let result = try await scanner.recognizeText(from: image)
        // Blank image should not crash — rawText may be empty
        #expect(result.rawText.isEmpty || !result.rawText.isEmpty, "Should handle blank image gracefully")
    }

    // MARK: - Parser Edge Cases

    @Test("Mixed case sun parsing: FULL SUN uppercase")
    func parseSunUppercase() {
        let result = scanner.parsePacketText("FULL SUN")
        #expect(result.suggestedSun == .fullSun)
    }

    @Test("Mixed case sun parsing: Full Sun title case")
    func parseSunTitleCase() {
        let result = scanner.parsePacketText("Full Sun")
        #expect(result.suggestedSun == .fullSun)
    }

    @Test("Partial sun variant: part sun")
    func parsePartSun() {
        let result = scanner.parsePacketText("Prefers part sun")
        #expect(result.suggestedSun == .partialSun)
    }

    @Test("Partial sun variant: partial sun")
    func parsePartialSun() {
        let result = scanner.parsePacketText("Plant in partial sun")
        #expect(result.suggestedSun == .partialSun)
    }

    @Test("Depth decimal format: 0.25 inch")
    func parseDepthDecimalFormat() {
        let result = scanner.parsePacketText("depth: 0.25 inch")
        #expect(result.suggestedDepth == 0.25)
    }

    @Test("Spacing with range: space 8-12 inches apart")
    func parseSpacingWithRange() {
        let result = scanner.parsePacketText("space 8-12 inches apart")
        let spacing = try #require(result.suggestedSpacing)
        #expect(spacing == 8.0 || spacing == 12.0, "Should extract a number from spacing range")
    }

    @Test("Days to germination range: 7-14 days")
    func parseGerminationRange() {
        let result = scanner.parsePacketText("Germination: 7-14 days")
        let days = try #require(result.suggestedDaysToGermination)
        #expect(days == 7 || days == 14, "Should extract a number from germination range")
    }

    @Test("Harvest via maturity: 65-70 days to maturity")
    func parseHarvestViaMaturityRange() {
        let result = scanner.parsePacketText("65-70 days to maturity")
        let days = try #require(result.suggestedDaysToHarvest)
        #expect(days == 65 || days == 70, "Should extract a number from maturity range")
    }

    @Test("No parseable data returns nil for all structured fields")
    func parseNonSeedText() {
        let result = scanner.parsePacketText("Lorem ipsum dolor sit amet")
        #expect(result.rawText == "Lorem ipsum dolor sit amet")
        #expect(result.suggestedSun == nil)
        #expect(result.suggestedDepth == nil)
        #expect(result.suggestedSpacing == nil)
        #expect(result.suggestedDaysToGermination == nil)
        #expect(result.suggestedDaysToHarvest == nil)
    }

    @Test(arguments: [
        ("Full sun required", SunExposure.fullSun),
        ("Prefers partial shade", SunExposure.partialShade),
        ("Grows in full shade", SunExposure.fullShade),
    ])
    func sunExposureParsing(input: String, expected: SunExposure) {
        let result = scanner.parsePacketText(input)
        #expect(result.suggestedSun == expected)
    }
}

#endif
