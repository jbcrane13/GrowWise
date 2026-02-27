import Testing
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("PlantRepository Tests")
@MainActor
struct PlantRepositoryTests {
    @Test("Add and fetch plant")
    func testAddAndFetchPlant() async throws {
        let container = try ModelContainer(for: Plant.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repo = PlantRepository(context: container.mainContext)
        
        let plant = Plant(name: "Test Fern", plantType: .houseplant, difficultyLevel: .beginner, isUserPlant: true)
        try repo.add(plant)
        
        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Fern")
    }
}
