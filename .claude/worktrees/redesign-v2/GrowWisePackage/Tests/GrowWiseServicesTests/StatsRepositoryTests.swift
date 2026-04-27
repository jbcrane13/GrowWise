import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct StatsRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeForTesting()
    }

    // MARK: - totalPlantCount (getPlantCount)

    @Test("totalPlantCount returns 0 for an empty store")
    func totalPlantCountIsZeroWhenEmpty() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        #expect(try repo.getPlantCount() == 0)
    }

    @Test("totalPlantCount returns the correct count after inserting plants")
    func totalPlantCountMatchesInsertedPlants() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let plant1 = Plant(name: "Basil", plantType: .herb)
        let plant2 = Plant(name: "Tomato", plantType: .vegetable)
        let plant3 = Plant(name: "Rose", plantType: .flower)
        container.mainContext.insert(plant1)
        container.mainContext.insert(plant2)
        container.mainContext.insert(plant3)

        #expect(try repo.getPlantCount() == 3)
    }

    // MARK: - healthyPlantCount (via getGardeningStats / healthyDescriptor)

    @Test("healthyPlantCount filters only plants with .healthy status")
    func healthyPlantCountFiltersCorrectly() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let healthyPlant = Plant(name: "Basil", plantType: .herb)
        let sickPlant = Plant(name: "Rose", plantType: .flower)
        sickPlant.healthStatus = .sick
        let dyingPlant = Plant(name: "Fern", plantType: .houseplant)
        dyingPlant.healthStatus = .dying

        container.mainContext.insert(healthyPlant)
        container.mainContext.insert(sickPlant)
        container.mainContext.insert(dyingPlant)

        let stats = try repo.getGardeningStats()
        #expect(stats.healthyPlants == 1)
    }

    @Test("healthyPlantCount is 0 when all plants are unhealthy")
    func healthyPlantCountIsZeroWhenNoHealthyPlants() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let sick = Plant(name: "Droopy Fern", plantType: .houseplant)
        sick.healthStatus = .needsAttention
        let dead = Plant(name: "Dead Cactus", plantType: .succulent)
        dead.healthStatus = .dead

        container.mainContext.insert(sick)
        container.mainContext.insert(dead)

        let stats = try repo.getGardeningStats()
        #expect(stats.healthyPlants == 0)
    }

    // MARK: - activeReminderCount (getReminderCount activeOnly)

    @Test("activeReminderCount counts enabled reminders with nextDueDate after now")
    func activeReminderCountIncludesEnabledFutureReminders() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let plant = Plant(name: "Cactus", plantType: .succulent)
        container.mainContext.insert(plant)

        let active = PlantReminder(
            title: "Water Soon",
            message: "Water it!",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date().addingTimeInterval(3600),
            plant: plant
        )
        active.isEnabled = true
        container.mainContext.insert(active)

        let disabled = PlantReminder(
            title: "Disabled Reminder",
            message: "Should not count",
            reminderType: .fertilizing,
            frequency: .weekly,
            nextDueDate: Date().addingTimeInterval(3600),
            plant: plant
        )
        disabled.isEnabled = false
        container.mainContext.insert(disabled)

        #expect(try repo.getReminderCount(activeOnly: true) == 1)
    }

    @Test("activeReminderCount excludes past-due reminders")
    func activeReminderCountExcludesPastDue() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let plant = Plant(name: "Basil", plantType: .herb)
        container.mainContext.insert(plant)

        let past = PlantReminder(
            title: "Missed Watering",
            message: "Should have watered",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date().addingTimeInterval(-86400),
            plant: plant
        )
        past.isEnabled = true
        container.mainContext.insert(past)

        #expect(try repo.getReminderCount(activeOnly: true) == 0)
    }

    // MARK: - totalJournalEntryCount (getJournalEntryCount)

    @Test("totalJournalEntryCount returns correct count of all entries")
    func totalJournalEntryCountMatchesInserted() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let plant = Plant(name: "Mint", plantType: .herb)
        container.mainContext.insert(plant)

        let entry1 = JournalEntry(title: "Log 1", content: "First entry", entryType: .observation, plant: plant)
        let entry2 = JournalEntry(title: "Log 2", content: "Second entry", entryType: .watering, plant: plant)
        container.mainContext.insert(entry1)
        container.mainContext.insert(entry2)

        #expect(try repo.getJournalEntryCount() == 2)
    }

    @Test("totalJournalEntryCount returns 0 for empty store")
    func totalJournalEntryCountIsZeroWhenEmpty() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        #expect(try repo.getJournalEntryCount() == 0)
    }

    // MARK: - getGardeningStats (composite)

    @Test("getGardeningStats aggregates all domain counts into a single struct")
    func getGardeningStatsReturnsComposite() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let plant = Plant(name: "Lavender", plantType: .herb)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Prune Lavender",
            message: "Time to prune",
            reminderType: .pruning,
            frequency: .monthly,
            nextDueDate: Date().addingTimeInterval(86400),
            plant: plant
        )
        reminder.isEnabled = true
        container.mainContext.insert(reminder)

        let entry = JournalEntry(title: "Note", content: "Looking great", entryType: .note, plant: plant)
        container.mainContext.insert(entry)

        let stats = try repo.getGardeningStats()
        #expect(stats.totalPlants == 1)
        #expect(stats.healthyPlants == 1)
        #expect(stats.activeReminders == 1)
        #expect(stats.totalJournalEntries == 1)
    }

    @Test("getGardeningStats returns all-zero GardeningStats for an empty store")
    func getGardeningStatsIsEmptyWhenNoData() throws {
        let container = try makeContainer()
        let repo = StatsRepository(context: container.mainContext)

        let stats = try repo.getGardeningStats()
        #expect(stats.totalPlants == 0)
        #expect(stats.healthyPlants == 0)
        #expect(stats.activeReminders == 0)
        #expect(stats.totalJournalEntries == 0)
    }
}
