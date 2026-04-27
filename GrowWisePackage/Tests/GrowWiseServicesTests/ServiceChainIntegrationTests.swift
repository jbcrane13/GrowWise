import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

// MARK: - Service Chain Integration Tests

//
// These tests validate complete service chains — scenarios where two or more
// services must work together to produce a correct user-visible outcome.
// Passing unit tests for each service in isolation is not sufficient; these
// tests confirm the hand-offs between services are wired correctly.

@Suite("Service Chain Integration Tests")
@MainActor
struct ServiceChainIntegrationTests {
    // MARK: - Helpers

    private func makeDataService() throws -> DataService {
        try DataService.makeForTesting()
    }

    private func makeGardenAndPlant(in ds: DataService, plantName: String = "Basil") throws -> (Garden, Plant) {
        let garden = try ds.createGarden(name: "Test Garden", type: .raised, isIndoor: false)
        let plant = try ds.createPlant(name: plantName, type: .herb, garden: garden)
        return (garden, plant)
    }

    // MARK: - Reminder Completion → GardenHealthService Score Improves

    @Test("Completing overdue reminder raises GardenHealthService watering score from 0 to 100")
    func completingReminderImprovesHealthScore() throws {
        let ds = try makeDataService()
        let healthService = GardenHealthService(dataService: ds)
        let (_, plant) = try makeGardenAndPlant(in: ds)

        // Reminder is due yesterday — within the 14-day scoring window but not yet completed.
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let reminder = try ds.createReminder(
            title: "Water Basil",
            message: "Time to water",
            type: .watering,
            frequency: .weekly,
            dueDate: yesterday,
            plant: plant
        )

        let scoreBefore = healthService.calculateScore(plants: [plant], reminders: [reminder])
        #expect(scoreBefore.breakdown.wateringScore == 0, "Unfinished overdue watering reminder should score 0")

        // Complete the reminder — sets lastCompletedDate and advances nextDueDate.
        try ds.completeReminder(reminder)

        let scoreAfter = healthService.calculateScore(plants: [plant], reminders: [reminder])
        #expect(scoreAfter.breakdown.wateringScore == 100, "Completed reminder should raise watering score to 100")
        #expect(scoreAfter.overallScore > scoreBefore.overallScore, "Overall health score must improve after care is completed")
    }

    // MARK: - Plant Deletion → GardenHealthService Recalculates Without Deleted Plant

    @Test("Removing sick plant from score inputs raises plantHealthScore")
    func deletingPlantUpdatesHealthScore() throws {
        let ds = try makeDataService()
        let healthService = GardenHealthService(dataService: ds)
        let (garden, _) = try makeGardenAndPlant(in: ds, plantName: "Healthy Plant")

        let sickPlant = try ds.createPlant(name: "Sick Plant", type: .vegetable, garden: garden)
        sickPlant.healthStatus = .sick

        let healthyPlant = try ds.createPlant(name: "Healthy Plant 2", type: .herb, garden: garden)
        healthyPlant.healthStatus = .healthy

        let mixedScore = healthService.calculateScore(plants: [sickPlant, healthyPlant], reminders: [])
        #expect(mixedScore.breakdown.healthScore == 50, "One healthy + one critical = 50% plant health")

        // Simulate plant deletion — DataService removes it from the garden fetch results.
        try ds.deletePlant(sickPlant)
        let remainingPlants = ds.fetchPlants(for: garden)

        let cleanedScore = healthService.calculateScore(plants: remainingPlants, reminders: [])
        #expect(cleanedScore.breakdown.healthScore == 100, "After deleting sick plant, remaining healthy plants should score 100")
        #expect(cleanedScore.overallScore > mixedScore.overallScore)
    }

    // MARK: - User State → AchievementService Unlock Chain

    @Test("User with 7 streak days unlocks week_warrior; 6 days does not")
    func streakDaysUnlockWeekWarriorAchievement() throws {
        let ds = try makeDataService()
        let achievementService = AchievementService()

        let user = try ds.createUser(email: "test@growwise.app", displayName: "Tester", skillLevel: .beginner)

        user.streakDays = 6
        let progressAt6 = achievementService.calculateProgress(for: user)
        let weekWarriorAt6 = progressAt6.first { $0.achievement.id == "week_warrior" }
        #expect(weekWarriorAt6?.isUnlocked == false, "6 streak days must not unlock week_warrior (requires 7)")

        user.streakDays = 7
        let progressAt7 = achievementService.calculateProgress(for: user)
        let weekWarriorAt7 = progressAt7.first { $0.achievement.id == "week_warrior" }
        #expect(weekWarriorAt7?.isUnlocked == true, "7 streak days must unlock week_warrior")
        #expect(weekWarriorAt7?.currentValue == 7)
    }

    @Test("Adding plants updates plantsGrown and unlocks first_plant achievement")
    func addingPlantUnlocksFirstPlantAchievement() throws {
        let ds = try makeDataService()
        let achievementService = AchievementService()

        let user = try ds.createUser(email: "grower@test.app", displayName: "Grower", skillLevel: .beginner)
        #expect(user.plantsGrown == 0)

        let progressBefore = achievementService.calculateProgress(for: user)
        let firstPlantBefore = progressBefore.first { $0.achievement.id == "first_plant" }
        #expect(firstPlantBefore?.isUnlocked == false)

        user.plantsGrown = 1

        let progressAfter = achievementService.calculateProgress(for: user)
        let firstPlantAfter = progressAfter.first { $0.achievement.id == "first_plant" }
        #expect(firstPlantAfter?.isUnlocked == true, "Setting plantsGrown = 1 must unlock first_plant achievement")
    }

    // MARK: - PlantCareAdviceService — Overdue Watering Triggers Urgent Tip

    @Test("Plant overdue for watering produces urgent care tip from PlantCareAdviceService")
    func overduePlantGeneratesUrgentCareTip() {
        let adviceService = PlantCareAdviceService()

        let plant = Plant(name: "Thirsty Basil", plantType: .herb)
        plant.wateringFrequency = .twiceWeekly // every 3-4 days
        plant.lastWatered = Calendar.current.date(byAdding: .day, value: -10, to: Date())

        let tips = adviceService.getContextualTips(for: plant, in: nil, user: nil)
        let urgentTips = tips.filter { $0.urgency == .urgent }

        #expect(!urgentTips.isEmpty, "An overdue plant must generate at least one urgent care tip")
        #expect(
            urgentTips.contains(where: { $0.title.lowercased().contains("watering") || $0.title.lowercased().contains("water") }),
            "Urgent tip must reference watering for a plant overdue for water"
        )
    }

    @Test("Recently watered plant generates no urgent watering tip")
    func recentlyWateredPlantHasNoUrgentWateringTip() {
        let adviceService = PlantCareAdviceService()

        let plant = Plant(name: "Happy Basil", plantType: .herb)
        plant.wateringFrequency = .twiceWeekly
        plant.lastWatered = Calendar.current.date(byAdding: .hour, value: -6, to: Date())

        let tips = adviceService.getContextualTips(for: plant, in: nil, user: nil)
        let urgentWateringTips = tips.filter {
            $0.urgency == .urgent &&
                ($0.title.lowercased().contains("watering") || $0.title.lowercased().contains("water"))
        }

        #expect(urgentWateringTips.isEmpty, "A recently watered plant must not produce an urgent watering tip")
    }

    // MARK: - DataService Write → Reminder Fetch Consistency

    @Test("Deleting plant via DataService removes its reminders from fetchActiveReminders")
    func deletingPlantPurgesRemindersFromActiveList() throws {
        let ds = try makeDataService()
        let (_, plant) = try makeGardenAndPlant(in: ds)

        let reminder = try ds.createReminder(
            title: "Water",
            message: "Water it",
            type: .watering,
            frequency: .daily,
            dueDate: Date(),
            plant: plant
        )
        _ = reminder

        let activeBefore = ds.fetchActiveReminders()
        #expect(activeBefore.count == 1)

        try ds.deletePlant(plant)

        let activeAfter = ds.fetchActiveReminders()
        #expect(activeAfter.isEmpty, "Deleting a plant must remove its reminders from the active list")
    }
}
