import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ReminderRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [PlantReminder] {
        let descriptor = FetchDescriptor<PlantReminder>()
        return try context.fetch(descriptor)
    }

    public func add(_ reminder: PlantReminder) throws {
        context.insert(reminder)
        do {
            try context.save()
        } catch {
            throw ReminderRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ reminder: PlantReminder) throws {
        context.delete(reminder)
        do {
            try context.save()
        } catch {
            throw ReminderRepositoryError.saveFailed(error)
        }
    }
}
