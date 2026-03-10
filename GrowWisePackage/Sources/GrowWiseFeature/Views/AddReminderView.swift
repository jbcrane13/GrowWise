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
            ZStack {
                CultivationTheme.Colors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                        // Drag handle
                        Capsule()
                            .fill(CultivationTheme.Colors.cardBorder)
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        plantSelectionSection
                        reminderTypeSection
                        frequencySection
                        timingSection
                        prioritySection
                        customContentSection

                        // Save Button
                        Button {
                            createReminder()
                        } label: {
                            HStack(spacing: 8) {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                }
                                Text(isCreating ? "Creating..." : "Create Reminder")
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDisabled: selectedPlant == nil || isCreating))
                        .disabled(selectedPlant == nil || isCreating)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("addreminder_button_create")
                        .padding(.bottom, 24)
                    }
                }

                // Creating overlay
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text("Creating reminder...")
                                .font(.headline)
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                        .padding(32)
                        .glassCard()
                    }
                }
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
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("addreminder_button_cancel")
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
        }
    }

    // MARK: - Form Sections

    private var plantSelectionSection: some View {
        reminderFormSection(title: "Plant") {
            if let selectedPlant {
                HStack(spacing: 12) {
                    IconBubble(
                        systemName: plantIcon(for: selectedPlant),
                        color: plantColor(for: selectedPlant),
                        size: 36,
                        iconSize: 16
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPlant.name ?? "Unknown Plant")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)

                        Text(selectedPlant.plantType?.displayName ?? "Unknown Type")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Button("Change") {
                        showingPlantPicker = true
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    .accessibilityIdentifier("addreminder_button_changeplant")
                }
            } else {
                Button(action: { showingPlantPicker = true }) {
                    HStack(spacing: 10) {
                        IconBubble(systemName: "plus.circle.fill", color: CultivationTheme.Colors.brandLeaf, size: 32, iconSize: 15)
                        Text("Select Plant")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        Spacer()
                    }
                }
                .accessibilityIdentifier("addreminder_button_selectplant")
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
        reminderFormSection(title: "Reminder Type") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderType.allCases, id: \.self) { type in
                            GlassPill(
                                label: type.displayName,
                                isSelected: reminderType == type,
                                accessibilityID: "addreminder_pill_type_\(type.rawValue)"
                            ) {
                                reminderType = type
                            }
                        }
                    }
                }

                Text(reminderType.defaultMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    private var frequencySection: some View {
        reminderFormSection(title: "Frequency") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frequencyOptions, id: \.self) { freq in
                            GlassPill(
                                label: freq.displayName,
                                isSelected: frequency == freq,
                                accessibilityID: "addreminder_pill_frequency_\(freq.displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
                            ) {
                                frequency = freq
                            }
                        }
                    }
                }

                if case .custom = frequency {
                    HStack {
                        Text("Every")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)

                        Spacer()

                        TextField("Days", value: $customDays, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityIdentifier("addreminder_textfield_customdays")

                        Text("days")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }

                Text("This plant will be watered \(frequencyDescription)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    private var timingSection: some View {
        reminderFormSection(title: "Timing") {
            VStack(spacing: 12) {
                HStack {
                    IconBubble(systemName: "clock.fill", color: CultivationTheme.Colors.brandForest, size: 28, iconSize: 13)
                    DatePicker(
                        "Preferred Time",
                        selection: $preferredTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.system(.subheadline, design: .rounded))
                    .accessibilityIdentifier("addreminder_datepicker_time")
                }

                Divider()
                    .background(CultivationTheme.Colors.divider)

                HStack {
                    IconBubble(systemName: "cloud.sun.fill", color: CultivationTheme.Colors.brandGold, size: 28, iconSize: 13)
                    Text("Smart Weather Adjustment")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $enableWeatherAdjustment)
                        .accessibilityIdentifier("addreminder_toggle_weatheradjustment")
                }

                if enableWeatherAdjustment {
                    Text("Reminders will adjust based on weather conditions")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
        }
    }

    private var prioritySection: some View {
        reminderFormSection(title: "Priority") {
            HStack(spacing: 8) {
                ForEach(ReminderPriority.allCases, id: \.self) { p in
                    GlassPill(
                        label: p.displayName,
                        isSelected: priority == p,
                        accessibilityID: "addreminder_pill_priority_\(p.displayName.lowercased())"
                    ) {
                        priority = p
                    }
                }
            }
        }
    }

    private var customContentSection: some View {
        reminderFormSection(title: "Custom Content (Optional)") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    IconBubble(systemName: "textformat", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                    ValidatedTextField(
                        "Custom Title",
                        text: $customTitle,
                        validation: { ValidationService.shared.validateText($0, fieldName: "Title", maxLength: 100) }
                    )
                    .accessibilityIdentifier("addreminder_textfield_customtitle")
                }

                Divider()
                    .background(CultivationTheme.Colors.divider)

                HStack(alignment: .top, spacing: 10) {
                    IconBubble(systemName: "text.alignleft", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                        .padding(.top, 2)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $customMessage)
                            .frame(minHeight: 80)
                            .font(.system(.body))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .accessibilityIdentifier("addreminder_texteditor_custommessage")
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            )
                            .onChange(of: customMessage) { _, newValue in
                                let validation = ValidationService.shared.validateText(newValue, fieldName: "Message", maxLength: 500)
                                if !validation.isValid {
                                    customMessage = String(newValue.prefix(500))
                                }
                            }

                        if customMessage.isEmpty {
                            Text("Custom Message")
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Form Section Builder

    @ViewBuilder
    private func reminderFormSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            content()
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
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
        case .houseplant, .herb, .shrub: CultivationTheme.Colors.brandLeaf
        case .succulent: .mint
        case .vegetable: .orange
        case .flower: .pink
        case .fruit: .red
        case .tree: .brown
        case .none: CultivationTheme.Colors.textTertiary
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
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)

                            Text(plant.plantType?.displayName ?? "Unknown Type")
                                .font(.caption)
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if selectedPlant?.id == plant.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addreminder_cell_plant_\(plant.id)")
            }
            .navigationTitle("Select Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .accessibilityIdentifier("addreminder_button_plantpickercancel")
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
        case .houseplant, .herb, .shrub: CultivationTheme.Colors.brandLeaf
        case .succulent: .mint
        case .vegetable: .orange
        case .flower: .pink
        case .fruit: .red
        case .tree: .brown
        case .none: CultivationTheme.Colors.textTertiary
        }
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let notificationService = NotificationService()
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)

    AddReminderView(reminderService: reminderService, dataService: dataService)
}
