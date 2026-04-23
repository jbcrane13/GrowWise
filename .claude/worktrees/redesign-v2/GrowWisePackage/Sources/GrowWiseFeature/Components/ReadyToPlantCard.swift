import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - ReadyToPlantCard

/// Home dashboard card showing seeds that are in their indoor start window.
/// Only appears when the user has seeds with `indoorStartWeeks` data that
/// fall within ±1 week of their ideal start date for the user's zone.
struct ReadyToPlantCard: View {
    let seeds: [Seed]

    var body: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            HStack(spacing: 8) {
                IconBubble(
                    systemName: "light.recessed.3.fill",
                    color: CultivationTheme.Colors.accentAmber,
                    size: CultivationTheme.Spacing.iconSizeSmall,
                    iconSize: 14
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to Plant")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Text("Start these seeds indoors this week")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
                Spacer()
                Text("\(seeds.count) seed\(seeds.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(CultivationTheme.Colors.accentAmber.opacity(0.12)))
            }

            ForEach(seeds.prefix(3), id: \.id) { seed in
                ReadyToPlantSeedRow(seed: seed)
            }

            if seeds.count > 3 {
                Text("+ \(seeds.count - 3) more in your inventory")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("home_card_readytoplant")
    }
}

// MARK: - ReadyToPlantSeedRow

private struct ReadyToPlantSeedRow: View {
    let seed: Seed

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.15))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(CultivationTheme.Colors.brandLeaf, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(seed.varietyName ?? "Unknown Variety")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                if let weeks = seed.indoorStartWeeks {
                    Text("Start \(weeks) weeks before last frost")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if let qty = seed.quantity {
                Text("Qty: \(qty)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(qty > 0 ? CultivationTheme.Colors.textSecondary : CultivationTheme.Colors.statusAlert)
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("home_readytoplant_row_\(seed.id?.uuidString ?? "unknown")")
    }
}
