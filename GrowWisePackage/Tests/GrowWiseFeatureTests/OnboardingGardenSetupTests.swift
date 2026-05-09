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

    @Test("completion summary describes selected first plant")
    func completionSummaryDescribesSelectedFirstPlant() {
        var profile = UserProfile()
        profile.selectedFirstPlantName = "Basil"

        #expect(CompletionView.firstPlantSummary(for: profile) == "Basil")
        #expect(CompletionView.nextCareSummary(for: profile) == "Watering reminder")
    }

    @Test("completion summary describes skipped first plant")
    func completionSummaryDescribesSkippedFirstPlant() {
        let profile = UserProfile()

        #expect(CompletionView.firstPlantSummary(for: profile) == "Skipped")
        #expect(CompletionView.nextCareSummary(for: profile) == nil)
    }

    @Test("completion summary joins primary goals")
    func completionSummaryJoinsPrimaryGoals() {
        var profile = UserProfile()
        profile.goals = [.growFood, .learnSkills, .sustainability]

        #expect(CompletionView.goalsSummary(for: profile) == "Grow My Own Food, Learn Gardening +1")
    }
}
