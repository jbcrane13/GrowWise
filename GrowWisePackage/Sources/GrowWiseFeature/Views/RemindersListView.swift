import SwiftUI
import UserNotifications
import GrowWiseModels
import GrowWiseServices

/// Full view for displaying and managing all plant reminders.
public struct RemindersListView: View {
    @Environment(DataService.self) private var dataService
    @Environment(NotificationService.self) private var notificationService

    @State private var reminders: [PlantReminder] = []
    @State private var isLoading = true
    @State private var selectedReminder: PlantReminder?
    @State private var showingDeleteAlert = false
    @State private var reminderToDelete: PlantReminder?

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading reminders...")
            } else if reminders.isEmpty {
                emptyStateView
            } else {
                remindersList
            }
        }
        .navigationTitle("Reminders")
        .gwNavigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadReminders()
        }
        .task {
            await loadReminders()
        }
        .alert("Delete Reminder", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let reminder = reminderToDelete {
                    deleteReminder(reminder)
                }
            }
        } message: {
            Text("Are you sure you want to delete this reminder?")
        }
        .accessibilityIdentifier("remindersListView")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add your first reminder to keep track of your plant care tasks")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .accessibilityLabel("No reminders available. Add your first reminder to keep track of your plant care tasks")
    }

    private var remindersList: some View {
        List {
            ForEach(groupedReminders.keys.sorted(), id: \.self) { dateKey in
                Section(dateKey) {
                    ForEach(groupedReminders[dateKey] ?? []) { reminder in
                        HomeReminderRowView(reminder: reminder) {
                            completeReminder(reminder)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                reminderToDelete = reminder
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedReminders: [String: [PlantReminder]] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [PlantReminder]] = [
            "Overdue": [],
            "Today": [],
            "Tomorrow": [],
            "This Week": [],
            "Later": []
        ]

        for reminder in reminders {
            // Skip disabled reminders (treated as completed)
            if !reminder.isEnabled {
                continue
            }

            let dueDate = reminder.nextDueDate

            if dueDate < now {
                groups["Overdue"]?.append(reminder)
            } else if calendar.isDateInToday(dueDate) {
                groups["Today"]?.append(reminder)
            } else if calendar.isDateInTomorrow(dueDate) {
                groups["Tomorrow"]?.append(reminder)
            } else if calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear) {
                groups["This Week"]?.append(reminder)
            } else {
                groups["Later"]?.append(reminder)
            }
        }

        // Remove empty sections
        return groups.filter { !$0.value.isEmpty }
    }

    @MainActor
    private func loadReminders() async {
        isLoading = true
        reminders = dataService.fetchActiveReminders()

        isLoading = false
    }

    private func completeReminder(_ reminder: PlantReminder) {
        reminder.isEnabled = false
        reminder.lastCompletedDate = Date()

        do {
            // Update reminder using completeReminder method
            try dataService.completeReminder(reminder)
            Task {
                await loadReminders()
            }
        } catch {
            print("Failed to complete reminder: \(error)")
        }
    }

    private func deleteReminder(_ reminder: PlantReminder) {
        do {
            try dataService.deleteReminder(reminder)
            Task {
                await loadReminders()
            }
        } catch {
            print("Failed to delete reminder: \(error)")
        }
    }

    private func scheduleNotificationForReminder(_ reminder: PlantReminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if !reminder.message.isEmpty {
            content.body = reminder.message
        }
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.nextDueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}

/// Row view for displaying a single reminder with completion checkbox.
struct HomeReminderRowView: View {
    let reminder: PlantReminder
    let onComplete: () -> Void

    @State private var isCompleted = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isCompleted.toggle()
                onComplete()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            Image(systemName: reminder.reminderType.iconName)
                .foregroundColor(priorityColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted)

                if let plant = reminder.plant {
                    Text(plant.name ?? "Unknown Plant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(dueDateText)
                    .font(.caption)
                    .foregroundColor(dueDateColor)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), \(dueDateText)")
    }

    private var priorityColor: Color {
        if Calendar.current.isDateInToday(reminder.nextDueDate) {
            return .orange
        } else if reminder.nextDueDate < Date() {
            return .red
        }
        return .blue
    }

    private var dueDateText: String {
        let calendar = Calendar.current
        let now = Date()

        if reminder.nextDueDate < now {
            return "Overdue"
        } else if calendar.isDateInToday(reminder.nextDueDate) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: reminder.nextDueDate))"
        } else if calendar.isDateInTomorrow(reminder.nextDueDate) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: reminder.nextDueDate))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: reminder.nextDueDate)
        }
    }

    private var dueDateColor: Color {
        if reminder.nextDueDate < Date() {
            return .red
        } else if Calendar.current.isDateInToday(reminder.nextDueDate) {
            return .orange
        }
        return .secondary
    }
}

#Preview {
    NavigationStack {
        RemindersListView()
    }
}
