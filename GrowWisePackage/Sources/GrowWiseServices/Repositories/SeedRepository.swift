import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class SeedRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Seed] {
        let descriptor = FetchDescriptor<Seed>(sortBy: [SortDescriptor(\.varietyName)])
        return try context.fetch(descriptor)
    }

    public func fetchAll(for garden: Garden) throws -> [Seed] {
        let gardenID = garden.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.garden?.id == gardenID
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetchUnassigned(for garden: Garden) throws -> [Seed] {
        let gardenID = garden.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.garden?.id == gardenID && seed.gardenBed == nil
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetch(for bed: GardenBed) throws -> [Seed] {
        let bedID = bed.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.gardenBed?.id == bedID
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetchByPlantType(_ type: PlantType, garden: Garden? = nil) throws -> [Seed] {
        // SwiftData #Predicate can't capture enum values directly — use rawValue
        let typeRaw = type.rawValue
        if let garden {
            let gardenID = garden.id
            var descriptor = FetchDescriptor<Seed>(
                predicate: #Predicate<Seed> { seed in
                    seed.plantType?.rawValue == typeRaw && seed.garden?.id == gardenID
                },
                sortBy: [SortDescriptor(\.varietyName)]
            )
            descriptor.fetchLimit = 200
            return try context.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<Seed>(
                predicate: #Predicate<Seed> { seed in
                    seed.plantType?.rawValue == typeRaw
                },
                sortBy: [SortDescriptor(\.varietyName)]
            )
            descriptor.fetchLimit = 200
            return try context.fetch(descriptor)
        }
    }

    public func search(query: String) throws -> [Seed] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        var descriptor = FetchDescriptor<Seed>(sortBy: [SortDescriptor(\.varietyName)])
        descriptor.fetchLimit = 200

        let allSeeds = try context.fetch(descriptor)
        let lowercased = trimmed.lowercased()
        return allSeeds.filter { seed in
            seed.varietyName?.lowercased().contains(lowercased) == true ||
                seed.brand?.lowercased().contains(lowercased) == true
        }
    }

    public func add(_ seed: Seed) throws {
        context.insert(seed)
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func update(_ seed: Seed) throws {
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func delete(_ seed: Seed) throws {
        context.delete(seed)
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func assignToBed(_ seed: Seed, bed: GardenBed) throws {
        seed.gardenBed = bed
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func unassign(_ seed: Seed) throws {
        seed.gardenBed = nil
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }
}
