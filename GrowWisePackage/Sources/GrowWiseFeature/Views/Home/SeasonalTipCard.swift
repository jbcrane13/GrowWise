import SwiftUI

/// Card shown at the bottom of the Home tab with a gardening tip
/// appropriate for the current calendar month.
struct SeasonalTipCard: View {
    var body: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: seasonIcon,
                color: CultivationTheme.Colors.accentAmber,
                size: 40,
                iconSize: 17
            )

            VStack(alignment: .leading, spacing: 3) {
                SmartTag(label: "Seasonal tip")
                    .accessibilityIdentifier("home_label_seasonal_tip_header")

                Text(seasonalTip)
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(3)
                    .accessibilityIdentifier("home_label_seasonal_tip_body")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("home_card_seasonal_tip")
    }

    private var seasonIcon: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3 ... 5: return "leaf.fill"
        case 6 ... 8: return "sun.max.fill"
        case 9 ... 11: return "wind"
        default: return "snowflake"
        }
    }

    private var seasonalTip: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3: return "Start seeds indoors 6–8 weeks before last frost. Check soil temperature before direct sowing."
        case 4: return "Great time to transplant seedlings outside. Watch for late frosts and cover tender plants."
        case 5: return "Warm-season crops like tomatoes and peppers thrive now. Mulch to retain moisture."
        case 6: return "Water deeply and less frequently to encourage deep roots. Watch for heat stress."
        case 7: return "Harvest regularly to encourage continued production. Watch for pest pressure in heat."
        case 8: return "Start fall crops now: broccoli, kale, carrots. They'll be ready before first frost."
        case 9: return "Perfect time to plant garlic and spring bulbs. Clean up spent plants to reduce disease."
        case 10: return "Protect tender perennials before frost. Bring in herbs like basil."
        case 11: return "Cover bare soil with mulch or cover crops to prevent erosion over winter."
        case 12: return "Plan next year's garden. Order seeds from catalogs and review what worked well."
        case 1: return "Check stored bulbs and tubers for rot. Review seed catalogs and make your wish list."
        default: return "Check soil moisture regularly and water at the base of plants to prevent disease."
        }
    }
}

#Preview {
    SeasonalTipCard()
        .padding()
}
