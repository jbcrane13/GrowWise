import Testing
import Foundation
@testable import GrowWiseModels

@Suite("Plant Model Tests")
struct PlantTests {
    
    @Test("Plant initialization with valid data")
    func testPlantInitialization() async throws {
        // Arrange
        let name = "Tomato"
        let plantType = PlantType.vegetable
        let difficultyLevel = DifficultyLevel.beginner
        
        // Act
        let plant = Plant(name: name, plantType: plantType, difficultyLevel: difficultyLevel)
        
        // Assert
        #expect(plant.name == name)
        #expect(plant.plantType == plantType)
        #expect(plant.difficultyLevel == difficultyLevel)
        #expect(plant.isUserPlant == true)
        #expect(plant.id != UUID())
        #expect(plant.sunlightRequirement == .fullSun)
        #expect(plant.wateringFrequency == .daily)
        #expect(plant.spaceRequirement == .small)
        #expect(plant.growthStage == .seedling)
        #expect(plant.healthStatus == .healthy)
        #expect(plant.notes.isEmpty)
        #expect(plant.photoURLs.isEmpty)
        #expect(plant.reminders.isEmpty)
        #expect(plant.journalEntries.isEmpty)
        #expect(plant.companionPlants.isEmpty)
    }
    
    @Test("Plant type display names")
    func testPlantTypeDisplayNames() async throws {
        #expect(PlantType.vegetable.displayName == "Vegetable")
        #expect(PlantType.herb.displayName == "Herb")
        #expect(PlantType.flower.displayName == "Flower")
        #expect(PlantType.houseplant.displayName == "Houseplant")
        #expect(PlantType.fruit.displayName == "Fruit")
        #expect(PlantType.succulent.displayName == "Succulent")
        #expect(PlantType.tree.displayName == "Tree")
        #expect(PlantType.shrub.displayName == "Shrub")
    }
    
    @Test("Difficulty level descriptions")
    func testDifficultyLevelDescriptions() async throws {
        #expect(DifficultyLevel.beginner.description == "Easy to grow, forgiving")
        #expect(DifficultyLevel.intermediate.description == "Some experience helpful")
        #expect(DifficultyLevel.advanced.description == "Requires expertise")
    }
    
    @Test("Sunlight level display names")
    func testSunlightLevelDisplayNames() async throws {
        #expect(SunlightLevel.fullSun.displayName == "Full Sun (6+ hours)")
        #expect(SunlightLevel.partialSun.displayName == "Partial Sun (4-6 hours)")
        #expect(SunlightLevel.partialShade.displayName == "Partial Shade (2-4 hours)")
        #expect(SunlightLevel.fullShade.displayName == "Full Shade (< 2 hours)")
    }
    
    @Test("Watering frequency day values")
    func testWateringFrequencyDayValues() async throws {
        #expect(WateringFrequency.daily.days == 1)
        #expect(WateringFrequency.everyOtherDay.days == 2)
        #expect(WateringFrequency.twiceWeekly.days == 3)
        #expect(WateringFrequency.weekly.days == 7)
        #expect(WateringFrequency.biweekly.days == 14)
        #expect(WateringFrequency.monthly.days == 30)
        #expect(WateringFrequency.asNeeded.days == 0)
    }
    
    @Test("Growth stage display names")
    func testGrowthStageDisplayNames() async throws {
        #expect(GrowthStage.seed.displayName == "Seed")
        #expect(GrowthStage.seedling.displayName == "Seedling")
        #expect(GrowthStage.vegetative.displayName == "Vegetative Growth")
        #expect(GrowthStage.flowering.displayName == "Flowering")
        #expect(GrowthStage.fruiting.displayName == "Fruiting")
        #expect(GrowthStage.mature.displayName == "Mature")
        #expect(GrowthStage.dormant.displayName == "Dormant")
    }
    
    @Test("Health status colors")
    func testHealthStatusColors() async throws {
        #expect(HealthStatus.healthy.color == "green")
        #expect(HealthStatus.needsAttention.color == "yellow")
        #expect(HealthStatus.sick.color == "orange")
        #expect(HealthStatus.dying.color == "red")
        #expect(HealthStatus.dead.color == "gray")
    }
    
    @Test("Container type display names")
    func testContainerTypeDisplayNames() async throws {
        #expect(ContainerType.inGround.displayName == "In Ground")
        #expect(ContainerType.raisedBed.displayName == "Raised Bed")
        #expect(ContainerType.container.displayName == "Container/Pot")
        #expect(ContainerType.hangingBasket.displayName == "Hanging Basket")
        #expect(ContainerType.windowBox.displayName == "Window Box")
        #expect(ContainerType.greenhouse.displayName == "Greenhouse")
        #expect(ContainerType.indoor.displayName == "Indoor")
    }
    
    @Test("Space requirement display names")
    func testSpaceRequirementDisplayNames() async throws {
        #expect(SpaceRequirement.small.displayName == "Small (< 1 sq ft)")
        #expect(SpaceRequirement.medium.displayName == "Medium (1-4 sq ft)")
        #expect(SpaceRequirement.large.displayName == "Large (4-9 sq ft)")
        #expect(SpaceRequirement.extraLarge.displayName == "Extra Large (> 9 sq ft)")
    }
    
    @Test("Plant initialization with database plant flag")
    func testDatabasePlantInitialization() async throws {
        // Arrange & Act
        let plant = Plant(name: "Database Plant", plantType: .herb, isUserPlant: false)
        
        // Assert
        #expect(plant.isUserPlant == false)
        #expect(plant.name == "Database Plant")
        #expect(plant.plantType == .herb)
    }
    
    @Test("Plant initialization with all plant types")
    func testPlantInitializationWithAllTypes() async throws {
        let name = "Test Plant"
        
        for plantType in PlantType.allCases {
            let plant = Plant(name: name, plantType: plantType)
            #expect(plant.plantType == plantType)
            #expect(plant.name == name)
            #expect(plant.isUserPlant == true) // Default value
        }
    }
    
    @Test("Plant initialization with all difficulty levels")
    func testPlantInitializationWithAllDifficultyLevels() async throws {
        let name = "Test Plant"
        let plantType = PlantType.vegetable
        
        for difficulty in DifficultyLevel.allCases {
            let plant = Plant(name: name, plantType: plantType, difficultyLevel: difficulty)
            #expect(plant.difficultyLevel == difficulty)
            #expect(plant.name == name)
            #expect(plant.plantType == plantType)
        }
    }
}