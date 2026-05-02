import CoreLocation
import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
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
}
