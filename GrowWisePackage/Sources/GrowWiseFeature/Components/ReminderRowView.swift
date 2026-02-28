import SwiftUI
import GrowWiseModels
import GrowWiseServices

#if canImport(UIKit)
import UIKit
#endif

public struct ReminderRowView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    
    @State private var isCompleting = false
    @State private var showingSnoozeOptions = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    public init(reminder: PlantReminder, reminderService: ReminderService) {
        self.reminder = reminder
        self.reminderService = reminderService
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Plant and reminder type icon
            VStack(spacing: 4) {
                Image(systemName: reminder.reminderType.iconName)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(priorityColor.opacity(0.1))
                    )
                
                Text(reminder.reminderType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Reminder details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.plant?.name ?? "Unknown Plant")
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(reminder.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // Due date info
                    dueDateView
                    
                    Spacer()
                    
                    // Priority indicator
                    priorityIndicator
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: completeReminder) {
                    if isCompleting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
                .disabled(isCompleting)
                
                Button(action: { showingSnoozeOptions = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                .disabled(isCompleting)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isOverdue ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .confirmationDialog("Snooze Reminder", isPresented: $showingSnoozeOptions) {
            ForEach(SnoozeDuration.allCases, id: \.self) { duration in
                Button(duration.displayName) {
                    snoozeReminder(for: duration)
                }
            }

            Button("Cancel", role: .cancel) { }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .opacity(reminder.isEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Computed Properties
    
    private var isOverdue: Bool {
        reminder.nextDueDate < Date()
    }
    
    private var priorityColor: Color {
        if isOverdue {
            return .red
        }
        
        switch reminder.priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var dueDateView: some View {
        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                .font(.caption)
                .foregroundColor(isOverdue ? .red : .secondary)
            
            Text(dueDateText)
                .font(.caption)
                .fontWeight(isOverdue ? .semibold : .regular)
                .foregroundColor(isOverdue ? .red : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isOverdue ? Color.red.opacity(0.1) : Color(.systemGray6))
        )
    }
    
    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    private var dueDateText: String {
        if Calendar.current.isDateInToday(reminder.nextDueDate) {
            return "Today \(Self.timeOnlyFormatter.string(from: reminder.nextDueDate))"
        } else if Calendar.current.isDateInYesterday(reminder.nextDueDate) {
            return "Yesterday"
        } else if Calendar.current.isDateInTomorrow(reminder.nextDueDate) {
            return "Tomorrow \(Self.timeOnlyFormatter.string(from: reminder.nextDueDate))"
        } else {
            return Self.dateOnlyFormatter.string(from: reminder.nextDueDate)
        }
    }
    
    private var priorityIndicator: some View {
        HStack(spacing: 2) {
            ForEach(1...reminder.priority.numericValue, id: \.self) { _ in
                Circle()
                    .fill(priorityColor)
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func completeReminder() {
        isCompleting = true
        
        Task {
            do {
                // Mark reminder as completed
                reminder.markCompleted()
                
                // Create completion feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
                // Reschedule notification if recurring
                if reminder.isRecurring {
                    try await reminderService.notificationService.scheduleReminderNotification(for: reminder)
                }
                
                await MainActor.run {
                    isCompleting = false
                }
                
            } catch {
                await MainActor.run {
                    isCompleting = false
                    alertTitle = "Action Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    private func snoozeReminder(for duration: SnoozeDuration) {
        reminder.snooze(for: duration)
        
        Task {
            do {
                // Reschedule notification with new time
                try await reminderService.notificationService.scheduleReminderNotification(for: reminder)
                
                // Provide feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
            } catch {
                await MainActor.run {
                    alertTitle = "Action Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    let plant = Plant(
        name: "Snake Plant",
        plantType: PlantType.houseplant,
        difficultyLevel: DifficultyLevel.beginner
    )
    
    let reminder = PlantReminder(
        title: "Water Snake Plant",
        message: "Check soil moisture and water if needed",
        reminderType: .watering,
        frequency: .weekly,
        nextDueDate: Date(),
        plant: plant
    )
    
    let dataService = try! DataService()
    let notificationService = NotificationService()
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
    
    VStack(spacing: 16) {
        ReminderRowView(reminder: reminder, reminderService: reminderService)
        
        // Create an overdue reminder for comparison
        let overdueReminder = PlantReminder(
            title: "Fertilize Pothos",
            message: "Apply liquid fertilizer",
            reminderType: .fertilizing,
            frequency: .monthly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            plant: plant
        )
        
        ReminderRowView(reminder: overdueReminder, reminderService: reminderService)
    }
    .padding()
    #if canImport(UIKit)
    .background(Color(.systemGroupedBackground))
    #else
    .background(Color(.controlBackgroundColor))
    #endif
}