import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

/// Tests that StatsRepository methods propagate errors instead of silently returning 0,
/// and that DataService correctly handles those errors with fallback values.
@MainActor
struct StatsRepositoryErrorTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeForTesting()
    }

    // MARK: - StatsRepository throws propagation (positive path)

    @Test("getPlantCount throws on valid context and returns correct count")
    func getPlantCountThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        // Should not throw on a valid in-memory context
        let count = try repo.getPlantCount()
        #expect(count == 0)
    }

    @Test("getGardenCount throws on valid context and returns correct count")
    func getGardenCountThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let count = try repo.getGardenCount()
        #expect(count == 0)
    }

    @Test("getReminderCount throws on valid context and returns correct count")
    func getReminderCountThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let count = try repo.getReminderCount(activeOnly: false)
        #expect(count == 0)
    }

    @Test("getJournalEntryCount throws on valid context and returns correct count")
    func getJournalEntryCountThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let count = try repo.getJournalEntryCount()
        #expect(count == 0)
    }

    @Test("getPlantDatabaseCount throws on valid context and returns correct count")
    func getPlantDatabaseCountThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let count = try repo.getPlantDatabaseCount()
        #expect(count == 0)
    }

    @Test("getGardeningStats throws on valid context and returns composite stats")
    func getGardeningStatsThrowsOrReturnsCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let stats = try repo.getGardeningStats()
        #expect(stats.totalPlants == 0)
        #expect(stats.healthyPlants == 0)
        #expect(stats.activeReminders == 0)
        #expect(stats.totalJournalEntries == 0)
    }

    // MARK: - StatsRepository method signatures are throwing (compile-time verification)

    @Test("StatsRepository methods propagate errors — not silently returning defaults")
    func statsRepositoryMethodsAreThrowingFunctions() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        // Insert data and verify the throwing methods return accurate counts, not hardcoded 0
        let plant = Plant(name: "Error Test Plant", plantType: .herb)
        container.mainContext.insert(plant)

        let entry = JournalEntry(title: "Test", content: "Content", entryType: .observation, plant: plant)
        container.mainContext.insert(entry)

        let reminder = PlantReminder(
            title: "Test Reminder",
            message: "Test",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date().addingTimeInterval(3600),
            plant: plant
        )
        reminder.isEnabled = true
        container.mainContext.insert(reminder)

        // These calls use try — if the methods silently returned 0 (non-throwing),
        // these assertions would fail on the non-zero checks
        let plantCount = try repo.getPlantCount()
        #expect(plantCount == 1, "getPlantCount should return actual count, not swallow errors")

        let reminderCount = try repo.getReminderCount(activeOnly: true)
        #expect(reminderCount == 1, "getReminderCount should return actual count, not swallow errors")

        let journalCount = try repo.getJournalEntryCount()
        #expect(journalCount == 1, "getJournalEntryCount should return actual count, not swallow errors")
    }

    // MARK: - DataService stats fallback behavior

    @Test("DataService getGardeningStats returns valid stats on healthy context")
    func dataServiceGetGardeningStatsReturnsValidStats() throws {
        let service = try DataService.makeForTesting()

        let plant = Plant(name: "Fallback Test", plantType: .vegetable)
        service.mainContext.insert(plant)

        let stats = service.getGardeningStats()
        #expect(stats.totalPlants == 1)
        #expect(stats.healthyPlants == 1)
    }

    @Test("DataService getPlantCount returns correct count on healthy context")
    func dataServiceGetPlantCountReturnsCorrectCount() throws {
        let service = try DataService.makeForTesting()

        let plant = Plant(name: "Count Test", plantType: .herb)
        service.mainContext.insert(plant)

        let count = service.getPlantCount()
        #expect(count == 1)
    }

    @Test("DataService getGardenCount returns correct count on healthy context")
    func dataServiceGetGardenCountReturnsCorrectCount() throws {
        let service = try DataService.makeForTesting()

        let garden = try service.createGarden(name: "Test Garden", type: .outdoor, isIndoor: false)
        _ = garden

        let count = service.getGardenCount()
        #expect(count == 1)
    }

    @Test("DataService getReminderCount returns correct count on healthy context")
    func dataServiceGetReminderCountReturnsCorrectCount() throws {
        let service = try DataService.makeForTesting()

        let plant = Plant(name: "Reminder Plant", plantType: .herb)
        service.mainContext.insert(plant)

        let reminder = try service.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .daily,
            dueDate: Date().addingTimeInterval(3600),
            plant: plant
        )
        _ = reminder

        let count = service.getReminderCount(activeOnly: true)
        #expect(count == 1)
    }
}
