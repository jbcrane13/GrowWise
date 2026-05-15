import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenType Icon Extension

extension GardenType {
    var iconName: String {
        switch self {
        case .outdoor: "sun.max.fill"
        case .indoor: "house.fill"
        case .container: "rectangle.3.offgrid.fill"
        case .raised: "rectangle.stack.fill"
        case .hydroponic: "drop.circle.fill"
        case .greenhouse: "leaf.fill"
        case .balcony: "building.2.fill"
        case .windowsill: "window.horizontal"
        }
    }
}

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
    var onOpen: (() -> Void)?

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

    private var accessibilitySummary: String {
        "\(plant.name ?? "Unnamed Plant"), \(careSubtitle), \(healthStatus.displayName)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Perenual-enriched thumbnail (falls back to icon bubble if no API data)
            PerenualEnrichmentThumbnail(plant: plant)

            // Name + care subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name ?? "Unnamed Plant")
                    .font(CultivationTheme.Fonts.display(17, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(careSubtitle)
                    .font(CultivationTheme.Fonts.body(13).italic())
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(CultivationTheme.Gradients.warmAccent)
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
        .contentShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
        .onTapGesture {
            onOpen?()
        }
        .background {
            if isUrgent {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.statusAlert.opacity(0.04))
            }
        }
        .paperCard()
        .accessibilityElement(children: isUrgent ? .contain : .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
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
                color: CultivationTheme.Colors.accentCoral,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 15
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(CultivationTheme.Fonts.display(15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(CultivationTheme.Fonts.body(12))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Plant count pill
            Text("\(plantCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.accentCoral)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.12))
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
                .font(CultivationTheme.Fonts.body(13).italic())
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .stroke(
                    CultivationTheme.Colors.brandLeaf.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
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
    var quickActionIcon: String = "checkmark.circle.fill"
    var quickActionColor: Color = CultivationTheme.Colors.textTertiary
    var onComplete: (() -> Void)?

    @State private var showCheckmark = false

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
                    .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                if let locationLabel {
                    Text(locationLabel)
                        .font(CultivationTheme.Fonts.body(12))
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(CultivationTheme.Gradients.warmAccent)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_complete_\(taskID.uuidString)")
            } else {
                // Outline complete button for normal tasks
                Button {
                    onComplete?()
                    showCheckmark = true
                    Task<Void, Never> {
                        try? await Task.sleep(for: .seconds(1.5))
                        showCheckmark = false
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isUrgent ? .white : quickActionColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(
                                    isUrgent || showCheckmark
                                        ? AnyShapeStyle(CultivationTheme.Gradients.warmAccent)
                                        : AnyShapeStyle(quickActionColor.opacity(0.08))
                                )
                        }
                        .overlay {
                            if !isUrgent, !showCheckmark {
                                Capsule()
                                    .stroke(quickActionColor.opacity(0.3), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_complete_\(taskID.uuidString)")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
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
        self.locationLabel = reminder.plant?.bed?.name ?? reminder.plant?.name
        self.statusColor = isUrgent
            ? CultivationTheme.Colors.statusAlert
            : CultivationTheme.Colors.brandLeaf
        self.isUrgent = isUrgent

        switch reminder.reminderType {
        case .watering:
            self.quickActionIcon = "drop.fill"
            self.quickActionColor = .blue

        case .fertilizing:
            self.quickActionIcon = "leaf.fill"
            self.quickActionColor = CultivationTheme.Colors.brandLeaf

        case .pruning:
            self.quickActionIcon = "scissors"
            self.quickActionColor = .orange

        default:
            self.quickActionIcon = "checkmark.circle.fill"
            self.quickActionColor = CultivationTheme.Colors.textTertiary
        }

        self.onComplete = onComplete
    }
}
