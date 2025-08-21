import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct PlantReminderDetailView: View {
    let plant: Plant
    let reminderService: ReminderService
    let dataService: DataService
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminders: [PlantReminder] = []
    @State private var showingAddReminder = false
    @State private var selectedReminder: PlantReminder?
    @State private var showingDeleteConfirmation = false
    @State private var reminderToDelete: PlantReminder?
    
    public init(plant: Plant, reminderService: ReminderService, dataService: DataService) {
        self.plant = plant
        self.reminderService = reminderService
        self.dataService = dataService
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Plant header
                    plantHeaderView
                    
                    // Quick stats
                    quickStatsView
                    
                    // Active reminders
                    activeRemindersSection
                    
                    // Quick actions
                    quickActionsSection
                    
                    // Suggestion section
                    if !suggestedReminders.isEmpty {
                        suggestionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("\(plant.name) Care")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Reminder", systemImage: "plus") {
                        showingAddReminder = true
                    }
                }
            }
            .onAppear {
                loadReminders()
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(reminderService: reminderService, dataService: dataService)
                    .onDisappear {
                        loadReminders()
                    }
            }
            .sheet(item: $selectedReminder) { reminder in
                EditReminderView(
                    reminder: reminder,
                    reminderService: reminderService,
                    onSave: { loadReminders() },
                    onDelete: { reminderToDelete in
                        self.reminderToDelete = reminderToDelete
                        showingDeleteConfirmation = true
                    }
                )
            }
            .alert("Delete Reminder", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let reminder = reminderToDelete {
                        deleteReminder(reminder)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this reminder? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Plant Header View
    
    private var plantHeaderView: some View {
        HStack(spacing: 16) {
            // Plant icon
            Image(systemName: plantIcon)
                .font(.system(size: 40))
                .foregroundColor(plantColor)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(plantColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(plant.scientificName ?? plant.plantType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label(plant.plantType.displayName, systemImage: "leaf")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(plant.difficultyLevel.displayName, systemImage: "star")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Quick Stats View
    
    private var quickStatsView: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Active",
                value: "\(activeReminders.count)",
                icon: "bell.fill",
                color: .blue
            )
            
            StatCard(
                title: "Overdue",
                value: "\(overdueReminders.count)",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            
            StatCard(
                title: "Today",
                value: "\(todaysReminders.count)",
                icon: "calendar",
                color: .green
            )
        }
    }
    
    // MARK: - Active Reminders Section
    
    private var activeRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(activeReminders.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
            
            if activeReminders.isEmpty {
                emptyRemindersView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(activeReminders, id: \.id) { reminder in
                        ReminderDetailCard(
                            reminder: reminder,
                            onTap: { selectedReminder = reminder },
                            onComplete: { completeReminder(reminder) },
                            onToggle: { toggleReminder(reminder) }
                        )
                    }
                }
            }
        }
    }
    
    private var emptyRemindersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Active Reminders")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add a reminder to help you remember to care for \(plant.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add First Reminder") {
                showingAddReminder = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PlantDetailQuickActionButton(
                    title: "Water Now",
                    icon: "drop.fill",
                    color: .blue,
                    action: { completeWateringReminder() }
                )
                
                PlantDetailQuickActionButton(
                    title: "Add Watering",
                    icon: "plus.circle",
                    color: .green,
                    action: { addWateringReminder() }
                )
                
                PlantDetailQuickActionButton(
                    title: "Fertilize",
                    icon: "leaf.fill",
                    color: .orange,
                    action: { addFertilizingReminder() }
                )
                
                PlantDetailQuickActionButton(
                    title: "Health Check",
                    icon: "magnifyingglass",
                    color: .purple,
                    action: { addInspectionReminder() }
                )
            }
        }
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Reminders")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(suggestedReminders, id: \.type) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        onAccept: { acceptSuggestion(suggestion) }
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeReminders: [PlantReminder] {
        reminders.filter { $0.isEnabled }
    }
    
    private var overdueReminders: [PlantReminder] {
        activeReminders.filter { $0.nextDueDate < Date() }
    }
    
    private var todaysReminders: [PlantReminder] {
        activeReminders.filter { Calendar.current.isDateInToday($0.nextDueDate) }
    }
    
    private var suggestedReminders: [ReminderSuggestion] {
        // In a real implementation, this would be fetched from the reminder service
        return []
    }
    
    private var plantIcon: String {
        switch plant.plantType {
        case .houseplant: return "house.fill"
        case .succulent: return "circle.hexagongrid.fill"
        case .herb: return "leaf.fill"
        case .vegetable: return "carrot.fill"
        case .flower: return "camera.macro"
        case .fruit: return "apple.logo"
        case .tree: return "tree.fill"
        case .shrub: return "leaf.circle.fill"
        }
    }
    
    private var plantColor: Color {
        switch plant.plantType {
        case .houseplant, .herb, .shrub: return .green
        case .succulent: return .mint
        case .vegetable: return .orange
        case .flower: return .pink
        case .fruit: return .red
        case .tree: return .brown
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadReminders() {
        // Get all reminders for this plant
        let allReminders = dataService.fetchActiveReminders()
        reminders = allReminders.filter { $0.plant?.id == plant.id }
    }
    
    private func completeReminder(_ reminder: PlantReminder) {
        reminder.markCompleted()
        
        Task {
            if reminder.isRecurring {
                try? await reminderService.scheduleNotification(for: reminder)
            }
            
            await MainActor.run {
                loadReminders()
            }
        }
        
        // Provide feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func toggleReminder(_ reminder: PlantReminder) {
        reminder.isEnabled.toggle()
        
        Task {
            if reminder.isEnabled {
                try? await reminderService.scheduleNotification(for: reminder)
            } else {
                reminderService.cancelNotification(for: reminder)
            }
        }
    }
    
    private func deleteReminder(_ reminder: PlantReminder) {
        reminderService.cancelNotification(for: reminder)
        // In a real implementation, you would delete from the data service
        loadReminders()
    }
    
    private func completeWateringReminder() {
        if let wateringReminder = activeReminders.first(where: { $0.reminderType == .watering }) {
            completeReminder(wateringReminder)
        }
    }
    
    private func addWateringReminder() {
        // Set reminder type to watering and show add reminder sheet
        showingAddReminder = true
    }
    
    private func addFertilizingReminder() {
        Task {
            try? await reminderService.createSmartReminder(
                for: plant,
                type: .fertilizing,
                baseFrequencyDays: 28,
                priority: .medium
            )
            
            await MainActor.run {
                loadReminders()
            }
        }
    }
    
    private func addInspectionReminder() {
        Task {
            try? await reminderService.createSmartReminder(
                for: plant,
                type: .inspection,
                baseFrequencyDays: 7,
                priority: .low
            )
            
            await MainActor.run {
                loadReminders()
            }
        }
    }
    
    private func acceptSuggestion(_ suggestion: ReminderSuggestion) {
        Task {
            try? await reminderService.createSmartReminder(
                for: suggestion.plant,
                type: suggestion.type,
                baseFrequencyDays: suggestion.suggestedFrequencyDays,
                priority: suggestion.priority
            )
            
            await MainActor.run {
                loadReminders()
            }
        }
    }
}

// MARK: - Supporting Views

struct ReminderDetailCard: View {
    let reminder: PlantReminder
    let onTap: () -> Void
    let onComplete: () -> Void
    let onToggle: () -> Void
    
    private var isOverdue: Bool {
        reminder.nextDueDate < Date()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Toggle switch
            Toggle("", isOn: .constant(reminder.isEnabled))
                .onChange(of: reminder.isEnabled) { _ in
                    onToggle()
                }
            
            // Reminder info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: reminder.reminderType.iconName)
                        .foregroundColor(isOverdue ? .red : .blue)
                    
                    Text(reminder.reminderType.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                }
                
                Text(formatNextDueDate(reminder.nextDueDate))
                    .font(.subheadline)
                    .foregroundColor(isOverdue ? .red : .secondary)
                
                Text("Every \(reminder.frequency.displayName.lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                Button(action: onTap) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
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
        .opacity(reminder.isEnabled ? 1.0 : 0.6)
    }
    
    private func formatNextDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday (Overdue)"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct PlantDetailQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct SuggestionCard: View {
    let suggestion: ReminderSuggestion
    let onAccept: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.type.iconName)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.type.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("Every \(suggestion.suggestedFrequencyDays) day\(suggestion.suggestedFrequencyDays == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Add") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

// Placeholder for EditReminderView
struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Edit Reminder - Coming Soon")
                .navigationTitle("Edit Reminder")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { 
                            onSave()
                            dismiss() 
                        }
                    }
                }
        }
    }
}

#Preview {
    let plant = Plant(
        name: "Fiddle Leaf Fig",
        plantType: PlantType.houseplant,
        difficultyLevel: DifficultyLevel.intermediate
    )
    
    let dataService = try! DataService()
    let notificationService = NotificationService.shared
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
    
    PlantReminderDetailView(plant: plant, reminderService: reminderService, dataService: dataService)
}