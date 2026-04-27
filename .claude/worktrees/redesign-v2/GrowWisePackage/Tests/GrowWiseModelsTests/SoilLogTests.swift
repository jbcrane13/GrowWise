import Testing
import Foundation
@testable import GrowWiseModels

@Suite("SoilLog Model Tests")
struct SoilLogTests {

    // MARK: - Initialization

    @Test("Default initialization sets id, logDate, createdDate, lastModified")
    func testDefaultInitialization() throws {
        let before = Date()
        let log = SoilLog()
        let after = Date()

        #expect(log.phLevel == nil)
        #expect(log.nitrogenLevel == nil)
        #expect(log.phosphorusLevel == nil)
        #expect(log.potassiumLevel == nil)

        let logDate = try #require(log.logDate)
        #expect(logDate >= before && logDate <= after)

        let created = try #require(log.createdDate)
        #expect(created >= before && created <= after)

        let modified = try #require(log.lastModified)
        #expect(modified >= before && modified <= after)
    }

    @Test("Initialization with all NPK and pH parameters")
    func testFullInitialization() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let log = SoilLog(
            logDate: date,
            phLevel: 6.5,
            nitrogenLevel: 30.0,
            phosphorusLevel: 15.0,
            potassiumLevel: 150.0
        )

        #expect(log.logDate == date)
        #expect(log.phLevel == 6.5)
        #expect(log.nitrogenLevel == 30.0)
        #expect(log.phosphorusLevel == 15.0)
        #expect(log.potassiumLevel == 150.0)
    }

    @Test("Initialization assigns a unique UUID each time")
    func testUniqueIDs() {
        let log1 = SoilLog()
        let log2 = SoilLog()
        #expect(log1.id != log2.id)
    }

    @Test("Optional properties start as nil after minimal init")
    func testNilOptionalProperties() {
        let log = SoilLog()
        #expect(log.calciumLevel == nil)
        #expect(log.magnesiumLevel == nil)
        #expect(log.sulfurLevel == nil)
        #expect(log.ironLevel == nil)
        #expect(log.manganeseLevel == nil)
        #expect(log.zincLevel == nil)
        #expect(log.copperLevel == nil)
        #expect(log.boronLevel == nil)
        #expect(log.molybdenumLevel == nil)
        #expect(log.organicMatter == nil)
        #expect(log.fertilizerApplied == nil)
        #expect(log.fertilizerAmount == nil)
        #expect(log.fertilizerType == nil)
        #expect(log.notes == nil)
        #expect(log.garden == nil)
        #expect(log.plant == nil)
    }

    // MARK: - npkDisplay

    @Test("npkDisplay returns formatted string when all values present")
    func testNPKDisplayWithAllValues() {
        let log = SoilLog(nitrogenLevel: 10.0, phosphorusLevel: 20.0, potassiumLevel: 30.0)
        #expect(log.npkDisplay == "10-20-30")
    }

    @Test("npkDisplay rounds to zero decimal places")
    func testNPKDisplayRounding() {
        let log = SoilLog(nitrogenLevel: 10.6, phosphorusLevel: 20.4, potassiumLevel: 150.9)
        #expect(log.npkDisplay == "11-20-151")
    }

    @Test("npkDisplay returns nil when nitrogen is missing")
    func testNPKDisplayNilNitrogen() {
        let log = SoilLog(nitrogenLevel: nil, phosphorusLevel: 20.0, potassiumLevel: 30.0)
        #expect(log.npkDisplay == nil)
    }

    @Test("npkDisplay returns nil when phosphorus is missing")
    func testNPKDisplayNilPhosphorus() {
        let log = SoilLog(nitrogenLevel: 10.0, phosphorusLevel: nil, potassiumLevel: 30.0)
        #expect(log.npkDisplay == nil)
    }

    @Test("npkDisplay returns nil when potassium is missing")
    func testNPKDisplayNilPotassium() {
        let log = SoilLog(nitrogenLevel: 10.0, phosphorusLevel: 20.0, potassiumLevel: nil)
        #expect(log.npkDisplay == nil)
    }

    @Test("npkDisplay returns nil when all NPK values are nil")
    func testNPKDisplayAllNil() {
        let log = SoilLog()
        #expect(log.npkDisplay == nil)
    }

    @Test("npkDisplay formats zero values correctly")
    func testNPKDisplayZeroValues() {
        let log = SoilLog(nitrogenLevel: 0.0, phosphorusLevel: 0.0, potassiumLevel: 0.0)
        #expect(log.npkDisplay == "0-0-0")
    }

    // MARK: - isPHOptimal boundaries

    @Test("isPHOptimal returns nil when phLevel is nil")
    func testIsPHOptimalNilPH() {
        let log = SoilLog()
        #expect(log.isPHOptimal == nil)
    }

    @Test("isPHOptimal returns false for pH 5.9 (below optimal)")
    func testIsPHOptimalBelowLowerBound() {
        let log = SoilLog(phLevel: 5.9)
        #expect(log.isPHOptimal == false)
    }

    @Test("isPHOptimal returns true for pH 6.0 (lower boundary)")
    func testIsPHOptimalAtLowerBound() {
        let log = SoilLog(phLevel: 6.0)
        #expect(log.isPHOptimal == true)
    }

    @Test("isPHOptimal returns true for pH 6.5 (middle of range)")
    func testIsPHOptimalMidRange() {
        let log = SoilLog(phLevel: 6.5)
        #expect(log.isPHOptimal == true)
    }

    @Test("isPHOptimal returns true for pH 7.0 (upper boundary)")
    func testIsPHOptimalAtUpperBound() {
        let log = SoilLog(phLevel: 7.0)
        #expect(log.isPHOptimal == true)
    }

    @Test("isPHOptimal returns false for pH 7.1 (above optimal)")
    func testIsPHOptimalAboveUpperBound() {
        let log = SoilLog(phLevel: 7.1)
        #expect(log.isPHOptimal == false)
    }

    // MARK: - phStatus descriptions

    @Test("phStatus returns nil when phLevel is nil")
    func testPHStatusNil() {
        let log = SoilLog()
        #expect(log.phStatus == nil)
    }

    @Test("phStatus returns Very Acidic for pH below 5.5")
    func testPHStatusVeryAcidic() {
        let log = SoilLog(phLevel: 4.0)
        #expect(log.phStatus == "Very Acidic")
    }

    @Test("phStatus returns Very Acidic at pH 5.499")
    func testPHStatusVeryAcidicBoundary() {
        let log = SoilLog(phLevel: 5.499)
        #expect(log.phStatus == "Very Acidic")
    }

    @Test("phStatus returns Acidic for pH in [5.5, 6.0)")
    func testPHStatusAcidic() {
        let log = SoilLog(phLevel: 5.5)
        #expect(log.phStatus == "Acidic")
    }

    @Test("phStatus returns Acidic at pH 5.9")
    func testPHStatusAcidicAt59() {
        let log = SoilLog(phLevel: 5.9)
        #expect(log.phStatus == "Acidic")
    }

    @Test("phStatus returns Optimal for pH in [6.0, 7.0]")
    func testPHStatusOptimal() {
        for ph in [6.0, 6.5, 7.0] {
            let log = SoilLog(phLevel: ph)
            #expect(log.phStatus == "Optimal", "Expected Optimal for pH \(ph)")
        }
    }

    @Test("phStatus returns Slightly Alkaline for pH in (7.0, 7.5]")
    func testPHStatusSlightlyAlkaline() {
        let log = SoilLog(phLevel: 7.3)
        #expect(log.phStatus == "Slightly Alkaline")
    }

    @Test("phStatus returns Slightly Alkaline at pH 7.5")
    func testPHStatusSlightlyAlkalineBoundary() {
        let log = SoilLog(phLevel: 7.5)
        #expect(log.phStatus == "Slightly Alkaline")
    }

    @Test("phStatus returns Alkaline for pH above 7.5")
    func testPHStatusAlkaline() {
        let log = SoilLog(phLevel: 8.5)
        #expect(log.phStatus == "Alkaline")
    }

    // MARK: - FertilizerType

    @Test("FertilizerType display names are non-empty")
    func testFertilizerTypeDisplayNames() {
        for type_ in FertilizerType.allCases {
            #expect(!type_.displayName.isEmpty, "displayName should not be empty for \(type_)")
        }
    }

    @Test("FertilizerType icon names are non-empty")
    func testFertilizerTypeIconNames() {
        for type_ in FertilizerType.allCases {
            #expect(!type_.iconName.isEmpty, "iconName should not be empty for \(type_)")
        }
    }

    // MARK: - SoilRecommendation

    @Test("SoilRecommendation isWithinRange returns true when level is inside range")
    func testSoilRecommendationWithinRange() {
        let rec = SoilRecommendation(
            nutrient: "Nitrogen",
            currentLevel: 30.0,
            optimalRange: 20.0...40.0,
            unit: "ppm",
            recommendation: "OK"
        )
        #expect(rec.isWithinRange == true)
        #expect(rec.status == .optimal)
    }

    @Test("SoilRecommendation status is low when below range")
    func testSoilRecommendationLow() {
        let rec = SoilRecommendation(
            nutrient: "Nitrogen",
            currentLevel: 5.0,
            optimalRange: 20.0...40.0,
            unit: "ppm",
            recommendation: "Add nitrogen"
        )
        #expect(rec.isWithinRange == false)
        #expect(rec.status == .low)
    }

    @Test("SoilRecommendation status is high when above range")
    func testSoilRecommendationHigh() {
        let rec = SoilRecommendation(
            nutrient: "Nitrogen",
            currentLevel: 80.0,
            optimalRange: 20.0...40.0,
            unit: "ppm",
            recommendation: "Reduce nitrogen"
        )
        #expect(rec.isWithinRange == false)
        #expect(rec.status == .high)
    }

    // MARK: - SoilTestRanges

    @Test("SoilTestRanges nitrogenStatus returns correct status")
    func testNitrogenStatus() {
        #expect(SoilTestRanges.nitrogenStatus(10.0) == .low)
        #expect(SoilTestRanges.nitrogenStatus(30.0) == .optimal)
        #expect(SoilTestRanges.nitrogenStatus(60.0) == .high)
    }

    @Test("SoilTestRanges phosphorusStatus returns correct status")
    func testPhosphorusStatus() {
        #expect(SoilTestRanges.phosphorusStatus(5.0) == .low)
        #expect(SoilTestRanges.phosphorusStatus(15.0) == .optimal)
        #expect(SoilTestRanges.phosphorusStatus(50.0) == .high)
    }

    @Test("SoilTestRanges potassiumStatus returns correct status")
    func testPotassiumStatus() {
        #expect(SoilTestRanges.potassiumStatus(50.0) == .low)
        #expect(SoilTestRanges.potassiumStatus(150.0) == .optimal)
        #expect(SoilTestRanges.potassiumStatus(300.0) == .high)
    }
}
