import SwiftUI

/// Hero header for the Home tab — cream-paper hero background,
/// time-based greeting and auto-derived weather pill.
struct HomeHeroHeader: View {
    let userName: String
    let weatherPillText: String

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var displayName: String {
        userName.isEmpty ? "Gardener" : userName
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)
                    .accessibilityIdentifier("home_label_date")

                (
                    Text("\(greeting),\n")
                        .font(CultivationTheme.Fonts.display(30, weight: .medium)) +
                        Text("\(displayName).")
                        .font(CultivationTheme.Fonts.displayItalic(30, weight: .medium))
                        .foregroundColor(CultivationTheme.Colors.accentCoralDeep)
                )
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .accessibilityIdentifier("home_label_greeting")

                Text(weatherPillText)
                    .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandSage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule()
                            .fill(CultivationTheme.Colors.brandLeaf.opacity(0.14))
                    }
                    .padding(.top, 4)
                    .accessibilityIdentifier("home_label_weather_pill")
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .heroBackground()
    }
}

#Preview {
    HomeHeroHeader(
        userName: "Blake",
        weatherPillText: "☀ 72° · Good day to water"
    )
}
