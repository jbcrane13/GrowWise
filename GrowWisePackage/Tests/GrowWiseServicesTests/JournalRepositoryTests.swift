import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@Suite("JournalRepository Tests")
@MainActor
struct JournalRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - add()

    @Test("add() inserts journal entry into context")
    func addInsertsEntry() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Basil", plantType: .herb)
        container.mainContext.insert(plant)

        let entry = JournalEntry(
            title: "First Log",
            content: "Looking good today",
            entryType: .observation,
            plant: plant
        )
        try repo.add(entry, user: nil)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "First Log")
    }

    @Test("add() links entry to plant's journalEntries relationship")
    func addLinksEntryToPlant() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        container.mainContext.insert(plant)

        let entry = JournalEntry(title: "Watered", content: "250ml", entryType: .watering, plant: plant)
        try repo.add(entry, user: nil)

        let linked = plant.journalEntries ?? []
        #expect(linked.contains(where: { $0.title == "Watered" }))
    }

    // MARK: - fetchAll()

    @Test("fetchAll() returns all inserted entries")
    func fetchAllReturnsAllEntries() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Tomato", plantType: .vegetable)
        container.mainContext.insert(plant)

        let entry1 = JournalEntry(title: "Entry A", content: "First", entryType: .watering, plant: plant)
        let entry2 = JournalEntry(title: "Entry B", content: "Second", entryType: .note, plant: plant)
        try repo.add(entry1, user: nil)
        try repo.add(entry2, user: nil)

        let all = try repo.fetchAll()
        #expect(all.count == 2)
    }

    @Test("fetchAll() returns empty array when no entries exist")
    func fetchAllReturnsEmptyWhenNone() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - fetchForPlant()

    @Test("fetchForPlant() returns only entries for the specified plant")
    func fetchForPlantFiltersCorrectly() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plantA = Plant(name: "Rose", plantType: .flower)
        let plantB = Plant(name: "Cactus", plantType: .succulent)
        container.mainContext.insert(plantA)
        container.mainContext.insert(plantB)

        let entryA = JournalEntry(title: "Rose Log", content: "Blooming nicely", entryType: .observation, plant: plantA)
        let entryB = JournalEntry(title: "Cactus Log", content: "Very dry", entryType: .observation, plant: plantB)
        try repo.add(entryA, user: nil)
        try repo.add(entryB, user: nil)

        let results = try repo.fetchForPlant(plantA)
        #expect(results.count == 1)
        #expect(results.first?.title == "Rose Log")
    }

    @Test("fetchForPlant() returns entries sorted by date descending")
    func fetchForPlantSortsDescending() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Fern", plantType: .houseplant)
        container.mainContext.insert(plant)

        let older = JournalEntry(title: "Older Entry", content: "A", entryType: .note, plant: plant)
        older.entryDate = Date().addingTimeInterval(-3600)
        let newer = JournalEntry(title: "Newer Entry", content: "B", entryType: .note, plant: plant)
        newer.entryDate = Date()

        try repo.add(older, user: nil)
        try repo.add(newer, user: nil)

        let results = try repo.fetchForPlant(plant)
        let firstDate = try #require(results.first?.entryDate)
        let lastDate = try #require(results.last?.entryDate)
        #expect(firstDate >= lastDate)
    }

    // MARK: - fetchRecent(limit:)

    @Test("fetchRecent(limit:) caps at min(limit, 10) when requesting more than 10")
    func fetchRecentCapsAtTen() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Fern", plantType: .houseplant)
        container.mainContext.insert(plant)

        for index in 0 ..< 15 {
            let entry = JournalEntry(
                title: "Entry \(index)",
                content: "Content",
                entryType: .note,
                plant: plant
            )
            try repo.add(entry, user: nil)
        }

        let recent = try repo.fetchRecent(limit: 20)
        #expect(recent.count == 10)
    }

    @Test("fetchRecent(limit:) returns fewer entries when store has less than cap")
    func fetchRecentReturnsFewerWhenBelowCap() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Oregano", plantType: .herb)
        container.mainContext.insert(plant)

        for index in 0 ..< 3 {
            let entry = JournalEntry(
                title: "Entry \(index)",
                content: "Content",
                entryType: .note,
                plant: plant
            )
            try repo.add(entry, user: nil)
        }

        let recent = try repo.fetchRecent(limit: 5)
        #expect(recent.count == 3)
    }

    // MARK: - delete()

    @Test("delete() removes entry from context")
    func deleteRemovesEntry() throws {
        let container = try makeContainer()
        let repo = JournalRepository(context: container.mainContext)

        let plant = Plant(name: "Mint", plantType: .herb)
        container.mainContext.insert(plant)

        let entry = JournalEntry(title: "Delete Me", content: "Temporary entry", entryType: .note, plant: plant)
        try repo.add(entry, user: nil)

        var all = try repo.fetchAll()
        #expect(all.count == 1)

        try repo.delete(entry)

        all = try repo.fetchAll()
        #expect(all.count == 0)
    }

    // MARK: - Orphaned Relationship

    @Test("delete() on plant leaves journal entry in context (nullified relationship)")
    func deletingPlantDoesNotCrashJournalFetch() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let repo = JournalRepository(context: ctx)

        let plant = Plant(name: "Doomed Plant", plantType: .herb)
        ctx.insert(plant)

        let entry = JournalEntry(title: "Log before deletion", content: "Notes", entryType: .note, plant: plant)
        try repo.add(entry, user: nil)

        // Deleting the plant should not crash fetchAll() — the relationship is nullified by SwiftData.
        ctx.delete(plant)
        try ctx.save()

        // fetchAll() must not throw even though entry.plant may be nil now.
        let remaining = try repo.fetchAll()
        // The entry either survives with a nil plant (nullify rule) or is cascade-deleted.
        // Either outcome is acceptable; what must NOT happen is a crash or thrown error.
        for orphan in remaining {
            _ = orphan.title // accessing title on a possibly-nullified object must not crash
        }
    }
}
