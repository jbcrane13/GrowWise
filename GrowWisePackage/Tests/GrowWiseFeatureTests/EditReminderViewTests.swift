import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
import Testing

@Suite("EditReminderView.FormState mapping")
struct EditReminderViewTests {
    @Test("FormState.initial maps all editable fields")
    func mapsAllFields() {
        let preferred = Date(timeIntervalSinceReferenceDate: 100_000)
        let reminder = PlantReminder(
            title: "Water the basil",
            message: "Check for dry soil first",
            reminderType: .watering,
            frequency: .biweekly,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.priority = .high
        reminder.enableWeatherAdjustment = true
        reminder.preferredNotificationTime = preferred
        reminder.customFrequencyDays = nil
        reminder.isEnabled = true

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.title == "Water the basil")
        #expect(state.message == "Check for dry soil first")
        #expect(state.type == .watering)
        #expect(state.frequency == .biweekly)
        #expect(state.preferredTime == preferred)
        #expect(state.priority == .high)
        #expect(state.enableWeatherAdjustment == true)
        #expect(state.isEnabled == true)
    }

    @Test("FormState.initial uses nextDueDate when preferredNotificationTime is nil")
    func defaultsPreferredTimeToNextDueDate() {
        let dueDate = Date(timeIntervalSinceReferenceDate: 200_000)
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .weekly,
            nextDueDate: dueDate,
            plant: nil
        )
        reminder.preferredNotificationTime = nil

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.preferredTime == dueDate)
    }

    @Test("FormState.initial defaults customDays to frequency.days when nil")
    func defaultsCustomDaysFromFrequency() {
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .weekly,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.customFrequencyDays = nil

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.customDays == ReminderFrequency.weekly.days)
    }

    @Test("FormState.initial preserves customDays when set")
    func preservesCustomDays() {
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .custom,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.customFrequencyDays = 5

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.customDays == 5)
    }
}
