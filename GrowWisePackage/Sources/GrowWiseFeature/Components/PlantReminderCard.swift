import SwiftUI
import GrowWiseModels
import GrowWiseServices

#if canImport(UIKit)
import UIKit
#endif

public struct PlantReminderCard: View {
    let plant: Plant
    let reminderService: ReminderService
    let onTap: () -> Void
    
    @State private var wateringReminders: [PlantReminder] = []
    @State private var showingReminderDetail = false
    
    public init(plant: Plant, reminderService: ReminderService, onTap: @escaping () -> Void) {
        self.plant = plant
        self.reminderService = reminderService
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Plant header
                HStack {
                    // Plant icon based on type
                    Image(systemName: plantIcon)
                        .font(.title2)
                        .foregroundColor(plantColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(plantColor.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plant.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(plant.plantType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Active reminder count
                    if !wateringReminders.isEmpty {
                        Text("\(wateringReminders.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(
                                Circle()
                                    .fill(hasOverdueReminders ? Color.red : Color.blue)
                            )
                    }
                }
                
                // Next watering info
                if let nextWatering = nextWateringReminder {
                    nextWateringView(nextWatering)
                } else {
                    noRemindersView
                }
                
                // Quick action buttons
                actionButtonsView
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(hasOverdueReminders ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadWateringReminders()
        }
        .sheet(isPresented: $showingReminderDetail) {
            PlantReminderDetailView(
                plant: plant,
                reminderService: reminderService,
                dataService: reminderService.dataService
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var plantIcon: String {
        switch plant.plantType {
        case .houseplant:
            return "house.fill"
        case .succulent:
            return "circle.hexagongrid.fill"
        case .herb:
            return "leaf.fill"
        case .vegetable:
            return "carrot.fill"
        case .flower:
            return "camera.macro"
        case .fruit:
            return "apple.logo"
        case .tree:
            return "tree.fill"
        case .shrub:
            return "leaf.circle.fill"
        }
    }
    
    private var plantColor: Color {
        switch plant.plantType {
        case .houseplant:
            return .green
        case .succulent:
            return .mint
        case .herb:
            return .green
        case .vegetable:
            return .orange
        case .flower:
            return .pink
        case .fruit:
            return .red
        case .tree:
            return .brown
        case .shrub:
            return .green
        }
    }
    
    private var nextWateringReminder: PlantReminder? {
        wateringReminders
            .filter { $0.isEnabled }
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .first
    }
    
    private var hasOverdueReminders: Bool {
        wateringReminders.contains { $0.nextDueDate < Date() && $0.isEnabled }
    }
    
    // MARK: - Subviews
    
    private func nextWateringView(_ reminder: PlantReminder) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Next Watering")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if reminder.nextDueDate < Date() {
                    Text("OVERDUE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.1))
                        )
                }
            }
            
            Text(formatNextWateringDate(reminder.nextDueDate))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(reminder.nextDueDate < Date() ? .red : .primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    private var noRemindersView: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "bell.slash")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("No Reminders")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text("Tap to add watering schedule")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Quick water button
            Button(action: quickWaterAction) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                    
                    Text("Water")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            Spacer()
            
            // View details button
            Button(action: { showingReminderDetail = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.caption)
                    
                    Text("Manage")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.quaternarySystemFill))
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadWateringReminders() {
        wateringReminders = reminderService.getWateringReminders(for: plant)
    }
    
    private func formatNextWateringDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Tomorrow at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday (Overdue)"
        } else {
            let daysDifference = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
            
            if daysDifference < 0 {
                return "\(abs(daysDifference)) days overdue"
            } else if daysDifference <= 7 {
                formatter.dateFormat = "EEEE"
                let dayName = formatter.string(from: date)
                formatter.timeStyle = .short
                formatter.dateStyle = .none
                return "\(dayName) at \(formatter.string(from: date))"
            } else {
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        }
    }
    
    private func quickWaterAction() {
        // Find the most urgent watering reminder and mark it complete
        if let reminder = nextWateringReminder {
            Task {
                reminder.markCompleted()
                
                // Provide haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                // Refresh reminders
                loadWateringReminders()
                
                // Reschedule notification if recurring
                if reminder.isRecurring {
                    try? await reminderService.notificationService.scheduleReminderNotification(for: reminder)
                }
            }
        }
    }
}

#Preview {
    let plant = Plant(
        name: "Monstera Deliciosa",
        plantType: PlantType.houseplant,
        difficultyLevel: DifficultyLevel.intermediate
    )
    
    let dataService = try! DataService()
    let notificationService = NotificationService.shared
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
    
    VStack(spacing: 16) {
        PlantReminderCard(
            plant: plant,
            reminderService: reminderService,
            onTap: { print("Plant tapped: \(plant.name)") }
        )
        
        PlantReminderCard(
            plant: Plant(
                name: "Snake Plant",
                plantType: .succulent,
                difficultyLevel: .beginner
            ),
            reminderService: reminderService,
            onTap: { print("Plant tapped") }
        )
    }
    .padding()
    #if canImport(UIKit)
    .background(Color(.systemGroupedBackground))
    #else
    .background(Color(.controlBackgroundColor))
    #endif
}