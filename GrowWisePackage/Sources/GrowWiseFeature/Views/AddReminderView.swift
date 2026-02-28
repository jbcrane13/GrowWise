import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct AddReminderView: View {
    let reminderService: ReminderService
    let dataService: DataService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlant: Plant?
    @State private var reminderType: ReminderType = .watering
    @State private var frequency: ReminderFrequency = .weekly
    @State private var customDays: Int = 7
    @State private var preferredTime = Date()
    @State private var enableWeatherAdjustment = true
    @State private var priority: ReminderPriority = .medium
    @State private var customTitle = ""
    @State private var customMessage = ""
    @State private var showingPlantPicker = false

    @State private var isCreating = false
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var plants: [Plant] = []

    public init(reminderService: ReminderService, dataService: DataService) {
        self.reminderService = reminderService
        self.dataService = dataService
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Plant selection
                plantSelectionSection

                // Reminder type
                reminderTypeSection

                // Frequency settings
                frequencySection

                // Timing settings
                timingSection

                // Advanced settings
                advancedSettingsSection

                // Custom content (optional)
                customContentSection
            }
            .navigationTitle("Add Reminder")
            .task {
                do {
                    plants = try dataService.plants.fetchAll()
                } catch {
                    errorMessage = "Could not load plants: \(error.localizedDescription)"
                }
            }
            .onDisappear {
                saveTask?.cancel()
            }
            .gwNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        createReminder()
                    }
                    .disabled(selectedPlant == nil || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text("Creating reminder...")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Form Sections

    private var plantSelectionSection: some View {
        Section("Plant") {
            if let selectedPlant {
                HStack {
                    Image(systemName: plantIcon(for: selectedPlant))
                        .foregroundColor(plantColor(for: selectedPlant))
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading) {
                        Text(selectedPlant.name ?? "Unknown Plant")
                            .font(.headline)

                        Text(selectedPlant.plantType?.displayName ?? "Unknown Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Change") {
                        showingPlantPicker = true
                    }
                    .font(.subheadline)
                }
            } else {
                Button(action: { showingPlantPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)

                        Text("Select Plant")
                            .foregroundColor(.blue)

                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPlantPicker) {
            PlantPickerView(
                plants: plants,
                selectedPlant: $selectedPlant,
                onDismiss: { showingPlantPicker = false }
            )
        }
    }

    private var reminderTypeSection: some View {
        Section("Reminder Type") {
            Picker("Type", selection: $reminderType) {
                ForEach(ReminderType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.iconName)
                            .foregroundColor(colorForReminderType(type))

                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)

            Text(reminderType.defaultMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Frequency", selection: $frequency) {
                ForEach(frequencyOptions, id: \.self) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .pickerStyle(.menu)

            if case .custom = frequency {
                HStack {
                    Text("Every")

                    Spacer()

                    TextField("Days", value: $customDays, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Text("days")
                }
            }

            Text("This plant will be watered \(frequencyDescription)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            DatePicker(
                "Preferred Time",
                selection: $preferredTime,
                displayedComponents: .hourAndMinute
            )

            HStack {
                Text("Smart Weather Adjustment")
                Spacer()
                Toggle("", isOn: $enableWeatherAdjustment)
            }

            if enableWeatherAdjustment {
                Text("Reminders will adjust based on weather conditions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var advancedSettingsSection: some View {
        Section("Priority") {
            Picker("Priority", selection: $priority) {
                ForEach(ReminderPriority.allCases, id: \.self) { priority in
                    HStack {
                        Circle()
                            .fill(Color(priority.color))
                            .frame(width: 12, height: 12)

                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var customContentSection: some View {
        Section("Custom Content (Optional)") {
            ValidatedTextField(
                "Custom Title",
                text: $customTitle,
                validation: { ValidationService.shared.validateText($0, fieldName: "Title", maxLength: 100) }
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $customMessage)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                if customMessage.isEmpty {
                    Text("Custom Message")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: customMessage) { _, newValue in
                let validation = ValidationService.shared.validateText(newValue, fieldName: "Message", maxLength: 500)
                if !validation.isValid {
                    customMessage = String(newValue.prefix(500))
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var frequencyOptions: [ReminderFrequency] {
        [.daily, .everyOtherDay, .twiceWeekly, .weekly, .biweekly, .monthly, .custom]
    }

    private var frequencyDescription: String {
        let freq = frequency == .custom ? frequency : frequency

        switch freq {
        case .daily:
            return "every day"
        case .everyOtherDay:
            return "every other day"
        case .twiceWeekly:
            return "twice a week"
        case .weekly:
            return "once a week"
        case .biweekly:
            return "every 2 weeks"
        case .monthly:
            return "once a month"
        case .custom:
            return "every \(customDays) day\(customDays == 1 ? "" : "s")"
        case .once:
            return "one time only"
        default:
            return freq.displayName.lowercased()
        }
    }

    // MARK: - Helper Methods

    private func plantIcon(for plant: Plant) -> String {
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

    private func plantColor(for plant: Plant) -> Color {
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

    private func colorForReminderType(_ type: ReminderType) -> Color {
        switch type {
        case .watering: .blue
        case .fertilizing: .green
        case .pruning: .orange
        case .pestControl: .red
        default: .gray
        }
    }

    private func createReminder() {
        guard let plant = selectedPlant else {
            errorMessage = "Please select a plant"
            return
        }

        isCreating = true

        saveTask = Task {
            do {
                let actualFrequency = frequency == .custom ? frequency : frequency

                let reminder = try await reminderService.createSmartReminder(
                    for: plant,
                    type: reminderType,
                    baseFrequencyDays: actualFrequency.days,
                    enableWeatherAdjustment: enableWeatherAdjustment,
                    priority: priority,
                    preferredTime: preferredTime
                )

                // Apply custom content if provided
                if !customTitle.isEmpty {
                    reminder.title = customTitle
                }

                if !customMessage.isEmpty {
                    reminder.message = customMessage
                }

                // Provide success feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                await MainActor.run {
                    isCreating = false
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Plant Picker View

struct PlantPickerView: View {
    let plants: [Plant]
    @Binding var selectedPlant: Plant?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(plants, id: \.id) { plant in
                Button(action: {
                    selectedPlant = plant
                    onDismiss()
                }) {
                    HStack {
                        Image(systemName: plantIcon(for: plant))
                            .foregroundColor(plantColor(for: plant))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading) {
                            Text(plant.name ?? "Unknown Plant")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(plant.plantType?.displayName ?? "Unknown Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedPlant?.id == plant.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func plantIcon(for plant: Plant) -> String {
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

    private func plantColor(for plant: Plant) -> Color {
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
}

#Preview {
    let dataService = DataService.createFallback()
    let notificationService = NotificationService()
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)

    AddReminderView(reminderService: reminderService, dataService: dataService)
}
