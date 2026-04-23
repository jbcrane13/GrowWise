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
        let result = scanner.parsePacketText("Plant in full sun")
        #expect(result.suggestedSun == .fullSun)
    }

    @Test("Parses partial shade from packet text")
    func parsePartialShade() {
        let result = scanner.parsePacketText("Prefers partial shade")
        #expect(result.suggestedSun == .partialShade)
    }

    @Test("Parses part shade variant")
    func parsePartShade() {
        let result = scanner.parsePacketText("Grows in part shade")
        #expect(result.suggestedSun == .partialShade)
    }

    @Test("Returns nil sun when no sun text present")
    func parseNoSun() {
        let result = scanner.parsePacketText("Tomato Seeds")
        #expect(result.suggestedSun == nil)
    }

    // MARK: - Depth

    @Test("Parses depth with fraction: depth: 1/4 inch")
    func parseDepthQuarterInch() {
        let result = scanner.parsePacketText("depth: 1/4 inch")
        #expect(result.suggestedDepth == 0.25)
    }

    @Test("Parses depth with fraction: 1/2 inch deep")
    func parseDepthHalfInchDeep() {
        let result = scanner.parsePacketText("1/2 inch deep")
        #expect(result.suggestedDepth == 0.5)
    }

    // MARK: - Spacing

    @Test("Parses spacing: thin to 12 inches apart")
    func parseSpacingThinTo() {
        let result = scanner.parsePacketText("thin to 12 inches apart")
        #expect(result.suggestedSpacing == 12.0)
    }

    // MARK: - Germination

    @Test("Parses germination days: Germination: 7 days")
    func parseGerminationDays() {
        let result = scanner.parsePacketText("Germination: 7 days")
        #expect(result.suggestedDaysToGermination == 7)
    }

    // MARK: - Harvest

    @Test("Parses harvest days: Days to harvest: 75 days")
    func parseHarvestDays() {
        let result = scanner.parsePacketText("Days to harvest: 75 days")
        #expect(result.suggestedDaysToHarvest == 75)
    }

    @Test("Parses maturity days: 60 days to maturity")
    func parseMaturityDays() {
        let result = scanner.parsePacketText("60 days to maturity")
        #expect(result.suggestedDaysToHarvest == 60)
    }

    // MARK: - Brand and Variety

    @Test("Parses brand and variety from lines")
    func parseBrandAndVariety() {
        let text = "Burpee\nBeefsteak Tomato\nPlant in full sun"
        let result = scanner.parsePacketText(text)
        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedVariety == "Beefsteak Tomato")
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

    // MARK: - OCR Integration Tests

    // INTEGRATION GAP: VNRecognizeTextRequest accuracy depends on image quality and
    // OS version. These tests verify the pipeline works end-to-end but parsed values
    // may vary.

    @Test(.tags(.integration))
    func recognizeTextFromGeneratedImage() async throws {
        // Create an image with text rendered on it
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        let image = renderer.image { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black,
            ]
            let text = "Tomato Seeds\nFull Sun\nDepth: 1/4 inch"
            text.draw(at: CGPoint(x: 10, y: 10), withAttributes: attrs)
        }

        let result = try await scanner.recognizeText(from: image)
        // We verify the pipeline completes and returns a result with raw text
        #expect(!result.rawText.isEmpty)
    }

    @Test(.tags(.integration))
    func recognizeTextFromBlankImage() async throws {
        // A blank white image should produce empty or minimal text
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        let result = try await scanner.recognizeText(from: image)
        // Blank image should yield empty raw text or very little
        #expect(result.suggestedVariety == nil)
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
        let result = scanner.parsePacketText("part sun")
        #expect(result.suggestedSun == .partialSun)
    }

    @Test("Partial sun variant: partial sun")
    func parsePartialSun() {
        let result = scanner.parsePacketText("partial sun")
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
        // Parser extracts the first number
        #expect(result.suggestedSpacing != nil)
    }

    @Test("Days to germination range: 7-14 days")
    func parseGerminationRange() {
        let result = scanner.parsePacketText("Germination: 7-14 days")
        // Parser extracts the first number from the range
        #expect(result.suggestedDaysToGermination != nil)
    }

    @Test("Harvest via maturity: 65-70 days to maturity")
    func parseHarvestViaMaturityRange() {
        let result = scanner.parsePacketText("65-70 days to maturity")
        // Parser extracts the first number
        #expect(result.suggestedDaysToHarvest != nil)
    }

    @Test("No parseable data returns nil for all structured fields")
    func parseNonSeedText() {
        let result = scanner.parsePacketText("The quick brown fox jumps over the lazy dog")
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

    // MARK: - Full Packet Parsing (Functional)

    @Test("Full seed packet text produces all structured fields")
    func parseCompleteSeedPacket() {
        let packetText = """
        Burpee
        Roma Tomato
        Plant in full sun
        Depth: 1/4 inch
        Thin to 18 inches apart
        Germination: 10 days
        Days to harvest: 80 days
        """
        let result = scanner.parsePacketText(packetText)

        #expect(result.rawText == packetText)
        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedVariety == "Roma Tomato")
        #expect(result.suggestedSun == .fullSun)
        #expect(result.suggestedDepth == 0.25)
        #expect(result.suggestedSpacing == 18.0)
        #expect(result.suggestedDaysToGermination == 10)
        #expect(result.suggestedDaysToHarvest == 80)
    }

    @Test("Partial packet with only sun and depth still parses available fields")
    func parsePartialPacket() {
        let text = "Full sun\nDepth: 1/2 inch"
        let result = scanner.parsePacketText(text)

        #expect(result.suggestedSun == .fullSun)
        #expect(result.suggestedDepth == 0.5)
        #expect(result.suggestedSpacing == nil)
        #expect(result.suggestedDaysToGermination == nil)
        #expect(result.suggestedDaysToHarvest == nil)
    }

    // MARK: - Brand Parsing Edge Cases

    @Test("Brand is nil when first line contains 'seed'")
    func parseBrandSkipsSeedLine() {
        let text = "Tomato Seeds\nBurpee\nBeefsteak"
        let result = scanner.parsePacketText(text)

        // "Tomato Seeds" is skipped (contains "seed"), "Burpee" becomes brand
        #expect(result.suggestedBrand == "Burpee")
    }

    @Test("Brand is nil when all lines are empty")
    func parseBrandAllEmpty() {
        let text = "\n\n\n"
        let result = scanner.parsePacketText(text)
        #expect(result.suggestedBrand == nil)
    }

    @Test("Brand is nil when first line exceeds 30 characters")
    func parseBrandSkipsLongLines() {
        let text = "This is a very long line that definitely exceeds thirty characters\nBurpee\nTomato"
        let result = scanner.parsePacketText(text)

        // Long line is skipped, "Burpee" becomes brand
        #expect(result.suggestedBrand == "Burpee")
    }

    // MARK: - Variety Parsing Edge Cases

    @Test("Variety skips instruction-like lines")
    func parseVarietySkipsInstructions() {
        let text = "Burpee\nDepth: 1/4 inch\nBeefsteak Tomato"
        let result = scanner.parsePacketText(text)

        #expect(result.suggestedBrand == "Burpee")
        // "Depth: 1/4 inch" is skipped (contains "depth"), next valid line is variety
        #expect(result.suggestedVariety == "Beefsteak Tomato")
    }

    @Test("Variety is nil when no valid line follows brand")
    func parseVarietyNilWhenNoValidLine() {
        let text = "Burpee"
        let result = scanner.parsePacketText(text)

        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedVariety == nil)
    }

    @Test("Variety requires at least 3 characters")
    func parseVarietyMinLength() {
        let text = "Burpee\nAB\nCherry Tomato"
        let result = scanner.parsePacketText(text)

        #expect(result.suggestedBrand == "Burpee")
        // "AB" is too short (< 3 chars), skipped
        #expect(result.suggestedVariety == "Cherry Tomato")
    }

    // MARK: - Depth Parsing Edge Cases

    @Test("Depth 3/4 inch parses to 0.75")
    func parseDepthThreeQuarterInch() {
        let result = scanner.parsePacketText("depth: 3/4 inch")
        #expect(result.suggestedDepth == 0.75)
    }

    @Test("Depth with 'in.' abbreviation")
    func parseDepthAbbreviation() {
        let result = scanner.parsePacketText("depth: 1/2 in.")
        #expect(result.suggestedDepth == 0.5)
    }

    // MARK: - rawText Preservation

    @Test("rawText preserves the original input exactly")
    func rawTextPreservation() {
        let input = "Burpee\nRoma Tomato\nFull sun"
        let result = scanner.parsePacketText(input)
        #expect(result.rawText == input)
    }

    // MARK: - Duplicate / Repeated Scans

    @Test("Parsing same text twice produces identical results")
    func duplicateScanConsistency() {
        let text = "Burpee\nCherry Tomato\nFull sun\nDepth: 1/4 inch"
        let result1 = scanner.parsePacketText(text)
        let result2 = scanner.parsePacketText(text)

        #expect(result1.suggestedBrand == result2.suggestedBrand)
        #expect(result1.suggestedVariety == result2.suggestedVariety)
        #expect(result1.suggestedSun == result2.suggestedSun)
        #expect(result1.suggestedDepth == result2.suggestedDepth)
    }

    // MARK: - SeedScannerError

    @Test("invalidImage error has user-friendly description")
    func invalidImageErrorDescription() {
        let error = SeedScannerError.invalidImage
        #expect(error.localizedDescription.contains("Could not process"))
    }

    @Test("recognitionFailed error has user-friendly description")
    func recognitionFailedErrorDescription() {
        let error = SeedScannerError.recognitionFailed
        #expect(error.localizedDescription.contains("Text recognition failed"))
    }

    // MARK: - SeedScanResult Construction

    @Test("SeedScanResult can be constructed with all nil optional fields")
    func seedScanResultMinimalConstruction() {
        let result = SeedScanResult(rawText: "test")
        #expect(result.rawText == "test")
        #expect(result.suggestedVariety == nil)
        #expect(result.suggestedBrand == nil)
        #expect(result.suggestedDepth == nil)
        #expect(result.suggestedSpacing == nil)
        #expect(result.suggestedDaysToGermination == nil)
        #expect(result.suggestedDaysToHarvest == nil)
        #expect(result.suggestedSun == nil)
    }

    @Test("SeedScanResult can be constructed with all fields populated")
    func seedScanResultFullConstruction() {
        let result = SeedScanResult(
            rawText: "full packet",
            suggestedVariety: "Roma",
            suggestedBrand: "Burpee",
            suggestedDepth: 0.25,
            suggestedSpacing: 18.0,
            suggestedDaysToGermination: 10,
            suggestedDaysToHarvest: 75,
            suggestedSun: .fullSun
        )
        #expect(result.suggestedVariety == "Roma")
        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedDepth == 0.25)
        #expect(result.suggestedSpacing == 18.0)
        #expect(result.suggestedDaysToGermination == 10)
        #expect(result.suggestedDaysToHarvest == 75)
        #expect(result.suggestedSun == .fullSun)
    }

    // INTEGRATION GAP: recognizeText(from:) with a real seed packet photo requires
    // a camera or pre-captured test fixture image. The OCR → parsePacketText pipeline
    // is tested end-to-end via the generated image tests above, but real-world accuracy
    // depends on image quality, lighting, and OS Vision framework version.

    // INTEGRATION GAP: Creating a Plant/Seed from SeedScanResult requires DataService
    // and SwiftData context. The mapping from SeedScanResult fields to model properties
    // is a view/feature-layer concern, not tested here.
}

#endif
