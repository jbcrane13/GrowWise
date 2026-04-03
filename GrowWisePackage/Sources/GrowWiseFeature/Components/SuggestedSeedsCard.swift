import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct SuggestedSeedsCard: View {
    @Environment(DataService.self) private var dataService

    let bed: GardenBed
    let onPlantSeed: (Seed) -> Void

    @State private var suggestedSeeds: [Seed] = []

    private let service = SeedInventoryService()

    var body: some View {
        if !suggestedSeeds.isEmpty {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
                HStack {
                    Text("Suggested Seeds")
                        .sectionLabelStyle()
                    Spacer()
                    Text("\(suggestedSeeds.count) compatible")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestedSeeds, id: \.id) { seed in
                            seedSuggestionChip(seed)
                        }
                    }
                }

                NavigationLink(value: "seed_inventory") {
                    HStack(spacing: 6) {
                        Text("View All Seeds")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
                .accessibilityIdentifier("suggested_seeds_view_all")
            }
            .task { loadSuggestions() }
            .accessibilityIdentifier("suggested_seeds_card")
        }
    }

    private func seedSuggestionChip(_ seed: Seed) -> some View {
        Button {
            onPlantSeed(seed)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(seed.varietyName ?? "Seed")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Text("Qty: \(seed.quantity ?? 0)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .padding(12)
            .frame(minWidth: 120, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("suggested_seeds_cell_\(seed.id?.uuidString ?? "unknown")")
    }

    private func loadSuggestions() {
        guard let garden = bed.garden else { return }
        let unassigned = (try? dataService.seeds.fetchUnassigned(for: garden)) ?? []
        suggestedSeeds = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: unassigned,
            plantDatabase: (try? dataService.plants.fetchAll()) ?? []
        )
    }
}
