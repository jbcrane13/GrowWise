import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct AchievementsView: View {
    @Environment(DataService.self)
    private var dataService

    @State private var progressItems: [AchievementProgress] = []
    @State private var totalPoints: Int = 0
    @State private var appeared = false

    private let achievementService = AchievementService()

    public init() {}

    private var currentUser: User? {
        dataService.getCurrentUser()
    }

    private var groupedByCategory: [(category: AchievementCategory, items: [AchievementProgress])] {
        AchievementCategory.allCases.compactMap { category in
            let items = progressItems.filter { $0.achievement.category == category }
            guard !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                pointsHeader
                categoryList
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle("Achievements")
        .task {
            loadProgress()
            withAnimation(CultivationTheme.Animation.entrance) {
                appeared = true
            }
        }
    }

    // MARK: - Points Header

    private var pointsHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.warmAccent)
                    .frame(width: 64, height: 64)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0.0)

            Text("\(totalPoints)")
                .font(.system(.largeTitle, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .accessibilityIdentifier("achievements_total_points")

            Text("Achievement Points")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)

            let unlocked = progressItems.filter(\.isUnlocked).count
            let total = progressItems.count
            Text("\(unlocked) of \(total) unlocked")
                .font(.system(.caption))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(CultivationTheme.Spacing.cardPadding + 4)
        .glassCard()
    }

    // MARK: - Category List

    private var categoryList: some View {
        ForEach(groupedByCategory, id: \.category) { group in
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
                Text(group.category.rawValue)
                    .sectionLabelStyle()
                    .padding(.leading, 4)
                    .accessibilityIdentifier("achievements_section_\(sectionID(group.category))")

                ForEach(group.items) { item in
                    achievementCard(item)
                        .accessibilityIdentifier("achievements_card_\(item.achievement.id)")
                }
            }
        }
    }

    // MARK: - Achievement Card

    private func achievementCard(_ item: AchievementProgress) -> some View {
        HStack(spacing: 14) {
            achievementIcon(item)
            achievementDetails(item)
            Spacer()
            achievementPoints(item)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .opacity(item.isUnlocked ? 1.0 : 0.55)
    }

    private func achievementIcon(_ item: AchievementProgress) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                .fill(
                    item.isUnlocked
                        ? CultivationTheme.Colors.accentAmber.opacity(0.18)
                        : Color.gray.opacity(0.1)
                )
                .frame(width: 44, height: 44)

            Image(systemName: item.achievement.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    item.isUnlocked
                        ? CultivationTheme.Colors.accentAmber
                        : CultivationTheme.Colors.textTertiary
                )

            if item.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                    .offset(x: 16, y: -16)
            }
        }
    }

    private func achievementDetails(_ item: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.achievement.name)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(
                    item.isUnlocked
                        ? CultivationTheme.Colors.textPrimary
                        : CultivationTheme.Colors.textSecondary
                )

            Text(item.achievement.description)
                .font(.system(.caption))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .lineLimit(2)

            if !item.isUnlocked {
                progressBar(item)
            }
        }
    }

    private func progressBar(_ item: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(CultivationTheme.Gradients.warmAccent)
                        .frame(
                            width: geometry.size.width * item.progress,
                            height: 6
                        )
                        .animation(CultivationTheme.Animation.entrance, value: item.progress)
                }
            }
            .frame(height: 6)

            Text("\(item.currentValue)/\(item.achievement.requirement)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }

    private func achievementPoints(_ item: AchievementProgress) -> some View {
        VStack(spacing: 2) {
            Text("\(item.achievement.pointsValue)")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(
                    item.isUnlocked
                        ? CultivationTheme.Colors.accentAmber
                        : CultivationTheme.Colors.textTertiary
                )
            Text("pts")
                .font(.system(size: 10))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }

    // MARK: - Helpers

    private func loadProgress() {
        guard let user = currentUser else { return }
        progressItems = achievementService.calculateProgress(for: user)
        totalPoints = achievementService.totalPoints(for: user)
    }

    private func sectionID(_ category: AchievementCategory) -> String {
        category.rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }
}

#Preview {
    NavigationStack {
        // swiftlint:disable:next force_try
        let dataService = try! DataService()
        AchievementsView()
            .environment(dataService)
    }
}
