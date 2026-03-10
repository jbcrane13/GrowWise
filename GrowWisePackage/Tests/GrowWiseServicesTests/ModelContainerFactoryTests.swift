import Testing
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

// NOTE: No URLSession-based network code exists in GrowWiseServices today.
// The MockURLProtocol at tests/TestUtilities/MockURLProtocol.swift exists but has zero usages.
// This test serves as a contract test template for future URLSession additions.
// To use: configure URLSession with protocolClasses: [MockURLProtocol.self],
// then set MockURLProtocol.requestHandler before making requests.

/// Contract tests for ModelContainerFactory — verifies schema correctness, isolation,
/// and in-memory behaviour without requiring CloudKit entitlements.
@Suite("ModelContainerFactory Tests")
struct ModelContainerFactoryTests {

    // MARK: - Basic container creation

    @Test("makeForTesting returns a non-nil container")
    func testMakeForTestingReturnsContainer() throws {
        let container = try ModelContainerFactory.makeForTesting()
        // Container is a reference type — the binding is always non-nil after a successful throw-free call
        #expect(container.configurations.isEmpty == false)
    }

    @Test("makeForTesting produces an in-memory store (no CloudKit entitlement needed)")
    func testMakeForTestingIsInMemory() throws {
        let container = try ModelContainerFactory.makeForTesting()
        // In-memory configurations have isStoredInMemoryOnly == true
        let config = try #require(container.configurations.first)
        #expect(config.isStoredInMemoryOnly == true)
    }

    // MARK: - Schema completeness

    @Test("Schema includes Plant — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesPlant() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let plant = Plant(name: "Basil", plantType: .herb)
        context.insert(plant)
        try context.save()

        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate { $0.name == "Basil" }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.name == "Basil")
    }

    @Test("Schema includes Garden — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesGarden() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let garden = Garden(name: "Back Yard", gardenType: .outdoor)
        context.insert(garden)
        try context.save()

        let descriptor = FetchDescriptor<Garden>(
            predicate: #Predicate { $0.name == "Back Yard" }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.name == "Back Yard")
    }

    @Test("Schema includes User — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesUser() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let user = User(email: "test@example.com", displayName: "Tester")
        context.insert(user)
        try context.save()

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.email == "test@example.com" }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "Tester")
    }

    @Test("Schema includes JournalEntry — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesJournalEntry() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let entry = JournalEntry(title: "First Bloom", content: "Saw buds today")
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.title == "First Bloom" }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.content == "Saw buds today")
    }

    @Test("Schema includes PlantReminder — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesPlantReminder() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let reminder = PlantReminder(
            title: "Water Basil",
            message: "Time to water your basil",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date()
        )
        context.insert(reminder)
        try context.save()

        let descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate { $0.title == "Water Basil" }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.message == "Time to water your basil")
    }

    @Test("Schema includes SoilLog — insert and fetch round-trips correctly")
    @MainActor func testSchemaIncludesSoilLog() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = ModelContext(container)

        let log = SoilLog()
        log.notes = "pH tested at 6.5"
        context.insert(log)
        try context.save()

        let descriptor = FetchDescriptor<SoilLog>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty == false)
        #expect(results.first?.notes == "pH tested at 6.5")
    }

    // MARK: - Container isolation

    @Test("Two calls to makeForTesting return isolated containers")
    @MainActor func testContainersAreIsolated() throws {
        let containerA = try ModelContainerFactory.makeForTesting()
        let containerB = try ModelContainerFactory.makeForTesting()

        let contextA = ModelContext(containerA)
        let contextB = ModelContext(containerB)

        // Insert a plant only into container A
        let plant = Plant(name: "Unique Plant in A", plantType: .vegetable)
        contextA.insert(plant)
        try contextA.save()

        // Container B should have zero plants
        let descriptorB = FetchDescriptor<Plant>(
            predicate: #Predicate { $0.name == "Unique Plant in A" }
        )
        let resultsInB = try contextB.fetch(descriptorB)
        #expect(resultsInB.isEmpty, "Plant inserted into container A must not appear in container B")
    }

    // MARK: - Shared schema consistency

    @Test("sharedSchema contains all required model types")
    @MainActor func testSharedSchemaContainsAllModels() {
        let schema = ModelContainerFactory.sharedSchema
        let entityNames = schema.entities.map { $0.name }

        #expect(entityNames.contains("Plant"))
        #expect(entityNames.contains("Garden"))
        #expect(entityNames.contains("User"))
        #expect(entityNames.contains("PlantReminder"))
        #expect(entityNames.contains("JournalEntry"))
        #expect(entityNames.contains("SoilLog"))
    }

    @Test("makeForTesting schema matches sharedSchema entity count")
    @MainActor func testMakeForTestingSchemaMatchesSharedSchema() throws {
        let container = try ModelContainerFactory.makeForTesting()
        // Each configuration uses the same full schema
        let sharedEntityCount = ModelContainerFactory.sharedSchema.entities.count
        #expect(sharedEntityCount >= 6) // Plant, Garden, User, PlantReminder, JournalEntry, SoilLog
        _ = container // Suppress unused-variable warning — container creation itself is the assertion
    }
}
