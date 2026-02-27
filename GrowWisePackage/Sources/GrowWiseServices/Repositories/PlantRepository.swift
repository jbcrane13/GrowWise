import SwiftData
import Foundation
import GrowWiseModels

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
    
    public func delete(_ plant: Plant) throws {
        context.delete(plant)
        do {
            try context.save()
        } catch {
            throw PlantError.saveFailed(error)
        }
    }
}
