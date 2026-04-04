import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct ProfileView: View {
    @Environment(DataService.self) private var dataService
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var plantCount: Int = 0
    @State private var journalCount: Int = 0
    @State private var streakDays: Int = 0
    @State private var showShareComingSoon = false
    @State private var showAppSettings = false

    // Navigation state
    @State private var showTutorials = false
    @State private var showNotifications = false
    @State private var showSubscription = false
    @State private var showCommunity = false
    @State private var showAchievements = false
    @State private var showForum = false
    @State private var showGardenClubs = false
    @State private var selectedProductID: String?
    @State private var purchaseError: String?
    @State private var showPurchaseError = false
    @State private var showRestoreSuccess = false

    // Product IDs
    private let monthlyProductID = "com.growwise.premium.monthly"
    private let yearlyProductID = "com.growwise.premium.yearly"

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
                    communitySection
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
            .navigationDestination(isPresented: $showForum) {
                ForumView()
            }
            .navigationDestination(isPresented: $showGardenClubs) {
                ClubListView()
                    .environment(dataService)
            }
            .navigationDestination(isPresented: $showAppSettings) {
                AppSettingsView()
            }
            .task {
                loadStats()
            }
            .alert("Coming Soon", isPresented: $showShareComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Garden sharing via iCloud is coming in a future update.")
            }
            .alert("Error", isPresented: $showPurchaseError, presenting: purchaseError) { _ in
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("profile_subscribe_error_dismiss")
            } message: { message in
                Text(message)
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("profile_restore_dismiss")
            } message: {
                Text("Your purchases have been restored successfully.")
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

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Community")
                .sectionLabelStyle()
                .padding(.leading, 4)

            menuRow(
                icon: "person.3.fill",
                color: CultivationTheme.Colors.brandLeaf,
                title: "Garden Showcase",
                id: "profile_row_community"
            ) {
                showCommunity = true
            }

            menuRow(
                icon: "bubble.left.and.bubble.right.fill",
                color: CultivationTheme.Colors.brandLeaf,
                title: "Q&A Forum",
                id: "profile_row_forum"
            ) {
                showForum = true
            }

            menuRow(
                icon: "person.3.fill",
                color: CultivationTheme.Colors.brandForest,
                title: "Garden Clubs",
                id: "profile_row_garden_clubs"
            ) {
                showGardenClubs = true
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
                icon: "gearshape.fill",
                color: .gray,
                title: "App Settings",
                id: "profile_row_settings"
            ) {
                showAppSettings = true
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

    // MARK: - Subscription Destination

    private var subscriptionDestination: some View {
        ScrollView {
            VStack(spacing: 20) {
                subscriptionSection
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .background(CultivationTheme.Colors.background)
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch subscriptionService.subscriptionStatus {
            case .active(let tier, let expiryDate):
                activeSubscriptionCard(tier: tier, expiryDate: expiryDate)

            case .notSubscribed:
                paywallView
            }
        }
    }

    private func activeSubscriptionCard(tier: SubscriptionTier, expiryDate: Date?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier == .pro ? "GrowWise Pro" : "GrowWise Premium")
                        .font(.headline)
                    Text("Active subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            if let expiry = expiryDate {
                Text("Renews \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassCard()
        .accessibilityIdentifier("profile_subscription_active")
    }

    // MARK: - Paywall

    private var paywallView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Gradients.ctaVertical)
                        .frame(width: 64, height: 64)
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                Text("Unlock GrowWise Premium")
                    .font(.title3.bold())
                Text("Get unlimited diagnoses, expert tips, and more.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            // Plan cards
            VStack(spacing: 12) {
                planCard(
                    productID: monthlyProductID,
                    title: "Monthly",
                    price: "$2.99/mo",
                    detail: "Billed monthly",
                    accessibilityID: "profile_subscribe_monthly"
                )
                planCard(
                    productID: yearlyProductID,
                    title: "Yearly",
                    price: "$19.99/yr",
                    detail: "Save 44% — only $1.67/mo",
                    accessibilityID: "profile_subscribe_yearly"
                )
            }

            // Subscribe button
            if subscriptionService.isLoading {
                ProgressView("Processing...")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityIdentifier("profile_subscribe_loading")
            } else {
                Button {
                    Task { await subscribe() }
                } label: {
                    Text("Subscribe")
                }
                .buttonStyle(GradientButtonStyle(isDisabled: selectedProductID == nil))
                .disabled(selectedProductID == nil)
                .accessibilityIdentifier("profile_subscribe_button")
            }

            // Restore purchases
            Button("Restore Purchases") {
                Task { await restorePurchases() }
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .disabled(subscriptionService.isLoading)
            .accessibilityIdentifier("profile_restore_purchases")

            Text("Subscription auto-renews. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassCard()
    }

    private func planCard(
        productID: String,
        title: String,
        price: String,
        detail: String,
        accessibilityID: String
    ) -> some View {
        let isSelected = selectedProductID == productID

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .white : .primary)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? CultivationTheme.Colors.brandForest : CultivationTheme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? CultivationTheme.Colors.brandLeaf : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Actions

    private func subscribe() async {
        guard let productID = selectedProductID else { return }

        let product = subscriptionService.availableProducts.first { $0.id == productID }
        guard let product else {
            purchaseError = "Product not available. Please check your connection and try again."
            showPurchaseError = true
            return
        }

        do {
            _ = try await subscriptionService.purchase(product)
        } catch {
            purchaseError = error.localizedDescription
            showPurchaseError = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            showRestoreSuccess = true
        } catch {
            purchaseError = error.localizedDescription
            showPurchaseError = true
        }
    }

    private func loadStats() {
        plantCount = dataService.getPlantCount()
        journalCount = dataService.getJournalEntryCount()
        streakDays = dataService.getCurrentUser()?.streakDays ?? 0
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let dataService = try! DataService()

    ProfileView()
        .environment(dataService)
}
