import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct UserRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: User.self, ReminderSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - getCurrent

    @Test("getCurrent() returns nil on empty store")
    func getCurrentReturnsNilOnEmptyStore() throws {
        let container = try makeContainer()
        let repo = UserRepository(context: container.mainContext)

        let result = repo.getCurrent()
        #expect(result == nil)
    }

    @Test("getCurrent() returns the inserted user")
    func getCurrentReturnsInsertedUser() throws {
        let container = try makeContainer()
        let repo = UserRepository(context: container.mainContext)

        let user = User(email: "test@example.com", displayName: "Test User")
        try repo.add(user)

        let result = repo.getCurrent()
        #expect(result?.email == "test@example.com")
        #expect(result?.displayName == "Test User")
    }

    // MARK: - update

    @Test("update() persists field changes and advances lastModified")
    func updatePersistsFieldChanges() throws {
        let container = try makeContainer()
        let repo = UserRepository(context: container.mainContext)

        let user = User(email: "a@example.com", displayName: "Original Name")
        try repo.add(user)

        let before = Date()
        user.displayName = "Updated Name"
        try repo.update(user)

        let fetched = try #require(repo.getCurrent())
        #expect(fetched.displayName == "Updated Name")
        #expect(fetched.lastModified >= before)
    }

    // MARK: - delete

    @Test("delete() removes user so getCurrent() returns nil")
    func deleteRemovesUser() throws {
        let container = try makeContainer()
        let repo = UserRepository(context: container.mainContext)

        let user = User(email: "b@example.com", displayName: "To Be Deleted")
        try repo.add(user)
        #expect(repo.getCurrent() != nil)

        try repo.delete(user)
        #expect(repo.getCurrent() == nil)
    }

    // MARK: - ordering

    @Test("getCurrent() with multiple users returns the one with the most-recent lastLoginDate")
    func getCurrentReturnsMostRecentLogin() throws {
        let container = try makeContainer()
        let repo = UserRepository(context: container.mainContext)

        let older = User(email: "older@example.com", displayName: "Older User")
        older.lastLoginDate = Date().addingTimeInterval(-3600) // 1 hour ago
        try repo.add(older)

        let newer = User(email: "newer@example.com", displayName: "Newer User")
        newer.lastLoginDate = Date()
        try repo.add(newer)

        let result = repo.getCurrent()
        #expect(result?.email == "newer@example.com")
    }
}
