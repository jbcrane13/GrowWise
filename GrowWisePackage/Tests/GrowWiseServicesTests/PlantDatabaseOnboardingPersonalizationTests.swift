@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("Plant database onboarding personalization")
struct PlantDatabaseOnboardingPersonalizationTests {
    @Test("recommendations use onboarding food goals for plant type and reason")
    func recommendationsUseOnboardingFoodGoal() throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try seedRecommendationFixtures(dataService: dataService)

        let profile = UserGardenProfile(
            skillLevel: .beginner,
            availableSpace: .small,
            timeCommitment: .moderate,
            gardenType: "outdoor",
            preferredPlantTypes: [.vegetable, .herb, .fruit],
            gardeningGoals: [.growFood]
        )

        let recommendations = plantDBService.getRecommendedPlants(for: profile, limit: 2)

        #expect(recommendations.first?.plant.name == "Tomato")
        #expect(recommendations.first?.reasons.contains("Matches your Grow My Own Food goal") == true)
    }

    private func seedRecommendationFixtures(dataService: DataService) throws {
        try dataService.insertDatabasePlant(
            name: "Marigold",
            scientificName: "Tagetes",
            type: .flower,
            difficulty: .beginner,
            sunlight: .fullSun,
            watering: .twiceWeekly,
            space: .small,
            notes: "A forgiving flower."
        )
        try dataService.insertDatabasePlant(
            name: "Tomato",
            scientificName: "Solanum lycopersicum",
            type: .vegetable,
            difficulty: .beginner,
            sunlight: .fullSun,
            watering: .twiceWeekly,
            space: .small,
            notes: "A productive food crop."
        )
    }
}
