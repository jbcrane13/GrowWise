import GrowWiseModels
import GrowWiseServices
import StoreKit
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable file_length force_unwrapping function_body_length function_parameter_count type_body_length

public struct PaywallView: View {
    @Environment(SubscriptionService.self)
    private var subscriptionService
    @Environment(\.dismiss)
    private var dismiss

    @State private var isYearly = true
    @State private var selectedTier: SubscriptionTier?
    @State private var purchaseError: String?
    @State private var showPurchaseError = false
    @State private var showRestoreSuccess = false
    @State private var appeared = false

    // Product IDs (Premium only — Pro is "Coming soon" and not purchasable)
    private let premiumMonthlyID = "com.growwise.premium.monthly"
    private let premiumYearlyID = "com.growwise.premium.annual"
    static let comparisonPlanNames = ["Free", "Premium"]
    static let comparisonRows: [PaywallComparisonRow] = [
        PaywallComparisonRow(feature: "Plant Health Guidance", free: "3/mo", premium: true),
        PaywallComparisonRow(feature: "Plant Limit", free: "50", premium: "500"),
        PaywallComparisonRow(feature: "Smart Reminders", free: false, premium: true),
        PaywallComparisonRow(feature: "Weather Adjust", free: false, premium: true),
        PaywallComparisonRow(feature: "Priority Support", free: false, premium: true),
        PaywallComparisonRow(feature: "Garden Clubs", free: true, premium: true),
        PaywallComparisonRow(feature: "Analytics", free: "Basic", premium: "Standard"),
    ]

    public init() {}

    // MARK: - Computed

    private var selectedProductID: String? {
        guard let tier = selectedTier else { return nil }
        switch (tier, isYearly) {
        case (.premium, false): return premiumMonthlyID
        case (.premium, true): return premiumYearlyID
        default: return nil
        }
    }

    private var isActiveSubscriber: Bool {
        subscriptionService.subscriptionStatus.isSubscribed
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                headerSection
                billingToggle
                tierCards
                featureComparison
                ctaSection
                legalFooter
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle("Choose Your Plan")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .alert("Error", isPresented: $showPurchaseError, presenting: purchaseError) { _ in
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("paywall_button_error_dismiss")
            } message: { message in
                Text(message)
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("paywall_button_restore_dismiss")
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .onChange(of: subscriptionService.errorMessage) { _, newValue in
                if let message = newValue, purchaseError == nil {
                    purchaseError = message
                    showPurchaseError = true
                }
            }
            .onAppear {
                withAnimation(CultivationTheme.Animation.entrance) {
                    appeared = true
                }
            }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.warmAccent)
                    .frame(width: 80, height: 80)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Text("Grow Without Limits")
                .font(.system(.title2, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Choose the plan that fits your garden")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
        .accessibilityIdentifier("paywall_header")
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            toggleButton(label: "Monthly", isActive: !isYearly) {
                withAnimation(CultivationTheme.Animation.selection) {
                    isYearly = false
                }
            }
            .accessibilityIdentifier("paywall_toggle_monthly")

            toggleButton(label: "Yearly", isActive: isYearly, badge: "Best Value") {
                withAnimation(CultivationTheme.Animation.selection) {
                    isYearly = true
                }
            }
            .accessibilityIdentifier("paywall_toggle_yearly")
        }
        .padding(3)
        .background {
            Capsule()
                .fill(CultivationTheme.Colors.cardSurface)
        }
        .overlay {
            Capsule()
                .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
        }
    }

    private func toggleButton(
        label: String,
        isActive: Bool,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(.subheadline, weight: isActive ? .semibold : .regular))
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CultivationTheme.Colors.accentAmber)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isActive ? CultivationTheme.Colors.textPrimary : CultivationTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isActive {
                    Capsule()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: 12) {
            tierCard(
                tier: .free,
                name: "Free",
                icon: "leaf",
                price: "$0",
                period: "forever",
                highlights: ["3 Plant Health checks/month", "Basic care reminders", "Up to 50 plants"],
                color: CultivationTheme.Colors.textSecondary,
                isCurrent: !isActiveSubscriber
            )
            .accessibilityIdentifier("paywall_card_free")

            tierCard(
                tier: .premium,
                name: "Premium",
                icon: "crown",
                price: isYearly ? "$34.99" : "$2.99",
                period: isYearly ? "/year" : "/month",
                highlights: [
                    "Unlimited Plant Health checks",
                    "Smart reminders",
                    "Weather adjustments",
                    "Priority support",
                ],
                color: CultivationTheme.Colors.accentCoral,
                isCurrent: currentTierIs(.premium),
                isPopular: true
            )
            .accessibilityIdentifier("paywall_card_premium")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func currentTierIs(_ tier: SubscriptionTier) -> Bool {
        if case .active(let activeTier, _) = subscriptionService.subscriptionStatus {
            return activeTier == tier
        }
        return false
    }

    private func tierCard(
        tier: SubscriptionTier,
        name: String,
        icon: String,
        price: String,
        period: String,
        highlights: [String],
        color: Color,
        isCurrent: Bool,
        isPopular: Bool = false,
        subtitle: String? = nil
    ) -> some View {
        let isSelected = selectedTier == tier

        return Button {
            if tier != .free {
                withAnimation(CultivationTheme.Animation.selection) {
                    selectedTier = tier
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: icon + name + price
                HStack {
                    IconBubble(
                        systemName: icon,
                        color: color,
                        size: 36,
                        iconSize: 16
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(.headline, design: .serif, weight: .regular))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)

                            if isPopular {
                                Text("POPULAR")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(CultivationTheme.Colors.accentAmber)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }

                            if isCurrent {
                                Text("CURRENT")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(CultivationTheme.Colors.statusHealthy.opacity(0.2))
                                    .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                                    .clipShape(Capsule())
                            }
                        }

                        if tier == .free {
                            Text("Free forever")
                                .font(.system(.caption))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        } else if let subtitle {
                            Text(subtitle)
                                .font(.system(.caption))
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    if tier != .free {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(price)
                                .font(.system(.title3, design: .serif, weight: .regular))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Text(period)
                                .font(.system(.caption2))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }
                    }
                }

                // Feature highlights
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(highlights, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(color)
                            Text(feature)
                                .font(.system(.subheadline))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.leading, 4)
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.cardSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(
                        isSelected ? color : CultivationTheme.Colors.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .disabled(tier == .free)
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Compare Plans")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Feature")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Self.comparisonPlanNames[0])
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .frame(width: 50)
                    Text(Self.comparisonPlanNames[1])
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                        .frame(width: 66)
                }
                .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
                .padding(.vertical, 10)

                Divider()
                    .background(CultivationTheme.Colors.divider)

                ForEach(Array(Self.comparisonRows.enumerated()), id: \.offset) { index, row in
                    comparisonRow(
                        feature: row.feature,
                        free: row.free,
                        premium: row.premium,
                        isLast: index == Self.comparisonRows.count - 1
                    )
                }
            }
            .glassCard()
        }
        .accessibilityIdentifier("paywall_comparison_table")
    }

    private func comparisonRow(
        feature: String,
        free: PaywallComparisonValue,
        premium: PaywallComparisonValue,
        isLast: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                comparisonCell(value: free)
                    .frame(width: 50)
                comparisonCell(value: premium)
                    .frame(width: 66)
            }
            .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
            .padding(.vertical, 8)

            if !isLast {
                Divider()
                    .background(CultivationTheme.Colors.divider)
            }
        }
    }

    @ViewBuilder
    private func comparisonCell(value: PaywallComparisonValue) -> some View {
        switch value {
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(CultivationTheme.Colors.statusHealthy)

        case .cross:
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

        case .text(let label):
            Text(label)
                .font(.system(.caption2))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if subscriptionService.isLoading {
                ProgressView("Processing...")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityIdentifier("paywall_loading")
            } else {
                Button {
                    Task<Void, Never> {
                        await purchase()
                    }
                } label: {
                    Text(purchaseButtonLabel)
                }
                .buttonStyle(GradientButtonStyle(isDisabled: selectedTier == nil))
                .disabled(selectedTier == nil)
                .accessibilityIdentifier("paywall_button_subscribe")
            }

            Button("Restore Purchases") {
                Task<Void, Never> {
                    await restorePurchases()
                }
            }
            .font(.system(.footnote))
            .foregroundStyle(CultivationTheme.Colors.textSecondary)
            .disabled(subscriptionService.isLoading)
            .accessibilityIdentifier("paywall_button_restore")
        }
    }

    private var purchaseButtonLabel: String {
        guard selectedTier == .premium else { return "Select a Plan" }
        let price = isYearly ? "$34.99/yr" : "$2.99/mo"
        return "Subscribe to Premium — \(price)"
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("Subscription auto-renews. Cancel anytime in Settings.")
                .font(.system(.caption2))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://cultivation.app/terms")!)
                    .accessibilityIdentifier("paywall_button_terms")
                Link("Privacy Policy", destination: URL(string: "https://cultivation.app/privacy")!)
                    .accessibilityIdentifier("paywall_button_privacy")
            }
            .font(.system(.caption2))
            .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .padding(.top, 4)
        .accessibilityIdentifier("paywall_footer")
    }

    // MARK: - Actions

    private func purchase() async {
        guard let productID = selectedProductID else { return }

        let product = subscriptionService.purchasableProducts.first { $0.id == productID }
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
}

// MARK: - Comparison Value

enum PaywallComparisonValue: ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    case check
    case cross
    case text(String)

    init(booleanLiteral value: Bool) {
        self = value ? .check : .cross
    }

    init(stringLiteral value: String) {
        self = .text(value)
    }
}

struct PaywallComparisonRow {
    let feature: String
    let free: PaywallComparisonValue
    let premium: PaywallComparisonValue
}

#Preview {
    NavigationStack {
        PaywallView()
            .environment(SubscriptionService())
    }
}

// swiftlint:enable file_length force_unwrapping function_body_length function_parameter_count type_body_length
