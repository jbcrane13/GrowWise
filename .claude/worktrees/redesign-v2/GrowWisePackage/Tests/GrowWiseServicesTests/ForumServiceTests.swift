import CloudKit
import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - ForumService Data Model Tests

// Note: CloudKit network methods (fetchQuestions, postQuestion, etc.) require hardware
// and are not tested here. These tests cover data models, enums, and service initial state.

struct ForumTopicTests {
    @Test("ForumTopic.allCases has 8 topics")
    func allCasesHasEightTopics() {
        #expect(ForumTopic.allCases.count == 8)
    }

    @Test("ForumTopic displayName is the capitalized rawValue")
    func displayNameIsCapitalizedRawValue() {
        for topic in ForumTopic.allCases {
            #expect(
                topic.displayName == topic.rawValue.capitalized,
                "Topic '\(topic.rawValue)' displayName should be '\(topic.rawValue.capitalized)' but got '\(topic.displayName)'"
            )
        }
    }

    @Test("ForumTopic pests displayName is Pests")
    func pestsDisplayName() {
        #expect(ForumTopic.pests.displayName == "Pests")
    }

    @Test("ForumTopic disease displayName is Disease")
    func diseaseDisplayName() {
        #expect(ForumTopic.disease.displayName == "Disease")
    }

    @Test("ForumTopic general displayName is General")
    func generalDisplayName() {
        #expect(ForumTopic.general.displayName == "General")
    }

    @Test("Every ForumTopic has a non-empty icon")
    func everyTopicHasNonEmptyIcon() {
        for topic in ForumTopic.allCases {
            #expect(!topic.icon.isEmpty, "Topic '\(topic.rawValue)' has an empty icon string")
        }
    }

    @Test("Each ForumTopic case has a distinct icon")
    func eachTopicHasDistinctIcon() {
        let icons = ForumTopic.allCases.map(\.icon)
        let uniqueIcons = Set(icons)
        #expect(
            icons.count == uniqueIcons.count,
            "ForumTopic cases share icons — each topic should have a unique SF Symbol"
        )
    }

    @Test("ForumTopic rawValues cover expected categories")
    func rawValuesCoverExpectedCategories() {
        let rawValues = Set(ForumTopic.allCases.map(\.rawValue))
        let expected: Set = ["pests", "disease", "soil", "watering", "pruning", "harvesting", "composting", "general"]
        #expect(rawValues == expected)
    }
}

struct ForumQuestionTests {
    @Test("ForumQuestion init sets all provided properties")
    func initSetsAllProperties() {
        let id = UUID()
        let createdDate = Date()
        let question = ForumQuestion(
            id: id,
            title: "Why are my tomato leaves curling?",
            body: "The lower leaves on my tomato plant have started curling inward.",
            authorName: "GardenGuru",
            topic: .disease,
            voteCount: 5,
            answerCount: 2,
            createdDate: createdDate
        )

        #expect(question.id == id)
        #expect(question.title == "Why are my tomato leaves curling?")
        #expect(question.body == "The lower leaves on my tomato plant have started curling inward.")
        #expect(question.authorName == "GardenGuru")
        #expect(question.topic == .disease)
        #expect(question.voteCount == 5)
        #expect(question.answerCount == 2)
        #expect(question.createdDate == createdDate)
    }

    @Test("ForumQuestion default voteCount is 0")
    func defaultVoteCountIsZero() {
        let question = ForumQuestion(
            title: "Test",
            body: "Test body",
            authorName: "Tester",
            topic: .general
        )
        #expect(question.voteCount == 0)
    }

    @Test("ForumQuestion default answerCount is 0")
    func defaultAnswerCountIsZero() {
        let question = ForumQuestion(
            title: "Test",
            body: "Test body",
            authorName: "Tester",
            topic: .general
        )
        #expect(question.answerCount == 0)
    }

    @Test("ForumQuestion default recordID is nil")
    func defaultRecordIDIsNil() {
        let question = ForumQuestion(
            title: "Test",
            body: "Test body",
            authorName: "Tester",
            topic: .general
        )
        #expect(question.recordID == nil)
    }

    @Test("ForumQuestion generates a unique id by default")
    func defaultIdIsUnique() {
        let q1 = ForumQuestion(title: "Q1", body: "Body 1", authorName: "User", topic: .soil)
        let q2 = ForumQuestion(title: "Q2", body: "Body 2", authorName: "User", topic: .soil)
        #expect(q1.id != q2.id)
    }

    @Test("ForumQuestion topic is preserved correctly")
    func topicIsPreservedCorrectly() {
        for topic in ForumTopic.allCases {
            let question = ForumQuestion(
                title: "Topic Test",
                body: "Body",
                authorName: "Author",
                topic: topic
            )
            #expect(question.topic == topic)
        }
    }
}

struct ForumAnswerTests {
    @Test("ForumAnswer init sets all provided properties")
    func initSetsAllProperties() {
        let id = UUID()
        let createdDate = Date()
        let answer = ForumAnswer(
            id: id,
            body: "Try watering less frequently and ensure good drainage.",
            authorName: "PlantExpert",
            voteCount: 10,
            isAccepted: true,
            createdDate: createdDate
        )

        #expect(answer.id == id)
        #expect(answer.body == "Try watering less frequently and ensure good drainage.")
        #expect(answer.authorName == "PlantExpert")
        #expect(answer.voteCount == 10)
        #expect(answer.isAccepted == true)
        #expect(answer.createdDate == createdDate)
    }

    @Test("ForumAnswer default voteCount is 0")
    func defaultVoteCountIsZero() {
        let answer = ForumAnswer(body: "Test answer", authorName: "User")
        #expect(answer.voteCount == 0)
    }

    @Test("ForumAnswer default isAccepted is false")
    func defaultIsAcceptedIsFalse() {
        let answer = ForumAnswer(body: "Test answer", authorName: "User")
        #expect(answer.isAccepted == false)
    }

    @Test("ForumAnswer default recordID is nil")
    func defaultRecordIDIsNil() {
        let answer = ForumAnswer(body: "Test answer", authorName: "User")
        #expect(answer.recordID == nil)
    }

    @Test("ForumAnswer generates a unique id by default")
    func defaultIdIsUnique() {
        let a1 = ForumAnswer(body: "Answer 1", authorName: "User")
        let a2 = ForumAnswer(body: "Answer 2", authorName: "User")
        #expect(a1.id != a2.id)
    }
}

struct ForumSortOrderTests {
    @Test("ForumSortOrder.allCases has 2 options")
    func allCasesHasTwoOptions() {
        #expect(ForumSortOrder.allCases.count == 2)
    }

    @Test("ForumSortOrder.newest displayName is Newest")
    func newestDisplayName() {
        #expect(ForumSortOrder.newest.displayName == "Newest")
    }

    @Test("ForumSortOrder.mostVoted displayName is Most Voted")
    func mostVotedDisplayName() {
        #expect(ForumSortOrder.mostVoted.displayName == "Most Voted")
    }

    @Test("ForumSortOrder rawValues are newest and mostVoted")
    func rawValues() {
        #expect(ForumSortOrder.newest.rawValue == "newest")
        #expect(ForumSortOrder.mostVoted.rawValue == "mostVoted")
    }
}

struct ForumErrorTests {
    @Test("ForumError.notAvailable has a non-empty error description")
    func notAvailableHasErrorDescription() {
        let error = ForumError.notAvailable
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.isEmpty == false)
    }

    @Test("ForumError.notAvailable error description mentions iCloud")
    func notAvailableDescriptionMentionsICloud() {
        let error = ForumError.notAvailable
        #expect(error.errorDescription?.contains("iCloud") == true)
    }

    @Test("ForumError.invalidQuestion has a non-empty error description")
    func invalidQuestionHasErrorDescription() {
        let error = ForumError.invalidQuestion
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.isEmpty == false)
    }

    @Test("ForumError.invalidQuestion error description mentions question")
    func invalidQuestionDescriptionMentionsQuestion() {
        let error = ForumError.invalidQuestion
        // The description should reference the entity that failed to be found
        #expect(error.errorDescription?.contains("question") == true)
    }
}

@MainActor
struct ForumServiceInitialStateTests {
    @Test("ForumService initializes without crashing")
    func initializesWithoutCrashing() {
        // ForumService skips CKContainer init when --uitesting argument is present.
        // In tests without --uitesting, it will attempt to access CKContainer.
        // We verify it at least initializes without a fatal error.
        _ = ForumService()
    }

    @Test("ForumService starts with empty questions array")
    func startsWithEmptyQuestions() {
        // Use --uitesting mode by invoking from test process
        // (test runner does not pass --uitesting, so publicDatabase will be set,
        //  but initial state should still be an empty array)
        let service = ForumService()
        #expect(service.questions.isEmpty)
    }

    @Test("ForumService starts not loading questions")
    func startsNotLoadingQuestions() {
        let service = ForumService()
        #expect(service.isLoadingQuestions == false)
    }

    @Test("ForumService starts not loading answers")
    func startsNotLoadingAnswers() {
        let service = ForumService()
        #expect(service.isLoadingAnswers == false)
    }

    @Test("ForumService starts not posting")
    func startsNotPosting() {
        let service = ForumService()
        #expect(service.isPosting == false)
    }

    @Test("ForumService starts with no error message")
    func startsWithNoErrorMessage() {
        let service = ForumService()
        #expect(service.errorMessage == nil)
    }
}
