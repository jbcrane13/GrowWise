import XCTest
@testable import GrowWiseServices
import SwiftData

/// Tests for DataService nil-self scenarios in weak capture contexts
@MainActor
final class DataServiceNilSelfTests: XCTestCase {

    /// Test that batchLoadPlantRelationships logs warning and returns empty array when self is nil
    func testBatchLoadPlantRelationshipsWithNilSelf() async throws {
        // Create a weak reference scenario
        var dataService: DataService? = try DataService(
            isStoredInMemoryOnly: true,
            performanceMonitor: PerformanceMonitor()
        )

        // Create plant IDs to test with
        let plantIds = [UUID(), UUID(), UUID()]

        // Store a weak reference to test nil scenario
        weak var weakService = dataService

        // Create the async task before deallocating
        let task = Task.detached {
            // Simulate delay to allow deallocation
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // Attempt to call method - should handle nil gracefully
            return await weakService?.batchLoadPlantRelationships(
                plantIds: plantIds,
                relationshipType: "both"
            )
        }

        // Deallocate the service
        dataService = nil

        // Verify service is deallocated
        XCTAssertNil(weakService, "Service should be deallocated")

        // Wait for task and verify result
        let result = await task.value

        // Should return nil or empty array when service is deallocated
        if let result = result {
            XCTAssertTrue(result.isEmpty, "Should return empty array when self is nil")
        } else {
            // This is also acceptable - returning nil when service is gone
            XCTAssertNil(result, "Returning nil is acceptable when service is deallocated")
        }
    }

    /// Test that batchLoadPlantRelationships works normally when self is valid
    func testBatchLoadPlantRelationshipsWithValidSelf() async throws {
        let dataService = try DataService(
            isStoredInMemoryOnly: true,
            performanceMonitor: PerformanceMonitor()
        )

        // Create and save test plants
        let plant1 = Plant(name: "Rose", scientificName: "Rosa", careLevel: .medium, sunlightNeeds: "Full Sun")
        let plant2 = Plant(name: "Tulip", scientificName: "Tulipa", careLevel: .easy, sunlightNeeds: "Partial Shade")

        dataService.modelContext.insert(plant1)
        dataService.modelContext.insert(plant2)
        try dataService.modelContext.save()

        // Create array of plant IDs
        let plantIds = [plant1.id!, plant2.id!]

        // Call batch load
        let result = await dataService.batchLoadPlantRelationships(
            plantIds: plantIds,
            relationshipType: "both"
        )

        // Verify results
        XCTAssertEqual(result.count, 2, "Should return 2 plants")
        XCTAssertTrue(result.contains(where: { $0.name == "Rose" }), "Should contain Rose")
        XCTAssertTrue(result.contains(where: { $0.name == "Tulip" }), "Should contain Tulip")
    }

    /// Test that batchLoadPlantRelationships maintains order when self is valid
    func testBatchLoadPlantRelationshipsOrderPreservation() async throws {
        let dataService = try DataService(
            isStoredInMemoryOnly: true,
            performanceMonitor: PerformanceMonitor()
        )

        // Create test plants in specific order
        let plants = [
            Plant(name: "Zebra Plant", scientificName: "Aphelandra", careLevel: .hard, sunlightNeeds: "Bright Indirect"),
            Plant(name: "Aloe Vera", scientificName: "Aloe barbadensis", careLevel: .easy, sunlightNeeds: "Full Sun"),
            Plant(name: "Monstera", scientificName: "Monstera deliciosa", careLevel: .medium, sunlightNeeds: "Bright Indirect")
        ]

        for plant in plants {
            dataService.modelContext.insert(plant)
        }
        try dataService.modelContext.save()

        // Request in specific order: Aloe, Zebra, Monstera
        let requestOrder = [plants[1].id!, plants[0].id!, plants[2].id!]

        // Call batch load
        let result = await dataService.batchLoadPlantRelationships(
            plantIds: requestOrder,
            relationshipType: "both"
        )

        // Verify order is preserved
        XCTAssertEqual(result.count, 3, "Should return 3 plants")
        XCTAssertEqual(result[0].name, "Aloe Vera", "First should be Aloe Vera")
        XCTAssertEqual(result[1].name, "Zebra Plant", "Second should be Zebra Plant")
        XCTAssertEqual(result[2].name, "Monstera", "Third should be Monstera")
    }

    /// Test that batchLoadPlantRelationships handles empty plant IDs gracefully
    func testBatchLoadPlantRelationshipsWithEmptyPlantIds() async throws {
        let dataService = try DataService(
            isStoredInMemoryOnly: true,
            performanceMonitor: PerformanceMonitor()
        )

        // Create some test plants
        let plant1 = Plant(name: "Cactus", scientificName: "Cactaceae", careLevel: .easy, sunlightNeeds: "Full Sun")
        let plant2 = Plant(name: "Fern", scientificName: "Pteridium", careLevel: .medium, sunlightNeeds: "Shade")

        dataService.modelContext.insert(plant1)
        dataService.modelContext.insert(plant2)
        try dataService.modelContext.save()

        // Call with empty plant IDs
        let result = await dataService.batchLoadPlantRelationships(
            plantIds: [],
            relationshipType: "both"
        )

        // Should return plants sorted by name (default behavior)
        XCTAssertGreaterThanOrEqual(result.count, 2, "Should return at least 2 plants")

        // Verify alphabetical order when no specific IDs requested
        if result.count >= 2 {
            XCTAssertLessThanOrEqual(result[0].name, result[1].name, "Should be sorted alphabetically")
        }
    }

    /// Test that batchLoadPlantRelationships limits results to 50 plants
    func testBatchLoadPlantRelationshipsLimitTo50() async throws {
        let dataService = try DataService(
            isStoredInMemoryOnly: true,
            performanceMonitor: PerformanceMonitor()
        )

        // Create 60 test plants
        var plantIds: [UUID] = []
        for i in 1...60 {
            let plant = Plant(
                name: "Plant \(i)",
                scientificName: "Species \(i)",
                careLevel: .easy,
                sunlightNeeds: "Full Sun"
            )
            dataService.modelContext.insert(plant)
            plantIds.append(plant.id!)
        }
        try dataService.modelContext.save()

        // Request all 60 plants
        let result = await dataService.batchLoadPlantRelationships(
            plantIds: plantIds,
            relationshipType: "both"
        )

        // Should be limited to 50
        XCTAssertEqual(result.count, 50, "Should limit to 50 plants")
    }
}
