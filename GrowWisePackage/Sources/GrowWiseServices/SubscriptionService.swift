import Foundation
import GrowWiseModels
import os
import StoreKit

/// Service for managing StoreKit subscriptions and purchases
@MainActor
@Observable
public final class SubscriptionService {
    // MARK: - Published State

    public private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    public private(set) var availableProducts: [Product] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    /// Transaction history
    public private(set) var purchaseHistory: [Transaction] = []

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.growwise.storekit", category: "SubscriptionService")

    /// Product IDs (must match App Store Connect).
    /// .yearly IDs retained to load legacy subscriber entitlements; .annual IDs are the active purchase path for 1.0+.
    private let productIDs = [
        "com.growwise.premium.monthly",
        "com.growwise.premium.yearly", // legacy — kept for existing subscribers
        "com.growwise.premium.annual", // active: $34.99/yr
        "com.growwise.pro.monthly",
        "com.growwise.pro.yearly", // legacy
        "com.growwise.pro.annual", // active: $79.99/yr
    ]

    // MARK: - Initialization

    public init() {
        // Start transaction listener
        updateListenerTask = listenForTransactions()

        // Load products on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Load available products from App Store
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let products = try await Product.products(for: Set(productIDs))
            availableProducts = products.sorted { $0.price < $1.price }
            isLoading = false
            logger.info("Loaded \(products.count) products")
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            isLoading = false
            logger.error("Failed to load products: \(message)")
        }
    }

    // MARK: - Purchase

    /// Purchase a product
    public func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check transaction verification
                let transaction = try checkVerified(verification)

                // Deliver content to user
                await deliverPurchase(product)

                // Update subscription status
                await updateSubscriptionStatus()

                logger.info("Purchase successful: \(product.id)")
                return transaction

            case .userCancelled:
                logger.info("User cancelled purchase")
                return nil

            case .pending:
                logger.info("Purchase pending approval")
                return nil

            @unknown default:
                throw SubscriptionError.unknownResult
            }
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            logger.error("Purchase failed: \(message)")
            throw SubscriptionError.purchaseFailed(message)
        }
    }

    /// Restore previous purchases
    public func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            logger.info("Purchases restored successfully")
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            logger.error("Failed to restore purchases: \(message)")
            throw SubscriptionError.restoreFailed(message)
        }
    }

    // MARK: - Subscription Status

    /// Check current subscription status
    public func updateSubscriptionStatus() async {
        do {
            // Get all entitlements
            let entitlements = try await Transaction.currentEntitlements

            var hasActiveSubscription = false
            var tier: SubscriptionTier = .free
            var expiryDate: Date?

            for await verification in entitlements {
                guard let transaction = checkVerifiedNoThrow(verification) else { continue }

                // Check if transaction is active
                if transaction.revocationDate == nil,
                   transaction.expirationDate ?? Date() > Date()
                {
                    hasActiveSubscription = true

                    // Determine tier from product ID
                    if transaction.productID.contains("pro") {
                        tier = SubscriptionTier.pro
                    } else if transaction.productID.contains("premium") {
                        tier = SubscriptionTier.premium
                    }

                    expiryDate = transaction.expirationDate
                }
            }

            if hasActiveSubscription {
                subscriptionStatus = .active(tier: tier, expiryDate: expiryDate)
            } else {
                subscriptionStatus = .notSubscribed
            }

            logger.info("Subscription status updated: \(hasActiveSubscription ? "active" : "not subscribed")")
        } catch {
            let message = error.localizedDescription
            errorMessage = "Unable to verify subscription: \(message)"
            logger.error("Failed to update subscription status: \(message)")
        }
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try checkVerified(verification)

                    // Handle the transaction
                    await handleTransaction(transaction)

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Handle a transaction update
    private func handleTransaction(_ transaction: Transaction) async {
        if transaction.revocationDate != nil {
            // Purchase was revoked (refund)
            logger.info("Purchase revoked: \(transaction.productID)")
        } else if let expirationDate = transaction.expirationDate,
                  expirationDate < Date()
        {
            // Subscription expired
            logger.info("Subscription expired: \(transaction.productID)")
        } else {
            // Active purchase
            logger.info("Active purchase: \(transaction.productID)")
        }

        // Update subscription status
        await updateSubscriptionStatus()
    }

    // MARK: - Helper Methods

    /// Verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed

        case .verified(let safe):
            return safe
        }
    }

    /// Verify a transaction without throwing
    private func checkVerifiedNoThrow<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .unverified:
            nil

        case .verified(let safe):
            safe
        }
    }

    /// Deliver purchased content
    private func deliverPurchase(_ product: Product) async {
        // Update user's subscription in app state
        // This could involve updating SwiftData models, UserDefaults, etc.
        logger.info("Delivering purchase: \(product.id)")
    }

    // MARK: - Feature Access

    /// Check if user can access premium features
    public var canAccessPremiumFeatures: Bool {
        switch subscriptionStatus {
        case .active(let tier, _):
            tier == SubscriptionTier.premium || tier == SubscriptionTier.pro

        case .notSubscribed:
            false
        }
    }

    /// Check if user can access pro features
    public var canAccessProFeatures: Bool {
        switch subscriptionStatus {
        case .active(let tier, _):
            tier == SubscriptionTier.pro

        case .notSubscribed:
            false
        }
    }

    /// Check if user has unlimited Plant Health checks
    public var hasUnlimitedDiagnoses: Bool {
        canAccessPremiumFeatures
    }

    /// Check if user can access expert consultations
    public var canAccessExpertConsultations: Bool {
        canAccessProFeatures
    }
}

// MARK: - Supporting Types

public enum SubscriptionStatus: Equatable, Sendable {
    case notSubscribed
    case active(tier: SubscriptionTier, expiryDate: Date?)

    public var isSubscribed: Bool {
        switch self {
        case .notSubscribed:
            false

        case .active:
            true
        }
    }

    public var currentTier: SubscriptionTier {
        switch self {
        case .notSubscribed:
            SubscriptionTier.free

        case .active(let tier, _):
            tier
        }
    }
}

public enum SubscriptionError: LocalizedError, Sendable {
    case purchaseFailed(String)
    case restoreFailed(String)
    case verificationFailed
    case unknownResult
    case productNotFound

    public var errorDescription: String? {
        switch self {
        case .purchaseFailed(let message):
            "Purchase failed: \(message)"

        case .restoreFailed(let message):
            "Restore failed: \(message)"

        case .verificationFailed:
            "Transaction verification failed"

        case .unknownResult:
            "Unknown purchase result"

        case .productNotFound:
            "Product not found in App Store"
        }
    }
}

// MARK: - Paywall State

@MainActor
@Observable
public final class PaywallState {
    public let service: SubscriptionService

    public var selectedProduct: Product?
    public var isPurchasing = false
    public var errorMessage: String?
    public var showSuccess = false

    public init(service: SubscriptionService) {
        self.service = service
    }

    public var monthlyProducts: [Product] {
        service.availableProducts.filter { $0.id.contains("monthly") }
    }

    public var yearlyProducts: [Product] {
        service.availableProducts.filter { $0.id.contains("yearly") }
    }

    public func purchaseSelectedProduct() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            let transaction = try await service.purchase(product)
            if transaction != nil {
                showSuccess = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    public func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil

        do {
            try await service.restorePurchases()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }
}
