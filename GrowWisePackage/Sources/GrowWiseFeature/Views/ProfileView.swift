import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct ProfileView: View {
    @Environment(DataService.self) private var dataService

    @State private var plantCount: Int = 0
    @State private var journalCount: Int = 0
    @State private var streakDays: Int = 0
    @State private var showShareComingSoon = false
    @State private var showAppSettingsComingSoon = false

    // Navigation state
    @State private var showTutorials = false
    @State private var showNotifications = false
    @State private var showSubscription = false
    @State private var showCommunity = false
    @State private var showAchievements = false

    public init() {}

    // MARK: - Computed

    private var currentUser: User? {
        dataService.getCurrentUser()
    }

    private var displayName: String {
        currentUser?.displayName ?? "Gardener"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2,
           let first = parts.first?.first,
           let last = parts.last?.first
        {
            return "\(first)\(last)".uppercased()
        } else if let first = displayName.first {
            return String(first).uppercased()
        }
        return "G"
    }

    private var skillLevelText: String {
        currentUser?.skillLevel.displayName ?? "Beginner"
    }

    private var zoneText: String {
        if let zone = currentUser?.hardinessZone {
            return "Zone \(zone)"
        }
        return "Zone —"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    userCard
                    statsRow
                    learningSection
                    settingsSection
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Profile")
            .sheet(isPresented: $showTutorials) {
                TutorialsView()
            }
            .navigationDestination(isPresented: $showNotifications) {
                RemindersListView()
            }
            .navigationDestination(isPresented: $showSubscription) {
                PaywallView()
            }
            .navigationDestination(isPresented: $showCommunity) {
                CommunityFeedView()
            }
            .navigationDestination(isPresented: $showAchievements) {
                AchievementsView()
            }
            .task {
                loadStats()
            }
            .alert("Coming Soon", isPresented: $showShareComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Garden sharing via iCloud is coming in a future update.")
            }
            .alert("Coming Soon", isPresented: $showAppSettingsComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("App Settings are coming in a future update.")
            }
        }
    }

    // MARK: - User Card

    private var userCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 72, height: 72)
                Text(initials)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("profile_avatar")

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Text(skillLevelText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Text(zoneText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("profile_user_card")
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(value: plantCount, label: "Plants")
                .accessibilityIdentifier("profile_stat_plants")
            statCard(value: streakDays, label: "Day Streak")
                .accessibilityIdentifier("profile_stat_streak")
            statCard(value: journalCount, label: "Entries")
                .accessibilityIdentifier("profile_stat_entries")
        }
    }

    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard()
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Learning")
                .sectionLabelStyle()
                .padding(.leading, 4)

            menuRow(
                icon: "book.fill",
                color: .blue,
                title: "Tutorials",
                id: "profile_row_tutorials"
            ) {
                showTutorials = true
            }

            menuRow(
                icon: "star.fill",
                color: .yellow,
                title: "Achievements",
                id: "profile_row_achievements"
            ) {
                showAchievements = true
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Settings")
                .sectionLabelStyle()
                .padding(.leading, 4)

            menuRow(
                icon: "bell.fill",
                color: .orange,
                title: "Notifications",
                id: "profile_row_notifications"
            ) {
                showNotifications = true
            }

            menuRow(
                icon: "crown.fill",
                color: CultivationTheme.Colors.brandLeaf,
                title: "Subscription",
                id: "profile_row_subscription"
            ) {
                showSubscription = true
            }

            menuRow(
                icon: "person.3.fill",
                color: CultivationTheme.Colors.brandLeaf,
                title: "Community",
                id: "profile_row_community"
            ) {
                showCommunity = true
            }

            menuRow(
                icon: "gearshape.fill",
                color: .gray,
                title: "App Settings",
                id: "profile_row_settings"
            ) {
                showAppSettingsComingSoon = true
            }
        }
    }

    // MARK: - Menu Row

    private func menuRow(
        icon: String,
        color: Color,
        title: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBubble(systemName: icon, color: color, size: 36, iconSize: 16)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: - Actions

    private func loadStats() {
        plantCount = dataService.getPlantCount()
        journalCount = dataService.getJournalEntryCount()
        streakDays = dataService.getCurrentUser()?.streakDays ?? 0
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let dataService = try! DataService()
    let subscriptionService = SubscriptionService()

    ProfileView()
        .environment(dataService)
        .environment(subscriptionService)
}
