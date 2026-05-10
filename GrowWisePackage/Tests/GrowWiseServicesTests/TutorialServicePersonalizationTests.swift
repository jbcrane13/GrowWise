@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("TutorialService personalization")
struct TutorialServicePersonalizationTests {
    @Test("recommended tutorials prioritize the learning goal over shortest duration")
    func recommendedTutorialsPrioritizeLearningGoal() throws {
        let dataService = try DataService.makeForTesting()
        let tutorialService = TutorialService(dataService: dataService)
        let user = User(
            email: "learner@example.com",
            displayName: "Learner",
            skillLevel: .beginner
        )
        user.gardeningGoals = [.learnSkills]

        let tutorials = tutorialService.getRecommendedTutorials(for: user)

        #expect(tutorials.first?.category == .planning)
    }
}
