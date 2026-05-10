@testable import GrowWiseFeature
import Testing

@Suite("Paywall presentation")
struct PaywallPresentationTests {
    @Test("1.0 paywall comparison does not advertise Pro")
    func onePointZeroPaywallComparisonDoesNotAdvertisePro() {
        #expect(PaywallView.freePlanName == "Free")
        #expect(PaywallView.premiumPlanName == "Premium")
        #expect(!PaywallView.freePlanName.localizedCaseInsensitiveContains("pro"))
        #expect(!PaywallView.premiumPlanName.localizedCaseInsensitiveContains("pro"))
        #expect(!PaywallView.comparisonRows.contains { $0.feature == "Expert Consults" })
        #expect(PaywallView.comparisonRows.contains { $0.feature == "Garden Clubs" })
    }
}
