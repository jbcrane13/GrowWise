import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class GardenRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(offset: Int = 0, limit: Int = 20) throws -> [Garden] {
        let clampedOffset = max(0, offset)
        let clampedLimit = max(1, min(limit, 50))

        var descriptor = FetchDescriptor<Garden>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = clampedLimit
        descriptor.fetchOffset = clampedOffset

        return try context.fetch(descriptor)
    }

    public func add(_ garden: Garden) throws {
        context.insert(garden)
        do {
            try context.save()
        } catch {
            throw GardenError.saveFailed(error)
        }
    }

    @discardableResult
    public func create(
        name: String,
        type: GardenType,
        isIndoor: Bool,
        user: User?,
        spaceSize: SpaceSize = .small
    ) throws -> Garden {
        let garden = Garden(name: name, gardenType: type, isIndoor: isIndoor)
        garden.spaceAvailable = spaceSize

        if let user {
            garden.user = user
            user.gardens = (user.gardens ?? []) + [garden]
        }

        context.insert(garden)
        try context.save()
        return garden
    }

    public func update(_ garden: Garden) throws {
        garden.lastModified = Date()
        do {
            try context.save()
        } catch {
            throw GardenError.saveFailed(error)
        }
    }

    public func delete(_ garden: Garden) throws {
        context.delete(garden)
        do {
            try context.save()
        } catch {
            throw GardenError.saveFailed(error)
        }
    }
}
