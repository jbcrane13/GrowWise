import CloudKit
import Foundation
import os

// MARK: - Forum Models

/// Topic categories for forum questions.
public enum ForumTopic: String, CaseIterable, Sendable {
    case pests, disease, soil, watering, pruning, harvesting, composting, general

    public var displayName: String {
        rawValue.capitalized
    }

    public var icon: String {
        switch self {
        case .pests: "ladybug.fill"
        case .disease: "allergens.fill"
        case .soil: "mountain.2.fill"
        case .watering: "drop.fill"
        case .pruning: "scissors"
        case .harvesting: "basket.fill"
        case .composting: "leaf.arrow.circlepath"
        case .general: "bubble.left.and.bubble.right.fill"
        }
    }
}

/// A community forum question backed by a CloudKit record.
public struct ForumQuestion: Identifiable, Sendable {
    public let id: UUID
    public let recordID: CKRecord.ID?
    public let title: String
    public let body: String
    public let authorName: String
    public let topic: ForumTopic
    public let voteCount: Int
    public let answerCount: Int
    public let createdDate: Date

    public init(
        id: UUID = UUID(),
        recordID: CKRecord.ID? = nil,
        title: String,
        body: String,
        authorName: String,
        topic: ForumTopic,
        voteCount: Int = 0,
        answerCount: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.recordID = recordID
        self.title = title
        self.body = body
        self.authorName = authorName
        self.topic = topic
        self.voteCount = voteCount
        self.answerCount = answerCount
        self.createdDate = createdDate
    }
}

/// An answer to a forum question backed by a CloudKit record.
public struct ForumAnswer: Identifiable, Sendable {
    public let id: UUID
    public let recordID: CKRecord.ID?
    public let body: String
    public let authorName: String
    public let voteCount: Int
    public let isAccepted: Bool
    public let createdDate: Date

    public init(
        id: UUID = UUID(),
        recordID: CKRecord.ID? = nil,
        body: String,
        authorName: String,
        voteCount: Int = 0,
        isAccepted: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.recordID = recordID
        self.body = body
        self.authorName = authorName
        self.voteCount = voteCount
        self.isAccepted = isAccepted
        self.createdDate = createdDate
    }
}

// MARK: - Forum Sort Order

/// Sort order options for the forum question list.
public enum ForumSortOrder: String, CaseIterable, Sendable {
    case newest
    case mostVoted

    public var displayName: String {
        switch self {
        case .newest: "Newest"
        case .mostVoted: "Most Voted"
        }
    }
}

// MARK: - ForumService

/// CloudKit-backed community Q&A forum service.
@MainActor
@Observable
public final class ForumService {
    // MARK: - Published State

    public private(set) var questions: [ForumQuestion] = []
    public private(set) var isLoadingQuestions = false
    public private(set) var isLoadingAnswers = false
    public private(set) var isPosting = false
    public private(set) var errorMessage: String?

    // MARK: - Private

    private var publicDatabase: CKDatabase?
    private var currentCursor: CKQueryOperation.Cursor?
    private let logger = Logger(subsystem: "com.growwise.forum", category: "ForumService")

    private static let questionRecordType = "ForumQuestion"
    private static let answerRecordType = "ForumAnswer"
    private static let resultsLimit = 20

    // MARK: - Init

    public init() {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        self.publicDatabase = container.publicCloudDatabase
    }

    // MARK: - Fetch Questions

    /// Fetches forum questions, optionally filtered by topic and/or search query.
    /// Returns questions and an optional cursor for pagination.
    public func fetchQuestions(
        topic: ForumTopic? = nil,
        searchQuery: String? = nil,
        sortOrder: ForumSortOrder = .newest,
        cursor: CKQueryOperation.Cursor? = nil
    ) async throws -> (questions: [ForumQuestion], cursor: CKQueryOperation.Cursor?) {
        guard let db = publicDatabase else {
            throw ForumError.notAvailable
        }

        isLoadingQuestions = true
        errorMessage = nil

        defer { isLoadingQuestions = false }

        let results: (
            matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)],
            queryCursor: CKQueryOperation.Cursor?
        )

        if let cursor {
            results = try await db.records(continuingMatchFrom: cursor, resultsLimit: Self.resultsLimit)
        } else {
            var predicates: [NSPredicate] = []

            if let topic {
                predicates.append(NSPredicate(format: "topic == %@", topic.rawValue))
            }

            if let searchQuery, !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                predicates.append(NSPredicate(
                    format: "self contains %@",
                    searchQuery.trimmingCharacters(in: .whitespaces)
                ))
            }

            let predicate: NSPredicate = predicates.isEmpty
                ? NSPredicate(value: true)
                : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            let sortKey: String = sortOrder == .mostVoted ? "voteCount" : "createdDate"
            let query = CKQuery(recordType: Self.questionRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]

            results = try await db.records(matching: query, resultsLimit: Self.resultsLimit)
        }

        let fetched = results.matchResults.compactMap { _, result -> ForumQuestion? in
            guard case .success(let record) = result else { return nil }
            return Self.questionFromRecord(record)
        }

        if cursor == nil {
            questions = fetched
        } else {
            questions.append(contentsOf: fetched)
        }

        currentCursor = results.queryCursor
        return (fetched, results.queryCursor)
    }

    /// Load more questions using the stored cursor.
    public func loadMoreQuestions(
        topic: ForumTopic? = nil,
        searchQuery: String? = nil,
        sortOrder: ForumSortOrder = .newest
    ) async throws {
        guard let cursor = currentCursor else { return }
        _ = try await fetchQuestions(topic: topic, searchQuery: searchQuery, sortOrder: sortOrder, cursor: cursor)
    }

    // MARK: - Fetch Answers

    /// Fetches all answers for a given question, sorted by vote count descending.
    public func fetchAnswers(for question: ForumQuestion) async throws -> [ForumAnswer] {
        guard let db = publicDatabase else {
            throw ForumError.notAvailable
        }
        guard let questionRecordID = question.recordID else {
            throw ForumError.invalidQuestion
        }

        isLoadingAnswers = true
        defer { isLoadingAnswers = false }

        let reference = CKRecord.Reference(recordID: questionRecordID, action: .none)
        let predicate = NSPredicate(format: "questionRef == %@", reference)
        let query = CKQuery(recordType: Self.answerRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "voteCount", ascending: false)]

        let results = try await db.records(matching: query, resultsLimit: 100)

        return results.matchResults.compactMap { _, result -> ForumAnswer? in
            guard case .success(let record) = result else { return nil }
            return Self.answerFromRecord(record)
        }
    }

    // MARK: - Post Question

    /// Posts a new question to the public CloudKit database.
    public func postQuestion(
        title: String,
        body: String,
        topic: ForumTopic,
        authorName: String
    ) async throws {
        guard let db = publicDatabase else {
            throw ForumError.notAvailable
        }

        isPosting = true
        defer { isPosting = false }

        let record = CKRecord(recordType: Self.questionRecordType)
        let questionID = UUID()
        record["questionID"] = questionID.uuidString as CKRecordValue
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        record["authorName"] = authorName as CKRecordValue
        record["topic"] = topic.rawValue as CKRecordValue
        record["voteCount"] = 0 as CKRecordValue
        record["answerCount"] = 0 as CKRecordValue
        record["createdDate"] = Date() as CKRecordValue

        let saved = try await db.save(record)
        let newQuestion = Self.questionFromRecord(saved)
        if let newQuestion {
            questions.insert(newQuestion, at: 0)
        }

        logger.info("Posted forum question: \(title)")
    }

    // MARK: - Post Answer

    /// Posts an answer to a given question.
    public func postAnswer(
        body: String,
        authorName: String,
        for question: ForumQuestion
    ) async throws {
        guard let db = publicDatabase else {
            throw ForumError.notAvailable
        }
        guard let questionRecordID = question.recordID else {
            throw ForumError.invalidQuestion
        }

        isPosting = true
        defer { isPosting = false }

        let record = CKRecord(recordType: Self.answerRecordType)
        let answerID = UUID()
        record["answerID"] = answerID.uuidString as CKRecordValue
        record["body"] = body as CKRecordValue
        record["authorName"] = authorName as CKRecordValue
        record["voteCount"] = 0 as CKRecordValue
        record["isAccepted"] = false as CKRecordValue
        record["createdDate"] = Date() as CKRecordValue
        record["questionRef"] = CKRecord.Reference(
            recordID: questionRecordID,
            action: .deleteSelf
        ) as CKRecordValue

        _ = try await db.save(record)

        // Increment answer count on the question record
        do {
            let questionRecord = try await db.record(for: questionRecordID)
            let currentCount = questionRecord["answerCount"] as? Int ?? 0
            questionRecord["answerCount"] = (currentCount + 1) as CKRecordValue
            _ = try await db.save(questionRecord)
        } catch {
            logger.warning("Failed to increment answer count: \(error.localizedDescription)")
        }

        logger.info("Posted answer for question: \(question.title)")
    }

    // MARK: - Voting

    /// Upvotes a forum question by incrementing its vote count.
    public func upvoteQuestion(_ question: ForumQuestion) async throws {
        guard let db = publicDatabase, let recordID = question.recordID else {
            throw ForumError.notAvailable
        }

        let record = try await db.record(for: recordID)
        let currentVotes = record["voteCount"] as? Int ?? 0
        record["voteCount"] = (currentVotes + 1) as CKRecordValue
        _ = try await db.save(record)

        // Update local state
        if let index = questions.firstIndex(where: { $0.id == question.id }) {
            let q = questions[index]
            questions[index] = ForumQuestion(
                id: q.id,
                recordID: q.recordID,
                title: q.title,
                body: q.body,
                authorName: q.authorName,
                topic: q.topic,
                voteCount: q.voteCount + 1,
                answerCount: q.answerCount,
                createdDate: q.createdDate
            )
        }
    }

    /// Upvotes a forum answer by incrementing its vote count.
    public func upvoteAnswer(_ answer: ForumAnswer) async throws {
        guard let db = publicDatabase, let recordID = answer.recordID else {
            throw ForumError.notAvailable
        }

        let record = try await db.record(for: recordID)
        let currentVotes = record["voteCount"] as? Int ?? 0
        record["voteCount"] = (currentVotes + 1) as CKRecordValue
        _ = try await db.save(record)
    }

    // MARK: - Report

    /// Reports inappropriate content by record ID with a reason.
    public func reportContent(recordID: CKRecord.ID, reason: String) async throws {
        guard let db = publicDatabase else {
            throw ForumError.notAvailable
        }

        let report = CKRecord(recordType: "ForumReport")
        report["reportedRecordID"] = recordID.recordName as CKRecordValue
        report["reason"] = reason as CKRecordValue
        report["reportDate"] = Date() as CKRecordValue

        _ = try await db.save(report)
        logger.info("Content reported: \(recordID.recordName)")
    }

    // MARK: - Record Mapping

    static func questionFromRecord(_ record: CKRecord) -> ForumQuestion? {
        guard
            let title = record["title"] as? String,
            let body = record["body"] as? String,
            let authorName = record["authorName"] as? String,
            let topicRaw = record["topic"] as? String,
            let topic = ForumTopic(rawValue: topicRaw)
        else {
            return nil
        }

        let idString = record["questionID"] as? String
        let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()

        return ForumQuestion(
            id: id,
            recordID: record.recordID,
            title: title,
            body: body,
            authorName: authorName,
            topic: topic,
            voteCount: record["voteCount"] as? Int ?? 0,
            answerCount: record["answerCount"] as? Int ?? 0,
            createdDate: record["createdDate"] as? Date ?? record.creationDate ?? Date()
        )
    }

    static func answerFromRecord(_ record: CKRecord) -> ForumAnswer? {
        guard
            let body = record["body"] as? String,
            let authorName = record["authorName"] as? String
        else {
            return nil
        }

        let idString = record["answerID"] as? String
        let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()

        return ForumAnswer(
            id: id,
            recordID: record.recordID,
            body: body,
            authorName: authorName,
            voteCount: record["voteCount"] as? Int ?? 0,
            isAccepted: record["isAccepted"] as? Bool ?? false,
            createdDate: record["createdDate"] as? Date ?? record.creationDate ?? Date()
        )
    }
}

// MARK: - ForumError

/// Errors specific to forum operations.
public enum ForumError: LocalizedError, Sendable {
    case notAvailable
    case invalidQuestion

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Forum is not available. Please check your iCloud connection."

        case .invalidQuestion:
            "The question could not be found."
        }
    }
}
