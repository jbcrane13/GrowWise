import GrowWiseModels
import SwiftUI

// MARK: - Plant Model Extensions

extension HealthStatus {
    /// Maps model-layer HealthStatus to UI-layer PlantHealthStatus.
    var uiStatus: PlantHealthStatus {
        switch self {
        case .healthy: .healthy
        case .needsAttention: .warning
        case .sick: .warning
        case .dying: .alert
        case .dead: .alert
        }
    }

    /// Accent color for icon bubbles and tints.
    var accentColor: Color {
        switch self {
        case .healthy: CultivationTheme.Colors.statusHealthy
        case .needsAttention: CultivationTheme.Colors.statusWarning
        case .sick: CultivationTheme.Colors.statusWarning
        case .dying: CultivationTheme.Colors.statusAlert
        case .dead: CultivationTheme.Colors.textTertiary
        }
    }
}

// MARK: - PlantRow

/// Garden tab plant row — glass card with icon, name, care subtitle, and status.
/// When `isUrgent` is true an "OVERDUE" badge and gradient complete button are shown.
struct PlantRow: View {
    let plant: Plant
    var isUrgent: Bool = false
    var onComplete: (() -> Void)?

    private var plantID: String {
        plant.id?.uuidString ?? "unknown"
    }

    private var healthStatus: HealthStatus {
        plant.healthStatus ?? .healthy
    }

    private var plantTypeIcon: String {
        plant.plantType?.iconName ?? "leaf.fill"
    }

    private var careSubtitle: String {
        // Build a subtitle from watering frequency + growth stage if available
        let watering = plant.wateringFrequency?.displayName ?? "Care"
        let stage = plant.growthStage?.displayName
        if let stage {
            return "\(watering) · \(stage)"
        }
        return watering
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon bubble tinted by health status
            IconBubble(
                systemName: plantTypeIcon,
                color: isUrgent ? CultivationTheme.Colors.statusAlert : healthStatus.accentColor,
                size: CultivationTheme.Spacing.iconSize,
                iconSize: 20
            )

            // Name + care subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name ?? "Unnamed Plant")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(careSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing: either status dot or overdue badge + complete button
            if isUrgent {
                VStack(spacing: 6) {
                    Text("OVERDUE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(CultivationTheme.Colors.statusAlert)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(CultivationTheme.Colors.statusAlert.opacity(0.12))
                        }
                        .overlay {
                            Capsule()
                                .stroke(CultivationTheme.Colors.statusAlert.opacity(0.3), lineWidth: 1)
                        }

                    Button {
                        onComplete?()
                    } label: {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(CultivationTheme.Gradients.cta)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("garden_button_complete_\(plantID)")
                }
            } else {
                StatusDot(status: healthStatus.uiStatus)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .background {
            if isUrgent {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.statusAlert.opacity(0.04))
            }
        }
        .glassCard()
        .accessibilityIdentifier("garden_row_plant_\(plantID)")
    }
}

// MARK: - BedGroupHeader

/// Section header for a garden bed / area grouping.
struct BedGroupHeader: View {
    let name: String
    let subtitle: String
    let plantCount: Int
    var showMenu: Bool = false
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            IconBubble(
                systemName: "rectangle.on.rectangle",
                color: CultivationTheme.Colors.brandLeaf,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 15
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Plant count pill
            Text("\(plantCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                }

            if showMenu {
                Button {
                    onMenuTap?()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(CultivationTheme.Colors.cardSurface)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("garden_button_bedmenu_\(name)")
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.vertical, 8)
    }
}

// MARK: - CompanionTipCard

/// Inline companion planting tip card with subtle green-tinted glass background.
struct CompanionTipCard: View {
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconBubble(
                systemName: "lightbulb.fill",
                color: CultivationTheme.Colors.brandLeaf,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 14
            )

            Text(tip)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.06))
                .background(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .fill(.ultraThinMaterial)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.15), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
    }
}

// MARK: - TaskRow

/// Home tab care task row — icon, task description, location, and a complete button.
/// When `isUrgent` a gradient complete button is used; otherwise an outline button.
struct TaskRow: View {
    let taskID: UUID
    let iconName: String
    let description: String
    let locationLabel: String?
    let statusColor: Color
    var isUrgent: Bool = false
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: iconName,
                color: statusColor,
                size: CultivationTheme.Spacing.iconSize,
                iconSize: 18
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                if let locationLabel {
                    Text(locationLabel)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isUrgent {
                // Gradient complete button for urgent tasks
                Button {
                    onComplete?()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(CultivationTheme.Gradients.cta)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_complete_\(taskID.uuidString)")
            } else {
                // Outline complete button for normal tasks
                Button {
                    onComplete?()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
                        }
                        .overlay {
                            Capsule()
                                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_complete_\(taskID.uuidString)")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("home_row_task_\(taskID.uuidString)")
    }
}

// MARK: - TaskRow convenience init from PlantReminder

extension TaskRow {
    /// Convenience initialiser that builds a TaskRow from a PlantReminder.
    init(reminder: PlantReminder, isUrgent: Bool = false, onComplete: (() -> Void)? = nil) {
        self.taskID = reminder.id
        self.iconName = reminder.reminderType.iconName
        self.description = reminder.title.isEmpty ? reminder.reminderType.displayName : reminder.title
        self.locationLabel = reminder.plant?.gardenLocation ?? reminder.plant?.name
        self.statusColor = isUrgent
            ? CultivationTheme.Colors.statusAlert
            : CultivationTheme.Colors.brandLeaf
        self.isUrgent = isUrgent
        self.onComplete = onComplete
    }
}
