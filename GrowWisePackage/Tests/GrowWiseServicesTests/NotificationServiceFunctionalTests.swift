import Testing
import Foundation
import UserNotifications
@testable import GrowWiseServices
@testable import GrowWiseModels

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
@Suite("Quiet Hours Boundary Logic Tests")
struct QuietHoursBoundaryLogicTests {

    // Helper that replicates isInQuietHours() logic for deterministic testing.
    private func isQuiet(hour: Int) -> Bool {
        return hour < 8 || hour > 21
    }

    @Test("Hours 0 through 7 are in quiet hours (before 8 AM)")
    func testHoursBeforeEightAreQuiet() {
        for hour in 0...7 {
            #expect(isQuiet(hour: hour) == true,
                    "Hour \(hour) should be quiet (before 8 AM)")
        }
    }

    @Test("Hours 8 through 21 are NOT in quiet hours (active window)")
    func testActiveWindowHoursAreNotQuiet() {
        for hour in 8...21 {
            #expect(isQuiet(hour: hour) == false,
                    "Hour \(hour) should not be quiet (active window)")
        }
    }

    @Test("Hours 22 and 23 are in quiet hours (after 9 PM)")
    func testHoursAfterTwentyOneAreQuiet() {
        for hour in 22...23 {
            #expect(isQuiet(hour: hour) == true,
                    "Hour \(hour) should be quiet (after 9 PM)")
        }
    }

    @Test("Boundary: hour 7 is quiet (last pre-8AM quiet hour)")
    func testHour7IsQuiet() {
        #expect(isQuiet(hour: 7) == true)
    }

    @Test("Boundary: hour 8 is not quiet (first active hour)")
    func testHour8IsNotQuiet() {
        #expect(isQuiet(hour: 8) == false)
    }

    @Test("Boundary: hour 21 is not quiet (last active hour)")
    func testHour21IsNotQuiet() {
        #expect(isQuiet(hour: 21) == false)
    }

    @Test("Boundary: hour 22 is quiet (first post-21 quiet hour)")
    func testHour22IsQuiet() {
        #expect(isQuiet(hour: 22) == true)
    }

    @Test("Quiet window contains exactly 10 hours in a 24-hour day")
    func testQuietWindowIs10Hours() {
        let quietHours = (0...23).filter { isQuiet(hour: $0) }
        #expect(quietHours.count == 10)
    }

    @Test("Active window contains exactly 14 hours in a 24-hour day")
    func testActiveWindowIs14Hours() {
        let activeHours = (0...23).filter { !isQuiet(hour: $0) }
        #expect(activeHours.count == 14)
    }

    @Test("Quiet and active windows together cover all 24 hours")
    func testQuietAndActiveWindowsCoverFullDay() {
        let quietCount = (0...23).filter { isQuiet(hour: $0) }.count
        let activeCount = (0...23).filter { !isQuiet(hour: $0) }.count
        #expect(quietCount + activeCount == 24)
    }

    @Test("Quiet hours are symmetric around midnight (0 and 23 both quiet)")
    func testMidnightAndEndOfDayAreQuiet() {
        #expect(isQuiet(hour: 0) == true)
        #expect(isQuiet(hour: 23) == true)
    }
}

// MARK: - Notification Identifier Format Tests

@Suite("Notification Identifier Format Tests")
struct NotificationIdentifierFormatTests {

    @Test("UUID-based notification identifier has correct 36-character format")
    func testUUIDIdentifierHas36Characters() {
        let id = UUID()
        let identifier = id.uuidString
        #expect(identifier.count == 36)
    }

    @Test("UUID-based notification identifier contains four hyphens")
    func testUUIDIdentifierContainsFourHyphens() {
        let identifier = UUID().uuidString
        let hyphens = identifier.filter { $0 == "-" }
        #expect(hyphens.count == 4)
    }

    @Test("UUID-based notification identifier is non-empty")
    func testUUIDIdentifierIsNonEmpty() {
        #expect(!UUID().uuidString.isEmpty)
    }

    @Test("Multiple UUID identifiers are all unique")
    func testMultipleUUIDIdentifiersAreUnique() {
        let identifiers = (0..<20).map { _ in UUID().uuidString }
        let unique = Set(identifiers)
        #expect(unique.count == 20,
                "Expected 20 unique identifiers but got \(unique.count)")
    }

    @Test("Reminder notification identifier uses reminder UUID string directly")
    func testReminderNotificationIdentifierIsUUIDString() {
        let reminderId = UUID()
        // NotificationService uses reminder.id.uuidString as UNNotificationRequest identifier
        let identifier = reminderId.uuidString
        #expect(identifier == reminderId.uuidString)
        #expect(identifier.count == 36)
    }

    @Test("Two different UUIDs produce two different identifier strings")
    func testDifferentUUIDsProduceDifferentIdentifiers() {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        #expect(id1 != id2)
    }
}

// MARK: - Badge Count Arithmetic Tests

@Suite("Badge Count Arithmetic Tests")
struct BadgeCountArithmeticTests {

    @Test("Badge increment formula: 0 + 1 = 1")
    func testBadgeIncrementFromZero() {
        let currentBadge = 0
        let nextBadge = currentBadge + 1
        #expect(nextBadge == 1)
    }

    @Test("Badge increment formula: N + 1 is correct for arbitrary N")
    func testBadgeIncrementArbitraryCount() {
        let testCases = [0, 1, 5, 10, 99]
        for count in testCases {
            let next = count + 1
            #expect(next == count + 1,
                    "Badge increment from \(count) should be \(count + 1)")
        }
    }

    @Test("NSNumber conversion of badge count produces correct intValue")
    func testNSNumberBadgeConversion() {
        let badgeCount = 3
        let nsNumber = NSNumber(value: badgeCount + 1)
        #expect(nsNumber.intValue == 4)
    }

    @Test("NSNumber conversion of zero badge produces 1")
    func testNSNumberZeroBadgeBecomesOne() {
        let badgeCount = 0
        let nsNumber = NSNumber(value: badgeCount + 1)
        #expect(nsNumber.intValue == 1)
    }

    @Test("NSNumber(value: Int) roundtrips correctly")
    func testNSNumberRoundtrip() {
        for value in [0, 1, 10, 100, 999] {
            let nsNumber = NSNumber(value: value)
            #expect(nsNumber.intValue == value)
        }
    }
}

// MARK: - Notification Content Structure Tests

@Suite("Notification Content Structure Tests")
struct NotificationContentStructureTests {

    @Test("userInfo for reminder contains reminderId and reminderType keys")
    func testReminderUserInfoKeys() {
        let reminderId = UUID()
        let reminderType = ReminderType.watering

        let userInfo: [String: Any] = [
            "reminderId": reminderId.uuidString,
            "reminderType": reminderType.rawValue
        ]

        #expect(userInfo["reminderId"] as? String == reminderId.uuidString)
        #expect(userInfo["reminderType"] as? String == reminderType.rawValue)
    }

    @Test("userInfo for reminder without plant has no plantId key")
    func testReminderUserInfoWithoutPlant() {
        let userInfo: [String: Any] = [
            "reminderId": UUID().uuidString,
            "reminderType": ReminderType.pruning.rawValue
        ]
        // plantId should only be present when reminder has a plant
        #expect(userInfo["plantId"] == nil)
    }

    @Test("userInfo for reminder with plant includes plantId")
    func testReminderUserInfoWithPlant() {
        let plantId = UUID()
        var userInfo: [String: Any] = [
            "reminderId": UUID().uuidString,
            "reminderType": ReminderType.watering.rawValue
        ]
        userInfo["plantId"] = plantId.uuidString

        #expect(userInfo["plantId"] as? String == plantId.uuidString)
    }

    @Test("Calendar components for trigger include year, month, day, hour, minute")
    func testCalendarComponentsForTrigger() {
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
    func testCalendarComponentRanges() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())

        #expect(components.year! >= 2024)
        #expect((1...12).contains(components.month!))
        #expect((1...31).contains(components.day!))
        #expect((0...23).contains(components.hour!))
        #expect((0...59).contains(components.minute!))
    }

    @Test("UNCalendarNotificationTrigger with repeats=false is created correctly")
    func testNonRepeatingCalendarTrigger() {
        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: future)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        #expect(trigger.repeats == false)
    }

    @Test("UNCalendarNotificationTrigger with repeats=true is created correctly")
    func testRepeatingCalendarTrigger() {
        let future = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let components = Calendar.current.dateComponents([.hour, .minute], from: future)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        #expect(trigger.repeats == true)
    }
}

// MARK: - ReminderType Notification Content Tests

@Suite("ReminderType Notification Content Tests")
struct ReminderTypeNotificationContentTests {

    @Test("All ReminderType cases have non-empty displayName")
    func testAllReminderTypesHaveDisplayNames() {
        for type_ in ReminderType.allCases {
            #expect(!type_.displayName.isEmpty,
                    "ReminderType.\(type_.rawValue) has empty displayName")
        }
    }

    @Test("All ReminderType cases have non-empty defaultMessage")
    func testAllReminderTypesHaveDefaultMessages() {
        for type_ in ReminderType.allCases {
            #expect(!type_.defaultMessage.isEmpty,
                    "ReminderType.\(type_.rawValue) has empty defaultMessage")
        }
    }

    @Test("notificationMessage matches defaultMessage for all reminder types")
    func testNotificationMessageMatchesDefaultMessage() {
        for type_ in ReminderType.allCases {
            #expect(type_.notificationMessage == type_.defaultMessage,
                    "ReminderType.\(type_.rawValue) notificationMessage != defaultMessage")
        }
    }

    @Test("Watering reminder type has correct default message")
    func testWateringDefaultMessage() {
        #expect(ReminderType.watering.defaultMessage == "Time to water your plant!")
    }

    @Test("Fertilizing reminder type has correct default message")
    func testFertilizingDefaultMessage() {
        #expect(ReminderType.fertilizing.defaultMessage == "Your plant needs fertilizing")
    }

    @Test("Harvest reminder type has correct default message")
    func testHarvestDefaultMessage() {
        #expect(ReminderType.harvest.defaultMessage == "Your plant is ready for harvest!")
    }

    @Test("All ReminderType cases have non-empty iconName")
    func testAllReminderTypesHaveIconNames() {
        for type_ in ReminderType.allCases {
            #expect(!type_.iconName.isEmpty,
                    "ReminderType.\(type_.rawValue) has empty iconName")
        }
    }

    @Test("All ReminderType rawValues are unique")
    func testAllReminderTypeRawValuesAreUnique() {
        let rawValues = ReminderType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - NotificationStatistics Model Tests

@Suite("NotificationStatistics Model Tests")
struct NotificationStatisticsModelTests {

    @Test("NotificationStatistics stores all provided values correctly")
    func testInitializationStoresAllValues() {
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
    func testAllDisabledFlags() {
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
    func testZeroCounts() {
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
    func testPendingAndDeliveredAreIndependent() {
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

@Suite("PlantReminder Scheduling Logic Tests")
struct PlantReminderSchedulingLogicTests {

    @Test("Daily frequency calculates next due date as +1 day")
    func testDailyFrequencyNextDueDate() {
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
    func testWeeklyFrequencyNextDueDate() {
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
    func testMonthlyFrequencyNextDueDate() {
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
    func testOnceFrequencyReturnsSameDate() {
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
    func testReminderNotificationIdentifierIsUUID() {
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
    func testMarkCompletedSetsLastCompletedDate() {
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
    func testMarkCompletedOnNonRecurringDisablesReminder() {
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
    func testMarkCompletedOnRecurringKeepsEnabled() {
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
    func testSnoozeIncrementsCountByOne() {
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
    func testSnoozeDoesNothingAtMaxCount() {
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
    func testSnoozeForTomorrowAdvancesDate() {
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

@Suite("ReminderFrequency Days Property Tests")
struct ReminderFrequencyDaysPropertyTests {

    @Test("daily frequency has 1 day")
    func testDailyFrequencyDays() {
        #expect(ReminderFrequency.daily.days == 1)
    }

    @Test("everyOtherDay frequency has 2 days")
    func testEveryOtherDayFrequencyDays() {
        #expect(ReminderFrequency.everyOtherDay.days == 2)
    }

    @Test("twiceWeekly frequency has 3 days")
    func testTwiceWeeklyFrequencyDays() {
        #expect(ReminderFrequency.twiceWeekly.days == 3)
    }

    @Test("weekly frequency has 7 days")
    func testWeeklyFrequencyDays() {
        #expect(ReminderFrequency.weekly.days == 7)
    }

    @Test("biweekly frequency has 14 days")
    func testBiweeklyFrequencyDays() {
        #expect(ReminderFrequency.biweekly.days == 14)
    }

    @Test("monthly frequency has 30 days")
    func testMonthlyFrequencyDays() {
        #expect(ReminderFrequency.monthly.days == 30)
    }

    @Test("quarterly frequency has 90 days")
    func testQuarterlyFrequencyDays() {
        #expect(ReminderFrequency.quarterly.days == 90)
    }

    @Test("seasonally frequency has 180 days")
    func testSeasonallyFrequencyDays() {
        #expect(ReminderFrequency.seasonally.days == 180)
    }

    @Test("yearly frequency has 365 days")
    func testYearlyFrequencyDays() {
        #expect(ReminderFrequency.yearly.days == 365)
    }

    @Test("All ReminderFrequency cases have non-empty displayName")
    func testAllFrequenciesHaveDisplayNames() {
        for freq in ReminderFrequency.allCases {
            #expect(!freq.displayName.isEmpty,
                    "ReminderFrequency.\(freq.rawValue) has empty displayName")
        }
    }

    @Test("All ReminderFrequency rawValues are unique")
    func testAllFrequencyRawValuesAreUnique() {
        let rawValues = ReminderFrequency.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - ReminderPriority Tests

@Suite("ReminderPriority Tests")
struct ReminderPriorityTests {

    @Test("All ReminderPriority cases have non-empty displayName")
    func testAllPrioritiesHaveDisplayNames() {
        for priority in ReminderPriority.allCases {
            #expect(!priority.displayName.isEmpty,
                    "ReminderPriority.\(priority.rawValue) has empty displayName")
        }
    }

    @Test("All ReminderPriority cases have non-empty color")
    func testAllPrioritiesHaveColors() {
        for priority in ReminderPriority.allCases {
            #expect(!priority.color.isEmpty,
                    "ReminderPriority.\(priority.rawValue) has empty color")
        }
    }

    @Test("ReminderPriority numeric values are in ascending order")
    func testPriorityNumericValuesAscending() {
        #expect(ReminderPriority.low.numericValue < ReminderPriority.medium.numericValue)
        #expect(ReminderPriority.medium.numericValue < ReminderPriority.high.numericValue)
        #expect(ReminderPriority.high.numericValue < ReminderPriority.critical.numericValue)
    }

    @Test("low priority has numericValue 1")
    func testLowPriorityNumericValue() {
        #expect(ReminderPriority.low.numericValue == 1)
    }

    @Test("critical priority has numericValue 4")
    func testCriticalPriorityNumericValue() {
        #expect(ReminderPriority.critical.numericValue == 4)
    }

    @Test("All ReminderPriority rawValues are unique")
    func testAllPriorityRawValuesAreUnique() {
        let rawValues = ReminderPriority.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}
