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

    // MARK: - Test notification body

    @Test("Test-notification body uses Cultivation")
    func notificationBodyUsesCultivation() {
        #expect(ReminderSettingsView.testNotificationBody.hasPrefix("This is a test notification from Cultivation"))
    }

    // MARK: - AR camera permission

    @Test("AR camera permission message uses Cultivation")
    func arCameraPermissionMessageUsesCultivation() {
        #expect(ARGardenView.cameraPermissionMessage.hasPrefix("Cultivation needs camera access"))
    }
}
