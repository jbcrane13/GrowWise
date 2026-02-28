import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class PlantRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }

    public func add(_ plant: Plant) throws {
        context.insert(plant)
        do {
            try context.save()
        } catch {
            throw PlantError.saveFailed(error)
        }
    }

    @discardableResult
    public func create(
        name: String,
        type: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        garden: Garden? = nil
    ) throws -> Plant {
        let plant = Plant(name: name, plantType: type, difficultyLevel: difficultyLevel)

        if let garden {
            plant.garden = garden
            garden.plants = (garden.plants ?? []) + [plant]
        }

        context.insert(plant)
        try context.save()
        return plant
    }

    public func delete(_ plant: Plant) throws {
        context.delete(plant)
        do {
            try context.save()
        } catch {
            throw PlantError.saveFailed(error)
        }
    }

    public func update(_ plant: Plant) throws {
        try context.save()
    }

    public func fetchPaginated(for garden: Garden? = nil, offset: Int = 0, limit: Int = 20) throws -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        if let garden {
            let gardenId = garden.id
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
        }

        return try context.fetch(descriptor)
    }

    public func fetchDatabasePage(offset: Int, limit: Int) throws -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.garden == nil || plant.garden?.user == nil
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        return try context.fetch(descriptor)
    }

    public func search(query: String, limit: Int = 20) throws -> [Plant] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return [] }

        let clampedLimit = max(1, min(limit, 50))

        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) {
            var descriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.fetchLimit = clampedLimit
            descriptor.predicate = #Predicate<Plant> { plant in
                (plant.name?.localizedStandardContains(query) ?? false) ||
                    (plant.scientificName?.localizedStandardContains(query) ?? false)
            }
            return try context.fetch(descriptor)
        }

        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 200 // Reasonable upper bound for search

        let allPlants = try context.fetch(descriptor)
        let lowercasedQuery = query.lowercased()
        let result = allPlants.filter { plant in
            plant.name?.lowercased().contains(lowercasedQuery) == true ||
                plant.scientificName?.lowercased().contains(lowercasedQuery) == true
        }.prefix(clampedLimit)

        return Array(result)
    }

    public func filter(
        byType type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil,
        offset: Int = 0,
        limit: Int = 20
    ) throws -> [Plant] {
        let noFilters = (type == nil && difficultyLevel == nil && sunlightRequirement == nil)

        if noFilters {
            var descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
            descriptor.fetchLimit = min(limit, 50)
            descriptor.fetchOffset = offset
            return try context.fetch(descriptor)
        }

        let predicate: Predicate<Plant>

        switch (type, difficultyLevel, sunlightRequirement) {
        case let (t?, d?, s?):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.difficultyLevel == d && plant.sunlightRequirement == s
            }
        case (let t?, let d?, nil):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.difficultyLevel == d
            }
        case (let t?, nil, let s?):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.sunlightRequirement == s
            }
        case (nil, let d?, let s?):
            predicate = #Predicate<Plant> { plant in
                plant.difficultyLevel == d && plant.sunlightRequirement == s
            }
        case (let t?, nil, nil):
            predicate = #Predicate<Plant> { plant in plant.plantType == t }
        case (nil, let d?, nil):
            predicate = #Predicate<Plant> { plant in plant.difficultyLevel == d }
        case (nil, nil, let s?):
            predicate = #Predicate<Plant> { plant in plant.sunlightRequirement == s }
        default:
            predicate = #Predicate<Plant> { _ in true }
        }

        var descriptor = FetchDescriptor<Plant>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        return try context.fetch(descriptor)
    }
}
