@testable import GrowWiseFeature
import Testing

@Suite("Paywall presentation")
struct PaywallPresentationTests {
    @Test("1.0 paywall comparison does not advertise Pro")
    func onePointZeroPaywallComparisonDoesNotAdvertisePro() {
        #expect(PaywallView.comparisonPlanNames == ["Free", "Premium"])
        #expect(!PaywallView.comparisonPlanNames.contains { $0.localizedCaseInsensitiveContains("pro") })
        #expect(!PaywallView.comparisonRows.contains { $0.feature == "Expert Consults" })
        #expect(PaywallView.comparisonRows.contains { $0.feature == "Garden Clubs" })
    }
}
