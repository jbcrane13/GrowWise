import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class UserRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [User] {
        let descriptor = FetchDescriptor<User>()
        return try context.fetch(descriptor)
    }

    public func getCurrent() -> User? {
        var descriptor = FetchDescriptor<User>(
            sortBy: [SortDescriptor(\.lastLoginDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    public func create(email: String, displayName: String, skillLevel: GardeningSkillLevel) throws -> User {
        let user = User(email: email, displayName: displayName, skillLevel: skillLevel)
        context.insert(user)
        try context.save()
        return user
    }

    public func update(_ user: User) throws {
        user.lastModified = Date()
        try context.save()
    }

    public func add(_ user: User) throws {
        context.insert(user)
        do {
            try context.save()
        } catch {
            throw UserRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ user: User) throws {
        context.delete(user)
        do {
            try context.save()
        } catch {
            throw UserRepositoryError.saveFailed(error)
        }
    }
}
