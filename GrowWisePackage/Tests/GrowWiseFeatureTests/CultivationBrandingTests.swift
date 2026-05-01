@testable import GrowWiseFeature
import GrowWiseModels
import Testing

@Suite("Cultivation branding")
struct CultivationBrandingTests {
    // MARK: - ProfileView paywall row

    @Test("Tier display name uses Cultivation Pro for .pro tier")
    func tierDisplayNameProUsesCultivation() {
        #expect(ProfileView.tierDisplayName(.pro) == "Cultivation Pro")
    }

    @Test("Tier display name uses Cultivation Premium for .premium tier")
    func tierDisplayNamePremiumUsesCultivation() {
        #expect(ProfileView.tierDisplayName(.premium) == "Cultivation Premium")
    }

    // MARK: - ProfileView paywall headline

    @Test("Paywall unlock headline uses Cultivation")
    func paywallUnlockHeadlineUsesCultivation() {
        #expect(ProfileView.unlockPremiumHeadline == "Unlock Cultivation Premium")
    }
}
