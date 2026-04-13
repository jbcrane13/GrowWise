import Foundation
import Testing
@testable import GrowWiseModels
@testable import GrowWiseServices

/// Integration tests exercising real DataService production code paths
/// against an in-memory SwiftData store. These tests directly address the
/// critical coverage gap (#203) by calling actual DataService methods
/// instead of mocks/stubs.
@MainActor
struct DataServiceHappyPathTests {

    // MARK: - Factory

    @Test("makeForTesting creates a valid DataService with accessible repositories")
    func makeForTestingCreatesValidService() throws {
        let ds = try DataService.makeForTesting()
        #expect(ds.plants != nil)
        #expect(ds.gardens != nil)
        #expect(ds.reminders != nil)
        #expect(ds.seeds != nil)
    }

    // MARK: - Garden CRUD

    @Test("createGarden persists and is fetchable")
    func createGardenHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "Test Garden", type: .raised, isIndoor: false)
        #expect(garden.name == "Test Garden")

        let fetched = ds.fetchGardens()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Garden")
    }

    @Test("deleteGarden removes it from fetch results")
    func deleteGardenHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "Doomed Garden", type: .inGround, isIndoor: false)
        #expect(ds.fetchGardens().count == 1)

        try ds.deleteGarden(garden)
        #expect(ds.fetchGardens().isEmpty)
    }

    // MARK: - Plant CRUD

    @Test("createPlant persists in garden and is fetchable")
    func createPlantHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "Herb Garden", type: .container, isIndoor: true)
        let plant = try ds.createPlant(
            name: "Basil",
            type: .herb,
            difficultyLevel: .easy,
            garden: garden
        )
        #expect(plant.name == "Basil")
        #expect(plant.garden?.name == "Herb Garden")

        let fetched = ds.fetchPlants(for: garden)
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Basil")
    }

    @Test("updatePlant persists changes")
    func updatePlantHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        let plant = try ds.createPlant(
            name: "Tomato",
            type: .vegetable,
            difficultyLevel: .easy,
            garden: garden
        )
        plant.name = "Cherry Tomato"
        try ds.updatePlant(plant)

        let fetched = ds.fetchPlants(for: garden)
        #expect(fetched.first?.name == "Cherry Tomato")
    }

    @Test("deletePlant removes it from garden")
    func deletePlantHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        let plant = try ds.createPlant(commonName: "Mint", scientificName: nil, garden: garden)
        #expect(ds.fetchPlants(for: garden).count == 1)

        try ds.deletePlant(plant)
        #expect(ds.fetchPlants(for: garden).isEmpty)
    }

    // MARK: - User CRUD

    @Test("createUser and getCurrentUser round-trips")
    func userCRUDHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let user = try ds.createUser(email: "test@example.com", displayName: "Tester", skillLevel: .beginner)
        #expect(user.displayName == "Tester")

        let current = ds.getCurrentUser()
        #expect(current?.email == "test@example.com")
    }

    @Test("updateUser persists changes")
    func updateUserHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let user = try ds.createUser(email: "a@b.com", displayName: "Alice", skillLevel: .beginner)
        user.displayName = "Bob"
        try ds.updateUser(user)

        let fetched = ds.getCurrentUser()
        #expect(fetched?.displayName == "Bob")
    }

    // MARK: - Reminder CRUD

    @Test("createReminder and fetchActiveReminders round-trips")
    func reminderCRUDHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        let plant = try ds.createPlant(commonName: "Rose", scientificName: nil, garden: garden)
        let reminder = try ds.createReminder(
            plant: plant,
            type: .watering,
            frequency: .daily,
            nextDueDate: Date()
        )
        #expect(reminder.reminderType == .watering)

        let active = ds.fetchActiveReminders()
        #expect(active.count >= 1)
    }

    @Test("completeReminder advances the due date")
    func completeReminderHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        let plant = try ds.createPlant(commonName: "Fern", scientificName: nil, garden: garden)
        let now = Date()
        let reminder = try ds.createReminder(
            plant: plant,
            type: .watering,
            frequency: .daily,
            nextDueDate: now
        )
        let originalDate = reminder.nextDueDate
        try ds.completeReminder(reminder)
        #expect(reminder.nextDueDate > originalDate)
    }

    // MARK: - Plant Count

    @Test("getPlantCount reflects actual count")
    func plantCountHappyPath() throws {
        let ds = try DataService.makeForTesting()
        #expect(ds.getPlantCount() == 0)

        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        _ = try ds.createPlant(commonName: "A", scientificName: nil, garden: garden)
        _ = try ds.createPlant(commonName: "B", scientificName: nil, garden: garden)
        #expect(ds.getPlantCount() == 2)
        #expect(ds.getPlantCount(for: garden) == 2)
    }

    // MARK: - Search

    @Test("searchPlants returns matching results")
    func searchPlantsHappyPath() throws {
        let ds = try DataService.makeForTesting()
        let garden = try ds.createGarden(name: "G", type: .raised, isIndoor: false)
        _ = try ds.createPlant(name: "Lavender", type: .herb, garden: garden)
        _ = try ds.createPlant(name: "Basil", type: .herb, garden: garden)

        let results = ds.searchPlants(query: "Lav")
        #expect(results.count == 1)
        #expect(results.first?.name == "Lavender")
    }
}
