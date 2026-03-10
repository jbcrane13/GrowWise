import GrowWiseModels
import SwiftUI

// MARK: - PlantQuickCard

/// Bottom sheet quick-summary card shown when a user taps a plant row in the Garden tab.
struct PlantQuickCard: View {
    let plant: Plant
    let onWater: () -> Void
    let onPrune: () -> Void
    let onLog: () -> Void
    let onViewDetails: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(CultivationTheme.Colors.cardBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    plantHeader
                    statCards
                    actionButtons
                    viewDetailsButton
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 32)
            }
        }
        .background(CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea())
        .accessibilityIdentifier("quickcard_sheet")
    }

    // MARK: - Plant Header

    private var plantHeader: some View {
        HStack(spacing: 14) {
            IconBubble(
                systemName: plantIconName,
                color: healthAccentColor,
                size: 52,
                iconSize: 22
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plant.name ?? "Plant")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    StatusDot(status: uiHealthStatus)
                }

                if let location = plant.gardenLocation, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                if let date = plant.plantingDate {
                    Text("Planted \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: 10) {
            quickStatItem(
                icon: "drop.fill",
                label: "Water",
                value: waterCountdown,
                color: .blue
            )
            quickStatItem(
                icon: "sun.max.fill",
                label: "Sun",
                value: sunLabel,
                color: .yellow
            )
            quickStatItem(
                icon: "heart.fill",
                label: "Health",
                value: healthLabel,
                color: healthAccentColor
            )
        }
    }

    private func quickStatItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onWater) {
                Label("Water Now", systemImage: "drop.fill")
            }
            .buttonStyle(GradientButtonStyle())
            .accessibilityIdentifier("quickcard_button_water")

            HStack(spacing: 10) {
                actionChip(
                    label: "Prune",
                    icon: "scissors",
                    id: "quickcard_button_prune",
                    action: onPrune
                )
                actionChip(
                    label: "Log",
                    icon: "square.and.pencil",
                    id: "quickcard_button_log",
                    action: onLog
                )
            }
        }
    }

    private func actionChip(
        label: String,
        icon: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: - View Details

    private var viewDetailsButton: some View {
        Button(action: onViewDetails) {
            HStack {
                Text("View Full Details")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickcard_button_viewdetails")
    }

    // MARK: - Computed Helpers

    /// Maps model HealthStatus → UI PlantHealthStatus using the existing extension.
    private var uiHealthStatus: PlantHealthStatus {
        (plant.healthStatus ?? .healthy).uiStatus
    }

    /// Color derived from the model health status via the existing accentColor extension.
    private var healthAccentColor: Color {
        (plant.healthStatus ?? .healthy).accentColor
    }

    private var healthLabel: String {
        switch plant.healthStatus ?? .healthy {
        case .healthy: "Good"
        case .needsAttention: "Fair"
        case .sick: "Fair"
        case .dying: "Poor"
        case .dead: "Dead"
        }
    }

    /// SF Symbol name from PlantType+UI extension, falling back to leaf.fill.
    private var plantIconName: String {
        plant.plantType?.iconName ?? "leaf.fill"
    }

    /// Water countdown: days remaining based on lastWatered + wateringFrequency.days.
    /// Falls back to the next watering reminder's nextDueDate if lastWatered is absent.
    private var waterCountdown: String {
        // Try computing from lastWatered + frequency
        if let lastWatered = plant.lastWatered,
           let freq = plant.wateringFrequency {
            let intervalDays = freq.days
            if intervalDays > 0 {
                guard let nextWater = Calendar.current.date(
                    byAdding: .day,
                    value: intervalDays,
                    to: lastWatered
                ) else { return "–" }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: nextWater).day ?? 0
                if days < 0 { return "Overdue" }
                if days == 0 { return "Today" }
                return "in \(days)d"
            }
        }
        // Fallback: check watering reminder nextDueDate
        if let reminder = plant.reminders?.first(where: { $0.reminderType == .watering }) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: reminder.nextDueDate).day ?? 0
            if days < 0 { return "Overdue" }
            if days == 0 { return "Today" }
            return "in \(days)d"
        }
        // Use wateringFrequency display name as a last resort
        return plant.wateringFrequency?.displayName ?? "–"
    }

    private var sunLabel: String {
        guard let sun = plant.sunlightRequirement else { return "–" }
        // Shorten the display name for the compact stat card
        switch sun {
        case .fullSun: return "Full Sun"
        case .partialSun: return "Part Sun"
        case .partialShade: return "Part Shade"
        case .fullShade: return "Full Shade"
        }
    }
}
