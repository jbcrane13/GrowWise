import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct ClubEventRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ClubEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - fetchAll(for:)

    @Test("fetchAll(for:) on empty store returns empty array")
    func fetchAllEmptyStoreReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubEventRepository(context: container.mainContext)

        let clubID = UUID()
        let results = try repo.fetchAll(for: clubID)
        #expect(results.isEmpty)
    }

    @Test("fetchAll(for:) returns event saved for that club")
    func fetchAllReturnsSavedEvent() throws {
        let container = try makeContainer()
        let repo = ClubEventRepository(context: container.mainContext)

        let clubID = UUID()
        let event = ClubEvent(
            clubID: clubID,
            title: "Spring Planting Day",
            startDate: Date().addingTimeInterval(86400),
            createdBy: "alice-1"
        )
        try repo.save(event)

        let results = try repo.fetchAll(for: clubID)
        #expect(results.count == 1)
        #expect(results.first?.title == "Spring Planting Day")
    }

    @Test("fetchAll(for:) after delete returns empty array")
    func fetchAllAfterDeleteReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubEventRepository(context: container.mainContext)

        let clubID = UUID()
        let event = ClubEvent(
            clubID: clubID,
            title: "Pruning Workshop",
            startDate: Date().addingTimeInterval(3600),
            createdBy: "bob-1"
        )
        try repo.save(event)
        #expect(try repo.fetchAll(for: clubID).count == 1)

        try repo.delete(event)

        let remaining = try repo.fetchAll(for: clubID)
        #expect(remaining.isEmpty)
    }

    // MARK: - fetchUpcoming(for:)

    @Test("fetchUpcoming(for:) returns only future events")
    func fetchUpcomingReturnsOnlyFutureEvents() throws {
        let container = try makeContainer()
        let repo = ClubEventRepository(context: container.mainContext)

        let clubID = UUID()

        let past = ClubEvent(
            clubID: clubID,
            title: "Past Meetup",
            startDate: Date().addingTimeInterval(-86400), // yesterday
            createdBy: "alice-1"
        )
        let future = ClubEvent(
            clubID: clubID,
            title: "Future Harvest Fest",
            startDate: Date().addingTimeInterval(86400), // tomorrow
            createdBy: "alice-1"
        )
        try repo.save(past)
        try repo.save(future)

        let upcoming = try repo.fetchUpcoming(for: clubID)
        #expect(upcoming.count == 1)
        #expect(upcoming.first?.title == "Future Harvest Fest")
    }

    @Test("fetchUpcoming(for:) with no future events returns empty array")
    func fetchUpcomingAllPastReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubEventRepository(context: container.mainContext)

        let clubID = UUID()
        let past = ClubEvent(
            clubID: clubID,
            title: "Old Workshop",
            startDate: Date().addingTimeInterval(-3600), // 1 hour ago
            createdBy: "bob-1"
        )
        try repo.save(past)

        let upcoming = try repo.fetchUpcoming(for: clubID)
        #expect(upcoming.isEmpty)
    }
}
