import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ReminderRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [PlantReminder] {
        let descriptor = FetchDescriptor<PlantReminder>()
        return try context.fetch(descriptor)
    }

    public func fetchActive(limit: Int = 50) throws -> [PlantReminder] {
        var descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        descriptor.fetchLimit = limit

        return try context.fetch(descriptor)
    }

    public func fetchOverdue() throws -> [PlantReminder] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate < startOfToday
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        return try context.fetch(descriptor)
    }

    public func fetchUpcoming(days: Int = 7, offset: Int = 0, limit: Int = 50) throws -> [PlantReminder] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now

        var descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate { reminder in
                reminder.isEnabled == true &&
                    reminder.nextDueDate > now &&
                    reminder.nextDueDate <= futureDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        dueDate: Date,
        plant: Plant,
        user: User?
    ) throws -> PlantReminder {
        let reminder = PlantReminder(
            title: title,
            message: message,
            reminderType: type,
            frequency: frequency,
            nextDueDate: dueDate,
            plant: plant
        )

        if let user {
            reminder.user = user
            user.reminders = (user.reminders ?? []) + [reminder]
        }

        plant.reminders = (plant.reminders ?? []) + [reminder]
        context.insert(reminder)
        try context.save()
        return reminder
    }

    public func complete(_ reminder: PlantReminder) throws {
        reminder.markCompleted()
        try context.save()
    }

    public func add(_ reminder: PlantReminder) throws {
        context.insert(reminder)
        do {
            try context.save()
        } catch {
            throw ReminderRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ reminder: PlantReminder) throws {
        context.delete(reminder)
        do {
            try context.save()
        } catch {
            throw ReminderRepositoryError.saveFailed(error)
        }
    }
}
