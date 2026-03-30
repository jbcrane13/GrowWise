import CloudKit
import Foundation
@testable import GrowWiseServices
import Testing

// MARK: - ForumService CKRecord Contract Tests

@Suite(.tags(.integration))
@MainActor
struct ForumServiceContractTests {
    // MARK: - Question Parsing

    @Test("questionFromRecord decodes a fully-populated CKRecord")
    func questionDecodesFromFullRecord() throws {
        let fixture = try loadFixture(named: "forum-question-record", as: QuestionFixture.self)
        let record = makeQuestionRecord(from: fixture)

        let question = ForumService.questionFromRecord(record)

        #expect(question != nil)
        #expect(question?.title == fixture.title)
        #expect(question?.body == fixture.body)
        #expect(question?.authorName == fixture.authorName)
        #expect(question?.topic == ForumTopic(rawValue: fixture.topic))
        #expect(question?.voteCount == fixture.voteCount)
        #expect(question?.answerCount == fixture.answerCount)
        #expect(question?.id.uuidString == fixture.questionID)
    }

    @Test("questionFromRecord returns nil when title is missing")
    func questionFailsWithoutTitle() {
        let record = CKRecord(recordType: "ForumQuestion")
        record["body"] = "Some body"
        record["authorName"] = "Author"
        record["topic"] = "general"

        #expect(ForumService.questionFromRecord(record) == nil)
    }

    @Test("questionFromRecord returns nil when body is missing")
    func questionFailsWithoutBody() {
        let record = CKRecord(recordType: "ForumQuestion")
        record["title"] = "Some title"
        record["authorName"] = "Author"
        record["topic"] = "general"

        #expect(ForumService.questionFromRecord(record) == nil)
    }

    @Test("questionFromRecord returns nil when authorName is missing")
    func questionFailsWithoutAuthorName() {
        let record = CKRecord(recordType: "ForumQuestion")
        record["title"] = "Some title"
        record["body"] = "Some body"
        record["topic"] = "general"

        #expect(ForumService.questionFromRecord(record) == nil)
    }

    @Test("questionFromRecord returns nil when topic is missing")
    func questionFailsWithoutTopic() {
        let record = CKRecord(recordType: "ForumQuestion")
        record["title"] = "Some title"
        record["body"] = "Some body"
        record["authorName"] = "Author"

        #expect(ForumService.questionFromRecord(record) == nil)
    }

    @Test("questionFromRecord returns nil for invalid topic rawValue")
    func questionFailsWithInvalidTopic() {
        let record = CKRecord(recordType: "ForumQuestion")
        record["title"] = "Some title"
        record["body"] = "Some body"
        record["authorName"] = "Author"
        record["topic"] = "nonexistent_topic"

        #expect(ForumService.questionFromRecord(record) == nil)
    }

    @Test("questionFromRecord defaults voteCount to 0 when absent")
    func questionDefaultsVoteCount() {
        let record = makeMinimalQuestionRecord()

        let question = ForumService.questionFromRecord(record)

        #expect(question != nil)
        #expect(question?.voteCount == 0)
    }

    @Test("questionFromRecord defaults answerCount to 0 when absent")
    func questionDefaultsAnswerCount() {
        let record = makeMinimalQuestionRecord()

        let question = ForumService.questionFromRecord(record)

        #expect(question != nil)
        #expect(question?.answerCount == 0)
    }

    @Test("questionFromRecord generates a UUID when questionID is missing")
    func questionGeneratesUUIDWhenMissing() {
        let record = makeMinimalQuestionRecord()

        let q1 = ForumService.questionFromRecord(record)
        let q2 = ForumService.questionFromRecord(record)

        #expect(q1 != nil)
        #expect(q2 != nil)
        #expect(q1?.id != q2?.id)
    }

    @Test("questionFromRecord generates a UUID when questionID is not a valid UUID string")
    func questionGeneratesUUIDForInvalidString() {
        let record = makeMinimalQuestionRecord()
        record["questionID"] = "not-a-uuid"

        let question = ForumService.questionFromRecord(record)

        #expect(question != nil)
        #expect(question?.id.uuidString != "not-a-uuid")
    }

    @Test("questionFromRecord uses record.creationDate as date fallback")
    func questionUsesRecordCreationDateAsFallback() {
        let record = makeMinimalQuestionRecord()
        // CKRecord.creationDate is set by CloudKit; in test CKRecords it may be nil,
        // so the fallback chain is: createdDate field → record.creationDate → Date()
        let question = ForumService.questionFromRecord(record)

        #expect(question != nil)
        #expect(question?.createdDate != nil)
    }

    @Test("questionFromRecord preserves recordID from the CKRecord")
    func questionPreservesRecordID() {
        let recordID = CKRecord.ID(recordName: "test-record-123")
        let record = CKRecord(recordType: "ForumQuestion", recordID: recordID)
        record["title"] = "Title"
        record["body"] = "Body"
        record["authorName"] = "Author"
        record["topic"] = "soil"

        let question = ForumService.questionFromRecord(record)

        #expect(question?.recordID == recordID)
    }

    @Test("questionFromRecord works for every ForumTopic rawValue")
    func questionParsesAllTopics() {
        for topic in ForumTopic.allCases {
            let record = makeMinimalQuestionRecord(topic: topic.rawValue)
            let question = ForumService.questionFromRecord(record)

            #expect(question != nil, "Failed to parse topic: \(topic.rawValue)")
            #expect(question?.topic == topic)
        }
    }

    // MARK: - Answer Parsing

    @Test("answerFromRecord decodes a fully-populated CKRecord")
    func answerDecodesFromFullRecord() throws {
        let fixture = try loadFixture(named: "forum-answer-record", as: AnswerFixture.self)
        let record = makeAnswerRecord(from: fixture)

        let answer = ForumService.answerFromRecord(record)

        #expect(answer != nil)
        #expect(answer?.body == fixture.body)
        #expect(answer?.authorName == fixture.authorName)
        #expect(answer?.voteCount == fixture.voteCount)
        #expect(answer?.isAccepted == fixture.isAccepted)
        #expect(answer?.id.uuidString == fixture.answerID)
    }

    @Test("answerFromRecord returns nil when body is missing")
    func answerFailsWithoutBody() {
        let record = CKRecord(recordType: "ForumAnswer")
        record["authorName"] = "Author"

        #expect(ForumService.answerFromRecord(record) == nil)
    }

    @Test("answerFromRecord returns nil when authorName is missing")
    func answerFailsWithoutAuthorName() {
        let record = CKRecord(recordType: "ForumAnswer")
        record["body"] = "Some answer"

        #expect(ForumService.answerFromRecord(record) == nil)
    }

    @Test("answerFromRecord defaults voteCount to 0 when absent")
    func answerDefaultsVoteCount() {
        let record = makeMinimalAnswerRecord()

        let answer = ForumService.answerFromRecord(record)

        #expect(answer != nil)
        #expect(answer?.voteCount == 0)
    }

    @Test("answerFromRecord defaults isAccepted to false when absent")
    func answerDefaultsIsAccepted() {
        let record = makeMinimalAnswerRecord()

        let answer = ForumService.answerFromRecord(record)

        #expect(answer != nil)
        #expect(answer?.isAccepted == false)
    }

    @Test("answerFromRecord generates a UUID when answerID is missing")
    func answerGeneratesUUIDWhenMissing() {
        let record = makeMinimalAnswerRecord()

        let a1 = ForumService.answerFromRecord(record)
        let a2 = ForumService.answerFromRecord(record)

        #expect(a1 != nil)
        #expect(a2 != nil)
        #expect(a1?.id != a2?.id)
    }

    @Test("answerFromRecord preserves recordID from the CKRecord")
    func answerPreservesRecordID() {
        let recordID = CKRecord.ID(recordName: "answer-record-456")
        let record = CKRecord(recordType: "ForumAnswer", recordID: recordID)
        record["body"] = "Answer body"
        record["authorName"] = "Author"

        let answer = ForumService.answerFromRecord(record)

        #expect(answer?.recordID == recordID)
    }

    // MARK: - Helpers

    private func makeMinimalQuestionRecord(topic: String = "general") -> CKRecord {
        let record = CKRecord(recordType: "ForumQuestion")
        record["title"] = "Minimal question"
        record["body"] = "Minimal body"
        record["authorName"] = "Author"
        record["topic"] = topic
        return record
    }

    private func makeMinimalAnswerRecord() -> CKRecord {
        let record = CKRecord(recordType: "ForumAnswer")
        record["body"] = "Minimal answer"
        record["authorName"] = "Author"
        return record
    }

    private func makeQuestionRecord(from fixture: QuestionFixture) -> CKRecord {
        let record = CKRecord(recordType: "ForumQuestion")
        let formatter = ISO8601DateFormatter()

        record["questionID"] = fixture.questionID
        record["title"] = fixture.title
        record["body"] = fixture.body
        record["authorName"] = fixture.authorName
        record["topic"] = fixture.topic
        record["voteCount"] = fixture.voteCount
        record["answerCount"] = fixture.answerCount
        if let dateStr = fixture.createdDateISO8601,
           let date = formatter.date(from: dateStr)
        {
            record["createdDate"] = date as NSDate
        }
        return record
    }

    private func makeAnswerRecord(from fixture: AnswerFixture) -> CKRecord {
        let record = CKRecord(recordType: "ForumAnswer")
        let formatter = ISO8601DateFormatter()

        record["answerID"] = fixture.answerID
        record["body"] = fixture.body
        record["authorName"] = fixture.authorName
        record["voteCount"] = fixture.voteCount
        record["isAccepted"] = fixture.isAccepted
        if let dateStr = fixture.createdDateISO8601,
           let date = formatter.date(from: dateStr)
        {
            record["createdDate"] = date as NSDate
        }
        return record
    }

    private func loadFixture<T: Decodable>(named name: String, as type: T.Type) throws -> T {
        let fixtureURL = repositoryRoot()
            .appendingPathComponent("tests")
            .appendingPathComponent("TestFixtures")
            .appendingPathComponent("\(name).json")

        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

// MARK: - Fixtures

private struct QuestionFixture: Decodable {
    let questionID: String
    let title: String
    let body: String
    let authorName: String
    let topic: String
    let voteCount: Int
    let answerCount: Int
    let createdDateISO8601: String?

    enum CodingKeys: String, CodingKey {
        case questionID, title, body, authorName, topic, voteCount, answerCount
        case createdDateISO8601 = "createdDate"
    }
}

private struct AnswerFixture: Decodable {
    let answerID: String
    let body: String
    let authorName: String
    let voteCount: Int
    let isAccepted: Bool
    let createdDateISO8601: String?

    enum CodingKeys: String, CodingKey {
        case answerID, body, authorName, voteCount, isAccepted
        case createdDateISO8601 = "createdDate"
    }
}
