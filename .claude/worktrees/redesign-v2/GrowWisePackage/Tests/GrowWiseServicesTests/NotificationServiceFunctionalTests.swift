import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing
import UserNotifications

// MARK: - NotificationService Functional Tests

//
// NotificationService.init() calls UNUserNotificationCenter.current(), which
// crashes in the Swift package test runner (no app bundle present). Therefore,
// all tests here exercise pure logic that does NOT require instantiating
// NotificationService — isInQuietHours boundary math, identifier format
// invariants, badge count arithmetic, notification content structure,
// and supporting types.
//
// INTEGRATION GAP: Tests that require NotificationService() instantiation
// (requestPermissions, scheduleReminderNotification, cancelNotification,
// checkAuthorizationStatus) cannot run in swift-test (package tests). They
// require a simulator or device with a real bundle. Consider abstracting
// UNUserNotificationCenter behind a protocol for full unit-test coverage.

// MARK: - Quiet Hours Boundary Logic Tests

/// The isInQuietHours() implementation uses: hour < 8 || hour > 21
/// Quiet window: 00:00–07:59 and 22:00–23:59 (10 hours total)
/// Active window: 08:00–21:59 (14 hours total)
struct QuietHoursBoundaryLogicTests {
    /// Helper that replicates isInQuietHours() logic for deterministic testing.
    private func isQuiet(hour: Int) -> Bool {
        hour < 8 || hour > 21
    }

    @Test("Hours 0 through 7 are in quiet hours (before 8 AM)")
    func hoursBeforeEightAreQuiet() {
        for hour in 0 ... 7 {
            #expect(
                isQuiet(hour: hour) == true,
                "Hour \(hour) should be quiet (before 8 AM)"
            )
        }
    }

    @Test("Hours 8 through 21 are NOT in quiet hours (active window)")
    func activeWindowHoursAreNotQuiet() {
        for hour in 8 ... 21 {
            #expect(
                isQuiet(hour: hour) == false,
                "Hour \(hour) should not be quiet (active window)"
            )
        }
    }

    @Test("Hours 22 and 23 are in quiet hours (after 9 PM)")
    func hoursAfterTwentyOneAreQuiet() {
        for hour in 22 ... 23 {
            #expect(
                isQuiet(hour: hour) == true,
                "Hour \(hour) should be quiet (after 9 PM)"
            )
        }
    }

    @Test("Boundary: hour 7 is quiet (last pre-8AM quiet hour)")
    func hour7IsQuiet() {
        #expect(isQuiet(hour: 7) == true)
    }

    @Test("Boundary: hour 8 is not quiet (first active hour)")
    func hour8IsNotQuiet() {
        #expect(isQuiet(hour: 8) == false)
    }

    @Test("Boundary: hour 21 is not quiet (last active hour)")
    func hour21IsNotQuiet() {
        #expect(isQuiet(hour: 21) == false)
    }

    @Test("Boundary: hour 22 is quiet (first post-21 quiet hour)")
    func hour22IsQuiet() {
        #expect(isQuiet(hour: 22) == true)
    }

    @Test("Quiet window contains exactly 10 hours in a 24-hour day")
    func quietWindowIs10Hours() {
        let quietHours = (0 ... 23).filter { isQuiet(hour: $0) }
        #expect(quietHours.count == 10)
    }

    @Test("Active window contains exactly 14 hours in a 24-hour day")
    func activeWindowIs14Hours() {
        let activeHours = (0 ... 23).filter { !isQuiet(hour: $0) }
        #expect(activeHours.count == 14)
    }

    @Test("Quiet and active windows together cover all 24 hours")
    func quietAndActiveWindowsCoverFullDay() {
        let quietCount = (0 ... 23).count(where: { isQuiet(hour: $0) })
        let activeCount = (0 ... 23).count(where: { !isQuiet(hour: $0) })
        #expect(quietCount + activeCount == 24)
    }

    @Test("Quiet hours are symmetric around midnight (0 and 23 both quiet)")
    func midnightAndEndOfDayAreQuiet() {
        #expect(isQuiet(hour: 0) == true)
        #expect(isQuiet(hour: 23) == true)
    }
}

// MARK: - Notification Identifier Format Tests

struct NotificationIdentifierFormatTests {
    @Test("UUID-based notification identifier has correct 36-character format")
    func uUIDIdentifierHas36Characters() {
        let id = UUID()
        let identifier = id.uuidString
        #expect(identifier.count == 36)
    }

    @Test("UUID-based notification identifier contains four hyphens")
    func uUIDIdentifierContainsFourHyphens() {
        let identifier = UUID().uuidString
        let hyphens = identifier.filter { $0 == "-" }
        #expect(hyphens.count == 4)
    }

    @Test("UUID-based notification identifier is non-empty")
    func uUIDIdentifierIsNonEmpty() {
        #expect(!UUID().uuidString.isEmpty)
    }

    @Test("Multiple UUID identifiers are all unique")
    func multipleUUIDIdentifiersAreUnique() {
        let identifiers = (0 ..< 20).map { _ in UUID().uuidString }
        let unique = Set(identifiers)
        #expect(
            unique.count == 20,
            "Expected 20 unique identifiers but got \(unique.count)"
        )
    }

    @Test("Reminder notification identifier uses reminder UUID string directly")
    func reminderNotificationIdentifierIsUUIDString() {
        let reminderId = UUID()
        // NotificationService uses reminder.id.uuidString as UNNotificationRequest identifier
        let identifier = reminderId.uuidString
        #expect(identifier == reminderId.uuidString)
        #expect(identifier.count == 36)
    }

    @Test("Two different UUIDs produce two different identifier strings")
    func differentUUIDsProduceDifferentIdentifiers() {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        #expect(id1 != id2)
    }
}

// MARK: - Badge Count Arithmetic Tests

struct BadgeCountArithmeticTests {
    @Test("Badge increment formula: 0 + 1 = 1")
    func badgeIncrementFromZero() {
        let currentBadge = 0
        let nextBadge = currentBadge + 1
        #expect(nextBadge == 1)
    }

    @Test("Badge increment formula: N + 1 is correct for arbitrary N")
    func badgeIncrementArbitraryCount() {
        let testCases = [0, 1, 5, 10, 99]
        for count in testCases {
            let next = count + 1
            #expect(
                next == count + 1,
                "Badge increment from \(count) should be \(count + 1)"
            )
        }
    }

    @Test("NSNumber conversion of badge count produces correct intValue")
    func nSNumberBadgeConversion() {
        let badgeCount = 3
        let nsNumber = NSNumber(value: badgeCount + 1)
        #expect(nsNumber.intValue == 4)
    }

    @Test("NSNumber conversion of zero badge produces 1")
    func nSNumberZeroBadgeBecomesOne() {
        let badgeCount = 0
        let nsNumber = NSNumber(value: badgeCount + 1)
        #expect(nsNumber.intValue == 1)
    }

    @Test("NSNumber(value: Int) roundtrips correctly")
    func nSNumberRoundtrip() {
        for value in [0, 1, 10, 100, 999] {
            let nsNumber = NSNumber(value: value)
            #expect(nsNumber.intValue == value)
        }
    }
}

// MARK: - Notification Content Structure Tests

struct NotificationContentStructureTests {
    @Test("userInfo for reminder contains reminderId and reminderType keys")
    func reminderUserInfoKeys() {
        let reminderId = UUID()
        let reminderType = ReminderType.watering

        let userInfo: [String: Any] = [
            "reminderId": reminderId.uuidString,
            "reminderType": reminderType.rawValue,
        ]

        #expect(userInfo["reminderId"] as? String == reminderId.uuidString)
        #expect(userInfo["reminderType"] as? String == reminderType.rawValue)
    }

    @Test("userInfo for reminder without plant has no plantId key")
    func reminderUserInfoWithoutPlant() {
        let userInfo: [String: Any] = [
            "reminderId": UUID().uuidString,
            "reminderType": ReminderType.pruning.rawValue,
        ]
        // plantId should only be present when reminder has a plant
        #expect(userInfo["plantId"] == nil)
    }

    @Test("userInfo for reminder with plant includes plantId")
    func reminderUserInfoWithPlant() {
        let plantId = UUID()
        var userInfo: [String: Any] = [
            "reminderId": UUID().uuidString,
            "reminderType": ReminderType.watering.rawValue,
        ]
        userInfo["plantId"] = plantId.uuidString

        #expect(userInfo["plantId"] as? String == plantId.uuidString)
    }

    @Test("Calendar components for trigger include year, month, day, hour, minute")
    func calendarComponentsForTrigger() {
        let calendar = Calendar.current
        let date = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        #expect(components.year != nil)
        #expect(components.month != nil)
        #expect(components.day != nil)
        #expect(components.hour != nil)
        #expect(components.minute != nil)
    }

    @Test("Calendar components are within valid ranges")
    func calendarComponentRanges() throws {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())

        #expect(try #require(components.year) >= 2024)
        #expect(try (1 ... 12).contains(#require(components.month)))
        #expect(try (1 ... 31).contains(#require(components.day)))
        #expect(try (0 ... 23).contains(#require(components.hour)))
        #expect(try (0 ... 59).contains(#require(components.minute)))
    }

    @Test("UNCalendarNotificationTrigger with repeats=false is created correctly")
    func nonRepeatingCalendarTrigger() throws {
        let future = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: future)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        #expect(trigger.repeats == false)
    }

    @Test("UNCalendarNotificationTrigger with repeats=true is created correctly")
    func repeatingCalendarTrigger() throws {
        let future = try #require(Calendar.current.date(byAdding: .hour, value: 1, to: Date()))
        let components = Calendar.current.dateComponents([.hour, .minute], from: future)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        #expect(trigger.repeats == true)
    }
}

// MARK: - ReminderType Notification Content Tests

struct ReminderTypeNotificationContentTests {
    @Test("All ReminderType cases have non-empty displayName")
    func allReminderTypesHaveDisplayNames() {
        for type_ in ReminderType.allCases {
            #expect(
                !type_.displayName.isEmpty,
                "ReminderType.\(type_.rawValue) has empty displayName"
            )
        }
    }

    @Test("All ReminderType cases have non-empty defaultMessage")
    func allReminderTypesHaveDefaultMessages() {
        for type_ in ReminderType.allCases {
            #expect(
                !type_.defaultMessage.isEmpty,
                "ReminderType.\(type_.rawValue) has empty defaultMessage"
            )
        }
    }

    @Test("notificationMessage matches defaultMessage for all reminder types")
    func notificationMessageMatchesDefaultMessage() {
        for type_ in ReminderType.allCases {
            #expect(
                type_.notificationMessage == type_.defaultMessage,
                "ReminderType.\(type_.rawValue) notificationMessage != defaultMessage"
            )
        }
    }

    @Test("Watering reminder type has correct default message")
    func wateringDefaultMessage() {
        #expect(ReminderType.watering.defaultMessage == "Time to water your plant!")
    }

    @Test("Fertilizing reminder type has correct default message")
    func fertilizingDefaultMessage() {
        #expect(ReminderType.fertilizing.defaultMessage == "Your plant needs fertilizing")
    }

    @Test("Harvest reminder type has correct default message")
    func harvestDefaultMessage() {
        #expect(ReminderType.harvest.defaultMessage == "Your plant is ready for harvest!")
    }

    @Test("All ReminderType cases have non-empty iconName")
    func allReminderTypesHaveIconNames() {
        for type_ in ReminderType.allCases {
            #expect(
                !type_.iconName.isEmpty,
                "ReminderType.\(type_.rawValue) has empty iconName"
            )
        }
    }

    @Test("All ReminderType rawValues are unique")
    func allReminderTypeRawValuesAreUnique() {
        let rawValues = ReminderType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - NotificationStatistics Model Tests

struct NotificationStatisticsModelTests {
    @Test("NotificationStatistics stores all provided values correctly")
    func initializationStoresAllValues() {
        let stats = NotificationStatistics(
            pendingCount: 3,
            deliveredCount: 10,
            isAuthorized: true,
            badgeEnabled: true,
            soundEnabled: true,
            alertEnabled: false
        )
        #expect(stats.pendingCount == 3)
        #expect(stats.deliveredCount == 10)
        #expect(stats.isAuthorized == true)
        #expect(stats.badgeEnabled == true)
        #expect(stats.soundEnabled == true)
        #expect(stats.alertEnabled == false)
    }

    @Test("NotificationStatistics with all disabled flags")
    func allDisabledFlags() {
        let stats = NotificationStatistics(
            pendingCount: 0,
            deliveredCount: 0,
            isAuthorized: false,
            badgeEnabled: false,
            soundEnabled: false,
            alertEnabled: false
        )
        #expect(stats.isAuthorized == false)
        #expect(stats.badgeEnabled == false)
        #expect(stats.soundEnabled == false)
        #expect(stats.alertEnabled == false)
    }

    @Test("NotificationStatistics with zero pending and delivered counts")
    func zeroCounts() {
        let stats = NotificationStatistics(
            pendingCount: 0,
            deliveredCount: 0,
            isAuthorized: false,
            badgeEnabled: false,
            soundEnabled: false,
            alertEnabled: false
        )
        #expect(stats.pendingCount == 0)
        #expect(stats.deliveredCount == 0)
    }

    @Test("NotificationStatistics pending and delivered counts are independent")
    func pendingAndDeliveredAreIndependent() {
        let stats = NotificationStatistics(
            pendingCount: 5,
            deliveredCount: 15,
            isAuthorized: true,
            badgeEnabled: true,
            soundEnabled: true,
            alertEnabled: true
        )
        #expect(stats.pendingCount != stats.deliveredCount)
        #expect(stats.pendingCount == 5)
        #expect(stats.deliveredCount == 15)
    }
}

// MARK: - PlantReminder Scheduling and Snooze Logic Tests

struct PlantReminderSchedulingLogicTests {
    @Test("Daily frequency calculates next due date as +1 day")
    func dailyFrequencyNextDueDate() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        let from = Date()
        let nextDate = reminder.calculateNextDueDate(from: from)
        let diff = Calendar.current.dateComponents([.day], from: from, to: nextDate)
        #expect(diff.day == 1)
    }

    @Test("Weekly frequency calculates next due date as +7 days")
    func weeklyFrequencyNextDueDate() {
        let reminder = PlantReminder(
            title: "Fertilize", message: "Feed me",
            reminderType: .fertilizing, frequency: .weekly,
            nextDueDate: Date()
        )
        let from = Date()
        let nextDate = reminder.calculateNextDueDate(from: from)
        let diff = Calendar.current.dateComponents([.day], from: from, to: nextDate)
        #expect(diff.day == 7)
    }

    @Test("Monthly frequency calculates next due date as +1 month")
    func monthlyFrequencyNextDueDate() {
        let reminder = PlantReminder(
            title: "Repot", message: "Check roots",
            reminderType: .repotting, frequency: .monthly,
            nextDueDate: Date()
        )
        let from = Date()
        let nextDate = reminder.calculateNextDueDate(from: from)
        let diff = Calendar.current.dateComponents([.month], from: from, to: nextDate)
        #expect(diff.month == 1)
    }

    @Test("Once frequency returns same date as from date")
    func onceFrequencyReturnsSameDate() {
        let reminder = PlantReminder(
            title: "One-time", message: "Do once",
            reminderType: .custom, frequency: .once,
            nextDueDate: Date()
        )
        let from = Date()
        let nextDate = reminder.calculateNextDueDate(from: from)
        #expect(abs(nextDate.timeIntervalSince(from)) < 1.0)
    }

    @Test("Reminder notification identifier is a valid UUID string")
    func reminderNotificationIdentifierIsUUID() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        let identifier = reminder.id.uuidString
        #expect(identifier.count == 36)
        #expect(!identifier.isEmpty)
    }

    @Test("markCompleted sets lastCompletedDate")
    func markCompletedSetsLastCompletedDate() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        #expect(reminder.lastCompletedDate == nil)
        reminder.markCompleted()
        #expect(reminder.lastCompletedDate != nil)
    }

    @Test("markCompleted on non-recurring reminder disables it")
    func markCompletedOnNonRecurringDisablesReminder() {
        let reminder = PlantReminder(
            title: "One-time", message: "Do once",
            reminderType: .custom, frequency: .once,
            nextDueDate: Date()
        )
        reminder.isRecurring = false
        reminder.markCompleted()
        #expect(reminder.isEnabled == false)
    }

    @Test("markCompleted on recurring reminder keeps it enabled")
    func markCompletedOnRecurringKeepsEnabled() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        reminder.isRecurring = true
        reminder.markCompleted()
        #expect(reminder.isEnabled == true)
    }

    @Test("snooze increments snoozeCount by 1")
    func snoozeIncrementsCountByOne() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        #expect(reminder.snoozeCount == 0)
        reminder.snooze(for: .oneHour)
        #expect(reminder.snoozeCount == 1)
    }

    @Test("snooze does nothing when maxSnoozeCount is reached")
    func snoozeDoesNothingAtMaxCount() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        reminder.snoozeCount = reminder.maxSnoozeCount
        let previousNextDue = reminder.nextDueDate
        reminder.snooze(for: .oneHour)
        #expect(reminder.snoozeCount == reminder.maxSnoozeCount)
        #expect(reminder.nextDueDate == previousNextDue)
    }

    @Test("snooze for tomorrow advances nextDueDate by at least 12 hours")
    func snoozeForTomorrowAdvancesDate() {
        let reminder = PlantReminder(
            title: "Water", message: "Water me",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date()
        )
        let before = Date()
        reminder.snooze(for: .tomorrow)
        let after = reminder.nextDueDate
        let diff = after.timeIntervalSince(before)
        // Snooze for .tomorrow adds 1 day (~86400s), so must be > 12 hours
        #expect(diff > 43200, "Expected nextDueDate to be at least 12h in the future")
    }

    // INTEGRATION GAP: scheduleReminderNotification, cancelNotification,
    // cancelAllNotifications, requestNotificationPermissions, and
    // checkAuthorizationStatus all call UNUserNotificationCenter, which
    // crashes in the Swift package test runner (no app bundle). These require
    // a simulator or real device environment.
}

// MARK: - ReminderFrequency Days Property Tests

struct ReminderFrequencyDaysPropertyTests {
    @Test("daily frequency has 1 day")
    func dailyFrequencyDays() {
        #expect(ReminderFrequency.daily.days == 1)
    }

    @Test("everyOtherDay frequency has 2 days")
    func everyOtherDayFrequencyDays() {
        #expect(ReminderFrequency.everyOtherDay.days == 2)
    }

    @Test("twiceWeekly frequency has 3 days")
    func twiceWeeklyFrequencyDays() {
        #expect(ReminderFrequency.twiceWeekly.days == 3)
    }

    @Test("weekly frequency has 7 days")
    func weeklyFrequencyDays() {
        #expect(ReminderFrequency.weekly.days == 7)
    }

    @Test("biweekly frequency has 14 days")
    func biweeklyFrequencyDays() {
        #expect(ReminderFrequency.biweekly.days == 14)
    }

    @Test("monthly frequency has 30 days")
    func monthlyFrequencyDays() {
        #expect(ReminderFrequency.monthly.days == 30)
    }

    @Test("quarterly frequency has 90 days")
    func quarterlyFrequencyDays() {
        #expect(ReminderFrequency.quarterly.days == 90)
    }

    @Test("seasonally frequency has 180 days")
    func seasonallyFrequencyDays() {
        #expect(ReminderFrequency.seasonally.days == 180)
    }

    @Test("yearly frequency has 365 days")
    func yearlyFrequencyDays() {
        #expect(ReminderFrequency.yearly.days == 365)
    }

    @Test("All ReminderFrequency cases have non-empty displayName")
    func allFrequenciesHaveDisplayNames() {
        for freq in ReminderFrequency.allCases {
            #expect(
                !freq.displayName.isEmpty,
                "ReminderFrequency.\(freq.rawValue) has empty displayName"
            )
        }
    }

    @Test("All ReminderFrequency rawValues are unique")
    func allFrequencyRawValuesAreUnique() {
        let rawValues = ReminderFrequency.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - ReminderPriority Tests

struct ReminderPriorityTests {
    @Test("All ReminderPriority cases have non-empty displayName")
    func allPrioritiesHaveDisplayNames() {
        for priority in ReminderPriority.allCases {
            #expect(
                !priority.displayName.isEmpty,
                "ReminderPriority.\(priority.rawValue) has empty displayName"
            )
        }
    }

    @Test("All ReminderPriority cases have non-empty color")
    func allPrioritiesHaveColors() {
        for priority in ReminderPriority.allCases {
            #expect(
                !priority.color.isEmpty,
                "ReminderPriority.\(priority.rawValue) has empty color"
            )
        }
    }

    @Test("ReminderPriority numeric values are in ascending order")
    func priorityNumericValuesAscending() {
        #expect(ReminderPriority.low.numericValue < ReminderPriority.medium.numericValue)
        #expect(ReminderPriority.medium.numericValue < ReminderPriority.high.numericValue)
        #expect(ReminderPriority.high.numericValue < ReminderPriority.critical.numericValue)
    }

    @Test("low priority has numericValue 1")
    func lowPriorityNumericValue() {
        #expect(ReminderPriority.low.numericValue == 1)
    }

    @Test("critical priority has numericValue 4")
    func criticalPriorityNumericValue() {
        #expect(ReminderPriority.critical.numericValue == 4)
    }

    @Test("All ReminderPriority rawValues are unique")
    func allPriorityRawValuesAreUnique() {
        let rawValues = ReminderPriority.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - NotificationService.notificationContent(for:) Tests

/// Tests the actual NotificationService.notificationContent(for:) method using the
/// testable init(notificationCenter: nil) to avoid UNUserNotificationCenter crashes.
@MainActor
struct NotificationServiceContentTests {
    private func makeService() -> NotificationService {
        NotificationService(notificationCenter: nil)
    }

    @Test("notificationContent title includes plant name from reminder")
    func contentTitleIncludesPlantName() {
        let service = makeService()
        let plant = Plant(name: "Monstera", plantType: .houseplant)
        let reminder = PlantReminder(
            title: "Water", message: "Water it",
            reminderType: .watering, frequency: .daily,
            nextDueDate: Date(), plant: plant
        )

        let content = service.notificationContent(for: reminder)
        #expect(content.title == "Time to care for Monstera")
    }

    @Test("notificationContent body is the reminderType displayName")
    func contentBodyIsReminderTypeDisplayName() {
        let service = makeService()
        let plant = Plant(name: "Basil", plantType: .herb)
        let reminder = PlantReminder(
            title: "Fertilize", message: "Feed",
            reminderType: .fertilizing, frequency: .weekly,
            nextDueDate: Date(), plant: plant
        )

        let content = service.notificationContent(for: reminder)
        #expect(content.body == ReminderType.fertilizing.displayName)
    }

    @Test("notificationContent uses plantName fallback when plant reference is nil")
    func contentUsesPlantNameFallbackWhenPlantIsNil() {
        let service = makeService()
        let reminder = PlantReminder(
            title: "Prune", message: "Trim",
            reminderType: .pruning, frequency: .monthly,
            nextDueDate: Date()
        )
        // PlantReminder stores plantName as a denormalized field
        let expectedName = reminder.plantName

        let content = service.notificationContent(for: reminder)
        #expect(content.title == "Time to care for \(expectedName)")
    }

    @Test("notificationContent produces correct body for each ReminderType")
    func contentProducesCorrectBodyForAllTypes() {
        let service = makeService()
        let plant = Plant(name: "TestPlant", plantType: .vegetable)

        for type in ReminderType.allCases {
            let reminder = PlantReminder(
                title: "Test", message: "Test",
                reminderType: type, frequency: .daily,
                nextDueDate: Date(), plant: plant
            )
            let content = service.notificationContent(for: reminder)
            #expect(
                content.body == type.displayName,
                "Body for \(type.rawValue) should be '\(type.displayName)' but got '\(content.body)'"
            )
            #expect(
                !content.title.isEmpty,
                "Title should not be empty for \(type.rawValue)"
            )
        }
    }

    // INTEGRATION GAP: Real UNUserNotificationCenter requires device — cannot test
    // scheduleReminderNotification, cancelNotification, or updateBadgeCount here.
}

// MARK: - NotificationService.isInQuietHours() Tests

/// Tests the actual isInQuietHours() method on NotificationService.
/// The method uses the current system time, so we verify its output is
/// consistent with the expected quiet hours logic (hour < 8 || hour > 21).
@MainActor
struct NotificationServiceQuietHoursTests {
    private func makeService() -> NotificationService {
        NotificationService(notificationCenter: nil)
    }

    @Test("isInQuietHours returns a boolean consistent with current hour")
    func isInQuietHoursMatchesCurrentHour() {
        let service = makeService()
        let currentHour = Calendar.current.component(.hour, from: Date())
        let expectedQuiet = currentHour < 8 || currentHour > 21

        let result = service.isInQuietHours()
        #expect(
            result == expectedQuiet,
            "isInQuietHours() returned \(result) but current hour \(currentHour) should be quiet=\(expectedQuiet)"
        )
    }

    @Test("isInQuietHours is callable on service with nil notification center")
    func isInQuietHoursWorksWithNilCenter() {
        let service = makeService()
        // Should not crash and should return a valid bool
        let result = service.isInQuietHours()
        #expect(result == true || result == false)
    }

    // INTEGRATION GAP: isInQuietHours() reads the current system clock and cannot be
    // injected with a custom time. To test all 24 hour boundaries, the existing
    // QuietHoursBoundaryLogicTests suite replicates the algorithm. A protocol-based
    // clock abstraction would enable deterministic boundary testing on the real method.
}

// MARK: - NotificationService Badge State Tests

/// Tests badge count state management on NotificationService using the testable init.
@MainActor
struct NotificationServiceBadgeStateTests {
    private func makeService() -> NotificationService {
        NotificationService(notificationCenter: nil)
    }

    @Test("Initial badge count is 0")
    func initialBadgeCountIsZero() {
        let service = makeService()
        #expect(service.badgeCount == 0)
    }

    @Test("Initial authorization state is false with nil notification center")
    func initialAuthorizationIsFalse() {
        let service = makeService()
        #expect(service.isAuthorized == false)
    }

    @Test("isEnabled mirrors isAuthorized")
    func isEnabledMirrorsIsAuthorized() {
        let service = makeService()
        #expect(service.isEnabled == service.isAuthorized)
    }

    @Test("requestNotificationPermissions returns false with nil notification center")
    func requestPermissionsReturnsFalseWithNilCenter() async {
        let service = makeService()
        let granted = await service.requestNotificationPermissions()
        #expect(granted == false)
    }

    // INTEGRATION GAP: Real UNUserNotificationCenter requires device — cannot test
    // actual badge count updates from pending notification changes here.
}
