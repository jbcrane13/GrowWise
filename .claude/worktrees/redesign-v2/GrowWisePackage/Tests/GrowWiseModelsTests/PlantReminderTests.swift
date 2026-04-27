import Testing
import Foundation
@testable import GrowWiseModels

@Suite("PlantReminder Logic Tests")
struct PlantReminderTests {

    private func makeReminder(
        frequency: ReminderFrequency = .weekly,
        nextDue: Date = Date()
    ) -> PlantReminder {
        PlantReminder(
            title: "Water",
            message: "Water your plant",
            reminderType: .watering,
            frequency: frequency,
            nextDueDate: nextDue
        )
    }

    @Test("PlantReminder initialization sets all expected fields")
    func testInitialization() {
        let due = Date().addingTimeInterval(86400)
        let reminder = makeReminder(frequency: .weekly, nextDue: due)
        #expect(reminder.title == "Water")
        #expect(reminder.message == "Water your plant")
        #expect(reminder.reminderType == .watering)
        #expect(reminder.frequency == .weekly)
        #expect(reminder.nextDueDate == due)
        #expect(reminder.isEnabled == true)
        #expect(reminder.isRecurring == true)
        #expect(reminder.snoozeCount == 0)
        #expect(reminder.maxSnoozeCount == 3)
        #expect(reminder.priority == .medium)
    }

    // MARK: - calculateNextDueDate

    @Test("calculateNextDueDate for daily adds 1 day")
    func testCalculateNextDueDateDaily() {
        let reminder = makeReminder(frequency: .daily)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 1)
    }

    @Test("calculateNextDueDate for everyOtherDay adds 2 days")
    func testCalculateNextDueDateEveryOtherDay() {
        let reminder = makeReminder(frequency: .everyOtherDay)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 2)
    }

    @Test("calculateNextDueDate for twiceWeekly adds 3 days")
    func testCalculateNextDueDateTwiceWeekly() {
        let reminder = makeReminder(frequency: .twiceWeekly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 3)
    }

    @Test("calculateNextDueDate for weekly adds 7 days")
    func testCalculateNextDueDateWeekly() {
        let reminder = makeReminder(frequency: .weekly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 7)
    }

    @Test("calculateNextDueDate for biweekly adds 14 days")
    func testCalculateNextDueDateBiweekly() {
        let reminder = makeReminder(frequency: .biweekly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 14)
    }

    @Test("calculateNextDueDate for monthly adds 1 month")
    func testCalculateNextDueDateMonthly() {
        let reminder = makeReminder(frequency: .monthly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.month], from: base, to: next).month
        #expect(delta == 1)
    }

    @Test("calculateNextDueDate for quarterly adds 3 months")
    func testCalculateNextDueDateQuarterly() {
        let reminder = makeReminder(frequency: .quarterly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.month], from: base, to: next).month
        #expect(delta == 3)
    }

    @Test("calculateNextDueDate for seasonally adds 6 months")
    func testCalculateNextDueDateSeasonally() {
        let reminder = makeReminder(frequency: .seasonally)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.month], from: base, to: next).month
        #expect(delta == 6)
    }

    @Test("calculateNextDueDate for yearly adds 1 year")
    func testCalculateNextDueDateYearly() {
        let reminder = makeReminder(frequency: .yearly)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.year], from: base, to: next).year
        #expect(delta == 1)
    }

    @Test("calculateNextDueDate for custom uses customFrequencyDays")
    func testCalculateNextDueDateCustom() {
        let reminder = makeReminder(frequency: .custom)
        reminder.customFrequencyDays = 10
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 10)
    }

    @Test("calculateNextDueDate for custom with nil days defaults to 1")
    func testCalculateNextDueDateCustomNilDays() {
        let reminder = makeReminder(frequency: .custom)
        reminder.customFrequencyDays = nil
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        let delta = Calendar.current.dateComponents([.day], from: base, to: next).day
        #expect(delta == 1)
    }

    @Test("calculateNextDueDate for once returns same date")
    func testCalculateNextDueDateOnce() {
        let reminder = makeReminder(frequency: .once)
        let base = Date()
        let next = reminder.calculateNextDueDate(from: base)
        #expect(next == base)
    }

    // MARK: - markCompleted

    @Test("markCompleted sets lastCompletedDate")
    func testMarkCompletedSetsLastCompleted() {
        let reminder = makeReminder(frequency: .weekly)
        let before = Date()
        reminder.markCompleted()
        #expect(reminder.lastCompletedDate != nil)
        #expect(reminder.lastCompletedDate! >= before)
    }

    @Test("markCompleted advances nextDueDate for recurring reminder")
    func testMarkCompletedAdvancesNextDueDate() {
        let reminder = makeReminder(frequency: .weekly)
        let originalDue = reminder.nextDueDate
        reminder.markCompleted()
        #expect(reminder.nextDueDate > originalDue)
        #expect(reminder.isEnabled == true)
    }

    @Test("markCompleted resets snoozeCount")
    func testMarkCompletedResetsSnoozeCount() {
        let reminder = makeReminder(frequency: .weekly)
        reminder.snoozeCount = 2
        reminder.markCompleted()
        #expect(reminder.snoozeCount == 0)
    }

    @Test("markCompleted on non-recurring disables reminder")
    func testMarkCompletedDisablesNonRecurring() {
        let reminder = makeReminder(frequency: .once)
        reminder.isRecurring = false
        reminder.markCompleted()
        #expect(reminder.isEnabled == false)
        #expect(reminder.lastCompletedDate != nil)
    }

    // MARK: - snooze

    @Test("snooze increments snoozeCount")
    func testSnoozeIncrementsCount() {
        let reminder = makeReminder()
        reminder.snooze(for: .oneHour)
        #expect(reminder.snoozeCount == 1)
    }

    @Test("snooze advances nextDueDate beyond current time")
    func testSnoozeAdvancesNextDueDate() {
        let now = Date()
        let reminder = makeReminder(nextDue: now)
        reminder.snooze(for: .oneHour)
        #expect(reminder.nextDueDate > now)
    }

    @Test("snooze at maxSnoozeCount does not increment or move date")
    func testSnoozeAtMaxDoesNotIncrement() {
        let reminder = makeReminder(nextDue: Date())
        reminder.snoozeCount = 3
        reminder.maxSnoozeCount = 3
        let dueBefore = reminder.nextDueDate
        reminder.snooze(for: .oneHour)
        #expect(reminder.snoozeCount == 3)
        #expect(reminder.nextDueDate == dueBefore)
    }

    @Test("snooze for tomorrow advances date by 1 day")
    func testSnoozeTomorrow() {
        let reminder = makeReminder(nextDue: Date())
        let before = Date()
        reminder.snooze(for: .tomorrow)
        let delta = Calendar.current.dateComponents([.day], from: before, to: reminder.nextDueDate).day
        #expect(delta == 1)
    }

    @Test("multiple snoozes increment count each time up to max")
    func testMultipleSnoozes() {
        let reminder = makeReminder()
        reminder.maxSnoozeCount = 3
        reminder.snooze(for: .fifteenMinutes)
        reminder.snooze(for: .thirtyMinutes)
        reminder.snooze(for: .oneHour)
        #expect(reminder.snoozeCount == 3)
        // One more should be blocked
        reminder.snooze(for: .twoHours)
        #expect(reminder.snoozeCount == 3)
    }

    // MARK: - Computed Properties

    @Test("plantName returns default when no plant attached")
    func testPlantNameDefaultWhenNoPlant() {
        let reminder = makeReminder()
        #expect(reminder.plantName == "Your Plant")
    }

    @Test("type computed property equals reminderType")
    func testTypeComputedProperty() {
        let reminder = makeReminder()
        #expect(reminder.type == reminder.reminderType)
    }

    // MARK: - Enum Coverage

    @Test("ReminderFrequency day values for all cases")
    func testReminderFrequencyDayValues() {
        #expect(ReminderFrequency.daily.days == 1)
        #expect(ReminderFrequency.everyOtherDay.days == 2)
        #expect(ReminderFrequency.twiceWeekly.days == 3)
        #expect(ReminderFrequency.weekly.days == 7)
        #expect(ReminderFrequency.biweekly.days == 14)
        #expect(ReminderFrequency.monthly.days == 30)
        #expect(ReminderFrequency.quarterly.days == 90)
        #expect(ReminderFrequency.seasonally.days == 180)
        #expect(ReminderFrequency.yearly.days == 365)
        #expect(ReminderFrequency.custom.days == 0)
        #expect(ReminderFrequency.once.days == 0)
    }

    @Test("ReminderFrequency display names are non-empty")
    func testReminderFrequencyDisplayNames() {
        for freq in ReminderFrequency.allCases {
            #expect(!freq.displayName.isEmpty, "displayName for \(freq.rawValue) should not be empty")
        }
    }

    @Test("ReminderPriority numeric values are strictly ascending")
    func testReminderPriorityNumericOrder() {
        #expect(ReminderPriority.low.numericValue < ReminderPriority.medium.numericValue)
        #expect(ReminderPriority.medium.numericValue < ReminderPriority.high.numericValue)
        #expect(ReminderPriority.high.numericValue < ReminderPriority.critical.numericValue)
    }

    @Test("ReminderPriority color names are non-empty")
    func testReminderPriorityColors() {
        for priority in ReminderPriority.allCases {
            #expect(!priority.color.isEmpty, "color for \(priority.rawValue) should not be empty")
        }
    }

    @Test("ReminderType default messages and notification messages are non-empty")
    func testReminderTypeMessages() {
        for type in ReminderType.allCases {
            #expect(!type.defaultMessage.isEmpty, "defaultMessage for \(type.rawValue) should not be empty")
            #expect(type.notificationMessage == type.defaultMessage)
        }
    }

    @Test("ReminderType icon names are non-empty")
    func testReminderTypeIconNames() {
        for type in ReminderType.allCases {
            #expect(!type.iconName.isEmpty, "iconName for \(type.rawValue) should not be empty")
        }
    }

    @Test("ReminderType display names are non-empty")
    func testReminderTypeDisplayNames() {
        for type in ReminderType.allCases {
            #expect(!type.displayName.isEmpty, "displayName for \(type.rawValue) should not be empty")
        }
    }

    @Test("SnoozeDuration display names are non-empty")
    func testSnoozeDurationDisplayNames() {
        for duration in SnoozeDuration.allCases {
            #expect(!duration.displayName.isEmpty, "displayName for \(duration.rawValue) should not be empty")
        }
    }
}
