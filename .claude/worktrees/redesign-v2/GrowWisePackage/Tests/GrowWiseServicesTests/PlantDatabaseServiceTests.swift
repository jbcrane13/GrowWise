import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

// MARK: - PlantDatabaseService Tests

/// Tests for PlantDatabaseService.
///
/// Uses `DataService.makeForTesting()` which creates a full-schema in-memory ModelContainer
/// and explicitly passes `cloudContainer: nil`, avoiding the `CKContainer.default()` crash
/// that occurs in `swift test` when no CloudKit entitlement is present.
///
/// Cache note: DataService caches `fetchPlantDatabase()` results.  The background
/// `PlantSeedingWorker` actor inserts plants via its own ModelContext and saves them, so
/// the data reaches the shared container — but the main-context cache is stale.
/// Each test calls `dataService.invalidateAllCaches()` after seeding to ensure fresh reads.
@MainActor
struct PlantDatabaseServiceTests {
    // MARK: - Shared setup helper

    /// Seeds the plant database and invalidates the DataService cache so subsequent
    /// reads pick up the freshly-inserted data.
    private func seedAndFlush(
        dataService: DataService,
        plantDBService: PlantDatabaseService
    ) async throws {
        try await plantDBService.seedPlantDatabase()
        dataService.invalidateAllCaches()
    }

    // MARK: - Initialization

    @Test("Service can be initialized with a DataService")
    func initialization() throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        _ = plantDBService
    }

    @Test("Initial plant database is empty before seeding")
    func initialDatabaseIsEmpty() throws {
        let dataService = try DataService.makeForTesting()
        #expect(dataService.getPlantDatabaseCount() == 0)
    }

    // MARK: - Seeding

    @Test("seedPlantDatabase executes without throwing")
    func seedPlantDatabaseSucceeds() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await plantDBService.seedPlantDatabase()
    }

    @Test("After seeding, database contains plants")
    func databaseContainsPlantsAfterSeeding() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        // Use getPlantDatabaseCount() which skips the cache
        #expect(dataService.getPlantDatabaseCount() > 0)
    }

    @Test("Seeded plants all have non-empty names")
    func allSeededPlantsHaveNames() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        for plant in dataService.fetchPlantDatabase() {
            let name = plant.name ?? ""
            #expect(!name.isEmpty, "Expected non-empty name but found empty for a seeded plant")
        }
    }

    @Test("Seeded plants all have a plant type")
    func allSeededPlantsHaveType() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        for plant in dataService.fetchPlantDatabase() {
            #expect(plant.plantType != nil, "Expected every seeded plant to have a plant type")
        }
    }

    @Test("Database contains vegetables after seeding")
    func databaseContainsVegetables() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let counts = plantDBService.getPlantCountByType()
        #expect((counts[.vegetable] ?? 0) > 0)
    }

    @Test("Database contains herbs after seeding")
    func databaseContainsHerbs() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect((plantDBService.getPlantCountByType()[.herb] ?? 0) > 0)
    }

    @Test("Database contains flowers after seeding")
    func databaseContainsFlowers() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect((plantDBService.getPlantCountByType()[.flower] ?? 0) > 0)
    }

    @Test("Database contains houseplants after seeding")
    func databaseContainsHouseplants() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect((plantDBService.getPlantCountByType()[.houseplant] ?? 0) > 0)
    }

    @Test("Database contains succulents after seeding")
    func databaseContainsSucculents() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect((plantDBService.getPlantCountByType()[.succulent] ?? 0) > 0)
    }

    @Test("Database contains fruits after seeding")
    func databaseContainsFruits() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect((plantDBService.getPlantCountByType()[.fruit] ?? 0) > 0)
    }

    @Test("Database contains multiple distinct plant types")
    func databaseContainsMultipleDistinctTypes() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        // Expect at least 4 distinct types seeded
        #expect(plantDBService.getAvailablePlantTypes().count >= 4)
    }

    @Test("getPlantDatabaseCount returns correct count after seeding")
    func getPlantDatabaseCountAfterSeeding() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await plantDBService.seedPlantDatabase()
        // Use the cache-free count API to verify all plants were persisted
        // Expanded database: 50+ plants across vegetables, herbs, flowers, houseplants, fruits, succulents, trees, shrubs
        #expect(dataService.getPlantDatabaseCount() >= 50)
        _ = plantDBService
    }

    // MARK: - Idempotency

    @Test("Calling seedPlantDatabase twice does not duplicate plants")
    func seedingIsIdempotent() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await plantDBService.seedPlantDatabase()

        // After the first seed, the DataService cache still holds [] (it was populated
        // before PlantSeedingWorker inserted any records). We must invalidate the cache
        // and re-fetch so it reflects the actual persisted plants. Only then will the
        // second call to seedPlantDatabase() see a non-empty result and exit early.
        dataService.invalidateAllCaches()
        _ = dataService.fetchPlantDatabase() // repopulates cache from the live container

        let countAfterFirst = dataService.getPlantDatabaseCount()

        // Second seed should be a no-op: fetchPlantDatabase() now returns the seeded
        // plants, so the early-exit guard triggers and no duplicates are inserted.
        try await plantDBService.seedPlantDatabase()
        #expect(dataService.getPlantDatabaseCount() == countAfterFirst)
    }

    // MARK: - Search

    @Test("searchPlants returns results for known plant name")
    func searchPlantsFindsKnownPlant() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let results = plantDBService.searchPlants(query: "Tomato")
        #expect(results.count >= 1)
        #expect(results.first?.name == "Tomato")
    }

    @Test("searchPlants returns results for scientific name query")
    func searchPlantsByScientificName() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        // Basil scientific name is "Ocimum basilicum"
        let results = plantDBService.searchPlants(query: "Ocimum")
        #expect(results.count >= 1)
    }

    @Test("searchPlants returns empty for unknown query")
    func searchPlantsReturnsEmptyForUnknownQuery() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        #expect(plantDBService.searchPlants(query: "xyzzy_nonexistent_plant_zzz").isEmpty)
    }

    @Test("searchPlants is case-insensitive")
    func searchPlantsIsCaseInsensitive() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let uppercase = plantDBService.searchPlants(query: "BASIL")
        let lowercase = plantDBService.searchPlants(query: "basil")
        #expect(uppercase.count == lowercase.count)
        #expect(!uppercase.isEmpty)
    }

    // MARK: - Filter

    @Test("filterPlants by type returns only plants of that type")
    func filterPlantsByTypeReturnsCorrectResults() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let herbs = plantDBService.filterPlants(by: .herb)
        for herb in herbs {
            #expect(herb.plantType == .herb)
        }
        #expect(!herbs.isEmpty)
    }

    @Test("filterPlants by difficulty level returns correct plants")
    func filterPlantsByDifficultyReturnsCorrectResults() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let beginnerPlants = plantDBService.filterPlants(difficulty: .beginner)
        for plant in beginnerPlants {
            #expect(plant.difficultyLevel == .beginner)
        }
        #expect(!beginnerPlants.isEmpty)
    }

    @Test("getBeginnerFriendlyPlants returns only beginner difficulty plants")
    func testGetBeginnerFriendlyPlants() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let beginnerPlants = plantDBService.getBeginnerFriendlyPlants()
        #expect(!beginnerPlants.isEmpty)
        for plant in beginnerPlants {
            #expect(plant.difficultyLevel == .beginner)
        }
    }

    // MARK: - Statistics

    @Test("getPlantCountByType returns non-zero counts for seeded categories")
    func testGetPlantCountByType() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let counts = plantDBService.getPlantCountByType()
        #expect((counts[.vegetable] ?? 0) > 0)
        #expect((counts[.herb] ?? 0) > 0)
        #expect((counts[.flower] ?? 0) > 0)
        #expect((counts[.houseplant] ?? 0) > 0)
    }

    @Test("getPlantCountByDifficulty returns non-zero counts")
    func testGetPlantCountByDifficulty() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let counts = plantDBService.getPlantCountByDifficulty()
        // The seed data has both beginner and intermediate plants
        #expect((counts[.beginner] ?? 0) > 0)
        #expect((counts[.intermediate] ?? 0) > 0)
    }

    @Test("getAvailablePlantTypes returns sorted unique types")
    func getAvailablePlantTypesIsSorted() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)
        let types = plantDBService.getAvailablePlantTypes()
        let sortedTypes = types.sorted { $0.displayName < $1.displayName }
        #expect(types.map(\.displayName) == sortedTypes.map(\.displayName))
    }

    // MARK: - Recommendations

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

    // MARK: - Season Filtering

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

    // MARK: - Companion Plants

    @Test("getCompanionPlants for a vegetable returns herbs or flowers")
    func getCompanionPlantsForVegetableReturnsHerbsOrFlowers() async throws {
        let dataService = try DataService.makeForTesting()
        let plantDBService = PlantDatabaseService(dataService: dataService)
        try await seedAndFlush(dataService: dataService, plantDBService: plantDBService)

        let vegetables = plantDBService.filterPlants(by: .vegetable)
        guard let tomato = vegetables.first else {
            Issue.record("Expected at least one vegetable plant after seeding")
            return
        }

        for companion in plantDBService.getCompanionPlants(for: tomato) {
            let type = companion.plantType
            let isValidCompanion = type == .herb || type == .flower
            #expect(isValidCompanion, "Unexpected companion type \(String(describing: type)) for vegetable")
        }
    }
}
