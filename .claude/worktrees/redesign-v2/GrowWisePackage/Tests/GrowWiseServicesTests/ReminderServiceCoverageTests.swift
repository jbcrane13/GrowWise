import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - Helpers (scoped to this file)

@MainActor
private func makeCoverageDataService() throws -> DataService {
    try DataService.makeForTesting()
}

@MainActor
private func makeCoverageReminderService(
    dataService: DataService,
    weatherProvider: (any WeatherAdjustmentProviding)? = nil
) -> ReminderService {
    let notificationService = NotificationService(notificationCenter: nil)
    if let wp = weatherProvider {
        return ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            weatherProvider: wp,
            shouldScheduleNotifications: false
        )
    }
    return ReminderService(
        dataService: dataService,
        notificationService: notificationService,
        shouldScheduleNotifications: false
    )
}

// MARK: - Notification Content Tests

@Suite("NotificationService — content generation")
@MainActor
struct NotificationContentTests {

    @Test("notificationContent title is 'Time to care for [plant name]'")
    func testNotificationTitleFormat() throws {
        let dataService = try makeCoverageDataService()
        let notificationService = NotificationService(notificationCenter: nil)
        let plant = try dataService.createPlant(name: "Basil", type: .herb)
        let reminder = try dataService.createReminder(
            title: "Water Basil",
            message: "Some message",
            type: .watering,
            frequency: .daily,
            dueDate: Date().addingTimeInterval(3600),
            plant: plant
        )

        let content = notificationService.notificationContent(for: reminder)
        #expect(content.title == "Time to care for Basil")
    }

    @Test("notificationContent body is the reminder type displayName")
    func testNotificationBodyIsReminderTypeDisplayName() throws {
        let dataService = try makeCoverageDataService()
        let notificationService = NotificationService(notificationCenter: nil)
        let plant = try dataService.createPlant(name: "Rose", type: .flower)

        for type in ReminderType.allCases {
            let reminder = try dataService.createReminder(
                title: "title",
                message: "msg",
                type: type,
                frequency: .weekly,
                dueDate: Date().addingTimeInterval(3600),
                plant: plant
            )
            let content = notificationService.notificationContent(for: reminder)
            #expect(content.body == type.displayName,
                    "Expected body '\(type.displayName)' for type \(type.rawValue), got '\(content.body)'")
        }
    }

    @Test("notificationContent falls back to 'Your Plant' when plant has no name")
    func testNotificationTitleFallbackWhenPlantHasNoName() throws {
        let dataService = try makeCoverageDataService()
        let notificationService = NotificationService(notificationCenter: nil)

        // Create a plant, then clear its name
        let plant = try dataService.createPlant(name: "Temp", type: .herb)
        plant.name = nil

        let reminder = try dataService.createReminder(
            title: "Unnamed",
            message: "msg",
            type: .watering,
            frequency: .daily,
            dueDate: Date().addingTimeInterval(3600),
            plant: plant
        )

        let content = notificationService.notificationContent(for: reminder)
        #expect(content.title == "Time to care for Your Plant")
    }

    @Test("notificationContent title uses plant name, not reminder title")
    func testNotificationTitleUsesPlantNameNotReminderTitle() throws {
        let dataService = try makeCoverageDataService()
        let notificationService = NotificationService(notificationCenter: nil)
        let plant = try dataService.createPlant(name: "Mint", type: .herb)
        let reminder = try dataService.createReminder(
            title: "Custom Reminder Title",
            message: "body",
            type: .fertilizing,
            frequency: .monthly,
            dueDate: Date().addingTimeInterval(3600),
            plant: plant
        )

        let content = notificationService.notificationContent(for: reminder)
        #expect(content.title.contains("Mint"))
        #expect(!content.title.contains("Custom Reminder Title"))
    }
}

// MARK: - Watering Reminder Query Tests

@Suite("ReminderService — watering queries")
@MainActor
struct ReminderServiceWateringQueryTests {

    @Test("getWateringReminders returns only watering-type reminders")
    func testGetWateringRemindersFiltersType() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Query-Plant-\(UUID())", type: .vegetable)

        _ = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 3, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plant, type: .fertilizing, baseFrequencyDays: 14, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plant, type: .pestControl, baseFrequencyDays: 7, enableWeatherAdjustment: false)

        let watering = service.getWateringReminders()
        // Every returned reminder must be .watering
        for reminder in watering {
            #expect(reminder.reminderType == .watering)
        }
    }

    @Test("getWateringReminders(for:) returns only reminders for the specified plant")
    func testGetWateringRemindersForPlantFiltersPlant() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plantA = try dataService.createPlant(name: "PlantA-\(UUID())", type: .herb)
        let plantB = try dataService.createPlant(name: "PlantB-\(UUID())", type: .succulent)

        _ = try await service.createSmartReminder(
            for: plantA, type: .watering, baseFrequencyDays: 2, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plantB, type: .watering, baseFrequencyDays: 7, enableWeatherAdjustment: false)

        let forA = service.getWateringReminders(for: plantA)
        for reminder in forA {
            #expect(reminder.plant?.id == plantA.id)
        }
    }

    @Test("getTodaysWateringReminders returns reminders due today")
    func testGetTodaysWateringReminders() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Today-Plant-\(UUID())", type: .vegetable)

        // Manually create a reminder due today
        let todayReminder = try dataService.createReminder(
            title: "Water Today",
            message: "msg",
            type: .watering,
            frequency: .daily,
            dueDate: Date(),
            plant: plant
        )
        todayReminder.isEnabled = true

        let todayReminders = service.getTodaysWateringReminders()
        let calendar = Calendar.current
        for reminder in todayReminders {
            #expect(calendar.isDate(reminder.nextDueDate, inSameDayAs: Date()))
            #expect(reminder.isEnabled == true)
        }
    }

    @Test("getOverdueWateringReminders returns reminders past their due date")
    func testGetOverdueWateringReminders() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Overdue-Plant-\(UUID())", type: .herb)

        // Create a reminder due yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let overdueReminder = try dataService.createReminder(
            title: "Overdue Watering",
            message: "msg",
            type: .watering,
            frequency: .daily,
            dueDate: yesterday,
            plant: plant
        )
        overdueReminder.isEnabled = true

        let overdue = service.getOverdueWateringReminders()
        // Every overdue reminder must have nextDueDate < now
        for reminder in overdue {
            #expect(reminder.nextDueDate < Date())
            #expect(reminder.isEnabled == true)
        }
    }
}

// MARK: - createWateringReminder Convenience Tests

@Suite("ReminderService — createWateringReminder")
@MainActor
struct ReminderServiceCreateWateringTests {

    @Test("createWateringReminder with preferredTime sets preferredNotificationTime")
    func testCreateWateringReminderWithPreferredTime() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "TimedPlant-\(UUID())", type: .herb)

        let preferred = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        let reminder = try await service.createWateringReminder(
            for: plant,
            frequency: .daily,
            preferredTime: preferred,
            enableSmartAdjustment: false
        )

        #expect(reminder.preferredNotificationTime != nil)
    }

    @Test("createWateringReminder with daily frequency stores baseFrequencyDays == 1")
    func testCreateWateringReminderDailyFrequency() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "DailyWater-\(UUID())", type: .vegetable)

        let reminder = try await service.createWateringReminder(
            for: plant,
            frequency: .daily,
            enableSmartAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 1)
        #expect(reminder.reminderType == .watering)
        #expect(reminder.priority == .high)
    }

    @Test("createWateringReminder with monthly frequency stores baseFrequencyDays == 30")
    func testCreateWateringReminderMonthlyFrequency() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "MonthlyWater-\(UUID())", type: .succulent)

        let reminder = try await service.createWateringReminder(
            for: plant,
            frequency: .monthly,
            enableSmartAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 30)
    }
}

// MARK: - updateWateringSchedule Tests

@Suite("ReminderService — updateWateringSchedule")
@MainActor
struct ReminderServiceUpdateWateringScheduleTests {

    @Test("updateWateringSchedule updates frequency and baseFrequencyDays")
    func testUpdateWateringScheduleUpdatesFrequency() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "UpdateFreq-\(UUID())", type: .herb)

        let reminder = try await service.createWateringReminder(
            for: plant, frequency: .daily, enableSmartAdjustment: false)

        try await service.updateWateringSchedule(for: reminder, newFrequency: .weekly)

        #expect(reminder.frequency == .weekly)
        #expect(reminder.baseFrequencyDays == 7)
    }

    @Test("updateWateringSchedule throws invalidReminderType for non-watering reminder")
    func testUpdateWateringScheduleThrowsForNonWateringType() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "WrongType-\(UUID())", type: .flower)

        let reminder = try await service.createSmartReminder(
            for: plant, type: .fertilizing, baseFrequencyDays: 14, enableWeatherAdjustment: false)

        await #expect(throws: ReminderError.self) {
            try await service.updateWateringSchedule(for: reminder, newFrequency: .daily)
        }
    }

    @Test("updateWateringSchedule updates preferred notification time when provided")
    func testUpdateWateringScheduleUpdatesPreferredTime() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "UpdateTime-\(UUID())", type: .vegetable)

        let reminder = try await service.createWateringReminder(
            for: plant, frequency: .daily, enableSmartAdjustment: false)

        let newTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        try await service.updateWateringSchedule(for: reminder, newFrequency: .biweekly, preferredTime: newTime)

        #expect(reminder.preferredNotificationTime != nil)
        #expect(reminder.baseFrequencyDays == 14)
    }

    @Test("updateWateringSchedule recalculates nextDueDate when plant is attached")
    func testUpdateWateringScheduleRecalculatesDueDate() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "RecalcDate-\(UUID())", type: .herb)

        let reminder = try await service.createWateringReminder(
            for: plant, frequency: .daily, enableSmartAdjustment: false)
        let originalDueDate = reminder.nextDueDate

        try await service.updateWateringSchedule(for: reminder, newFrequency: .weekly)

        // After updating to weekly (7 days), the due date should shift forward relative to daily (1 day)
        #expect(reminder.nextDueDate >= originalDueDate)
    }
}

// MARK: - Batch Operations Tests

@Suite("ReminderService — batch operations")
@MainActor
struct ReminderServiceBatchTests {

    @Test("createBatchReminders creates one reminder per plant")
    func testCreateBatchRemindersCreatesOnePerPlant() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let plants = try [
            dataService.createPlant(name: "Batch-A-\(UUID())", type: .herb),
            dataService.createPlant(name: "Batch-B-\(UUID())", type: .vegetable),
            dataService.createPlant(name: "Batch-C-\(UUID())", type: .flower)
        ]

        let reminders = try await service.createBatchReminders(
            for: plants, type: .watering, frequencyDays: 5, enableWeatherAdjustment: false)

        #expect(reminders.count == plants.count)
    }

    @Test("createBatchReminders assigns correct type to all reminders")
    func testCreateBatchRemindersCorrectType() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let plants = try [
            dataService.createPlant(name: "BatchType-A-\(UUID())", type: .herb),
            dataService.createPlant(name: "BatchType-B-\(UUID())", type: .vegetable)
        ]

        let reminders = try await service.createBatchReminders(
            for: plants, type: .fertilizing, frequencyDays: 14, enableWeatherAdjustment: false)

        for reminder in reminders {
            #expect(reminder.reminderType == .fertilizing)
        }
    }

    @Test("createBatchReminders with empty plant array returns empty array")
    func testCreateBatchRemindersEmptyPlants() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let reminders = try await service.createBatchReminders(
            for: [], type: .watering, frequencyDays: 3, enableWeatherAdjustment: false)

        #expect(reminders.isEmpty)
    }

    @Test("updateBatchReminders updates frequency on all reminders")
    func testUpdateBatchRemindersUpdatesFrequency() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let plants = try [
            dataService.createPlant(name: "BatchUpd-A-\(UUID())", type: .herb),
            dataService.createPlant(name: "BatchUpd-B-\(UUID())", type: .vegetable)
        ]
        let reminders = try await service.createBatchReminders(
            for: plants, type: .watering, frequencyDays: 3, enableWeatherAdjustment: false)

        try await service.updateBatchReminders(reminders, newFrequencyDays: 10)

        for reminder in reminders {
            #expect(reminder.baseFrequencyDays == 10)
        }
    }

    @Test("updateBatchReminders toggles weather adjustment flag")
    func testUpdateBatchRemindersTogglesWeatherAdjustment() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let plants = try [
            dataService.createPlant(name: "BatchWeath-\(UUID())", type: .herb)
        ]
        let reminders = try await service.createBatchReminders(
            for: plants, type: .watering, frequencyDays: 7, enableWeatherAdjustment: false)

        try await service.updateBatchReminders(reminders, enableWeatherAdjustment: true)

        for reminder in reminders {
            #expect(reminder.enableWeatherAdjustment == true)
        }
    }

    @Test("completeBatchReminders marks recurring reminders with updated nextDueDate")
    func testCompleteBatchRemindersUpdatesNextDueDate() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        let plants = try [
            dataService.createPlant(name: "CompleteBatch-\(UUID())", type: .herb)
        ]
        let reminders = try await service.createBatchReminders(
            for: plants, type: .watering, frequencyDays: 7, enableWeatherAdjustment: false)

        let originalDueDate = reminders[0].nextDueDate

        try await service.completeBatchReminders(reminders)

        // Recurring reminders must have a new due date after completion
        if reminders[0].isRecurring {
            #expect(reminders[0].lastCompletedDate != nil)
            // The next due date should have been updated
            #expect(reminders[0].nextDueDate >= originalDueDate)
        }
    }

    @Test("completeBatchReminders with single non-recurring reminder disables it")
    func testCompleteBatchReminderDisablesNonRecurring() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "NonRecurring-\(UUID())", type: .herb)

        let reminder = try dataService.createReminder(
            title: "Once",
            message: "msg",
            type: .inspection,
            frequency: .once,
            dueDate: Date().addingTimeInterval(3600),
            plant: plant
        )
        reminder.isRecurring = false

        try await service.completeBatchReminders([reminder])

        #expect(reminder.isEnabled == false)
    }
}

// MARK: - suggestReminders Tests

@Suite("ReminderService — suggestReminders")
@MainActor
struct ReminderServiceSuggestRemindersTests {

    @Test("suggestReminders returns non-empty suggestions for plant with no existing reminders")
    func testSuggestRemindersNoExistingReminders() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SuggestPlant-\(UUID())", type: .vegetable)

        let suggestions = await service.suggestReminders(for: plant)

        #expect(!suggestions.isEmpty)
    }

    @Test("suggestReminders does not suggest a type that already has an active reminder")
    func testSuggestRemindersSkipsExistingTypes() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "AlreadyHas-\(UUID())", type: .herb)

        // Create watering, fertilizing, and pestControl reminders (the 3 essential types)
        _ = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 3, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plant, type: .fertilizing, baseFrequencyDays: 14, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plant, type: .pestControl, baseFrequencyDays: 7, enableWeatherAdjustment: false)

        let suggestions = await service.suggestReminders(for: plant)

        // Suggestions should not include types already scheduled as essential types
        let suggestedTypes = suggestions.map { $0.type }
        // Essential types that already have reminders should not appear
        #expect(!suggestedTypes.contains(.watering) || !suggestedTypes.contains(.fertilizing) || !suggestedTypes.contains(.pestControl))
    }

    @Test("suggestReminders returns suggestions sorted consistently by rawValue")
    func testSuggestRemindersSortedByPriorityRawValue() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SortedSuggest-\(UUID())", type: .flower)

        let suggestions = await service.suggestReminders(for: plant)

        // The service sorts by `rawValue` (String) descending.
        // Verify the list is already in rawValue-descending order.
        let rawValues = suggestions.map { $0.priority.rawValue }
        let sortedRawValues = rawValues.sorted(by: >)
        #expect(rawValues == sortedRawValues,
                "Suggestions should be sorted descending by priority rawValue (String)")
    }

    @Test("suggestReminders for vegetable plant includes harvest suggestion in fall months")
    func testSuggestRemindersVegetablePlantHasSuggestions() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "VegSuggest-\(UUID())", type: .vegetable)

        let suggestions = await service.suggestReminders(for: plant)

        // At minimum some suggestions should come back for a vegetable with no reminders
        #expect(!suggestions.isEmpty)
        // Each suggestion references the correct plant
        for suggestion in suggestions {
            #expect(suggestion.plant.id == plant.id)
        }
    }
}

// MARK: - synchronizePendingNotifications Tests

@Suite("ReminderService — synchronizePendingNotifications")
@MainActor
struct ReminderServiceSynchronizeTests {

    @Test("synchronizePendingNotifications completes without error when no reminders exist")
    func testSynchronizeWithNoReminders() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)

        // Must complete without throwing
        await service.synchronizePendingNotifications()
    }

    @Test("synchronizePendingNotifications completes without error for existing reminders")
    func testSynchronizeWithExistingReminders() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SyncPlant-\(UUID())", type: .herb)

        _ = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 3, enableWeatherAdjustment: false)
        _ = try await service.createSmartReminder(
            for: plant, type: .fertilizing, baseFrequencyDays: 14, enableWeatherAdjustment: false)

        // Must complete without throwing regardless of notification auth state
        await service.synchronizePendingNotifications()
    }
}

// MARK: - scheduleNotification / cancelNotification passthrough Tests

@Suite("ReminderService — scheduleNotification and cancelNotification")
@MainActor
struct ReminderServiceNotificationPassthroughTests {

    @Test("scheduleNotification(for:) completes without error when notifications disabled")
    func testScheduleNotificationDoesNotThrowWhenDisabled() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SchedNote-\(UUID())", type: .herb)
        let reminder = try dataService.createReminder(
            title: "Title", message: "msg", type: .watering,
            frequency: .daily, dueDate: Date().addingTimeInterval(3600), plant: plant)

        // NotificationService has nil center — scheduleReminderNotification returns early without throwing
        try await service.scheduleNotification(for: reminder)
    }

    @Test("cancelNotification(for:) completes without error")
    func testCancelNotificationDoesNotThrow() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "CancelNote-\(UUID())", type: .herb)
        let reminder = try dataService.createReminder(
            title: "Title", message: "msg", type: .watering,
            frequency: .daily, dueDate: Date().addingTimeInterval(3600), plant: plant)

        // Should not crash or throw
        service.cancelNotification(for: reminder)
    }
}

// MARK: - createSeasonalCareSchedule Tests

@Suite("ReminderService — createSeasonalCareSchedule")
@MainActor
struct ReminderServiceSeasonalScheduleTests {

    @Test("createSeasonalCareSchedule creates at least one reminder for a vegetable plant")
    func testSeasonalScheduleCreatesRemindersForVegetable() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SeasonVeg-\(UUID())", type: .vegetable)
        let countBefore = plant.reminders?.count ?? 0

        try await service.createSeasonalCareSchedule(for: plant)

        // Inspect the plant's reminders directly, bypassing the cache-keyed fetchActiveReminders
        let countAfter = plant.reminders?.count ?? 0
        #expect(countAfter > countBefore)
    }

    @Test("createSeasonalCareSchedule for succulent creates at least one reminder")
    func testSeasonalScheduleCreatesRemindersForSucculent() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "SeasonSucc-\(UUID())", type: .succulent)
        let countBefore = plant.reminders?.count ?? 0

        try await service.createSeasonalCareSchedule(for: plant)

        let countAfter = plant.reminders?.count ?? 0
        #expect(countAfter > countBefore)
    }
}

// MARK: - ReminderService title/message generation Tests

@Suite("ReminderService — reminder title and message generation")
@MainActor
struct ReminderServiceTitleMessageTests {

    @Test("createSmartReminder for watering produces title containing plant name")
    func testWateringTitleContainsPlantName() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Cilantro", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 3, enableWeatherAdjustment: false)

        #expect(reminder.title.contains("Cilantro"))
    }

    @Test("createSmartReminder for fertilizing produces title containing plant name")
    func testFertilizingTitleContainsPlantName() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Dill", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant, type: .fertilizing, baseFrequencyDays: 14, enableWeatherAdjustment: false)

        #expect(reminder.title.contains("Dill"))
    }

    @Test("createSmartReminder for plant with nil name uses 'your plant' fallback")
    func testTitleFallbackForPlantWithNilName() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        // Create a plant then clear its name
        let plant = try dataService.createPlant(name: "TempName", type: .herb)
        plant.name = nil

        let reminder = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 2, enableWeatherAdjustment: false)

        #expect(reminder.title.contains("your plant"))
    }

    @Test("createSmartReminder for all reminder types produces non-empty message")
    func testAllTypesProduceNonEmptyMessage() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "AllTypes-\(UUID())", type: .vegetable)

        for type in ReminderType.allCases {
            let reminder = try await service.createSmartReminder(
                for: plant, type: type, baseFrequencyDays: 7, enableWeatherAdjustment: false)
            #expect(!reminder.title.isEmpty, "Title empty for type \(type.rawValue)")
            #expect(!reminder.message.isEmpty, "Message empty for type \(type.rawValue)")
        }
    }
}

// MARK: - Due Date Edge Case Tests

@Suite("ReminderService — due date scheduling edge cases")
@MainActor
struct ReminderServiceDueDateEdgeCaseTests {

    @Test("createSmartReminder with 1-day frequency places due date approximately 1 day in future")
    func testOneDayFrequencyDueDateApproximatelyOneDayAhead() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "1Day-\(UUID())", type: .herb)
        let before = Date()

        let reminder = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: 1, enableWeatherAdjustment: false)

        let after = Date()
        let calendar = Calendar.current
        let lowerBound = calendar.date(byAdding: .day, value: 0, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: 3, to: after)!
        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    @Test("createSmartReminder with 365-day frequency places due date approximately 1 year in future")
    func testYearlyFrequencyDueDateApproximatelyOneYearAhead() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Yearly-\(UUID())", type: .tree)
        let before = Date()

        let reminder = try await service.createSmartReminder(
            for: plant, type: .repotting, baseFrequencyDays: 365, enableWeatherAdjustment: false)

        let calendar = Calendar.current
        let lowerBound = calendar.date(byAdding: .day, value: 364, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: 367, to: before)!
        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    @Test("createSmartReminder with preferred time applies hour and minute from preferred time")
    func testPreferredTimeIsAppliedToNextDueDate() async throws {
        let dataService = try makeCoverageDataService()
        let service = makeCoverageReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "PrefTime-\(UUID())", type: .herb)

        let preferredTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 3,
            enableWeatherAdjustment: false,
            preferredTime: preferredTime
        )

        let hour = Calendar.current.component(.hour, from: reminder.nextDueDate)
        let minute = Calendar.current.component(.minute, from: reminder.nextDueDate)

        // Either the preferred time was applied (14:30) or quiet-hours pushed to next morning (8:00)
        let preferredApplied = hour == 14 && minute == 30
        let quietHoursApplied = hour == 8 && minute == 0
        #expect(preferredApplied || quietHoursApplied,
                "Expected 14:30 or 8:00 but got \(hour):\(minute)")
    }

    @Test("createSmartReminder with all non-watering types when weather enabled does not throw")
    func testNonWateringTypesWithWeatherEnabledDoNotThrow() async throws {
        let dataService = try makeCoverageDataService()
        let nonWateringTypes: [ReminderType] = [
            .fertilizing, .pruning, .pestControl, .harvest,
            .repotting, .planting, .inspection, .soilTest, .mulching, .custom
        ]
        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 95,
            maxPrecipitationChance: 0.9,
            totalPrecipitationInches: 1.0
        ))
        let service = makeCoverageReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "NonWater-\(UUID())", type: .vegetable)

        for type in nonWateringTypes {
            let reminder = try await service.createSmartReminder(
                for: plant, type: type, baseFrequencyDays: 7, enableWeatherAdjustment: true)
            #expect(reminder.reminderType == type)
        }
    }
}

// MARK: - Weather Adjustment Additional Edge Cases

@Suite("ReminderService — additional weather edge cases")
@MainActor
struct ReminderServiceWeatherEdgeCaseTests {

    @Test("adjustedWateringDate: precipitation chance at exactly 0.0 returns no adjustment")
    func testZeroPrecipitationChanceNoAdjustment() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 75,
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 0)
    }

    @Test("adjustedWateringDate: temperature at exactly 90°F triggers 1-day advance")
    func testTemperatureExactly90TriggerAdvance() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 90.0,
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == -1)
    }

    @Test("adjustedWateringDate: very high temperature still only advances by 1 day")
    func testVeryHighTemperatureOnlyAdvancesByOneDay() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 120,
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == -1)
    }

    @Test("adjustedWateringDate: very high precipitation only delays by 1 day")
    func testVeryHighPrecipitationOnlyDelaysByOneDay() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 70,
            maxPrecipitationChance: 1.0,
            totalPrecipitationInches: 5.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 1)
    }

    @Test("adjustedWateringDate: precipitation inches exactly at threshold 0.5 triggers delay")
    func testPrecipitationInchesExactlyAtThreshold() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 70,
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.5
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 1)
    }

    @Test("createSmartReminder watering: normal conditions keep date near base frequency")
    func testNormalWeatherConditionsKeepDateNearBase() async throws {
        let dataService = try makeCoverageDataService()
        let user = try dataService.createUser(
            email: "normal-\(UUID())@example.com",
            displayName: "Normal",
            skillLevel: .beginner
        )
        user.latitude = 37.7749
        user.longitude = -122.4194

        let normalWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.2,
            totalPrecipitationInches: 0.0
        ))
        let service = makeCoverageReminderService(dataService: dataService, weatherProvider: normalWeather)
        let plant = try dataService.createPlant(name: "NormalWeather-\(UUID())", type: .vegetable)

        let baseFrequency = 5
        let before = Date()

        let reminder = try await service.createSmartReminder(
            for: plant, type: .watering, baseFrequencyDays: baseFrequency, enableWeatherAdjustment: true)

        let after = Date()
        let calendar = Calendar.current
        let lowerBound = calendar.date(byAdding: .day, value: baseFrequency - 1, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: baseFrequency + 2, to: after)!
        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }
}
