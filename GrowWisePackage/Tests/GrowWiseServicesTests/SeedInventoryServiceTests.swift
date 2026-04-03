@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct SeedInventoryServiceTests {
    private let service = SeedInventoryService()

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - compatibleSeeds

    @Test("Shade garden rejects full-sun seeds")
    func compatibleSeedsFiltersBySunExposure() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let garden = Garden(name: "Shade Garden")
        garden.sunExposure = .fullShade
        context.insert(garden)

        let bed = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        context.insert(bed)

        let fullSunSeed = Seed(varietyName: "Sun Tomato", plantType: .vegetable)
        fullSunSeed.sunRequirement = .fullSun

        let shadeSeed = Seed(varietyName: "Fern", plantType: .houseplant)
        shadeSeed.sunRequirement = .fullShade

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [fullSunSeed, shadeSeed],
            plantDatabase: []
        )

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Fern")
    }

    @Test("Incompatible plants filter removes fennel when tomato in bed")
    func compatibleSeedsFiltersByIncompatiblePlants() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let garden = Garden(name: "Veggie Garden")
        garden.sunExposure = .fullSun
        context.insert(garden)

        let bed = GardenBed(name: "Bed B", bedType: .raisedBed, garden: garden)
        context.insert(bed)

        let tomato = Plant(name: "Tomato", plantType: .vegetable)
        tomato.bed = bed
        context.insert(tomato)

        let fennelSeed = Seed(varietyName: "Fennel", plantType: .herb)
        fennelSeed.sunRequirement = .fullSun
        fennelSeed.incompatiblePlants = ["Tomato"]

        let basilSeed = Seed(varietyName: "Basil", plantType: .herb)
        basilSeed.sunRequirement = .fullSun
        basilSeed.incompatiblePlants = []

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [fennelSeed, basilSeed],
            plantDatabase: []
        )

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Basil")
    }

    @Test("No garden sun exposure returns all seeds")
    func compatibleSeedsNoGardenSunReturnsAll() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let garden = Garden(name: "Unknown Garden")
        garden.sunExposure = nil
        context.insert(garden)

        let bed = GardenBed(name: "Bed C", bedType: .raisedBed, garden: garden)
        context.insert(bed)

        let seed1 = Seed(varietyName: "Seed A", plantType: .vegetable)
        seed1.sunRequirement = .fullSun

        let seed2 = Seed(varietyName: "Seed B", plantType: .herb)
        seed2.sunRequirement = .fullShade

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [seed1, seed2],
            plantDatabase: []
        )

        #expect(result.count == 2)
    }

    // MARK: - readyToPlant

    @Test("Returns seeds within start window for zone 6")
    func readyToPlantReturnsInWindow() throws {
        // Zone 6 last frost = April 15
        // 6 weeks indoor start → ideal start = March 4
        // Window: Feb 25 – March 11
        let seed = Seed(varietyName: "Tomato", plantType: .vegetable)
        seed.indoorStartWeeks = 6

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 3, day: 5)))

        let result = service.readyToPlant(seeds: [seed], zone: "6a", currentDate: testDate)

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Tomato")
    }

    @Test("Excludes seeds outside start window")
    func readyToPlantExcludesOutsideWindow() throws {
        let seed = Seed(varietyName: "Tomato", plantType: .vegetable)
        seed.indoorStartWeeks = 6

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 1, day: 10)))

        let result = service.readyToPlant(seeds: [seed], zone: "6", currentDate: testDate)

        #expect(result.isEmpty)
    }

    @Test("Skips seeds without indoorStartWeeks")
    func readyToPlantSkipsNoIndoorWeeks() throws {
        let seed = Seed(varietyName: "Direct Sow Carrot", plantType: .vegetable)
        seed.indoorStartWeeks = nil

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 3, day: 5)))

        let result = service.readyToPlant(seeds: [seed], zone: "6a", currentDate: testDate)

        #expect(result.isEmpty)
    }

    // MARK: - suggestPlantDatabaseLink

    @Test("Finds exact name match")
    func suggestLinkExactMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        context.insert(plant)

        let seed = Seed(varietyName: "Tomato", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        #expect(result == plant.id?.uuidString)
    }

    @Test("Finds substring match — Cherry Tomato matches Tomato")
    func suggestLinkSubstringMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        context.insert(plant)

        let seed = Seed(varietyName: "Cherry Tomato", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        #expect(result == plant.id?.uuidString)
    }

    @Test("Returns nil for no match")
    func suggestLinkNoMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plant = Plant(name: "Basil", plantType: .herb)
        context.insert(plant)

        let seed = Seed(varietyName: "Watermelon", plantType: .fruit)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        #expect(result == nil)
    }

    @Test("Returns nil for empty variety name")
    func suggestLinkEmptyVarietyName() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        context.insert(plant)

        let seed = Seed(varietyName: "", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        #expect(result == nil)
    }

    // MARK: - Edge Cases: compatibleSeeds

    @Test("Plant database link fallback filters seed by linked plant sun requirement")
    func compatibleSeedsFallbackToPlantDatabaseSun() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let garden = Garden(name: "Shade Garden")
        garden.sunExposure = .partialShade
        context.insert(garden)

        let bed = GardenBed(name: "Bed D", bedType: .raisedBed, garden: garden)
        context.insert(bed)

        // Plant in database with fullSun requirement
        let dbPlant = Plant(name: "Sun Lover", plantType: .vegetable)
        dbPlant.sunlightRequirement = .fullSun
        context.insert(dbPlant)
        try context.save()

        // Seed has NO direct sunRequirement but links to the full-sun plant
        let seed = Seed(varietyName: "Sun Lover Hybrid", plantType: .vegetable)
        seed.sunRequirement = nil
        seed.plantDatabaseID = dbPlant.id?.uuidString

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [seed],
            plantDatabase: [dbPlant]
        )

        // partialShade (1) < fullSun (3), seed should be filtered out
        #expect(result.isEmpty)
    }

    @Test("Artificial sun garden accepts full-sun seeds")
    func compatibleSeedsArtificialSunAcceptsFullSun() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let garden = Garden(name: "Indoor Garden")
        garden.sunExposure = .artificial
        context.insert(garden)

        let bed = GardenBed(name: "Grow Light Shelf", bedType: .raisedBed, garden: garden)
        context.insert(bed)

        let seed = Seed(varietyName: "Full Sun Tomato", plantType: .vegetable)
        seed.sunRequirement = .fullSun

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [seed],
            plantDatabase: []
        )

        // artificial (3) >= fullSun (3), seed should pass
        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Full Sun Tomato")
    }

    // MARK: - Edge Cases: readyToPlant

    @Test("Ready to plant for cold zone 3a — 8 weeks indoor start on April 6")
    func readyToPlantColdZone() throws {
        // Zone 3 last frost = June 1
        // 8 weeks before June 1 = ~April 6
        // Window: 1 week before/after = March 30 – April 13
        let seed = Seed(varietyName: "Cold Hardy Tomato", plantType: .vegetable)
        seed.indoorStartWeeks = 8

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 4, day: 6)))

        let result = service.readyToPlant(seeds: [seed], zone: "3a", currentDate: testDate)

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Cold Hardy Tomato")
    }

    @Test("Ready to plant for warm zone 10a — 4 weeks indoor start on Jan 5")
    func readyToPlantWarmZone() throws {
        // Zone 10 last frost = January 31
        // 4 weeks before Jan 31 = ~January 3
        // Window: 1 week before/after = Dec 27 – Jan 10
        let seed = Seed(varietyName: "Warm Pepper", plantType: .vegetable)
        seed.indoorStartWeeks = 4

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 1, day: 5)))

        let result = service.readyToPlant(seeds: [seed], zone: "10a", currentDate: testDate)

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Warm Pepper")
    }

    @Test("Ready to plant with invalid zone returns empty array")
    func readyToPlantInvalidZone() throws {
        let seed = Seed(varietyName: "Mystery Plant", plantType: .vegetable)
        seed.indoorStartWeeks = 6

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let testDate = try #require(calendar.date(from: DateComponents(year: year, month: 3, day: 5)))

        let result = service.readyToPlant(seeds: [seed], zone: "xyz", currentDate: testDate)

        #expect(result.isEmpty)
    }

    // MARK: - Edge Cases: suggestPlantDatabaseLink

    @Test("Word-level match — shared significant word triggers match")
    func suggestLinkWordLevelMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // "Garden Fennel" and "Bronze Fennel" share the word "Fennel" (>2 chars)
        // Neither name is a substring of the other, so only word-level match fires.
        let plant = Plant(name: "Garden Fennel", plantType: .herb)
        context.insert(plant)
        try context.save()

        let seed = Seed(varietyName: "Bronze Fennel", plantType: .herb)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        #expect(result == plant.id?.uuidString)
    }

    @Test("Short words excluded from word-level matching")
    func suggestLinkNoShortWordMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Plant name has only short words (<=2 chars) so word-level match
        // filters them all out. Names are chosen so neither is a substring
        // of the other, preventing substring match from firing.
        let plant = Plant(name: "Qx Zy", plantType: .vegetable)
        context.insert(plant)
        try context.save()

        let seed = Seed(varietyName: "Jm Zy Qx", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])

        // Substring check: "jm zy qx" does not contain "qx zy" and vice versa
        // Word-level check: all words ("jm", "zy", "qx") are <=2 chars, filtered out
        #expect(result == nil)
    }
}
