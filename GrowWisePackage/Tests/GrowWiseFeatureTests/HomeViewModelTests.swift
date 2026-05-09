import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - HomeViewModelTests

@Suite(.serialized)
@MainActor
struct HomeViewModelTests {
    // MARK: - load() — bucket separation

    @Test("load populates overdueReminders with past-day reminders")
    func loadSeparatesOverdueReminders() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let oneDay: TimeInterval = 24 * 60 * 60
        let pastDate = Date(timeIntervalSinceNow: -oneDay)
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

        let oneDay: TimeInterval = 24 * 60 * 60
        let futureDate = Date(timeIntervalSinceNow: 2 * oneDay)
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

        #expect(vm.userName.isEmpty)
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

    @Test("visibleCareReminders shows at most three pending tasks with overdue first")
    func visibleCareRemindersLimitsPendingTasksWithOverdueFirst() async throws {
        let dataService = try DataService.makeForTesting()
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: startOfToday) ?? Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? Date()
        let laterToday = calendar.date(byAdding: .hour, value: 10, to: startOfToday) ?? Date()
        let tonight = calendar.date(byAdding: .hour, value: 20, to: startOfToday) ?? Date()

        let oldestOverdue = try dataService.createReminder(
            title: "Water tomatoes",
            message: "Water the tomato bed",
            type: .watering,
            frequency: .daily,
            dueDate: twoDaysAgo,
            plant: plant
        )
        let completedOverdue = try dataService.createReminder(
            title: "Feed roses",
            message: "Feed the roses",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: yesterday,
            plant: plant
        )
        let dueToday = try dataService.createReminder(
            title: "Prune basil",
            message: "Prune the basil",
            type: .pruning,
            frequency: .weekly,
            dueDate: laterToday,
            plant: plant
        )
        let laterDueToday = try dataService.createReminder(
            title: "Inspect peppers",
            message: "Check the pepper leaves",
            type: .inspection,
            frequency: .weekly,
            dueDate: tonight,
            plant: plant
        )

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)
        vm.completedIDs.insert(completedOverdue.id)

        #expect(vm.visibleCareReminders.map(\.title) == [oldestOverdue.title, dueToday.title, laterDueToday.title])
        #expect(vm.visibleCareReminders.count == 3)
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

    @Test("complete() does not set errorMessage on success")
    func completeDoesNotSetErrorOnSuccess() async throws {
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

        let vm = HomeViewModel()
        await vm.load(dataService: dataService)
        await vm.complete(reminder: reminder, dataService: dataService)

        #expect(vm.errorMessage == nil)
        #expect(vm.completedIDs.contains(reminder.id))
    }

    @Test("complete() reloads without stale completed reminders")
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

        #expect(reminder.isEnabled == false) // markCompleted() ran
        #expect(vm.completedIDs.contains(reminder.id)) // optimistic id retained after reload
        #expect(vm.dueTodayReminders.isEmpty) // reload no longer reads stale active-reminder cache
        #expect(vm.allTasksDone) // completed reminder is no longer pending
    }

    // MARK: - latestClubPost

    @Test("load populates latestClubPost when a club activity exists")
    func loadPopulatesLatestClubPost() async throws {
        let service = try await DataService.makeForTesting()
        // Create a minimal club + activity via mainContext directly.
        let clubID = UUID()
        let club = GardenClub(name: "Test Club", ownerID: "user-1", inviteCode: "TEST01")
        club.id = clubID
        service.mainContext.insert(club)

        let activity = ClubActivity(
            clubID: clubID,
            memberName: "Alice",
            memberID: "user-2",
            activityType: "journaled",
            description: "My tomato bloomed!"
        )
        activity.timestamp = Date()
        service.mainContext.insert(activity)
        try service.mainContext.save()

        let vm = HomeViewModel()
        await vm.load(dataService: service)

        #expect(vm.latestClubPost != nil)
        #expect(vm.latestClubPost?.activityDescription == "My tomato bloomed!")
    }
}
