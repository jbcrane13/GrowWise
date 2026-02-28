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
