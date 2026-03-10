import GrowWiseModels
import SwiftUI

// MARK: - GardenBedSection

/// One grouped section in the Garden tab list.
/// Shows the bed/location header, all plant rows, and an optional companion tip.
struct GardenBedSection: View {
    let group: PlantGroup
    let onPlantTap: (Plant) -> Void
    let onQuickAction: (Plant) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            // Bed group header
            BedGroupHeader(
                name: group.displayName,
                subtitle: "\(group.plants.count) plant\(group.plants.count == 1 ? "" : "s")",
                plantCount: group.plants.count
            )

            // Plant rows
            ForEach(group.plants) { plant in
                PlantRow(
                    plant: plant,
                    isUrgent: isOverdue(plant),
                    onComplete: { onQuickAction(plant) }
                )
                .onTapGesture { onPlantTap(plant) }
                .accessibilityIdentifier("garden_row_plant_\(plant.id?.uuidString ?? plant.name ?? "unknown")")
            }

            // Companion tip shown when a location group has 2+ plants
            if group.plants.count >= 2 {
                CompanionTipCard(tip: companionTip(for: group))
            }
        }
    }

    // MARK: - Helpers

    /// Derives overdue status from the plant's enabled reminders.
    private func isOverdue(_ plant: Plant) -> Bool {
        let now = Date()
        return (plant.reminders ?? []).contains { reminder in
            reminder.isEnabled && reminder.nextDueDate < now
        }
    }

    /// Returns a deterministic companion planting tip for the group.
    private func companionTip(for group: PlantGroup) -> String {
        let tips = [
            "Basil planted near tomatoes can improve their flavor and repel pests.",
            "Marigolds are excellent companions — they deter many common garden pests.",
            "Rotating crops each season helps prevent soil depletion and disease buildup.",
            "Nasturtiums attract aphids away from more valuable crops — a great sacrificial plant.",
            "Tall plants can shade heat-sensitive neighbors during the hottest part of the day.",
        ]
        let index = abs((group.locationKey ?? "__ungrouped__").hashValue) % tips.count
        return tips[index]
    }
}
