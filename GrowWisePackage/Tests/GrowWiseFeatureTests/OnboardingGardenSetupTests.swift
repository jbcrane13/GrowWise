@testable import GrowWiseFeature
import Testing

@MainActor
@Suite("Onboarding garden setup state")
struct OnboardingGardenSetupTests {
    @Test("user profile defaults to creating a first garden")
    func userProfileDefaultsToCreatingFirstGarden() {
        let profile = UserProfile()

        #expect(profile.shouldCreateFirstGarden)
        #expect(profile.firstGardenName == "My First Garden")
    }

    @Test("completion summary describes skipped first garden")
    func completionSummaryDescribesSkippedGarden() {
        var profile = UserProfile()
        profile.shouldCreateFirstGarden = false

        #expect(CompletionView.gardenSummary(for: profile) == "Skipped")
    }
}
