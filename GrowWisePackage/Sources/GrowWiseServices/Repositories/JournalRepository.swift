import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class JournalRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>()
        return try context.fetch(descriptor)
    }

    public func add(_ entry: JournalEntry) throws {
        context.insert(entry)
        do {
            try context.save()
        } catch {
            throw JournalRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ entry: JournalEntry) throws {
        context.delete(entry)
        do {
            try context.save()
        } catch {
            throw JournalRepositoryError.saveFailed(error)
        }
    }
}
