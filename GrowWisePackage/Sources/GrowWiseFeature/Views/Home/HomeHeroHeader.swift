import SwiftUI

/// Hero header for the Home tab — cream-paper hero background,
/// time-based greeting, seasonal note, and three quick-stat cards.
struct HomeHeroHeader: View {
    let userName: String
    let overdueCount: Int
    let dueTodayCount: Int
    let totalPlantCount: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var seasonalNote: String {
        let month = Calendar.current.component(.month, from: Date())
        let taskCount = overdueCount + dueTodayCount
        let taskPrefix: String = if taskCount == 0 {
            "Everything is on track."
        } else {
            taskCount == 1 ? "1 task needs attention." : "\(taskCount) tasks need attention."
        }
        switch month {
        case 3 ... 5: return "\(taskPrefix) Your spring garden is waking up."
        case 6 ... 8: return "\(taskPrefix) Peak growing season is here."
        case 9 ... 11: return "\(taskPrefix) Time to prepare for the harvest."
        default: return "\(taskPrefix) Plan ahead for next season."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + ", " + (userName.isEmpty ? "Gardener" : userName))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .accessibilityIdentifier("home_label_greeting")

                (
                    Text("Your garden is ")
                        .font(.system(.title, design: .serif)) +
                        Text("thriving")
                        .font(.system(.title, design: .serif))
                        .italic()
                        .foregroundColor(CultivationTheme.Colors.accentAmber)
                )
                .accessibilityIdentifier("home_label_headline")

                Text(seasonalNote)
                    .font(.system(size: 14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .padding(.top, 2)
                    .accessibilityIdentifier("home_label_seasonal_note")
            }

            HStack(spacing: 10) {
                QuickStatCard(
                    value: overdueCount,
                    label: "Overdue",
                    color: CultivationTheme.Colors.statusAlert
                )
                .accessibilityIdentifier("home_stat_overdue")

                QuickStatCard(
                    value: dueTodayCount,
                    label: "Due Today",
                    color: CultivationTheme.Colors.statusWarning
                )
                .accessibilityIdentifier("home_stat_duetoday")

                QuickStatCard(
                    value: totalPlantCount,
                    label: "Plants",
                    color: CultivationTheme.Colors.brandLeaf
                )
                .accessibilityIdentifier("home_stat_plants")
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
        overdueCount: 2,
        dueTodayCount: 4,
        totalPlantCount: 12
    )
}
