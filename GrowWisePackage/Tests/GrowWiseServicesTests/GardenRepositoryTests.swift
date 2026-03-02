import Foundation
import Testing
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("GardenRepository Tests")
@MainActor
struct GardenRepositoryTests {
    @Test("update() sets lastModified date")
    func updateSetsLastModifiedDate() async throws {
        let container = try ModelContainer(
            for: Garden.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "Test Garden", gardenType: .outdoor, isIndoor: false)
        try repo.add(garden)

        let before = Date()
        try repo.update(garden)

        let lastModified = try #require(garden.lastModified)
        #expect(lastModified >= before)
    }

    @Test("update() does not throw on valid context")
    func updateDoesNotThrowOnValidContext() async throws {
        let container = try ModelContainer(
            for: Garden.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "No Throw Garden", gardenType: .indoor, isIndoor: true)
        try repo.add(garden)

        #expect(throws: Never.self) {
            try repo.update(garden)
        }
    }

    @Test("update() preserves other garden properties")
    func updatePreservesOtherGardenProperties() async throws {
        let container = try ModelContainer(
            for: Garden.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = GardenRepository(context: container.mainContext)

        let garden = Garden(name: "Herb Garden", gardenType: .container, isIndoor: true)
        try repo.add(garden)

        try repo.update(garden)

        #expect(garden.name == "Herb Garden")
        #expect(garden.gardenType == .container)
        #expect(garden.isIndoor == true)
    }
}
