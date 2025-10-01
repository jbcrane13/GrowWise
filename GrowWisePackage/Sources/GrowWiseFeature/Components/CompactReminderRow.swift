import SwiftUI
import GrowWiseModels

/// A reusable compact reminder row component for displaying reminders in a compact format.
public struct CompactReminderRow: View {
    let reminder: PlantReminder

    public init(reminder: PlantReminder) {
        self.reminder = reminder
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.reminderType.iconName)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let plant = reminder.plant {
                    Text(plant.name ?? "Unknown Plant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(reminder.nextDueDate, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view reminder details")
    }

    private var accessibilityLabel: String {
        var label = "\(reminder.title) reminder"
        if let plant = reminder.plant {
            label += " for \(plant.name ?? "Unknown Plant")"
        }
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        label += ", due at \(timeFormatter.string(from: reminder.nextDueDate))"
        return label
    }
}

// Preview disabled - requires SwiftData ModelContext
// #Preview {
//     VStack(spacing: 12) {
//         Text("CompactReminderRow Preview")
//         Text("Requires SwiftData ModelContext")
//     }
//     .padding()
// }
