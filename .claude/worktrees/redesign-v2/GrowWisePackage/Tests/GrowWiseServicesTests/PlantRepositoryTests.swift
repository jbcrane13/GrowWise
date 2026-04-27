@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct PlantRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Plant.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Existing

    @Test("Add and fetch plant")
    func addAndFetchPlant() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let plant = Plant(name: "Test Fern", plantType: .houseplant, difficultyLevel: .beginner, isUserPlant: true)
        try repo.add(plant)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Fern")
    }

    // MARK: - fetchAll

    @Test("fetchAll() returns all plants sorted by name")
    func fetchAllReturnsAllPlants() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let basil = Plant(name: "Basil", plantType: .herb)
        let aloe = Plant(name: "Aloe", plantType: .succulent)
        let cactus = Plant(name: "Cactus", plantType: .succulent)
        try repo.add(basil)
        try repo.add(aloe)
        try repo.add(cactus)

        let all = try repo.fetchAll()
        #expect(all.count == 3)
        #expect(all[0].name == "Aloe")
        #expect(all[1].name == "Basil")
        #expect(all[2].name == "Cactus")
    }

    // MARK: - create

    @Test("create() persists plant with correct properties")
    func createPersistsPlant() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let plant = try repo.create(name: "Tomato", type: .vegetable, difficultyLevel: .intermediate)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Tomato")
        #expect(plant.plantType == .vegetable)
        #expect(plant.difficultyLevel == .intermediate)
    }

    // MARK: - delete

    @Test("delete() removes plant from context")
    func deleteRemovesPlant() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let plant = Plant(name: "Doomed Plant", plantType: .flower)
        try repo.add(plant)
        #expect(try repo.fetchAll().count == 1)

        try repo.delete(plant)

        let remaining = try repo.fetchAll()
        #expect(remaining.isEmpty)
    }

    // MARK: - update

    @Test("update() persists modified plant properties")
    func updateModifiesPlantProperties() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let plant = Plant(name: "Old Name", plantType: .herb)
        try repo.add(plant)

        plant.name = "New Name"
        plant.difficultyLevel = .advanced
        try repo.update(plant)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "New Name")
        #expect(fetched.first?.difficultyLevel == .advanced)
    }

    // MARK: - fetchPaginated

    @Test("fetchPaginated() returns correct page of results")
    func fetchPaginatedReturnsCorrectPage() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        // Insert 5 plants with alphabetical names
        for name in ["Apple", "Basil", "Carrot", "Dill", "Eggplant"] {
            try repo.add(Plant(name: name, plantType: .vegetable))
        }

        let page = try repo.fetchPaginated(offset: 2, limit: 2)
        #expect(page.count == 2)
        #expect(page[0].name == "Carrot")
        #expect(page[1].name == "Dill")
    }

    @Test("fetchPaginated() with offset beyond data returns empty")
    func fetchPaginatedOffsetBeyondDataReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        try repo.add(Plant(name: "Solo Plant", plantType: .herb))

        let page = try repo.fetchPaginated(offset: 100, limit: 20)
        #expect(page.isEmpty)
    }

    // MARK: - fetchDatabasePage

    @Test("fetchDatabasePage() returns plants without a garden or user-owned garden")
    func fetchDatabasePageReturnsSeededPlants() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        // A plant with no garden (database/seeded plant)
        let seeded = Plant(name: "Seeded Tomato", plantType: .vegetable)
        try repo.add(seeded)

        let results = try repo.fetchDatabasePage(offset: 0, limit: 20)
        #expect(results.count == 1)
        #expect(results.first?.name == "Seeded Tomato")
    }

    // MARK: - search

    @Test("search() finds plants matching name")
    func searchByNameFindsMatching() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        try repo.add(Plant(name: "Basil", plantType: .herb))
        try repo.add(Plant(name: "Bay Laurel", plantType: .herb))
        try repo.add(Plant(name: "Tomato", plantType: .vegetable))

        let results = try repo.search(query: "ba")
        #expect(results.count == 2)
        let names = results.compactMap(\.name)
        #expect(names.contains("Basil"))
        #expect(names.contains("Bay Laurel"))
    }

    @Test("search() with no matches returns empty")
    func searchWithNoMatchesReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        try repo.add(Plant(name: "Basil", plantType: .herb))

        let results = try repo.search(query: "zzzzz")
        #expect(results.isEmpty)
    }

    // MARK: - filter

    @Test("filter() with no criteria returns all plants")
    func filterWithNoCriteriaReturnsAll() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        try repo.add(Plant(name: "Basil", plantType: .herb))
        try repo.add(Plant(name: "Tomato", plantType: .vegetable))
        try repo.add(Plant(name: "Fern", plantType: .houseplant))

        let all = try repo.filter()
        #expect(all.count == 3)
    }

    @Test("filter() with no criteria respects pagination")
    func filterWithNoCriteriaRespectsPagination() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        for name in ["Alpha", "Bravo", "Charlie", "Delta"] {
            try repo.add(Plant(name: name, plantType: .herb))
        }

        let page = try repo.filter(offset: 1, limit: 2)
        #expect(page.count == 2)
        #expect(page[0].name == "Bravo")
        #expect(page[1].name == "Charlie")
    }

    // SwiftData's in-memory store does not support #Predicate with optional enum types.
    // The filter(byType:difficultyLevel:sunlightRequirement:) predicate paths throw
    // "unsupportedPredicate" in the in-memory configuration. These tests are disabled
    // until SwiftData resolves this limitation (FB13847263).

    @Test("filter() by type returns correct subset", .disabled("SwiftData in-memory store unsupported predicate for optional enums"))
    func filterByTypeReturnsCorrectSubset() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        try repo.add(Plant(name: "Basil", plantType: .herb))
        try repo.add(Plant(name: "Mint", plantType: .herb))
        try repo.add(Plant(name: "Tomato", plantType: .vegetable))

        let herbs = try repo.filter(byType: .herb)
        #expect(herbs.count == 2)
        #expect(herbs.allSatisfy { $0.plantType == .herb })
    }

    @Test("filter() by difficulty returns correct subset", .disabled("SwiftData in-memory store unsupported predicate for optional enums"))
    func filterByDifficultyReturnsCorrectSubset() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let easy = Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner)
        let hard = Plant(name: "Orchid", plantType: .flower, difficultyLevel: .advanced)
        try repo.add(easy)
        try repo.add(hard)

        let beginnerPlants = try repo.filter(difficultyLevel: .beginner)
        #expect(beginnerPlants.count == 1)
        #expect(beginnerPlants.first?.name == "Basil")
    }

    @Test("filter() by sunlight requirement returns correct subset", .disabled("SwiftData in-memory store unsupported predicate for optional enums"))
    func filterBySunlightReturnsCorrectSubset() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let sunPlant = Plant(name: "Tomato", plantType: .vegetable)
        sunPlant.sunlightRequirement = .fullSun
        let shadePlant = Plant(name: "Fern", plantType: .houseplant)
        shadePlant.sunlightRequirement = .fullShade
        try repo.add(sunPlant)
        try repo.add(shadePlant)

        let shadeResults = try repo.filter(sunlightRequirement: .fullShade)
        #expect(shadeResults.count == 1)
        #expect(shadeResults.first?.name == "Fern")
    }

    @Test("filter() with multiple criteria applies AND logic", .disabled("SwiftData in-memory store unsupported predicate for optional enums"))
    func filterWithMultipleCriteriaAppliesAndLogic() throws {
        let container = try makeContainer()
        let repo = PlantRepository(context: container.mainContext)

        let basilBeginner = Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner)
        let mintAdvanced = Plant(name: "Mint", plantType: .herb, difficultyLevel: .advanced)
        let tomatoBeginner = Plant(name: "Tomato", plantType: .vegetable, difficultyLevel: .beginner)
        try repo.add(basilBeginner)
        try repo.add(mintAdvanced)
        try repo.add(tomatoBeginner)

        let results = try repo.filter(byType: .herb, difficultyLevel: .beginner)
        #expect(results.count == 1)
        #expect(results.first?.name == "Basil")
    }
}
