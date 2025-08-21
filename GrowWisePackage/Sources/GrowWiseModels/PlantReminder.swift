import Foundation
import SwiftData

@Model
public final class PlantReminder {
    public var id: UUID
    public var title: String
    public var message: String
    public var reminderTypeRawValue: String
    public var storedFrequency: String
    public var customFrequencyDays: Int?
    
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
    public var preferredNotificationTime: Date?
    
    // Smart reminder properties
    public var priorityRawValue: String
    public var enableWeatherAdjustment: Bool
    public var baseFrequencyDays: Int
    
    // Seasonal properties
    public var seasonalContext: String?
    public var isSeasonalReminder: Bool
    
    // Metadata
    public var createdDate: Date
    public var lastModified: Date
    
    public var reminderType: ReminderType {
        get { ReminderType(rawValue: reminderTypeRawValue) ?? .custom }
        set { reminderTypeRawValue = newValue.rawValue }
    }
    
    public var frequency: ReminderFrequency {
        get {
            if let frequency = ReminderFrequency(rawValue: storedFrequency) {
                if frequency == .custom {
                    return .custom
                }
                return frequency
            }
            // fallback
            return .daily
        }
        set {
            switch newValue {
            case .custom:
                storedFrequency = ReminderFrequency.custom.rawValue
                // customFrequencyDays is handled elsewhere if needed
            default:
                storedFrequency = newValue.rawValue
                customFrequencyDays = nil
            }
        }
    }
    
    public var priority: ReminderPriority {
        get { ReminderPriority(rawValue: priorityRawValue) ?? ReminderPriority.medium }
        set { priorityRawValue = newValue.rawValue }
    }
    
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
        self.reminderTypeRawValue = reminderType.rawValue
        self.nextDueDate = nextDueDate
        self.plant = plant
        self.user = nil
        self.isEnabled = true
        self.isRecurring = true
        self.snoozeCount = 0
        self.maxSnoozeCount = 3
        self.preferredNotificationTime = nil
        self.priorityRawValue = ReminderPriority.medium.rawValue
        self.enableWeatherAdjustment = false
        self.customFrequencyDays = nil
        self.seasonalContext = nil
        self.isSeasonalReminder = false
        self.createdDate = Date()
        self.lastModified = Date()
        
        switch frequency {
        case .custom:
            self.storedFrequency = ReminderFrequency.custom.rawValue
            // customFrequencyDays should be set outside as needed; leave as initialized
        default:
            self.storedFrequency = frequency.rawValue
            self.customFrequencyDays = nil
        }
        self.baseFrequencyDays = frequency.days
    }
    
    // Calculate next due date based on frequency
    public func calculateNextDueDate(from completedDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let freq = self.frequency
        
        switch freq {
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
        case .custom:
            let days = self.customFrequencyDays ?? 1
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
    
    // MARK: - Computed Properties
    
    public var plantName: String {
        return plant?.name ?? "Your Plant"
    }
    
    public var plantId: UUID {
        return plant?.id ?? UUID()
    }
    
    public var type: ReminderType {
        return reminderType
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
    
    public var notificationMessage: String {
        return self.defaultMessage
    }
    
    public var iconName: String {
        switch self {
        case .watering: return "drop.fill"
        case .fertilizing: return "leaf.fill"
        case .pruning: return "scissors"
        case .repotting: return "circle.fill"
        case .harvest: return "basket.fill"
        case .planting: return "sprout.circle"
        case .inspection: return "magnifyingglass"
        case .pestControl: return "ladybug.fill"
        case .soilTest: return "testtube.2"
        case .mulching: return "layers.fill"
        case .custom: return "bell.fill"
        }
    }
}

public enum ReminderFrequency: String, Codable, Sendable, Hashable, Equatable, CaseIterable {
    case daily
    case everyOtherDay
    case twiceWeekly
    case weekly
    case biweekly
    case monthly
    case quarterly
    case seasonally
    case yearly
    case custom
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
        case .custom: return "Custom"
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
        case .custom: return 0 // handled separately
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

public enum ReminderPriority: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
    case critical
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    public var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}
