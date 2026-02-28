import GrowWiseModels
import GrowWiseServices
import StoreKit
import SwiftUI

public struct ProfileView: View {
    @Environment(DataService.self) private var dataService
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var gardenCount: Int = 0
    @State private var plantCount: Int = 0
    @State private var showShareComingSoon = false
    @State private var selectedProductID: String?
    @State private var purchaseError: String?
    @State private var showPurchaseError = false
    @State private var showRestoreSuccess = false

    // Fixed product IDs matching SubscriptionService
    private let monthlyProductID = "com.growwise.premium.monthly"
    private let yearlyProductID = "com.growwise.premium.yearly"

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    gardenShowcaseSection
                    subscriptionSection
                }
                .padding()
            }
            .navigationTitle("Profile")
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
            } message: { message in
                Text(message)
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your purchases have been restored successfully.")
            }
        }
    }

    // MARK: - Garden Showcase

    private var gardenShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Garden Showcase")
                .font(.headline)

            HStack(spacing: 0) {
                statCell(value: gardenCount, label: "Gardens", icon: "leaf.fill")
                Divider().frame(height: 50)
                statCell(value: plantCount, label: "Plants", icon: "camera.macro")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button {
                showShareComingSoon = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Garden")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("profile_share_garden")
        }
    }

    private func statCell(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.headline)

            switch subscriptionService.subscriptionStatus {
            case let .active(tier, expiryDate):
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityIdentifier("profile_subscription_active")
    }

    // MARK: - Paywall

    private var paywallView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
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
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
            .background(isSelected ? Color.green : Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green : Color(.systemGray4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Actions

    private func loadStats() {
        gardenCount = dataService.getGardenCount()
        plantCount = dataService.getPlantCount()
    }

    private func subscribe() async {
        guard let productID = selectedProductID else { return }

        // Find the matching product from the service
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
}

#Preview {
    // swiftlint:disable:next force_try
    let dataService = try! DataService()
    let subscriptionService = SubscriptionService()

    ProfileView()
        .environment(dataService)
        .environment(subscriptionService)
}
