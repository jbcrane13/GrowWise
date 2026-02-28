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

    public func fetchForPlant(_ plant: Plant, offset: Int = 0, limit: Int = 20) throws -> [JournalEntry] {
        guard let plantId = plant.id else { return [] }

        var descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        )
        descriptor.sortBy = [SortDescriptor<JournalEntry>(\.entryDate, order: .reverse)]
        descriptor.fetchLimit = min(limit, 30)
        descriptor.fetchOffset = offset

        return try context.fetch(descriptor)
    }

    public func fetchRecent(limit: Int = 10) throws -> [JournalEntry] {
        let safeLimit = min(limit, 10)

        var descriptor = FetchDescriptor<JournalEntry>()
        descriptor.sortBy = [SortDescriptor<JournalEntry>(\.entryDate, order: .reverse)]
        descriptor.fetchLimit = safeLimit

        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(
        title: String,
        content: String,
        type: JournalEntryType,
        plant: Plant,
        user: User?
    ) throws -> JournalEntry {
        let entry = JournalEntry(title: title, content: content, entryType: type, plant: plant)

        if let user {
            entry.user = user
            user.journalEntries = (user.journalEntries ?? []) + [entry]
        }

        plant.journalEntries = (plant.journalEntries ?? []) + [entry]
        context.insert(entry)
        try context.save()
        return entry
    }

    public func add(_ entry: JournalEntry, user: User?) throws {
        if let user {
            entry.user = user
            user.journalEntries = (user.journalEntries ?? []) + [entry]
        }

        if let plant = entry.plant {
            plant.journalEntries = (plant.journalEntries ?? []) + [entry]
        }

        context.insert(entry)
        try context.save()
    }

    public func delete(_ entry: JournalEntry) {
        context.delete(entry)
        try? context.save()
    }
}
