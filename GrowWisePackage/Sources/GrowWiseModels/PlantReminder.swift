import Foundation
import SwiftData

@Model
public final class PlantReminder {
    public var id: UUID
    public var title: String
    public var message: String
    public var reminderType: ReminderType
    public var frequency: ReminderFrequency
    
    // Scheduling
    public var nextDueDate: Date
    public var lastCompletedDate: Date?
    public var isEnabled: Bool
    public var isRecurring: Bool
    
    // Relationships
    public var plant: Plant?
    public var user: User?
    
    // Notification settings
    public var notificationIdentifier: String?
    public var snoozeCount: Int
    public var maxSnoozeCount: Int
    
    // Metadata
    public var createdDate: Date
    public var lastModified: Date
    
    public init(
        title: String,
        message: String,
        reminderType: ReminderType,
        frequency: ReminderFrequency,
        nextDueDate: Date,
        plant: Plant? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.reminderType = reminderType
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.plant = plant
        self.isEnabled = true
        self.isRecurring = true
        self.snoozeCount = 0
        self.maxSnoozeCount = 3
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    // Calculate next due date based on frequency
    public func calculateNextDueDate(from completedDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: completedDate) ?? completedDate
        case .everyOtherDay:
            return calendar.date(byAdding: .day, value: 2, to: completedDate) ?? completedDate
        case .twiceWeekly:
            return calendar.date(byAdding: .day, value: 3, to: completedDate) ?? completedDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: completedDate) ?? completedDate
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: completedDate) ?? completedDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: completedDate) ?? completedDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: completedDate) ?? completedDate
        case .seasonally:
            return calendar.date(byAdding: .month, value: 6, to: completedDate) ?? completedDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: completedDate) ?? completedDate
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: completedDate) ?? completedDate
        case .once:
            return completedDate // One-time reminder
        }
    }
    
    public func markCompleted() {
        lastCompletedDate = Date()
        snoozeCount = 0
        
        if isRecurring {
            nextDueDate = calculateNextDueDate()
        } else {
            isEnabled = false
        }
        
        lastModified = Date()
    }
    
    public func snooze(for duration: SnoozeDuration = .oneHour) {
        guard snoozeCount < maxSnoozeCount else { return }
        
        let calendar = Calendar.current
        let snoozeDate: Date
        
        switch duration {
        case .fifteenMinutes:
            snoozeDate = calendar.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        case .thirtyMinutes:
            snoozeDate = calendar.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        case .oneHour:
            snoozeDate = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        case .twoHours:
            snoozeDate = calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        case .tomorrow:
            snoozeDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        
        nextDueDate = snoozeDate
        snoozeCount += 1
        lastModified = Date()
    }
}

// MARK: - Supporting Enums

public enum ReminderType: String, CaseIterable, Codable, Sendable {
    case watering
    case fertilizing
    case pruning
    case repotting
    case harvest
    case planting
    case inspection
    case pestControl
    case soilTest
    case mulching
    case custom
    
    public var displayName: String {
        switch self {
        case .watering: return "Watering"
        case .fertilizing: return "Fertilizing"
        case .pruning: return "Pruning"
        case .repotting: return "Repotting"
        case .harvest: return "Harvest"
        case .planting: return "Planting"
        case .inspection: return "Health Check"
        case .pestControl: return "Pest Control"
        case .soilTest: return "Soil Test"
        case .mulching: return "Mulching"
        case .custom: return "Custom"
        }
    }
    
    public var defaultMessage: String {
        switch self {
        case .watering: return "Time to water your plant!"
        case .fertilizing: return "Your plant needs fertilizing"
        case .pruning: return "Check if your plant needs pruning"
        case .repotting: return "Consider repotting your plant"
        case .harvest: return "Your plant is ready for harvest!"
        case .planting: return "Time to plant your seeds"
        case .inspection: return "Check your plant's health"
        case .pestControl: return "Inspect for pests and diseases"
        case .soilTest: return "Test your soil conditions"
        case .mulching: return "Add mulch around your plant"
        case .custom: return "Custom reminder"
        }
    }
    
    public var iconName: String {
        switch self {
        case .watering: return "drop.fill"
        case .fertilizing: return "leaf.fill"
        case .pruning: return "scissors"
        case .repotting: return "circle.fill"
        case .harvest: return "basket.fill"
        case .planting: return "seedling"
        case .inspection: return "magnifyingglass"
        case .pestControl: return "ladybug.fill"
        case .soilTest: return "testtube.2"
        case .mulching: return "layers.fill"
        case .custom: return "bell.fill"
        }
    }
}

public enum ReminderFrequency: Codable, Sendable {
    case daily
    case everyOtherDay
    case twiceWeekly
    case weekly
    case biweekly
    case monthly
    case quarterly
    case seasonally
    case yearly
    case custom(days: Int)
    case once
    
    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .everyOtherDay: return "Every Other Day"
        case .twiceWeekly: return "Twice Weekly"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .seasonally: return "Seasonally"
        case .yearly: return "Yearly"
        case .custom(let days): return "Every \(days) days"
        case .once: return "One-time"
        }
    }
    
    public var days: Int {
        switch self {
        case .daily: return 1
        case .everyOtherDay: return 2
        case .twiceWeekly: return 3
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 90
        case .seasonally: return 180
        case .yearly: return 365
        case .custom(let days): return days
        case .once: return 0
        }
    }
}

public enum SnoozeDuration: String, CaseIterable, Codable, Sendable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case tomorrow
    
    public var displayName: String {
        switch self {
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .tomorrow: return "Tomorrow"
        }
    }
}