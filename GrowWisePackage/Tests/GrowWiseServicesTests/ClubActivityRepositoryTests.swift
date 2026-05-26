import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct ClubActivityRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ClubActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - fetchAll(for:)

    @Test("fetchAll(for:) on empty store returns empty array")
    func fetchAllEmptyStoreReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubActivityRepository(context: container.mainContext)

        let clubID = UUID()
        let results = try repo.fetchAll(for: clubID)
        #expect(results.isEmpty)
    }

    @Test("fetchAll(for:) returns activity saved for that club")
    func fetchAllReturnsSavedActivity() throws {
        let container = try makeContainer()
        let repo = ClubActivityRepository(context: container.mainContext)

        let clubID = UUID()
        let activity = ClubActivity(
            clubID: clubID,
            memberName: "Alice",
            memberID: "alice-1",
            activityType: "watered",
            description: "Watered the tomatoes"
        )
        try repo.save(activity)

        let results = try repo.fetchAll(for: clubID)
        #expect(results.count == 1)
        #expect(results.first?.memberName == "Alice")
        #expect(results.first?.activityType == "watered")
    }

    @Test("fetchAll(for:) after delete returns empty array")
    func fetchAllAfterDeleteReturnsEmpty() throws {
        let container = try makeContainer()
        let repo = ClubActivityRepository(context: container.mainContext)

        let clubID = UUID()
        let activity = ClubActivity(
            clubID: clubID,
            memberName: "Bob",
            memberID: "bob-1",
            activityType: "planted",
            description: "Planted seedlings"
        )
        try repo.save(activity)
        #expect(try repo.fetchAll(for: clubID).count == 1)

        try repo.delete(activity)

        let remaining = try repo.fetchAll(for: clubID)
        #expect(remaining.isEmpty)
    }

    @Test("fetchAll(for:) filters to the specified club only")
    func fetchAllFiltersToCorrectClub() throws {
        let container = try makeContainer()
        let repo = ClubActivityRepository(context: container.mainContext)

        let clubA = UUID()
        let clubB = UUID()

        let activityA = ClubActivity(
            clubID: clubA,
            memberName: "Alice",
            memberID: "alice-1",
            activityType: "harvested",
            description: "Harvested beans"
        )
        let activityB = ClubActivity(
            clubID: clubB,
            memberName: "Bob",
            memberID: "bob-1",
            activityType: "watered",
            description: "Watered herbs"
        )
        try repo.save(activityA)
        try repo.save(activityB)

        let resultsA = try repo.fetchAll(for: clubA)
        let resultsB = try repo.fetchAll(for: clubB)

        #expect(resultsA.count == 1)
        #expect(resultsA.first?.memberName == "Alice")
        #expect(resultsB.count == 1)
        #expect(resultsB.first?.memberName == "Bob")
    }
}
