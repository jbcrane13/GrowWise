import Foundation
import GrowWiseModels
import os
import SwiftData

private let logger = Logger(subsystem: "com.growwise", category: "StatsRepository")

@MainActor
public final class StatsRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func getPlantCount(for garden: Garden? = nil) throws -> Int {
        var descriptor = FetchDescriptor<Plant>()

        if let garden {
            let gardenId = garden.id
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
        }

        return try context.fetchCount(descriptor)
    }

    public func getGardenCount() throws -> Int {
        let descriptor = FetchDescriptor<Garden>()
        return try context.fetchCount(descriptor)
    }

    public func getReminderCount(activeOnly: Bool = false) throws -> Int {
        var descriptor = FetchDescriptor<PlantReminder>()

        if activeOnly {
            let currentDate = Date()
            descriptor.predicate = #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate > currentDate
            }
        }

        return try context.fetchCount(descriptor)
    }

    public func getJournalEntryCount(for plant: Plant? = nil) throws -> Int {
        var descriptor = FetchDescriptor<JournalEntry>()

        if let plant, let plantId = plant.id {
            descriptor.predicate = #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        }

        return try context.fetchCount(descriptor)
    }

    public func getPlantDatabaseCount() throws -> Int {
        var descriptor = FetchDescriptor<Plant>()
        descriptor.predicate = #Predicate<Plant> { $0.isUserPlant == false || $0.isUserPlant == nil }
        return try context.fetchCount(descriptor)
    }

    /// Compute gardening stats using predicate-based counting instead of full-table scan.
    public func getGardeningStats() throws -> GardeningStats {
        let totalPlants = try getPlantCount()

        // SwiftData #Predicate has issues comparing optional enum properties in-memory,
        // so fetch all plants and filter. Plant count is bounded by user's garden size.
        let allPlants = try context.fetch(FetchDescriptor<Plant>())
        let healthyPlants = allPlants.count(where: { $0.healthStatus == .healthy })

        let activeReminders = try getReminderCount(activeOnly: true)
        let totalJournalEntries = try getJournalEntryCount()

        return GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: healthyPlants,
            activeReminders: activeReminders,
            totalJournalEntries: totalJournalEntries
        )
    }
}
