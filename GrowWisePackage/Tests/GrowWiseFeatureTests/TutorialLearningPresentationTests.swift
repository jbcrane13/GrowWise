@testable import GrowWiseFeature
import Testing

@Suite("Tutorial learning presentation")
struct TutorialLearningPresentationTests {
    @Test("Learning hub title is beginner focused")
    func learningHubTitleIsBeginnerFocused() {
        #expect(TutorialView.learningHubTitle == "Learn & Grow")
    }

    @Test("Home learning card title points to planting guidance")
    func homeLearningCardTitlePointsToPlantingGuidance() {
        #expect(TutorialView.homeLearningCardTitle == "Learn what to plant now")
    }
}
