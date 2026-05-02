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
        try await service.updateReminder(
            reminder,
            title: reminder.title,
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
