import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Card shown on Home when seeds are in their ideal indoor-start window.
/// Links to SeasonalPlannerView for full calendar.
struct SeedStartCard: View {
    let seeds: [Seed]
    let zone: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            HStack(spacing: 8) {
                IconBubble(
                    systemName: "leaf.arrow.triangle.circlepath",
                    color: CultivationTheme.Colors.brandLeaf,
                    size: 36,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start seeds now")
                        .font(CultivationTheme.Fonts.display(15, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text("\(seeds.count) variety\(seeds.count == 1 ? "" : "ies") ready for indoor sowing")
                        .font(CultivationTheme.Fonts.body(12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()
            }

            // Show up to 3 seed chips
            HStack(spacing: 6) {
                ForEach(seeds.prefix(3), id: \.id) { seed in
                    GlassPill(label: seed.varietyName ?? "Unknown") {}
                }
                if seeds.count > 3 {
                    GlassPill(label: "+\(seeds.count - 3) more") {}
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("home_card_seed_start")
    }
}
