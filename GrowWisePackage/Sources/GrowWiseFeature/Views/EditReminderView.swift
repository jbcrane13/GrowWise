import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void

    @Environment(\.dismiss)
    private var dismiss

    public init(
        reminder: PlantReminder,
        reminderService: ReminderService,
        onSave: @escaping () -> Void,
        onDelete: @escaping (PlantReminder) -> Void
    ) {
        self.reminder = reminder
        self.reminderService = reminderService
        self.onSave = onSave
        self.onDelete = onDelete
    }

    public var body: some View {
        // Body filled in by Task 8.
        Text("EditReminderView pending")
    }
}

extension EditReminderView {
    struct FormState: Equatable {
        var title: String
        var message: String
        var type: ReminderType
        var frequency: ReminderFrequency
        var customDays: Int
        var preferredTime: Date
        var priority: ReminderPriority
        var enableWeatherAdjustment: Bool
        var isEnabled: Bool

        static func initial(from reminder: PlantReminder) -> FormState {
            FormState(
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customDays: reminder.customFrequencyDays ?? max(1, reminder.frequency.days),
                preferredTime: reminder.preferredNotificationTime ?? reminder.nextDueDate,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }
}
