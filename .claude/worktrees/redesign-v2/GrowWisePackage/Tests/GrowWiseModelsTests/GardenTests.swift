import Testing
import Foundation
@testable import GrowWiseModels

@Suite("Garden Model Tests")
struct GardenTests {

    @Test("Garden initialization with defaults")
    func testGardenInitialization() {
        let garden = Garden(name: "My Garden")
        #expect(garden.name == "My Garden")
        #expect(garden.gardenType == .outdoor)
        #expect(garden.isIndoor == false)
        #expect(garden.sunExposure == .fullSun)
        #expect(garden.soilType == .loam)
        #expect(garden.spaceAvailable == .small)
        #expect(garden.plants?.isEmpty ?? true)
        #expect(garden.id != nil)
        #expect(garden.createdDate != nil)
        #expect(garden.lastModified != nil)
    }

    @Test("Garden initialization with custom type and indoor flag")
    func testGardenInitializationCustomType() {
        let garden = Garden(name: "Indoor Herb Garden", gardenType: .indoor, isIndoor: true)
        #expect(garden.name == "Indoor Herb Garden")
        #expect(garden.gardenType == .indoor)
        #expect(garden.isIndoor == true)
    }

    @Test("Garden initialization with all garden types")
    func testGardenInitializationAllTypes() {
        for gardenType in GardenType.allCases {
            let garden = Garden(name: "Test", gardenType: gardenType)
            #expect(garden.gardenType == gardenType)
        }
    }

    @Test("GardenType display names")
    func testGardenTypeDisplayNames() {
        #expect(GardenType.outdoor.displayName == "Outdoor Garden")
        #expect(GardenType.indoor.displayName == "Indoor Garden")
        #expect(GardenType.container.displayName == "Container Garden")
        #expect(GardenType.raised.displayName == "Raised Bed Garden")
        #expect(GardenType.hydroponic.displayName == "Hydroponic System")
        #expect(GardenType.greenhouse.displayName == "Greenhouse")
        #expect(GardenType.balcony.displayName == "Balcony Garden")
        #expect(GardenType.windowsill.displayName == "Windowsill Garden")
    }

    @Test("SunExposure hours of sunlight")
    func testSunExposureHoursOfSunlight() {
        #expect(SunExposure.fullSun.hoursOfSunlight == 8)
        #expect(SunExposure.partialSun.hoursOfSunlight == 5)
        #expect(SunExposure.partialShade.hoursOfSunlight == 3)
        #expect(SunExposure.fullShade.hoursOfSunlight == 1)
        #expect(SunExposure.artificial.hoursOfSunlight == 12)
    }

    @Test("SunExposure display names")
    func testSunExposureDisplayNames() {
        #expect(SunExposure.fullSun.displayName == "Full Sun (6+ hours)")
        #expect(SunExposure.partialSun.displayName == "Partial Sun (4-6 hours)")
        #expect(SunExposure.partialShade.displayName == "Partial Shade (2-4 hours)")
        #expect(SunExposure.fullShade.displayName == "Full Shade (< 2 hours)")
        #expect(SunExposure.artificial.displayName == "Artificial Light")
    }

    @Test("SoilType drainage levels")
    func testSoilTypeDrainageLevels() {
        #expect(SoilType.clay.drainageLevel == .poor)
        #expect(SoilType.loam.drainageLevel == .good)
        #expect(SoilType.sand.drainageLevel == .excellent)
        #expect(SoilType.silt.drainageLevel == .fair)
        #expect(SoilType.chalk.drainageLevel == .good)
        #expect(SoilType.peat.drainageLevel == .poor)
        #expect(SoilType.potting.drainageLevel == .good)
        #expect(SoilType.compost.drainageLevel == .good)
        #expect(SoilType.hydroponic.drainageLevel == .excellent)
    }

    @Test("SoilType display names")
    func testSoilTypeDisplayNames() {
        #expect(SoilType.clay.displayName == "Clay Soil")
        #expect(SoilType.loam.displayName == "Loam Soil")
        #expect(SoilType.sand.displayName == "Sandy Soil")
        #expect(SoilType.silt.displayName == "Silty Soil")
        #expect(SoilType.chalk.displayName == "Chalky Soil")
        #expect(SoilType.peat.displayName == "Peaty Soil")
        #expect(SoilType.potting.displayName == "Potting Mix")
        #expect(SoilType.compost.displayName == "Compost")
        #expect(SoilType.hydroponic.displayName == "Hydroponic Medium")
    }

    @Test("DrainageLevel display names")
    func testDrainageLevelDisplayNames() {
        #expect(DrainageLevel.poor.displayName == "Poor Drainage")
        #expect(DrainageLevel.fair.displayName == "Fair Drainage")
        #expect(DrainageLevel.good.displayName == "Good Drainage")
        #expect(DrainageLevel.excellent.displayName == "Excellent Drainage")
    }

    @Test("SpaceSize square footage values")
    func testSpaceSizeSquareFeet() {
        #expect(SpaceSize.tiny.squareFeet == 5)
        #expect(SpaceSize.small.squareFeet == 30)
        #expect(SpaceSize.medium.squareFeet == 125)
        #expect(SpaceSize.large.squareFeet == 350)
        #expect(SpaceSize.extraLarge.squareFeet == 750)
    }

    @Test("SpaceSize recommended plant counts")
    func testSpaceSizeRecommendedPlantCount() {
        #expect(SpaceSize.tiny.recommendedPlantCount == 3)
        #expect(SpaceSize.small.recommendedPlantCount == 8)
        #expect(SpaceSize.medium.recommendedPlantCount == 20)
        #expect(SpaceSize.large.recommendedPlantCount == 40)
        #expect(SpaceSize.extraLarge.recommendedPlantCount == 80)
    }

    @Test("SpaceSize display names")
    func testSpaceSizeDisplayNames() {
        #expect(SpaceSize.tiny.displayName == "Tiny (< 10 sq ft)")
        #expect(SpaceSize.small.displayName == "Small (10-50 sq ft)")
        #expect(SpaceSize.medium.displayName == "Medium (50-200 sq ft)")
        #expect(SpaceSize.large.displayName == "Large (200-500 sq ft)")
        #expect(SpaceSize.extraLarge.displayName == "Extra Large (> 500 sq ft)")
    }

    @Test("SpaceSize plant counts are in ascending order")
    func testSpaceSizePlantCountsAscending() {
        let sizes = SpaceSize.allCases
        for i in 0..<sizes.count - 1 {
            #expect(sizes[i].recommendedPlantCount < sizes[i + 1].recommendedPlantCount)
        }
    }

    @Test("SpaceSize square feet are in ascending order")
    func testSpaceSizeSquareFeetAscending() {
        let sizes = SpaceSize.allCases
        for i in 0..<sizes.count - 1 {
            #expect(sizes[i].squareFeet < sizes[i + 1].squareFeet)
        }
    }
}
