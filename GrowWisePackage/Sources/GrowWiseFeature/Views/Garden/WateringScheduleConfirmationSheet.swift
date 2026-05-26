import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - WateringScheduleConfirmationSheet

/// Shown after adding a plant, presents the suggested watering schedule
/// with options to set a reminder, customize, or skip.
struct WateringScheduleConfirmationSheet: View {
    let plant: Plant
    let schedule: WateringSchedule
    let reminderService: ReminderService

    @Environment(\.dismiss)
    private var dismiss

    @State private var isSettingReminder = false
    @State private var reminderError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    Spacer(minLength: 20)

                    // Success icon
                    IconBubble(
                        systemName: "drop.fill",
                        color: Color.blue,
                        size: 72,
                        iconSize: 32
                    )

                    // Title
                    VStack(spacing: 6) {
                        Text("Watering Schedule")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)

                        Text(plant.name ?? "Your plant")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    // Schedule card
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggested Frequency")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                Text("Every \(schedule.frequencyDays) days")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Next Watering")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                Text(schedule.nextDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            }
                        }

                        Divider()
                            .background(CultivationTheme.Colors.divider)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                            Text(schedule.adjustedReason)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                    Spacer()

                    // Action buttons
                    VStack(spacing: 10) {
                        Button {
                            setReminder()
                        } label: {
                            HStack(spacing: 8) {
                                if isSettingReminder {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.fill")
                                }
                                Text("Set Reminder")
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDisabled: isSettingReminder))
                        .disabled(isSettingReminder)
                        .accessibilityIdentifier("watering_button_setreminder")

                        Button("Skip for Now") {
                            dismiss()
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .accessibilityIdentifier("watering_button_skip")
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Plant Added")
            .gwNavigationBarTitleDisplayMode(.inline)
            .alert("Could not set reminder", isPresented: Binding(
                get: { reminderError != nil },
                set: { if !$0 { reminderError = nil } }
            )) {
                Button("OK", role: .cancel) { reminderError = nil }
                    .accessibilityIdentifier("watering_button_error_dismiss")
            } message: {
                Text(reminderError ?? "")
            }
        }
    }

    private func setReminder() {
        isSettingReminder = true
        Task<Void, Never> {
            do {
                _ = try await reminderService.createWateringReminder(
                    for: plant,
                    frequency: schedule.frequency
                )
            } catch {
                await MainActor.run {
                    reminderError = error.localizedDescription
                    isSettingReminder = false
                }
                return
            }
            dismiss()
        }
    }
}
