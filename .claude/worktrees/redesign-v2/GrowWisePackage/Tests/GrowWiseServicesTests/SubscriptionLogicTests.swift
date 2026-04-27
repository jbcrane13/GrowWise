import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("SubscriptionStatus Logic Tests")
struct SubscriptionStatusLogicTests {

    @Test("notSubscribed isSubscribed returns false")
    func testNotSubscribedIsNotSubscribed() {
        let status = SubscriptionStatus.notSubscribed
        #expect(status.isSubscribed == false)
    }

    @Test("active status isSubscribed returns true")
    func testActiveIsSubscribed() {
        let status = SubscriptionStatus.active(tier: .premium, expiryDate: nil)
        #expect(status.isSubscribed == true)
    }

    @Test("active pro status isSubscribed returns true")
    func testActiveProIsSubscribed() {
        let status = SubscriptionStatus.active(tier: .pro, expiryDate: nil)
        #expect(status.isSubscribed == true)
    }

    @Test("notSubscribed currentTier is free")
    func testNotSubscribedCurrentTierIsFree() {
        let status = SubscriptionStatus.notSubscribed
        #expect(status.currentTier == .free)
    }

    @Test("active premium currentTier is premium")
    func testActivePremiumCurrentTier() {
        let status = SubscriptionStatus.active(tier: .premium, expiryDate: nil)
        #expect(status.currentTier == .premium)
    }

    @Test("active pro currentTier is pro")
    func testActiveProCurrentTier() {
        let status = SubscriptionStatus.active(tier: .pro, expiryDate: nil)
        #expect(status.currentTier == .pro)
    }

    @Test("notSubscribed equals notSubscribed")
    func testNotSubscribedEquality() {
        #expect(SubscriptionStatus.notSubscribed == SubscriptionStatus.notSubscribed)
    }

    @Test("active statuses with same tier and expiry are equal")
    func testActiveEqualityWithSameTierAndExpiry() {
        let expiry = Date(timeIntervalSinceNow: 86400)
        let a = SubscriptionStatus.active(tier: .premium, expiryDate: expiry)
        let b = SubscriptionStatus.active(tier: .premium, expiryDate: expiry)
        #expect(a == b)
    }

    @Test("active statuses with different tiers are not equal")
    func testActiveInequalityDifferentTiers() {
        let a = SubscriptionStatus.active(tier: .premium, expiryDate: nil)
        let b = SubscriptionStatus.active(tier: .pro, expiryDate: nil)
        #expect(a != b)
    }

    @Test("notSubscribed and active are not equal")
    func testNotSubscribedAndActiveAreNotEqual() {
        let active = SubscriptionStatus.active(tier: .premium, expiryDate: nil)
        #expect(SubscriptionStatus.notSubscribed != active)
    }
}

@Suite("SubscriptionService Feature Access Tests")
@MainActor
struct SubscriptionServiceFeatureAccessTests {

    @Test("canAccessPremiumFeatures is false when not subscribed")
    func testCanAccessPremiumFeaturesNotSubscribed() {
        let service = SubscriptionService()
        // Default state is notSubscribed before StoreKit resolves
        #expect(service.canAccessPremiumFeatures == false)
    }

    @Test("canAccessProFeatures is false when not subscribed")
    func testCanAccessProFeaturesNotSubscribed() {
        let service = SubscriptionService()
        #expect(service.canAccessProFeatures == false)
    }

    @Test("hasUnlimitedDiagnoses is false when not subscribed")
    func testHasUnlimitedDiagnosesNotSubscribed() {
        let service = SubscriptionService()
        #expect(service.hasUnlimitedDiagnoses == false)
    }

    @Test("canAccessExpertConsultations is false when not subscribed")
    func testCanAccessExpertConsultationsNotSubscribed() {
        let service = SubscriptionService()
        #expect(service.canAccessExpertConsultations == false)
    }

    @Test("hasUnlimitedDiagnoses matches canAccessPremiumFeatures")
    func testHasUnlimitedDiagnosesMatchesPremium() {
        let service = SubscriptionService()
        #expect(service.hasUnlimitedDiagnoses == service.canAccessPremiumFeatures)
    }

    @Test("canAccessExpertConsultations matches canAccessProFeatures")
    func testExpertConsultationsMatchesPro() {
        let service = SubscriptionService()
        #expect(service.canAccessExpertConsultations == service.canAccessProFeatures)
    }
}

@Suite("SubscriptionError Tests")
struct SubscriptionErrorTests {

    @Test("Error descriptions are non-empty for all cases")
    func testAllErrorDescriptionsNonEmpty() {
        #expect(SubscriptionError.purchaseFailed("test").errorDescription?.isEmpty == false)
        #expect(SubscriptionError.restoreFailed("test").errorDescription?.isEmpty == false)
        #expect(SubscriptionError.verificationFailed.errorDescription?.isEmpty == false)
        #expect(SubscriptionError.unknownResult.errorDescription?.isEmpty == false)
        #expect(SubscriptionError.productNotFound.errorDescription?.isEmpty == false)
    }

    @Test("purchaseFailed includes the provided message")
    func testPurchaseFailedIncludesMessage() {
        let error = SubscriptionError.purchaseFailed("network timeout")
        #expect(error.errorDescription?.contains("network timeout") == true)
    }

    @Test("restoreFailed includes the provided message")
    func testRestoreFailedIncludesMessage() {
        let error = SubscriptionError.restoreFailed("server unavailable")
        #expect(error.errorDescription?.contains("server unavailable") == true)
    }
}
