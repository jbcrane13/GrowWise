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

    @Test("beginner learning path returns outdoor curriculum in order")
    func beginnerLearningPathReturnsOutdoorCurriculumInOrder() throws {
        let dataService = try DataService.makeForTesting()
        let tutorialService = TutorialService(dataService: dataService)

        let path = tutorialService.getBeginnerLearningPath()

        #expect(path.map(\.id) == [
            "first-outdoor-garden",
            "what-to-plant-this-month",
            "seed-starting-indoors",
            "direct-sowing-basics",
            "transplanting-hardening-off",
            "succession-planting",
            "harvesting-basics",
        ])
    }
}
