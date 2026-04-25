import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// SeedInventoryService is in GrowWiseServices (imported above)

/// Observable view-model for the Home tab care dashboard.
/// Loads active reminders from DataService and separates them into
/// overdue vs. due-today buckets. Handles optimistic complete animation.
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Published State

    var overdueReminders: [PlantReminder] = []
    var dueTodayReminders: [PlantReminder] = []
    var allGoodCount: Int = 0
    var totalPlantCount: Int = 0
    var isLoading = false
    var userName: String = ""

    /// Seeds that are ready to start indoors based on zone and current date.
    var readyToPlantSeeds: [Seed] = []
    /// User's hardiness zone, resolved on load.
    var hardinessZone: String?

    /// Most-recent ClubActivity across all clubs. Displayed in the Home "Your Club" card.
    var latestClubPost: ClubActivity?

    /// IDs of reminders the user has tapped "Done" on — used to filter them
    /// from the list with a slide-away animation before the next data reload.
    var completedIDs: Set<UUID> = []

    // MARK: - Private Services

    private let seedService = SeedInventoryService()

    /// Error message surfaced to the user when a complete operation fails.
    var errorMessage: String?

    // MARK: - Derived

    var allTasksDone: Bool {
        pendingOverdueReminders.isEmpty && pendingTodayReminders.isEmpty
    }

    var visibleCareReminders: [PlantReminder] {
        Array((pendingOverdueReminders + pendingTodayReminders).prefix(3))
    }

    var visibleCareTaskCount: Int {
        pendingOverdueReminders.count + pendingTodayReminders.count
    }

    var visibleOverdueCount: Int {
        pendingOverdueReminders.count
    }

    private var pendingOverdueReminders: [PlantReminder] {
        overdueReminders
            .filter { !completedIDs.contains($0.id) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var pendingTodayReminders: [PlantReminder] {
        dueTodayReminders
            .filter { !completedIDs.contains($0.id) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    // MARK: - Load

    @MainActor
    func load(dataService: DataService) async {
        isLoading = true

        // Resolve user display name
        userName = dataService.getCurrentUser()?.displayName ?? ""

        // Fetch all active reminders
        let all = dataService.fetchActiveReminders()

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        overdueReminders = all.filter { $0.nextDueDate < startOfToday }
        dueTodayReminders = all.filter { $0.nextDueDate >= startOfToday && $0.nextDueDate < startOfTomorrow }

        // "All Good" = enabled reminders that aren't overdue or due today
        let urgentIDs = Set((overdueReminders + dueTodayReminders).map(\.id))
        allGoodCount = all.count(where: { !urgentIDs.contains($0.id) })

        do {
            totalPlantCount = try dataService.plants.fetchAll().count
        } catch {
            totalPlantCount = 0
            errorMessage = "Failed to load plants: \(error.localizedDescription)"
        }

        // Resolve ready-to-plant seeds
        let user = dataService.getCurrentUser()
        hardinessZone = user?.hardinessZone
        let allSeeds: [Seed]
        do {
            allSeeds = try dataService.seeds.fetchAll()
        } catch {
            allSeeds = []
            errorMessage = "Failed to load seeds: \(error.localizedDescription)"
        }
        readyToPlantSeeds = seedService.readyToPlant(seeds: allSeeds, zone: hardinessZone ?? "6", currentDate: Date())

        // Latest club post for the Home "Your Club" card
        do {
            latestClubPost = try dataService.fetchLatestClubActivity()
        } catch {
            Logger(subsystem: "com.growwise", category: "HomeViewModel")
                .error("latestClubPost fetch failed: \(error.localizedDescription, privacy: .public)")
            latestClubPost = nil
        }

        isLoading = false
    }

    // MARK: - Complete

    @MainActor
    func complete(reminder: PlantReminder, dataService: DataService) async {
        // Optimistic: slide the row away immediately
        _ = withAnimation(CultivationTheme.Animation.card) {
            completedIDs.insert(reminder.id)
        }

        // Persist reminder completion and update plant care date
        do {
            try dataService.completeReminder(reminder)

            // Update the plant's last-care timestamp for the relevant type
            // SwiftData auto-persists property mutations on managed objects.
            if let plant = reminder.plant {
                switch reminder.reminderType {
                case .watering:
                    plant.lastWatered = Date()

                case .fertilizing:
                    plant.lastFertilized = Date()

                case .pruning:
                    plant.lastPruned = Date()

                default:
                    break
                }
            }
        } catch {
            // Roll back optimistic UI and surface the error
            _ = withAnimation(CultivationTheme.Animation.card) {
                completedIDs.remove(reminder.id)
            }
            errorMessage = "Failed to complete reminder: \(error.localizedDescription)"
            return
        }

        // After animation settles, reload to get fresh state (updated nextDueDate etc.)
        try? await Task.sleep(nanoseconds: 400_000_000)
        await load(dataService: dataService)
    }
}
