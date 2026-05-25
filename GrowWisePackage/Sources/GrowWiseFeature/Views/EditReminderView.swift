import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable type_body_length

public struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var title: String
    @State private var message: String
    @State private var reminderType: ReminderType
    @State private var frequency: ReminderFrequency
    @State private var customDays: Int
    @State private var preferredTime: Date
    @State private var priority: ReminderPriority
    @State private var enableWeatherAdjustment: Bool
    @State private var isPaused: Bool

    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String?

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
        let initial = FormState.initial(from: reminder)
        _title = State(initialValue: initial.title)
        _message = State(initialValue: initial.message)
        _reminderType = State(initialValue: initial.type)
        _frequency = State(initialValue: initial.frequency)
        _customDays = State(initialValue: initial.customDays)
        _preferredTime = State(initialValue: initial.preferredTime)
        _priority = State(initialValue: initial.priority)
        _enableWeatherAdjustment = State(initialValue: initial.enableWeatherAdjustment)
        _isPaused = State(initialValue: !initial.isEnabled)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                        Capsule()
                            .fill(CultivationTheme.Colors.cardBorder)
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        plantHeader
                        reminderTypeSection
                        frequencySection
                        timingSection
                        prioritySection
                        customContentSection
                        pauseSection

                        Button(role: .destructive) {
                            onDelete(reminder)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Delete Reminder")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(CultivationTheme.Colors.statusAlert)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("editreminder_button_delete")

                        Button {
                            save()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isSaving ? "Saving..." : "Save Changes")
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDisabled: isSaving))
                        .disabled(isSaving)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("plantreminder_button_edit_save")
                        .padding(.bottom, 24)
                    }
                }

                if isSaving {
                    ZStack {
                        CultivationTheme.Colors.textPrimary.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.2)
                            Text("Saving changes...")
                                .font(.headline)
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                        .padding(32)
                        .paperCard()
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .gwNavigationBarTitleDisplayMode(.inline)
            .onDisappear { saveTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("plantreminder_button_edit_cancel")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
                    .accessibilityIdentifier("editreminder_button_error_ok")
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Plant header (read-only)

    private var plantHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plant")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            HStack(spacing: 12) {
                IconBubble(
                    systemName: plantIcon(for: reminder.plant),
                    color: plantColor(for: reminder.plant),
                    size: 36,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.plant?.name ?? "Unknown Plant")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Text(reminder.plant?.plantType?.displayName ?? "Unknown Type")
                        .font(.system(.caption))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        }
    }

    // MARK: - Form sections

    private var reminderTypeSection: some View {
        formSection(title: "Reminder Type") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderType.allCases, id: \.self) { type in
                            GlassPill(
                                label: type.displayName,
                                isSelected: reminderType == type,
                                accessibilityID: "editreminder_pill_type_\(type.rawValue)"
                            ) {
                                reminderType = type
                            }
                        }
                    }
                }
                Text(reminderType.defaultMessage)
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    private var frequencySection: some View {
        formSection(title: "Frequency") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frequencyOptions, id: \.self) { freq in
                            GlassPill(
                                label: freq.displayName,
                                isSelected: frequency == freq,
                                // swiftlint:disable:next line_length
                                accessibilityID: "editreminder_pill_frequency_\(freq.displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
                            ) {
                                frequency = freq
                            }
                        }
                    }
                }

                if case .custom = frequency {
                    HStack {
                        Text("Every")
                            .font(.system(.subheadline))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        Spacer()
                        TextField("Days", value: $customDays, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityIdentifier("editreminder_textfield_customdays")
                        Text("days")
                            .font(.system(.subheadline))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        formSection(title: "Timing") {
            VStack(spacing: 12) {
                HStack {
                    IconBubble(systemName: "clock.fill", color: CultivationTheme.Colors.brandForest, size: 28, iconSize: 13)
                    DatePicker("Preferred Time", selection: $preferredTime, displayedComponents: .hourAndMinute)
                        .font(.system(.subheadline))
                        .accessibilityIdentifier("editreminder_datepicker_time")
                }

                Divider().background(CultivationTheme.Colors.divider)

                HStack {
                    IconBubble(systemName: "cloud.sun.fill", color: CultivationTheme.Colors.accentAmber, size: 28, iconSize: 13)
                    Text("Smart Weather Adjustment")
                        .font(.system(.subheadline))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $enableWeatherAdjustment)
                        .accessibilityIdentifier("editreminder_toggle_weatheradjustment")
                }
            }
        }
    }

    private var prioritySection: some View {
        formSection(title: "Priority") {
            HStack(spacing: 8) {
                // swiftlint:disable:next identifier_name
                ForEach(ReminderPriority.allCases, id: \.self) { p in
                    GlassPill(
                        label: p.displayName,
                        isSelected: priority == p,
                        accessibilityID: "editreminder_pill_priority_\(p.displayName.lowercased())"
                    ) {
                        priority = p
                    }
                }
            }
        }
    }

    private var customContentSection: some View {
        formSection(title: "Title & Message") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    IconBubble(systemName: "textformat", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                    ValidatedTextField(
                        "Title",
                        text: $title,
                        validation: { ValidationService.shared.validateText($0, fieldName: "Title", maxLength: 100) }
                    )
                    .accessibilityIdentifier("editreminder_textfield_title")
                }

                Divider().background(CultivationTheme.Colors.divider)

                HStack(alignment: .top, spacing: 10) {
                    IconBubble(systemName: "text.alignleft", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                        .padding(.top, 2)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(minHeight: 80)
                            .font(.system(.body))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .accessibilityIdentifier("editreminder_texteditor_message")
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            )
                            .onChange(of: message) { _, newValue in
                                let validation = ValidationService.shared.validateText(
                                    newValue, fieldName: "Message", maxLength: 500
                                )
                                if !validation.isValid {
                                    message = String(newValue.prefix(500))
                                }
                            }

                        if message.isEmpty {
                            Text("Message")
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

    private var pauseSection: some View {
        formSection(title: "Status") {
            HStack {
                IconBubble(systemName: "pause.circle.fill", color: CultivationTheme.Colors.textSecondary, size: 28, iconSize: 13)
                Text("Pause Reminder")
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isPaused)
                    .accessibilityIdentifier("editreminder_toggle_pause")
            }
        }
    }

    // MARK: - Section builder

    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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

    // MARK: - Computed

    private var frequencyOptions: [ReminderFrequency] {
        [.daily, .everyOtherDay, .twiceWeekly, .weekly, .biweekly, .monthly, .custom]
    }

    // MARK: - Helpers

    private func plantIcon(for plant: Plant?) -> String {
        switch plant?.plantType {
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

    private func plantColor(for plant: Plant?) -> Color {
        switch plant?.plantType {
        case .houseplant, .herb, .shrub: CultivationTheme.Colors.brandLeaf
        case .succulent: .mint
        case .vegetable: .orange
        case .flower: .pink
        case .fruit: .red
        case .tree: .brown
        case .none: CultivationTheme.Colors.textTertiary
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        saveTask = Task<Void, Never> {
            do {
                try await reminderService.updateReminder(
                    reminder,
                    title: title,
                    message: message,
                    type: reminderType,
                    frequency: frequency,
                    customFrequencyDays: frequency == .custom ? customDays : nil,
                    preferredTime: preferredTime,
                    priority: priority,
                    enableWeatherAdjustment: enableWeatherAdjustment,
                    isEnabled: !isPaused
                )
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
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

// swiftlint:enable type_body_length
