import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@Suite("ReminderService.updateReminder")
@MainActor
struct ReminderServiceUpdateTests {
    // MARK: - Helpers

    // swiftlint:disable:next large_tuple
    private func makeService() async throws -> (ReminderService, DataService, Plant, PlantReminder) {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let service = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: false
        )
        let plant = try dataService.createPlant(name: "Basil-\(UUID())", type: .herb)
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: ReminderFrequency.weekly.days,
            enableWeatherAdjustment: false,
            priority: .medium,
            preferredTime: Date()
        )
        return (service, dataService, plant, reminder)
    }

    // MARK: - Smoke

    @Test("updateReminder stub completes without throwing")
    func stubCompletes() async throws {
        let (service, _, _, reminder) = try await makeService()
        // createSmartReminder stores frequency as .custom internally; pass .weekly
        // (the logical frequency) so validation does not reject a nil customFrequencyDays.
        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )
    }

    // MARK: - Validation

    @Test("updateReminder rejects empty title")
    func rejectsEmptyTitle() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: "",
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customFrequencyDays: reminder.customFrequencyDays,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects whitespace-only title")
    func rejectsWhitespaceTitle() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: "   \n  ",
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customFrequencyDays: reminder.customFrequencyDays,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects custom frequency without days")
    func rejectsCustomFrequencyWithoutDays() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: .custom,
                customFrequencyDays: nil,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects custom frequency below 1 day")
    func rejectsCustomFrequencyBelowOne() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: .custom,
                customFrequencyDays: 0,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    // MARK: - Mutation

    @Test("updateReminder mutates editable fields")
    func mutatesEditableFields() async throws {
        let (service, _, _, reminder) = try await makeService()
        let newTime = Date(timeIntervalSinceNow: 3600)

        try await service.updateReminder(
            reminder,
            title: "Updated title",
            message: "Updated message",
            type: .fertilizing,
            frequency: .biweekly,
            customFrequencyDays: nil,
            preferredTime: newTime,
            priority: .high,
            enableWeatherAdjustment: true,
            isEnabled: true
        )

        #expect(reminder.title == "Updated title")
        #expect(reminder.message == "Updated message")
        #expect(reminder.reminderType == .fertilizing)
        #expect(reminder.frequency == .biweekly)
        #expect(reminder.baseFrequencyDays == ReminderFrequency.biweekly.days)
        #expect(reminder.customFrequencyDays == nil)
        #expect(reminder.preferredNotificationTime == newTime)
        #expect(reminder.priority == .high)
        #expect(reminder.enableWeatherAdjustment == true)
        #expect(reminder.isEnabled == true)
    }

    @Test("updateReminder advances lastModified")
    func advancesLastModified() async throws {
        let (service, _, _, reminder) = try await makeService()
        let pre = reminder.lastModified
        try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms — ensures clock advances on fast machines

        try await service.updateReminder(
            reminder,
            title: "New title",
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.lastModified > pre)
    }

    // MARK: - Schedule recalc

    @Test("updateReminder recalculates nextDueDate when frequency changes")
    func recalculatesNextDueDateOnFrequencyChange() async throws {
        let (service, _, _, reminder) = try await makeService()
        let originalDate = reminder.nextDueDate
        // Reminder was created weekly. Switch to daily — next due should move much closer.

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .daily,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.nextDueDate != originalDate)
        // Daily reminder should be due within ~2 days; weekly is ~7 days out.
        let twoDays: TimeInterval = 60 * 60 * 24 * 2
        #expect(reminder.nextDueDate.timeIntervalSinceNow < twoDays)
    }

    @Test("updateReminder leaves nextDueDate alone when only title changes")
    func preservesNextDueDateWhenScheduleUnchanged() async throws {
        let (service, _, _, reminder) = try await makeService()
        let originalDate = reminder.nextDueDate

        try await service.updateReminder(
            reminder,
            title: "Renamed",
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .weekly,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.nextDueDate == originalDate)
    }

    @Test("updateReminder accepts custom frequency days")
    func acceptsCustomFrequencyDays() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .custom,
            customFrequencyDays: 3,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.frequency == .custom)
        #expect(reminder.customFrequencyDays == 3)
    }

    // MARK: - Message prefill on type change

    @Test("updateReminder prefills message with new type's default when message is empty and type changes")
    func prefillsMessageOnTypeChangeWhenEmpty() async throws {
        let (service, _, _, reminder) = try await makeService()
        // Original reminder is .watering; change to .fertilizing with empty message.

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "",
            type: .fertilizing,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == ReminderType.fertilizing.defaultMessage)
    }

    @Test("updateReminder preserves user message when type changes and message is non-empty")
    func preservesUserMessageOnTypeChange() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "Custom user message",
            type: .fertilizing,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == "Custom user message")
    }

    @Test("updateReminder preserves empty message when type does not change")
    func preservesEmptyMessageWhenTypeUnchanged() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "",
            type: reminder.reminderType, // unchanged
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == "")
    }

    // MARK: - Notification reschedule

    @Test("updateReminder runs without throwing when shouldScheduleNotifications is true")
    func runsWithSchedulingEnabled() async throws {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let service = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: true
        )
        let plant = try dataService.createPlant(name: "Mint-\(UUID())", type: .herb)
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: ReminderFrequency.weekly.days,
            enableWeatherAdjustment: false,
            priority: .medium,
            preferredTime: Date()
        )

        // Toggle isEnabled both ways and change frequency — exercises both cancel and schedule branches.
        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .daily,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: false // disable — should hit the cancel branch
        )

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: true // re-enable — should hit the cancel + schedule branches
        )

        #expect(reminder.isEnabled == true)
    }
}
