import SwiftUI

/// Hero header for the Home tab — dark background with green glow orb,
/// time-based greeting, user name, and three quick-stat cards.
struct HomeHeroHeader: View {
    let userName: String
    let overdueCount: Int
    let dueTodayCount: Int
    let allGoodCount: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Greeting block
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .accessibilityIdentifier("home_label_greeting")

                Text(userName.isEmpty ? "Gardener" : userName)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .accessibilityIdentifier("home_label_username")
            }

            // Quick stat cards
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
                    value: allGoodCount,
                    label: "All Good",
                    color: CultivationTheme.Colors.statusHealthy
                )
                .accessibilityIdentifier("home_stat_allgood")
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
        allGoodCount: 7
    )
}
