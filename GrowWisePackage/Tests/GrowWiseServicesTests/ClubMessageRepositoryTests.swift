import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct ClubMessageRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ClubMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - fetchAll(for:)

    @Test("fetchAll(for:) on empty store returns empty array")
    func fetchAllEmptyStoreReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubMessageRepository(context: container.mainContext)

        let clubID = UUID()
        let results = try repo.fetchAll(for: clubID)
        #expect(results.isEmpty)
    }

    @Test("fetchAll(for:) returns message saved for that club")
    func fetchAllReturnsSavedMessage() throws {
        let container = try makeContainer()
        let repo = ClubMessageRepository(context: container.mainContext)

        let clubID = UUID()
        let message = ClubMessage(
            clubID: clubID,
            senderName: "Alice",
            senderID: "alice-1",
            text: "Hello, garden club!"
        )
        try repo.save(message)

        let results = try repo.fetchAll(for: clubID)
        #expect(results.count == 1)
        #expect(results.first?.senderName == "Alice")
        #expect(results.first?.text == "Hello, garden club!")
    }

    @Test("fetchAll(for:) after delete returns empty array")
    func fetchAllAfterDeleteReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubMessageRepository(context: container.mainContext)

        let clubID = UUID()
        let message = ClubMessage(
            clubID: clubID,
            senderName: "Bob",
            senderID: "bob-1",
            text: "See you at the meetup!"
        )
        try repo.save(message)
        #expect(try repo.fetchAll(for: clubID).count == 1)

        try repo.delete(message)

        let remaining = try repo.fetchAll(for: clubID)
        #expect(remaining.isEmpty)
    }

    @Test("fetchAll(for:) returns messages sorted by timestamp ascending")
    func fetchAllSortedByTimestampAscending() throws {
        let container = try makeContainer()
        let repo = ClubMessageRepository(context: container.mainContext)

        let clubID = UUID()
        let now = Date()

        let first = ClubMessage(
            clubID: clubID,
            senderName: "Alice",
            senderID: "alice-1",
            text: "First message"
        )
        first.timestamp = now.addingTimeInterval(-60) // 1 minute ago

        let second = ClubMessage(
            clubID: clubID,
            senderName: "Bob",
            senderID: "bob-1",
            text: "Second message"
        )
        second.timestamp = now

        try repo.save(first)
        try repo.save(second)

        let results = try repo.fetchAll(for: clubID)
        #expect(results.count == 2)
        #expect(results[0].text == "First message")
        #expect(results[1].text == "Second message")
    }

    @Test("fetchAll(for:) filters to the specified club only")
    func fetchAllFiltersToCorrectClub() throws {
        let container = try makeContainer()
        let repo = ClubMessageRepository(context: container.mainContext)

        let clubA = UUID()
        let clubB = UUID()

        let msgA = ClubMessage(
            clubID: clubA,
            senderName: "Alice",
            senderID: "alice-1",
            text: "Club A message"
        )
        let msgB = ClubMessage(
            clubID: clubB,
            senderName: "Bob",
            senderID: "bob-1",
            text: "Club B message"
        )
        try repo.save(msgA)
        try repo.save(msgB)

        let resultsA = try repo.fetchAll(for: clubA)
        let resultsB = try repo.fetchAll(for: clubB)

        #expect(resultsA.count == 1)
        #expect(resultsA.first?.text == "Club A message")
        #expect(resultsB.count == 1)
        #expect(resultsB.first?.text == "Club B message")
    }
}
