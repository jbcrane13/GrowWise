import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - Subscription Tier Determination Contract Tests

@Suite(.tags(.integration))
struct SubscriptionTierDeterminationTests {
    @Test("Product ID containing 'pro' maps to pro tier")
    func proProductIDMapsToPro() {
        let tier = tierFromProductID("com.growwise.pro.monthly")
        #expect(tier == .pro)
    }

    @Test("Product ID containing 'premium' maps to premium tier")
    func premiumProductIDMapsToPremium() {
        let tier = tierFromProductID("com.growwise.premium.yearly")
        #expect(tier == .premium)
    }

    @Test("Product ID containing both 'pro' and 'premium' maps to pro (pro wins)")
    func proTakesPrecedenceOverPremium() {
        // Edge case: if a product ID somehow contained both
        let tier = tierFromProductID("com.growwise.pro.premium.monthly")
        #expect(tier == .pro)
    }

    @Test("Product ID with neither 'pro' nor 'premium' stays free")
    func unknownProductIDStaysFree() {
        let tier = tierFromProductID("com.growwise.basic.monthly")
        #expect(tier == .free)
    }

    /// Replicates the tier determination logic from SubscriptionService.updateSubscriptionStatus()
    private func tierFromProductID(_ productID: String) -> SubscriptionTier {
        if productID.contains("pro") {
            return .pro
        } else if productID.contains("premium") {
            return .premium
        }
        return .free
    }
}

// MARK: - SubscriptionStatus Feature Access Contract Tests

@Suite(.tags(.integration))
struct SubscriptionStatusFeatureAccessTests {
    @Test("Free tier: no premium features, no pro features")
    func freeTierAccess() {
        let status = SubscriptionStatus.notSubscribed

        #expect(status.isSubscribed == false)
        #expect(status.currentTier == .free)
    }

    @Test("Premium tier: subscribed with premium tier")
    func premiumTierAccess() {
        let status = SubscriptionStatus.active(tier: .premium, expiryDate: futureDate())

        #expect(status.isSubscribed == true)
        #expect(status.currentTier == .premium)
    }

    @Test("Pro tier: subscribed with pro tier")
    func proTierAccess() {
        let status = SubscriptionStatus.active(tier: .pro, expiryDate: futureDate())

        #expect(status.isSubscribed == true)
        #expect(status.currentTier == .pro)
    }

    @Test("Active status with nil expiryDate is still subscribed")
    func activeWithNilExpiryIsSubscribed() {
        let status = SubscriptionStatus.active(tier: .premium, expiryDate: nil)

        #expect(status.isSubscribed == true)
    }

    @Test("SubscriptionTier.free has 3 diagnoses per month")
    func freeTierDiagnoseLimit() {
        #expect(SubscriptionTier.free.aiDiagnosesPerMonth == 3)
    }

    @Test("SubscriptionTier.premium has unlimited diagnoses (represented as -1)")
    func premiumTierDiagnoseLimit() {
        #expect(SubscriptionTier.premium.aiDiagnosesPerMonth == -1)
    }

    @Test("SubscriptionTier.pro has unlimited diagnoses (represented as -1)")
    func proTierDiagnoseLimit() {
        #expect(SubscriptionTier.pro.aiDiagnosesPerMonth == -1)
    }

    @Test("SubscriptionTier prices are ordered: free < premium < pro")
    func tierPricesOrdered() {
        #expect(SubscriptionTier.free.monthlyPrice < SubscriptionTier.premium.monthlyPrice)
        #expect(SubscriptionTier.premium.monthlyPrice < SubscriptionTier.pro.monthlyPrice)
    }

    @Test("SubscriptionTier rawValues are stable strings for Codable compatibility")
    func tierRawValuesAreStable() {
        #expect(SubscriptionTier.free.rawValue == "free")
        #expect(SubscriptionTier.premium.rawValue == "premium")
        #expect(SubscriptionTier.pro.rawValue == "pro")
    }

    @Test("SubscriptionTier round-trips through Codable")
    func tierCodableRoundTrip() throws {
        for tier in SubscriptionTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(SubscriptionTier.self, from: data)
            #expect(decoded == tier)
        }
    }

    private func futureDate() -> Date {
        Date(timeIntervalSinceNow: 30 * 86400)
    }
}

// MARK: - SubscriptionService Initial State Contract Tests

@Suite(.tags(.integration))
@MainActor
struct SubscriptionServiceInitialStateTests {
    @Test("Service starts as not subscribed")
    func startsNotSubscribed() {
        let service = SubscriptionService()

        #expect(service.subscriptionStatus == .notSubscribed)
    }

    @Test("Service starts with empty product list")
    func startsWithEmptyProducts() {
        let service = SubscriptionService()

        #expect(service.availableProducts.isEmpty)
    }

    @Test("Service starts with no error message")
    func startsWithNoError() {
        let service = SubscriptionService()

        #expect(service.errorMessage == nil)
    }

    @Test("Service starts with empty purchase history")
    func startsWithEmptyHistory() {
        let service = SubscriptionService()

        #expect(service.purchaseHistory.isEmpty)
    }

    @Test("Premium feature access is false on fresh service")
    func premiumAccessFalseOnInit() {
        let service = SubscriptionService()

        #expect(service.canAccessPremiumFeatures == false)
        #expect(service.canAccessProFeatures == false)
        #expect(service.hasUnlimitedDiagnoses == false)
        #expect(service.canAccessExpertConsultations == false)
    }
}

// MARK: - SubscriptionError Contract Tests

@Suite(.tags(.integration))
struct SubscriptionErrorContractTests {
    @Test("All error cases conform to LocalizedError with non-nil descriptions")
    func allErrorsHaveDescriptions() throws {
        let errors: [SubscriptionError] = [
            .purchaseFailed("test"),
            .restoreFailed("test"),
            .verificationFailed,
            .unknownResult,
            .productNotFound,
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "\(error) has nil description")
            #expect(try !#require(error.errorDescription?.isEmpty), "\(error) has empty description")
        }
    }

    @Test("purchaseFailed preserves the failure reason in the description")
    func purchaseFailedPreservesReason() {
        let reason = "insufficient funds"
        let error = SubscriptionError.purchaseFailed(reason)

        #expect(error.errorDescription?.contains(reason) == true)
    }

    @Test("restoreFailed preserves the failure reason in the description")
    func restoreFailedPreservesReason() {
        let reason = "network timeout"
        let error = SubscriptionError.restoreFailed(reason)

        #expect(error.errorDescription?.contains(reason) == true)
    }

    @Test("verificationFailed description mentions verification")
    func verificationFailedMentionsVerification() {
        let error = SubscriptionError.verificationFailed

        #expect(error.errorDescription?.lowercased().contains("verification") == true)
    }
}
