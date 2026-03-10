import Foundation
import Testing
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("ReminderRepository Tests")
@MainActor
struct ReminderRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PlantReminder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - add()

    @Test("add() inserts reminder into context")
    func addInsertsReminder() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Basil", plantType: .herb)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Water Basil",
            message: "Give it 250ml",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date().addingTimeInterval(3_600),
            plant: plant
        )
        try repo.add(reminder)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "Water Basil")
    }

    @Test("add() does not throw with a valid in-memory context")
    func addDoesNotThrowWithValidContext() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Mint", plantType: .herb)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Prune Mint",
            message: "Cut back leggy growth",
            reminderType: .pruning,
            frequency: .monthly,
            nextDueDate: Date().addingTimeInterval(86_400),
            plant: plant
        )
        #expect(throws: Never.self) {
            try repo.add(reminder)
        }
    }

    // MARK: - fetchActive()

    @Test("fetchActive() returns enabled reminders with nextDueDate on or after start of today")
    func fetchActiveReturnsEnabledCurrentReminders() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        container.mainContext.insert(plant)

        let active = PlantReminder(
            title: "Active Today",
            message: "Do this now",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date(),
            plant: plant
        )
        active.isEnabled = true
        try repo.add(active)

        let results = try repo.fetchActive()
        #expect(results.count == 1)
        #expect(results.first?.title == "Active Today")
    }

    @Test("fetchActive() excludes disabled reminders")
    func fetchActiveExcludesDisabled() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Cactus", plantType: .succulent)
        container.mainContext.insert(plant)

        let disabled = PlantReminder(
            title: "Disabled Reminder",
            message: "Should not appear",
            reminderType: .watering,
            frequency: .weekly,
            nextDueDate: Date(),
            plant: plant
        )
        disabled.isEnabled = false
        try repo.add(disabled)

        let results = try repo.fetchActive()
        #expect(results.isEmpty)
    }

    @Test("fetchActive() excludes reminders with nextDueDate before start of today")
    func fetchActiveExcludesBeforeStartOfDay() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Mint", plantType: .herb)
        container.mainContext.insert(plant)

        let yesterday = Date().addingTimeInterval(-25 * 3_600)
        let pastReminder = PlantReminder(
            title: "Missed Yesterday",
            message: "Overdue and before startOfDay",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: yesterday,
            plant: plant
        )
        pastReminder.isEnabled = true
        try repo.add(pastReminder)

        let results = try repo.fetchActive()
        #expect(results.isEmpty)
    }

    // MARK: - fetchUpcoming(days:)

    @Test("fetchUpcoming(days:) returns enabled reminders within the time window")
    func fetchUpcomingReturnsWithinWindow() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Lavender", plantType: .herb)
        container.mainContext.insert(plant)

        let threeDaysOut = Date().addingTimeInterval(3 * 86_400)
        let insideWindow = PlantReminder(
            title: "Inside Window",
            message: "Due in 3 days",
            reminderType: .fertilizing,
            frequency: .weekly,
            nextDueDate: threeDaysOut,
            plant: plant
        )
        insideWindow.isEnabled = true

        let tenDaysOut = Date().addingTimeInterval(10 * 86_400)
        let outsideWindow = PlantReminder(
            title: "Outside Window",
            message: "Due in 10 days",
            reminderType: .fertilizing,
            frequency: .monthly,
            nextDueDate: tenDaysOut,
            plant: plant
        )
        outsideWindow.isEnabled = true

        try repo.add(insideWindow)
        try repo.add(outsideWindow)

        let results = try repo.fetchUpcoming(days: 7)
        #expect(results.count == 1)
        #expect(results.first?.title == "Inside Window")
    }

    @Test("fetchUpcoming(days:) excludes disabled reminders within the window")
    func fetchUpcomingExcludesDisabledWithinWindow() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Oregano", plantType: .herb)
        container.mainContext.insert(plant)

        let twoDaysOut = Date().addingTimeInterval(2 * 86_400)
        let disabledUpcoming = PlantReminder(
            title: "Disabled Upcoming",
            message: "Would be upcoming but disabled",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: twoDaysOut,
            plant: plant
        )
        disabledUpcoming.isEnabled = false
        try repo.add(disabledUpcoming)

        let results = try repo.fetchUpcoming(days: 7)
        #expect(results.isEmpty)
    }

    // MARK: - delete()

    @Test("delete() removes reminder from context")
    func deleteRemovesReminder() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Oregano", plantType: .herb)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Delete Me",
            message: "Temporary reminder",
            reminderType: .watering,
            frequency: .once,
            nextDueDate: Date().addingTimeInterval(3_600),
            plant: plant
        )
        try repo.add(reminder)

        var all = try repo.fetchAll()
        #expect(all.count == 1)

        try repo.delete(reminder)

        all = try repo.fetchAll()
        #expect(all.count == 0)
    }

    // MARK: - complete() / update lastModified

    @Test("complete() sets lastModified date on the reminder")
    func completeSetsLastModified() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Sunflower", plantType: .flower)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Water Sunflower",
            message: "Give 500ml",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date().addingTimeInterval(3_600),
            plant: plant
        )
        try repo.add(reminder)

        let before = Date()
        try repo.complete(reminder)

        #expect(reminder.lastModified >= before)
    }

    @Test("complete() marks lastCompletedDate on a recurring reminder")
    func completeSetsLastCompletedDate() async throws {
        let container = try makeContainer()
        let repo = ReminderRepository(context: container.mainContext)

        let plant = Plant(name: "Basil", plantType: .herb)
        container.mainContext.insert(plant)

        let reminder = PlantReminder(
            title: "Fertilize Basil",
            message: "Use balanced feed",
            reminderType: .fertilizing,
            frequency: .weekly,
            nextDueDate: Date().addingTimeInterval(3_600),
            plant: plant
        )
        reminder.isRecurring = true
        try repo.add(reminder)

        let before = Date()
        try repo.complete(reminder)

        let completedDate = try #require(reminder.lastCompletedDate)
        #expect(completedDate >= before)
    }
}
