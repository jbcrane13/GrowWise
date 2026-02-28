import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class StatsRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func getPlantCount(for garden: Garden? = nil) -> Int {
        var descriptor = FetchDescriptor<Plant>()

        if let garden {
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

        if let plant, let plantId = plant.id {
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
}
