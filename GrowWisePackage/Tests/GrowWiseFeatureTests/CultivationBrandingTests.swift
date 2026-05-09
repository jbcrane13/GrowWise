@testable import GrowWiseFeature
import Foundation
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

    // MARK: - Club invite share copy

    @Test("Club invite share item uses Cultivation")
    func clubInviteShareItemUsesCultivation() {
        let item = ClubInviteSharing.shareItem(code: "ABC123")
        #expect(item == "Join my garden club on Cultivation! Use invite code: ABC123")
    }

    @Test("Club invite share message uses Cultivation and includes club name")
    func clubInviteShareMessageUsesCultivation() {
        let message = ClubInviteSharing.shareMessage(clubName: "My Garden", code: "ABC123")
        #expect(message == "Join My Garden on Cultivation with code ABC123")
    }

    @Test("Club invite share message defaults club name when nil")
    func clubInviteShareMessageDefaultsClubName() {
        let message = ClubInviteSharing.shareMessage(clubName: nil, code: "XYZ")
        #expect(message == "Join our club on Cultivation with code XYZ")
    }

    // MARK: - Resource-backed branding

    @Test("Resource-backed user-facing copy uses Cultivation")
    func resourceBackedCopyUsesCultivation() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let resourcePaths = [
            "Sources/GrowWiseFeature/Resources/en.lproj/Localizable.strings",
            "Sources/GrowWiseFeature/Resources/fr.lproj/Localizable.strings",
            "Sources/GrowWiseFeature/Resources/es.lproj/Localizable.strings",
            "Sources/GrowWiseFeature/Resources/de.lproj/Localizable.strings",
            "Sources/GrowWiseServices/Resources/tutorials.json",
        ]

        for resourcePath in resourcePaths {
            let resourceURL = packageRoot.appendingPathComponent(resourcePath)
            let contents = try String(contentsOf: resourceURL, encoding: .utf8)
            #expect(!contents.contains("GrowWise"), "\(resourcePath) still contains GrowWise")
            #expect(!contents.contains("Grow Wise"), "\(resourcePath) still contains Grow Wise")
        }
    }
}
