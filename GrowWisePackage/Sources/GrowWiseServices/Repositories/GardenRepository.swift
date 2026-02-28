import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class GardenRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Garden] {
        let descriptor = FetchDescriptor<Garden>()
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

    public func delete(_ garden: Garden) throws {
        context.delete(garden)
        do {
            try context.save()
        } catch {
            throw GardenError.saveFailed(error)
        }
    }
}
