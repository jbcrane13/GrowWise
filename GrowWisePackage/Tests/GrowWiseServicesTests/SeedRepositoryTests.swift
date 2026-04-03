@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct SeedRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Add and fetch seed")
    func addAndFetchSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed = Seed(varietyName: "Roma Tomato", plantType: .vegetable, quantity: 3)
        try repo.add(seed)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.varietyName == "Roma Tomato")
        #expect(fetched.first?.quantity == 3)
    }

    @Test("Fetch seeds for garden")
    func fetchForGarden() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        try ctx.save()

        let seed1 = Seed(varietyName: "Basil", plantType: .herb)
        seed1.garden = garden
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Mint", plantType: .herb)
        try repo.add(seed2) // No garden

        let gardenSeeds = try repo.fetchAll(for: garden)
        #expect(gardenSeeds.count == 1)
        #expect(gardenSeeds.first?.varietyName == "Basil")
    }

    @Test("Fetch unassigned seeds")
    func fetchUnassigned() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Raised Bed", bedType: .raisedBed, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed1 = Seed(varietyName: "Tomato", plantType: .vegetable)
        seed1.garden = garden
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Pepper", plantType: .vegetable)
        seed2.garden = garden
        seed2.gardenBed = bed
        try repo.add(seed2)

        let unassigned = try repo.fetchUnassigned(for: garden)
        #expect(unassigned.count == 1)
        #expect(unassigned.first?.varietyName == "Tomato")
    }

    @Test("Fetch seeds for bed")
    func fetchForBed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Herb Pot", bedType: .pot, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Cilantro", plantType: .herb)
        seed.garden = garden
        seed.gardenBed = bed
        try repo.add(seed)

        let bedSeeds = try repo.fetch(for: bed)
        #expect(bedSeeds.count == 1)
        #expect(bedSeeds.first?.varietyName == "Cilantro")
    }

    @Test("Assign and unassign seed to bed")
    func assignAndUnassign() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Window Box", bedType: .windowBox, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Lettuce", plantType: .vegetable)
        seed.garden = garden
        try repo.add(seed)

        // Assign
        try repo.assignToBed(seed, bed: bed)
        let bedSeeds = try repo.fetch(for: bed)
        #expect(bedSeeds.count == 1)

        // Unassign
        try repo.unassign(seed)
        let bedSeedsAfter = try repo.fetch(for: bed)
        #expect(bedSeedsAfter.count == 0)
        let unassigned = try repo.fetchUnassigned(for: garden)
        #expect(unassigned.count == 1)
    }

    @Test("Delete seed")
    func deleteSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed = Seed(varietyName: "Carrot", plantType: .vegetable)
        try repo.add(seed)
        #expect(try repo.fetchAll().count == 1)

        try repo.delete(seed)
        #expect(try repo.fetchAll().count == 0)
    }

    @Test("Search seeds by variety name and brand")
    func searchSeeds() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed1 = Seed(varietyName: "Cherry Tomato", plantType: .vegetable)
        seed1.brand = "Burpee"
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Roma Tomato", plantType: .vegetable)
        seed2.brand = "Johnny's"
        try repo.add(seed2)

        let seed3 = Seed(varietyName: "Sweet Basil", plantType: .herb)
        try repo.add(seed3)

        let tomatoResults = try repo.search(query: "tomato")
        #expect(tomatoResults.count == 2)

        let burpeeResults = try repo.search(query: "burpee")
        #expect(burpeeResults.count == 1)
        #expect(burpeeResults.first?.varietyName == "Cherry Tomato")

        let emptyResults = try repo.search(query: "")
        #expect(emptyResults.count == 0)
    }

    @Test("Fetch seeds by plant type")
    func fetchByPlantType() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        try repo.add(Seed(varietyName: "Tomato", plantType: .vegetable))
        try repo.add(Seed(varietyName: "Basil", plantType: .herb))
        try repo.add(Seed(varietyName: "Sunflower", plantType: .flower))

        let herbs = try repo.fetchByPlantType(.herb)
        #expect(herbs.count == 1)
        #expect(herbs.first?.varietyName == "Basil")
    }

    @Test("GardenBed deletion nullifies seed assignment")
    func bedDeletionNullifiesSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Temp Bed", bedType: .pot, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Dill", plantType: .herb)
        seed.garden = garden
        seed.gardenBed = bed
        try repo.add(seed)

        // Delete the bed
        ctx.delete(bed)
        try ctx.save()

        // Seed should still exist but be unassigned
        let allSeeds = try repo.fetchAll()
        #expect(allSeeds.count == 1)
        #expect(allSeeds.first?.gardenBed == nil)
    }
}
