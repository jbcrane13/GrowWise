import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct GardenRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Garden.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Existing: update()

    @Test("update() sets lastModified date")
    func updateSetsLastModifiedDate() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "Test Garden", gardenType: .outdoor, isIndoor: false)
        try repo.add(garden)

        let before = Date()
        try repo.update(garden)

        let lastModified = try #require(garden.lastModified)
        #expect(lastModified >= before)
    }

    @Test("update() does not throw on valid context")
    func updateDoesNotThrowOnValidContext() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "No Throw Garden", gardenType: .indoor, isIndoor: true)
        try repo.add(garden)

        #expect(throws: Never.self) {
            try repo.update(garden)
        }
    }

    @Test("update() preserves other garden properties")
    func updatePreservesOtherGardenProperties() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "Herb Garden", gardenType: .container, isIndoor: true)
        try repo.add(garden)

        try repo.update(garden)

        #expect(garden.name == "Herb Garden")
        #expect(garden.gardenType == .container)
        #expect(garden.isIndoor == true)
    }

    // MARK: - fetchAll

    @Test("fetchAll() returns all gardens sorted by name")
    func fetchAllReturnsAllGardens() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        try repo.add(Garden(name: "Zen Garden", gardenType: .outdoor))
        try repo.add(Garden(name: "Balcony Herbs", gardenType: .balcony))
        try repo.add(Garden(name: "Kitchen Window", gardenType: .windowsill))

        let all = try repo.fetchAll()
        #expect(all.count == 3)
        #expect(all[0].name == "Balcony Herbs")
        #expect(all[1].name == "Kitchen Window")
        #expect(all[2].name == "Zen Garden")
    }

    @Test("fetchAll() with pagination returns correct slice")
    func fetchAllWithPaginationReturnsCorrectSlice() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        for name in ["Alpha", "Bravo", "Charlie", "Delta", "Echo"] {
            try repo.add(Garden(name: name, gardenType: .outdoor))
        }

        let page = try repo.fetchAll(offset: 1, limit: 2)
        #expect(page.count == 2)
        #expect(page[0].name == "Bravo")
        #expect(page[1].name == "Charlie")
    }

    // MARK: - add

    @Test("add() persists garden to context")
    func addPersistsGarden() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "My Garden", gardenType: .raised, isIndoor: false)
        try repo.add(garden)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "My Garden")
        #expect(fetched.first?.gardenType == .raised)
    }

    // MARK: - create

    @Test("create() persists garden with correct name, type, and isIndoor")
    func createWithNameTypeIsIndoor() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = try repo.create(name: "Greenhouse", type: .greenhouse, isIndoor: true, user: nil)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(garden.name == "Greenhouse")
        #expect(garden.gardenType == .greenhouse)
        #expect(garden.isIndoor == true)
    }

    // MARK: - delete

    @Test("delete() removes garden from context")
    func deleteRemovesGarden() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "Temporary", gardenType: .container)
        try repo.add(garden)
        #expect(try repo.fetchAll().count == 1)

        try repo.delete(garden)

        let remaining = try repo.fetchAll()
        #expect(remaining.isEmpty)
    }

    @Test("delete() garden cascades to associated plants")
    func deleteGardenCascadesToPlants() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)
        let plantRepo = PlantRepository(context: container.mainContext)

        let garden = Garden(name: "Doomed Garden", gardenType: .outdoor)
        try repo.add(garden)

        let plant = Plant(name: "Doomed Plant", plantType: .herb)
        plant.garden = garden
        garden.plants = [plant]
        try plantRepo.add(plant)

        try repo.delete(garden)

        let remainingPlants = try plantRepo.fetchAll()
        #expect(remainingPlants.isEmpty)
    }

    // MARK: - multiple gardens

    @Test("create multiple gardens persists all of them")
    func createMultipleGardensPersistsAll() throws {
        let container = try makeContainer()
        let repo = GardenRepository(context: container.mainContext)

        try repo.create(name: "Front Yard", type: .outdoor, isIndoor: false, user: nil)
        try repo.create(name: "Back Patio", type: .container, isIndoor: false, user: nil)
        try repo.create(name: "Indoor Herbs", type: .indoor, isIndoor: true, user: nil)

        let all = try repo.fetchAll()
        #expect(all.count == 3)
        let names = all.compactMap(\.name)
        #expect(names.contains("Front Yard"))
        #expect(names.contains("Back Patio"))
        #expect(names.contains("Indoor Herbs"))
    }
}
