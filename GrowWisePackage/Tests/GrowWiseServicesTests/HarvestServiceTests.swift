import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
struct HarvestServiceTests {
    @Test("logHarvest creates a harvest and links to plant")
    func logHarvest() async throws {
        let dataService = try await DataService.makeForTesting()
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        try dataService.updatePlant(plant)

        let harvest = try dataService.logHarvest(
            quantity: 2.5,
            unit: .pounds,
            plant: plant,
            notes: "Great yield"
        )

        #expect(harvest.quantity == 2.5)
        #expect(harvest.unit == .pounds)
        #expect(harvest.notes == "Great yield")
        #expect(harvest.plant?.id == plant.id)
    }

    @Test("fetchHarvests returns harvests sorted by date descending")
    func fetchHarvestsSorted() async throws {
        let dataService = try await DataService.makeForTesting()
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        try dataService.updatePlant(plant)

        try dataService.logHarvest(quantity: 1, unit: .pieces, plant: plant)
        try dataService.logHarvest(quantity: 2, unit: .pieces, plant: plant)

        let harvests = dataService.fetchHarvests(for: plant)
        #expect(harvests.count == 2)
        // Most recent first
        #expect(harvests.first?.quantity == 2)
    }

    @Test("deleteHarvest removes harvest from context")
    func deleteHarvest() async throws {
        let dataService = try await DataService.makeForTesting()
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        try dataService.updatePlant(plant)

        let harvest = try dataService.logHarvest(quantity: 5, unit: .pieces, plant: plant)
        try dataService.deleteHarvest(harvest)

        let remaining = dataService.fetchHarvests(for: plant)
        #expect(remaining.isEmpty)
    }
}
