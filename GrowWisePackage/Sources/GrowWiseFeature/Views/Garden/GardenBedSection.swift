import GrowWiseModels
import SwiftUI

// MARK: - GardenBedSection

/// One grouped section in the Garden tab list.
/// Shows the bed/location header, all plant rows, companion tip, and suggested seeds.
struct GardenBedSection: View {
    let group: PlantGroup
    var currentMemberID: String?
    let onPlantTap: (Plant) -> Void
    let onQuickAction: (Plant) -> Void
    let onDelete: (Plant) -> Void
    var onPlantSeedInBed: ((Seed, GardenBed) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            // Bed group header
            BedGroupHeader(
                name: group.displayName,
                subtitle: "\(group.plants.count) plant\(group.plants.count == 1 ? "" : "s")",
                plantCount: group.plants.count
            )
            .accessibilityIdentifier("garden_section_\(group.displayName)")

            // Plant rows
            ForEach(group.plants) { plant in
                PlantRow(
                    plant: plant,
                    isUrgent: isOverdue(plant),
                    onComplete: { onQuickAction(plant) },
                    onOpen: { onPlantTap(plant) }
                )
                .contextMenu {
                    if !plant.isReadOnlySharedPlant(for: currentMemberID) {
                        Button(role: .destructive) {
                            onDelete(plant)
                        } label: {
                            Label("Delete Plant", systemImage: "trash")
                        }
                        .accessibilityIdentifier("garden_button_delete_plant_\(plant.id?.uuidString ?? "unknown")")
                    }
                }
                .accessibilityIdentifier("garden_row_plant_\(plant.id?.uuidString ?? plant.name ?? "unknown")")
            }

            // Companion tip shown when a location group has 2+ plants
            if group.plants.count >= 2 {
                CompanionTipCard(tip: companionTip(for: group))
            }

            // Suggested seeds for this bed (only for named beds)
            if let bed = group.bed, let plantSeedCallback = onPlantSeedInBed {
                SuggestedSeedsCard(bed: bed, onPlantSeed: { seed in
                    plantSeedCallback(seed, bed)
                })
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
        let index = abs((group.bed?.id?.uuidString ?? "__unassigned__").hashValue) % tips.count
        return tips[index]
    }
}
