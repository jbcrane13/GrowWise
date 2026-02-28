import SwiftData
import Foundation
import GrowWiseModels

@MainActor
public final class StatsRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func getPlantCount(for garden: Garden? = nil) -> Int {
        var descriptor = FetchDescriptor<Plant>()

        if let garden = garden {
            let gardenId = garden.id
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
        }

        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func getGardenCount() -> Int {
        let descriptor = FetchDescriptor<Garden>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func getReminderCount(activeOnly: Bool = false) -> Int {
        var descriptor = FetchDescriptor<PlantReminder>()

        if activeOnly {
            let currentDate = Date()
            descriptor.predicate = #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate > currentDate
            }
        }

        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func getJournalEntryCount(for plant: Plant? = nil) -> Int {
        var descriptor = FetchDescriptor<JournalEntry>()

        if let plant = plant, let plantId = plant.id {
            descriptor.predicate = #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        }

        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func getPlantDatabaseCount() -> Int {
        var descriptor = FetchDescriptor<Plant>()
        descriptor.predicate = #Predicate<Plant> { $0.isUserPlant == false || $0.isUserPlant == nil }
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Compute gardening stats using predicate-based counting instead of full-table scan.
    public func getGardeningStats() -> GardeningStats {
        let totalPlants = getPlantCount()

        // Use fetchCount with a predicate for healthy plants instead of loading all plants.
        // SwiftData #Predicate requires the full enum type for comparison.
        let healthyStatus = HealthStatus.healthy
        var healthyDescriptor = FetchDescriptor<Plant>()
        healthyDescriptor.predicate = #Predicate<Plant> { plant in
            plant.healthStatus == healthyStatus
        }
        let healthyPlants = (try? context.fetchCount(healthyDescriptor)) ?? 0

        let activeReminders = getReminderCount(activeOnly: true)
        let totalJournalEntries = getJournalEntryCount()

        return GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: healthyPlants,
            activeReminders: activeReminders,
            totalJournalEntries: totalJournalEntries
        )
    }
}
