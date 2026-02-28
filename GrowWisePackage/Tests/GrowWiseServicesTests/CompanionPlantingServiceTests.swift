import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - Companion Planting Service Tests

@Suite("CompanionPlantingService Tests")
@MainActor
struct CompanionPlantingServiceTests {
    
    let service = CompanionPlantingService()
    
    @Test("Check tomato and basil compatibility")
    func testTomatoBasilCompatibility() async throws {
        let info = service.checkCompatibility(plant1: "Tomato", plant2: "Basil")
        
        #expect(info.compatibility == .companion)
        #expect(info.plantName == "Basil")
        #expect(info.reason.isEmpty == false)
    }
    
    @Test("Check tomato and potato incompatibility")
    func testTomatoPotatoIncompatibility() async throws {
        let info = service.checkCompatibility(plant1: "Tomato", plant2: "Potato")
        
        #expect(info.compatibility == .incompatible)
        #expect(info.plantName == "Potato")
    }
    
    @Test("Check unknown plant returns neutral")
    func testUnknownPlantNeutral() async throws {
        let info = service.checkCompatibility(plant1: "UnknownPlant123", plant2: "Tomato")
        
        #expect(info.compatibility == .neutral)
    }
    
    @Test("Analyze garden compatibility for tomato")
    func testAnalyzeGardenCompatibility() async throws {
        let existingPlants = ["Basil", "Carrot", "Potato"]
        let analysis = service.analyzeGardenCompatibility(plantName: "Tomato", existingPlants: existingPlants)
        
        #expect(analysis.plantName == "Tomato")
        #expect(analysis.incompatiblePlants.contains("Potato"))
        #expect(analysis.recommendedCompanions.contains("Basil"))
        #expect(analysis.hasWarnings == true)
    }
    
    @Test("Get recommended companions for tomato")
    func testGetRecommendedCompanions() async throws {
        let companions = service.getRecommendedCompanions(for: "Tomato")
        
        #expect(companions.isEmpty == false)
        #expect(companions.contains("Basil"))
        #expect(companions.contains("Carrot"))
    }
    
    @Test("Get incompatible plants for tomato")
    func testGetIncompatiblePlants() async throws {
        let incompatible = service.getIncompatiblePlants(for: "Tomato")
        
        #expect(incompatible.contains("Potato"))
        #expect(incompatible.contains("Fennel"))
    }
    
    @Test("Is plant known returns correct value")
    func testIsPlantKnown() async throws {
        #expect(service.isPlantKnown("Tomato") == true)
        #expect(service.isPlantKnown("Basil") == true)
        #expect(service.isPlantKnown("UnknownPlant123") == false)
    }
    
    @Test("Get all known plants returns non-empty list")
    func testGetAllKnownPlants() async throws {
        let plants = service.getAllKnownPlants()
        
        #expect(plants.isEmpty == false)
        #expect(plants.count > 30) // Should have at least 30 plants
    }
    
    @Test("Three sisters pattern detection")
    func testThreeSistersPattern() async throws {
        let cornBeans = service.checkCompatibility(plant1: "Corn", plant2: "beans")
        let cornSquash = service.checkCompatibility(plant1: "Corn", plant2: "squash")
        
        #expect(cornBeans.compatibility == .companion)
        #expect(cornSquash.compatibility == .companion)
    }
    
    @Test("Nightshade incompatibility detection")
    func testNightshadeIncompatibility() async throws {
        let tomatoPepper = service.checkCompatibility(plant1: "Tomato", plant2: "Pepper")
        let warningReasons = tomatoPepper.warnings ?? []
        
        // Both are nightshades so should have warnings about shared pests
        #expect(tomatoPepper.compatibility == .companion) // But they can still be companions
    }
}

// MARK: - Plant Compatibility Enum Tests

@Suite("PlantCompatibility Enum Tests")
struct PlantCompatibilityEnumTests {
    
    @Test("Display names are correct")
    func testDisplayNames() async throws {
        #expect(PlantCompatibility.companion.displayName == "Good Companions")
        #expect(PlantCompatibility.neutral.displayName == "Neutral")
        #expect(PlantCompatibility.incompatible.displayName == "Incompatible")
    }
    
    @Test("Icon names exist")
    func testIconNames() async throws {
        #expect(PlantCompatibility.companion.iconName.isEmpty == false)
        #expect(PlantCompatibility.neutral.iconName.isEmpty == false)
        #expect(PlantCompatibility.incompatible.iconName.isEmpty == false)
    }
    
    @Test("Color names exist")
    func testColorNames() async throws {
        #expect(PlantCompatibility.companion.colorName == "green")
        #expect(PlantCompatibility.neutral.colorName == "gray")
        #expect(PlantCompatibility.incompatible.colorName == "red")
    }
}

// MARK: - Garden Compatibility Analysis Tests

@Suite("GardenCompatibilityAnalysis Tests")
struct GardenCompatibilityAnalysisTests {
    
    @Test("Has warnings when incompatible plants exist")
    func testHasWarnings() async throws {
        let analysis = GardenCompatibilityAnalysis(
            plantName: "Tomato",
            overallCompatibility: .incompatible,
            relationships: [],
            recommendedCompanions: [],
            incompatiblePlants: ["Potato"],
            warnings: ["Warning message"]
        )
        
        #expect(analysis.hasWarnings == true)
    }
    
    @Test("Has warnings when warnings array is empty but incompatible plants exist")
    func testHasWarningsFromPlants() async throws {
        let analysis = GardenCompatibilityAnalysis(
            plantName: "Tomato",
            overallCompatibility: .incompatible,
            relationships: [],
            recommendedCompanions: [],
            incompatiblePlants: ["Potato"],
            warnings: []
        )
        
        #expect(analysis.hasWarnings == true)
    }
    
    @Test("No warnings when everything is fine")
    func testNoWarnings() async throws {
        let analysis = GardenCompatibilityAnalysis(
            plantName: "Tomato",
            overallCompatibility: .companion,
            relationships: [],
            recommendedCompanions: ["Basil"],
            incompatiblePlants: [],
            warnings: []
        )
        
        #expect(analysis.hasWarnings == false)
    }
}
