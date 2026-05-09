@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("Onboarding persistence")
struct OnboardingPersistenceTests {
    @Test("updateOnboardingProfile persists goals and preferred plant types")
    func updateOnboardingProfilePersistsPreferences() throws {
        let dataService = try DataService.makeForTesting()
        let user = try dataService.createUser(
            email: "gardener@example.com",
            displayName: "Gardener",
            skillLevel: .beginner
        )

        try dataService.updateOnboardingProfile(
            for: user,
            gardeningGoals: [.growFood, .learnSkills],
            preferredPlantTypes: [.vegetable, .herb, .fruit]
        )

        let savedUser = try #require(dataService.getCurrentUser())

        #expect(savedUser.gardeningGoals == [.growFood, .learnSkills])
        #expect(savedUser.preferredPlantTypes == [.vegetable, .herb, .fruit])
    }
}
