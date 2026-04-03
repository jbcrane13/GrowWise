#if canImport(UIKit)
import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

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
}

#endif
