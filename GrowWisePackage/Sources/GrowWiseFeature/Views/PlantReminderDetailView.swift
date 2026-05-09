import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable file_length type_body_length

public struct PlantReminderDetailView: View {
    let plant: Plant
    let reminderService: ReminderService
    let dataService: DataService

    @Environment(\.dismiss)
    private var dismiss

    @State private var reminders: [PlantReminder] = []
    @State private var showingAddReminder = false
    @State private var selectedReminder: PlantReminder?
    @State private var showingDeleteConfirmation = false
    @State private var reminderToDelete: PlantReminder?
    @State private var showingError = false
    @State private var errorMessage = ""

    public init(plant: Plant, reminderService: ReminderService, dataService: DataService) {
        self.plant = plant
        self.reminderService = reminderService
        self.dataService = dataService
    }

    private var plantDisplayName: String {
        plant.name ?? "Unknown Plant"
    }

    public var body: some View {
        NavigationStack {
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
            .navigationTitle(plantDisplayName + " Care")
            .gwNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("plantreminder_button_done")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add Reminder", systemImage: "plus") {
                        showingAddReminder = true
                    }
                    .accessibilityIdentifier("plantreminder_button_addreminder")
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
                .accessibilityIdentifier("plantreminder_button_delete_confirm")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("plantreminder_button_delete_cancel")
            } message: {
                Text("Are you sure you want to delete this reminder? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
                    .accessibilityIdentifier("plantreminder_button_error_ok")
            } message: {
                Text(errorMessage)
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
                Text(plant.name ?? "Unknown Plant")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(plant.scientificName ?? plant.plantType?.displayName ?? "Unknown Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Label(plant.plantType?.displayName ?? "Unknown Type", systemImage: "leaf")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(plant.difficultyLevel?.displayName ?? "Unknown", systemImage: "star")
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
        let cats = categorizedReminders
        return HStack(spacing: 16) {
            StatCard(
                title: "Active",
                value: "\(cats.active.count)",
                icon: "bell.fill",
                color: .blue
            )

            StatCard(
                title: "Overdue",
                value: "\(cats.overdue.count)",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )

            StatCard(
                title: "Today",
                value: "\(cats.today.count)",
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

            Text(verbatim: "Add a reminder to help you remember to care for \(plantDisplayName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Add First Reminder") {
                showingAddReminder = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("plantreminder_button_addfirst")
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
                GridItem(.flexible()),
            ], spacing: 12) {
                PlantDetailQuickActionButton(
                    title: "Water Now",
                    icon: "drop.fill",
                    color: .blue,
                    action: { completeWateringReminder() }
                )
                .accessibilityIdentifier("plantreminder_button_waternow")

                PlantDetailQuickActionButton(
                    title: "Add Watering",
                    icon: "plus.circle",
                    color: .green,
                    action: { addWateringReminder() }
                )
                .accessibilityIdentifier("plantreminder_button_addwatering")

                PlantDetailQuickActionButton(
                    title: "Fertilize",
                    icon: "leaf.fill",
                    color: .orange,
                    action: { addFertilizingReminder() }
                )
                .accessibilityIdentifier("plantreminder_button_fertilize")

                PlantDetailQuickActionButton(
                    title: "Health Check",
                    icon: "magnifyingglass",
                    color: .purple,
                    action: { addInspectionReminder() }
                )
                .accessibilityIdentifier("plantreminder_button_healthcheck")
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

    private struct CategorizedReminders {
        var active: [PlantReminder] = []
        var overdue: [PlantReminder] = []
        var today: [PlantReminder] = []
    }

    private var categorizedReminders: CategorizedReminders {
        let now = Date()
        let calendar = Calendar.current
        var result = CategorizedReminders()
        for reminder in reminders where reminder.isEnabled {
            result.active.append(reminder)
            if reminder.nextDueDate < now {
                result.overdue.append(reminder)
            }
            if calendar.isDateInToday(reminder.nextDueDate) {
                result.today.append(reminder)
            }
        }
        return result
    }

    private var activeReminders: [PlantReminder] {
        categorizedReminders.active
    }

    private var overdueReminders: [PlantReminder] {
        categorizedReminders.overdue
    }

    private var todaysReminders: [PlantReminder] {
        categorizedReminders.today
    }

    private var suggestedReminders: [ReminderSuggestion] {
        // In a real implementation, this would be fetched from the reminder service
        []
    }

    private var plantIcon: String {
        switch plant.plantType {
        case .houseplant: "house.fill"
        case .succulent: "circle.hexagongrid.fill"
        case .herb: "leaf.fill"
        case .vegetable: "carrot.fill"
        case .flower: "camera.macro"
        case .fruit: "apple.logo"
        case .tree: "tree.fill"
        case .shrub: "leaf.circle.fill"
        case .none: "questionmark.circle.fill"
        }
    }

    private var plantColor: Color {
        switch plant.plantType {
        case .houseplant, .herb, .shrub: .green
        case .succulent: .mint
        case .vegetable: .orange
        case .flower: .pink
        case .fruit: .red
        case .tree: .brown
        case .none: .gray
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
            do {
                if reminder.isRecurring {
                    try await reminderService.scheduleNotification(for: reminder)
                }
            } catch {
                errorMessage = "Failed to reschedule reminder: \(error.localizedDescription)"
                showingError = true
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
            do {
                if reminder.isEnabled {
                    try await reminderService.scheduleNotification(for: reminder)
                } else {
                    reminderService.cancelNotification(for: reminder)
                }
            } catch {
                errorMessage = "Failed to update reminder notification: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func deleteReminder(_ reminder: PlantReminder) {
        do {
            reminderService.cancelNotification(for: reminder)
            try dataService.deleteReminder(reminder)
            loadReminders()
        } catch {
            errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
            showingError = true
        }
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
            do {
                _ = try await reminderService.createSmartReminder(
                    for: plant,
                    type: .fertilizing,
                    baseFrequencyDays: 28,
                    priority: .medium
                )
            } catch {
                errorMessage = "Failed to create fertilizing reminder: \(error.localizedDescription)"
                showingError = true
            }

            await MainActor.run {
                loadReminders()
            }
        }
    }

    private func addInspectionReminder() {
        Task {
            do {
                _ = try await reminderService.createSmartReminder(
                    for: plant,
                    type: .inspection,
                    baseFrequencyDays: 7,
                    priority: .low
                )
            } catch {
                errorMessage = "Failed to create inspection reminder: \(error.localizedDescription)"
                showingError = true
            }

            await MainActor.run {
                loadReminders()
            }
        }
    }

    private func acceptSuggestion(_ suggestion: ReminderSuggestion) {
        Task {
            do {
                _ = try await reminderService.createSmartReminder(
                    for: suggestion.plant,
                    type: suggestion.type,
                    baseFrequencyDays: suggestion.suggestedFrequencyDays,
                    priority: suggestion.priority
                )
            } catch {
                errorMessage = "Failed to create reminder: \(error.localizedDescription)"
                showingError = true
            }

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
            Toggle(
                "",
                isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { _ in onToggle() }
                )
            )

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
                .accessibilityIdentifier("plantreminder_button_complete")

                Button(action: onTap) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("plantreminder_button_edit")
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

    private static let timeOnlyFormatter: DateFormatter = {
        // swiftlint:disable:next identifier_name
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        // swiftlint:disable:next identifier_name
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formatNextDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            "Today at \(Self.timeOnlyFormatter.string(from: date))"
        } else if Calendar.current.isDateInTomorrow(date) {
            "Tomorrow at \(Self.timeOnlyFormatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            "Yesterday (Overdue)"
        } else {
            Self.dateTimeFormatter.string(from: date)
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
            .accessibilityIdentifier("plantreminder_button_suggestion_add")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

#Preview {
    let plant = Plant(
        name: "Fiddle Leaf Fig",
        plantType: PlantType.houseplant,
        difficultyLevel: DifficultyLevel.intermediate
    )

    let dataService = DataService.createFallback()
    let notificationService = NotificationService()
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)

    PlantReminderDetailView(plant: plant, reminderService: reminderService, dataService: dataService)
}

// swiftlint:enable file_length type_body_length
