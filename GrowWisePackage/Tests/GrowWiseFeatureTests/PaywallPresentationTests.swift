@testable import GrowWiseFeature
import Testing

@Suite("Paywall presentation")
struct PaywallPresentationTests {
    @Test("1.0 paywall comparison does not advertise Pro")
    @MainActor
    func onePointZeroPaywallComparisonDoesNotAdvertisePro() {
        #expect(PaywallView.freePlanName == "Free")
        #expect(PaywallView.premiumPlanName == "Premium")
        #expect(!PaywallView.freePlanName.localizedCaseInsensitiveContains("pro"))
        #expect(!PaywallView.premiumPlanName.localizedCaseInsensitiveContains("pro"))
        #expect(!PaywallView.comparisonRows.contains { $0.feature == "Expert Consults" })
        #expect(PaywallView.comparisonRows.contains { $0.feature == "Garden Clubs" })
    }

    @Test("1.0 paywall prices match Premium launch pricing")
    @MainActor
    func onePointZeroPaywallPricesMatchLaunchPricing() {
        #expect(PaywallView.premiumMonthlyPriceText == "$2.99")
        #expect(PaywallView.premiumAnnualPriceText == "$34.99")
        #expect(PaywallView.premiumMonthlyPurchaseLabel == "Subscribe to Premium — $2.99/mo")
        #expect(PaywallView.premiumAnnualPurchaseLabel == "Subscribe to Premium — $34.99/yr")
    }
}
