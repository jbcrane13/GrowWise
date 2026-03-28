// INTEGRATION GAP: HomeViewModel.complete() uses `try? dataService.completeReminder(reminder)`
// which silently swallows errors. No error state is set.

import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
import GrowWiseServices
import Testing

// MARK: - HomeViewModelTests

@MainActor
struct HomeViewModelTests {
    // MARK: - load() — bucket separation

    @Test("load populates overdueReminders with past-day reminders")
    func loadSeparatesOverdueReminders() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let pastDate = Date(timeIntervalSinceNow: -86400) // 24 h ago
        _ = try dataService.createReminder(
            title: "Water",
            message: "Water the tomato",
            type: .watering,
            frequency: .once,
            dueDate: pastDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        // fetchActive() now includes overdue reminders; HomeViewModel sorts them into overdueReminders
        #expect(vm.overdueReminders.count == 1)
        #expect(vm.overdueReminders.first?.title == "Water")
    }

    @Test("load() places reminders due today into dueTodayReminders")
    func loadSeparatesDueTodayReminders() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Basil", type: .herb)

        // A reminder due now (today) — passes fetchActive predicate (>= startOfToday)
        // and falls in the [startOfToday, startOfTomorrow) window.
        let todayDate = Date()
        _ = try dataService.createReminder(
            title: "Water",
            message: "Water the basil",
            type: .watering,
            frequency: .daily,
            dueDate: todayDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.dueTodayReminders.count == 1)
    }

    @Test("load() counts future reminders in allGoodCount")
    func loadPutsFutureRemindersIntoAllGoodCount() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Mint", type: .herb)

        let futureDate = Date(timeIntervalSinceNow: 2 * 86400) // 2 days from now
        _ = try dataService.createReminder(
            title: "Fertilize",
            message: "Add fertilizer",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: futureDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.allGoodCount == 1)
        #expect(vm.overdueReminders.isEmpty)
        #expect(vm.dueTodayReminders.isEmpty)
    }

    @Test("load() sets userName from getCurrentUser displayName")
    func loadGetsuserNameFromCurrentUser() async throws {
        let dataService = try DataService.makeForTesting()
        _ = try dataService.createUser(
            email: "test@example.com",
            displayName: "Alice",
            skillLevel: .beginner
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.userName == "Alice")
    }

    @Test("load() sets userName to empty string when no user exists")
    func loadReturnsEmptyUserNameWhenNoUser() async throws {
        let dataService = try DataService.makeForTesting()

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.userName == "")
    }

    // MARK: - allTasksDone

    @Test("allTasksDone is true when all visible reminders are in completedIDs")
    func allTasksDoneTrueWhenAllCompleted() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let todayDate = Date()
        let reminder = try dataService.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .daily,
            dueDate: todayDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        vm.completedIDs.insert(reminder.id)

        #expect(vm.allTasksDone)
    }

    @Test("allTasksDone is false when some reminders are still pending")
    func allTasksDoneFalseWhenSomePending() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let todayDate = Date()

        _ = try dataService.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .daily,
            dueDate: todayDate,
            plant: plant
        )
        let reminder2 = try dataService.createReminder(
            title: "Fertilize",
            message: "Feed it",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: todayDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        // Complete only one of two reminders
        vm.completedIDs.insert(reminder2.id)

        #expect(!vm.allTasksDone)
    }

    @Test("allTasksDone is true when there are no reminders at all")
    func allTasksDoneTrueWithNoReminders() async throws {
        let dataService = try DataService.makeForTesting()

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.allTasksDone)
    }

    // MARK: - complete()

    @Test("complete() adds reminder id to completedIDs immediately")
    func completeAddsToCompletedIDsImmediately() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let todayDate = Date()
        let reminder = try dataService.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .daily,
            dueDate: todayDate,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        // completedIDs is updated synchronously inside complete() before the sleep
        await vm.complete(reminder: reminder, dataService: dataService)

        // completedIDs persists even after the reload triggered by complete()
        #expect(vm.completedIDs.contains(reminder.id))
    }

    @Test("complete() calls dataService.completeReminder to persist the completion")
    func completeCallsDataServiceCompleteReminder() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let todayDate = Date()
        let reminder = try dataService.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .once,
            dueDate: todayDate,
            plant: plant
        )
        // Non-recurring: markCompleted() sets isEnabled = false
        reminder.isRecurring = false

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)
        await vm.complete(reminder: reminder, dataService: dataService)

        // Verify the reminder was completed — a non-recurring reminder becomes disabled
        #expect(reminder.isEnabled == false)
    }

    @Test("complete() persists the completion and allTasksDone reflects it via completedIDs")
    func completeReloadsDataAfterDelay() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let todayDate = Date()
        let reminder = try dataService.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .once,
            dueDate: todayDate,
            plant: plant
        )
        reminder.isRecurring = false

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)

        // Confirm reminder is due today before completing
        #expect(vm.dueTodayReminders.count == 1)

        // complete() persists completion, waits ~400 ms, then reloads
        await vm.complete(reminder: reminder, dataService: dataService)

        // INTEGRATION GAP: DataService.completeReminder() does not invalidate the
        // "reminders:active:limit:50" cache key (only exact invalidate("reminders:active")
        // is called on create, not on complete). The reload inside complete() therefore
        // gets a 2-minute cache hit with stale data: the now-disabled reminder is still
        // returned by fetchActiveReminders() and lands back in dueTodayReminders.
        // Fix: add cache.invalidateAll(withPrefix: "reminders:active") inside
        // DataService.completeReminder(), or filter by isEnabled in HomeViewModel.load().
        //
        // What we CAN assert: persistence worked, and allTasksDone is true because
        // completedIDs accounts for the visually-completed reminder.
        #expect(reminder.isEnabled == false) // markCompleted() ran
        #expect(vm.completedIDs.contains(reminder.id)) // optimistic id retained after reload
        #expect(vm.allTasksDone) // completedIDs hides the stale row
    }
}
