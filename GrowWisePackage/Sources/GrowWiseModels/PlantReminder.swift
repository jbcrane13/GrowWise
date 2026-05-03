import Foundation
import SwiftData

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable cyclomatic_complexity

@Model
public final class PlantReminder {
    public var id = UUID()
    public var title: String = ""
    public var message: String = ""
    public var reminderTypeRawValue: String = "watering"
    public var storedFrequency: String = "daily"
    public var customFrequencyDays: Int?

    // Scheduling
    public var nextDueDate = Date()
    public var lastCompletedDate: Date?
    public var isEnabled: Bool = true
    public var isRecurring: Bool = true

    // Relationships
    public var plant: Plant?
    public var user: User?

    // Notification settings
    public var notificationIdentifier: String?
    public var snoozeCount: Int = 0
    public var maxSnoozeCount: Int = 3
    public var preferredNotificationTime: Date?

    // Smart reminder properties
    public var priorityRawValue: String = "medium"
    public var enableWeatherAdjustment: Bool = false
    public var baseFrequencyDays: Int = 1

    // Seasonal properties
    public var seasonalContext: String?
    public var isSeasonalReminder: Bool = false

    // Metadata
    public var createdDate = Date()
    public var lastModified = Date()

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
        id = UUID()
        self.title = title
        self.message = message
        reminderTypeRawValue = reminderType.rawValue
        self.nextDueDate = nextDueDate
        self.plant = plant
        user = nil
        isEnabled = true
        isRecurring = true
        snoozeCount = 0
        maxSnoozeCount = 3
        preferredNotificationTime = nil
        priorityRawValue = ReminderPriority.medium.rawValue
        enableWeatherAdjustment = false
        customFrequencyDays = nil
        seasonalContext = nil
        isSeasonalReminder = false
        createdDate = Date()
        lastModified = Date()

        switch frequency {
        case .custom:
            storedFrequency = ReminderFrequency.custom.rawValue

        // customFrequencyDays should be set outside as needed; leave as initialized
        default:
            storedFrequency = frequency.rawValue
            customFrequencyDays = nil
        }
        baseFrequencyDays = frequency.days
    }

    /// Calculate next due date based on frequency
    public func calculateNextDueDate(from completedDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let freq = frequency

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
            let days = customFrequencyDays ?? 1
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
        let snoozeDate: Date = switch duration {
        case .fifteenMinutes:
            calendar.date(byAdding: .minute, value: 15, to: Date()) ?? Date()

        case .thirtyMinutes:
            calendar.date(byAdding: .minute, value: 30, to: Date()) ?? Date()

        case .oneHour:
            calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

        case .twoHours:
            calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

        case .tomorrow:
            calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }

        nextDueDate = snoozeDate
        snoozeCount += 1
        lastModified = Date()
    }

    // MARK: - Computed Properties

    public var plantName: String {
        plant?.name ?? "Your Plant"
    }

    public var plantId: UUID {
        plant?.id ?? UUID()
    }

    public var type: ReminderType {
        reminderType
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
        case .watering: "Watering"
        case .fertilizing: "Fertilizing"
        case .pruning: "Pruning"
        case .repotting: "Repotting"
        case .harvest: "Harvest"
        case .planting: "Planting"
        case .inspection: "Health Check"
        case .pestControl: "Pest Control"
        case .soilTest: "Soil Test"
        case .mulching: "Mulching"
        case .custom: "Custom"
        }
    }

    public var defaultMessage: String {
        switch self {
        case .watering: "Time to water your plant!"
        case .fertilizing: "Your plant needs fertilizing"
        case .pruning: "Check if your plant needs pruning"
        case .repotting: "Consider repotting your plant"
        case .harvest: "Your plant is ready for harvest!"
        case .planting: "Time to plant your seeds"
        case .inspection: "Check your plant's health"
        case .pestControl: "Inspect for pests and diseases"
        case .soilTest: "Test your soil conditions"
        case .mulching: "Add mulch around your plant"
        case .custom: "Custom reminder"
        }
    }

    public var notificationMessage: String {
        defaultMessage
    }

    public var iconName: String {
        switch self {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .pruning: "scissors"
        case .repotting: "circle.fill"
        case .harvest: "basket.fill"
        case .planting: "sprout.circle"
        case .inspection: "magnifyingglass"
        case .pestControl: "ladybug.fill"
        case .soilTest: "testtube.2"
        case .mulching: "layers.fill"
        case .custom: "bell.fill"
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
        case .daily: "Daily"
        case .everyOtherDay: "Every Other Day"
        case .twiceWeekly: "Twice Weekly"
        case .weekly: "Weekly"
        case .biweekly: "Bi-weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .seasonally: "Seasonally"
        case .yearly: "Yearly"
        case .custom: "Custom"
        case .once: "One-time"
        }
    }

    public var days: Int {
        switch self {
        case .daily: 1
        case .everyOtherDay: 2
        case .twiceWeekly: 3
        case .weekly: 7
        case .biweekly: 14
        case .monthly: 30
        case .quarterly: 90
        case .seasonally: 180
        case .yearly: 365
        case .custom: 0 // handled separately
        case .once: 0
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
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .tomorrow: "Tomorrow"
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
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    public var color: String {
        switch self {
        case .low: "gray"
        case .medium: "blue"
        case .high: "orange"
        case .critical: "red"
        }
    }

    public var numericValue: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
    }
}

// swiftlint:enable cyclomatic_complexity
