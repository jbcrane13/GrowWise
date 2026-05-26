import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct PlantDatabaseSeededContentTests {
    private struct ExpectedSeededPlant {
        let name: String
        let scientificName: String
        let type: PlantType
        let difficulty: DifficultyLevel
        let sunlight: SunlightLevel
        let watering: WateringFrequency
        let space: SpaceRequirement
        let description: String
        let careInstruction: String
        let companionPlants: [String]
    }

    private static let expectedSeededPlants = [
        ExpectedSeededPlant(
            name: "Tomato",
            scientificName: "Solanum lycopersicum",
            type: .vegetable,
            difficulty: .intermediate,
            sunlight: .fullSun,
            watering: .everyOtherDay,
            space: .medium,
            description: "Popular warm-season vegetable that produces nutritious fruits",
            careInstruction: "Provide support with stakes or cages",
            companionPlants: ["Basil", "Oregano", "Parsley", "Marigold"]
        ),
        ExpectedSeededPlant(
            name: "Basil",
            scientificName: "Ocimum basilicum",
            type: .herb,
            difficulty: .beginner,
            sunlight: .fullSun,
            watering: .daily,
            space: .small,
            description: "Aromatic herb perfect for cooking and companion planting",
            careInstruction: "Pinch flowers to encourage leaf growth",
            companionPlants: ["Tomatoes", "Peppers", "Oregano"]
        ),
        ExpectedSeededPlant(
            name: "Snake Plant",
            scientificName: "Dracaena trifasciata",
            type: .houseplant,
            difficulty: .beginner,
            sunlight: .fullShade,
            watering: .biweekly,
            space: .small,
            description: "Extremely low-maintenance upright plant that tolerates neglect and low light",
            careInstruction: "Allow soil to dry completely between waterings",
            companionPlants: ["ZZ Plant", "Pothos"]
        ),
        ExpectedSeededPlant(
            name: "Aloe Vera",
            scientificName: "Aloe barbadensis",
            type: .succulent,
            difficulty: .beginner,
            sunlight: .fullSun,
            watering: .biweekly,
            space: .small,
            description: "Medicinal succulent with healing gel in leaves",
            careInstruction: "Water deeply but infrequently",
            companionPlants: ["Jade Plant", "Echeveria"]
        ),
    ]

    private func seedAndFlush(
        dataService: DataService,
        plantDBService: PlantDatabaseService
    ) async throws {
        try await plantDBService.seedPlantDatabase()
        dataService.invalidateAllCaches()
    }

    @Test("Seeded database preserves curated plant fields")
    func seededDatabasePreservesCuratedPlantFields() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)

        let plantsByName = Dictionary(grouping: dataService.fetchPlantDatabase()) { $0.name ?? "" }

        for expected in Self.expectedSeededPlants {
            let plant = try #require(
                plantsByName[expected.name]?.first,
                "Expected seeded plant named \(expected.name)"
            )
            #expect(plant.scientificName == expected.scientificName)
            #expect(plant.plantType == expected.type)
            #expect(plant.difficultyLevel == expected.difficulty)
            #expect(plant.sunlightRequirement == expected.sunlight)
            #expect(plant.wateringFrequency == expected.watering)
            #expect(plant.spaceRequirement == expected.space)
            #expect(plant.isUserPlant == false)
            #expect(plant.notes?.contains(expected.description) == true)
            #expect(plant.notes?.contains("Care Instructions:") == true)
            #expect(plant.notes?.contains(expected.careInstruction) == true)
            #expect((plant.companionPlants ?? []) == expected.companionPlants)
        }
    }

    @Test("Seeded database includes practical tree and shrub coverage")
    func databaseIncludesPracticalTreeAndShrubCoverage() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let counts = plantDBService.getPlantCountByType()

        #expect((counts[.tree] ?? 0) >= 3)
        #expect((counts[.shrub] ?? 0) >= 3)
    }

    @Test("getRecommendedPlants returns results for a beginner profile")
    func getRecommendedPlantsForBeginnerProfile() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let profile = UserGardenProfile(
            skillLevel: .beginner,
            availableSpace: .small,
            timeCommitment: .minimal,
            gardenType: "outdoor"
        )
        let recommendations = plantDBService.getRecommendedPlants(for: profile, limit: 5)
        #expect(!recommendations.isEmpty)
        #expect(recommendations.count <= 5)
    }

    @Test("getRecommendedPlants compatibility scores are between 0 and 100")
    func recommendationCompatibilityScoresAreValid() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let profile = UserGardenProfile(
            skillLevel: .intermediate,
            availableSpace: .medium,
            timeCommitment: .moderate,
            gardenType: "raised_bed"
        )
        for rec in plantDBService.getRecommendedPlants(for: profile) {
            #expect(rec.compatibilityScore >= 0)
            #expect(rec.compatibilityScore <= 100)
        }
    }

    @Test("getRecommendedPlants returns non-empty reasons for each recommendation")
    func recommendationReasonsAreNonEmpty() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let profile = UserGardenProfile(
            skillLevel: .advanced,
            availableSpace: .large,
            timeCommitment: .heavy,
            gardenType: "outdoor"
        )
        for rec in plantDBService.getRecommendedPlants(for: profile, limit: 3) {
            #expect(!rec.reasons.isEmpty)
        }
    }

    @Test("getRecommendedPlants are sorted by descending compatibility score")
    func recommendationsAreSortedByScore() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let profile = UserGardenProfile(
            skillLevel: .beginner,
            availableSpace: .small,
            timeCommitment: .minimal,
            gardenType: "indoor"
        )
        let recommendations = plantDBService.getRecommendedPlants(for: profile)
        var previousScore = Double.infinity
        for rec in recommendations {
            #expect(rec.compatibilityScore <= previousScore)
            previousScore = rec.compatibilityScore
        }
    }

    @Test("getPlantsBySeason spring returns spring-appropriate plants")
    func getPlantsBySeasonSpring() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect(!plantDBService.getPlantsBySeason(.spring).isEmpty)
    }

    @Test("getPlantsBySeason winter returns only houseplants and succulents")
    func getPlantsBySeasonWinter() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        for plant in plantDBService.getPlantsBySeason(.winter) {
            let type = plant.plantType
            let isWinterSuitable = type == .houseplant || type == .succulent
            #expect(isWinterSuitable, "Unexpected plant type \(String(describing: type)) for winter season")
        }
    }

    @Test("getCompanionPlants returns curated seeded companion names")
    func getCompanionPlantsReturnsCuratedSeededCompanionNames() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)

        let tomato = try #require(plantDBService.searchPlants(query: "Tomato").first { $0.name == "Tomato" })
        let companionNames = Set(plantDBService.getCompanionPlants(for: tomato).compactMap(\.name))

        #expect(companionNames == Set(["Basil", "Oregano", "Parsley", "Marigold"]))

        let basil = try #require(plantDBService.searchPlants(query: "Basil").first { $0.name == "Basil" })
        let basilCompanionNames = Set(plantDBService.getCompanionPlants(for: basil).compactMap(\.name))

        #expect(basilCompanionNames == Set(["Tomato", "Bell Pepper", "Oregano"]))
    }

    @Test("getCompanionPlants falls back to type categories without curated names")
    func getCompanionPlantsFallsBackToTypeCategoriesWithoutCuratedNames() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)

        let plant = Plant(name: "Fallback Vegetable", plantType: .vegetable)
        plant.companionPlants = []

        for companion in plantDBService.getCompanionPlants(for: plant) {
            let type = companion.plantType
            let isValidCompanion = type == .herb || type == .flower
            #expect(isValidCompanion, "Unexpected companion type \(String(describing: type)) for vegetable")
        }
    }
}
