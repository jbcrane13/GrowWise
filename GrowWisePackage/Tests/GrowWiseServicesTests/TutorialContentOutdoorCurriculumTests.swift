@testable import GrowWiseServices
import Testing

@Suite("TutorialContent outdoor beginner curriculum")
struct TutorialContentOutdoorCurriculumTests {
    private let requiredIDs = [
        "first-outdoor-garden",
        "what-to-plant-this-month",
        "seed-starting-indoors",
        "direct-sowing-basics",
        "transplanting-hardening-off",
        "succession-planting",
        "harvesting-basics",
    ]

    @Test("Tutorial corpus includes the outdoor beginner learning path")
    func outdoorBeginnerLearningPathIDsExist() {
        let ids = Set(TutorialContent.allTutorials.map(\.id))

        for id in requiredIDs {
            #expect(ids.contains(id), "Missing beginner learning path tutorial: \(id)")
        }
    }

    @Test("Outdoor beginner learning path tutorials are beginner friendly")
    func outdoorBeginnerLearningPathIsBeginnerDifficulty() throws {
        for id in requiredIDs {
            let tutorial = try #require(TutorialContent.allTutorials.first { $0.id == id })
            #expect(tutorial.difficultyLevel == .beginner)
        }
    }
}
