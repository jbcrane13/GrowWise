import Testing
import Foundation
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Tests for DataService batchLoadPlantRelationships behaviour
@Suite("DataService Batch Load Tests")
@MainActor
struct DataServiceBatchLoadTests {

    // MARK: - Helpers

    private func makeService() throws -> DataService {
        try DataService.makeForTesting()
    }

    /// Seeds a user and garden, returning both.
    private func seedUserAndGarden(in service: DataService) throws -> (user: User, garden: Garden) {
        let user = try service.createUser(
            email: "batch@growwise.test",
            displayName: "Batch Tester",
            skillLevel: .intermediate
        )
        let garden = try service.createGarden(name: "Batch Garden", type: .outdoor, isIndoor: false)
        return (user, garden)
    }

    // MARK: - Tests

    @Test("batchLoadPlantRelationships works normally when self is valid")
    func testBatchLoadPlantRelationshipsWithValidSelf() async throws {
        let service = try makeService()
        let (_, garden) = try seedUserAndGarden(in: service)

        let plant1 = try service.createPlant(name: "Rose", type: .flower, garden: garden)
        let plant2 = try service.createPlant(name: "Tulip", type: .flower, garden: garden)

        guard let id1 = plant1.id, let id2 = plant2.id else {
            Issue.record("Plants should have valid IDs")
            return
        }

        let result = await service.batchLoadPlantRelationships(plantIds: [id1, id2])

        #expect(result.count == 2)
        let names = Set(result.compactMap { $0.name })
        #expect(names.contains("Rose"))
        #expect(names.contains("Tulip"))
    }

    @Test("batchLoadPlantRelationships maintains order matching input IDs")
    func testBatchLoadPlantRelationshipsOrderPreservation() async throws {
        let service = try makeService()
        let (_, garden) = try seedUserAndGarden(in: service)

        let zebra = try service.createPlant(name: "Zebra Plant", type: .houseplant, garden: garden)
        let aloe = try service.createPlant(name: "Aloe Vera", type: .succulent, garden: garden)
        let monstera = try service.createPlant(name: "Monstera", type: .houseplant, garden: garden)

        guard let zebraId = zebra.id, let aloeId = aloe.id, let monsteraId = monstera.id else {
            Issue.record("Plants should have valid IDs")
            return
        }

        // Request in specific order: Aloe, Zebra, Monstera
        let result = await service.batchLoadPlantRelationships(
            plantIds: [aloeId, zebraId, monsteraId]
        )

        #expect(result.count == 3)
        #expect(result[0].name == "Aloe Vera")
        #expect(result[1].name == "Zebra Plant")
        #expect(result[2].name == "Monstera")
    }

    @Test("batchLoadPlantRelationships handles empty plant IDs gracefully")
    func testBatchLoadPlantRelationshipsWithEmptyPlantIds() async throws {
        let service = try makeService()
        let (_, garden) = try seedUserAndGarden(in: service)

        let _ = try service.createPlant(name: "Cactus", type: .succulent, garden: garden)
        let _ = try service.createPlant(name: "Fern", type: .houseplant, garden: garden)

        let result = await service.batchLoadPlantRelationships(plantIds: [])

        // Should return plants sorted by name (default behavior)
        #expect(result.count >= 2)
    }
}
