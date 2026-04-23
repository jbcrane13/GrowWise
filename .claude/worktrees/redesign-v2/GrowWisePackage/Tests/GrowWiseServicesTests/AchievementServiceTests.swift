import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

// MARK: - AchievementService Tests

@Suite("AchievementService Tests")
@MainActor
struct AchievementServiceTests {
    // MARK: - Helpers

    /// Creates an in-memory ModelContainer registering all needed model types.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: User.self, Garden.self, JournalEntry.self, Plant.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Creates a fresh User inserted into the given container's main context.
    private func makeUser(in container: ModelContainer) -> User {
        let user = User(email: "test@growwise.app", displayName: "Tester")
        container.mainContext.insert(user)
        return user
    }

    // MARK: - Static Catalog Tests

    @Test("allAchievements contains exactly 21 achievements")
    func allAchievementsCount() {
        #expect(AchievementService.allAchievements.count == 21)
    }

    @Test("allAchievements covers all 6 categories")
    func allAchievementsCoverAllCategories() {
        let categories = Set(AchievementService.allAchievements.map(\.category))
        #expect(categories == Set(AchievementCategory.allCases))
    }

    @Test("Every achievement has non-empty id, name, description, and icon")
    func achievementFieldsNonEmpty() {
        for achievement in AchievementService.allAchievements {
            #expect(!achievement.id.isEmpty, "Achievement id is empty")
            #expect(!achievement.name.isEmpty, "Achievement '\(achievement.id)' has empty name")
            #expect(!achievement.description.isEmpty, "Achievement '\(achievement.id)' has empty description")
            #expect(!achievement.icon.isEmpty, "Achievement '\(achievement.id)' has empty icon")
        }
    }

    // MARK: - calculateProgress Tests

    @Test("calculateProgress returns progress for every achievement")
    func calculateProgressCoversAllAchievements() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        let progress = service.calculateProgress(for: user)
        #expect(progress.count == AchievementService.allAchievements.count)
    }

    @Test("Brand new user has no unlocked achievements")
    func newUserHasNoUnlockedAchievements() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        // Ensure all seasonal conditions are also unmet
        user.plantsGrown = 0
        user.plantsHarvested = 0
        user.streakDays = 0
        user.completedTutorials = []
        user.gardens = []
        user.journalEntries = []

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.isEmpty)
    }

    // MARK: - Getting Started Achievements

    @Test("User with 1 plant unlocks first_plant achievement")
    func firstPlantAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.plantsGrown = 1

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "first_plant" }))
    }

    @Test("User with 1 garden unlocks garden_creator achievement")
    func gardenCreatorAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        let garden = Garden(name: "Test Garden")
        container.mainContext.insert(garden)
        user.gardens = [garden]

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "garden_creator" }))
    }

    @Test("User with 1 journal entry unlocks journal_starter achievement")
    func journalStarterAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        let entry = JournalEntry(title: "First Entry", content: "Hello garden!")
        container.mainContext.insert(entry)
        user.journalEntries = [entry]

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "journal_starter" }))
    }

    // MARK: - Growth Milestone Achievements

    @Test("User with 5 plants unlocks green_thumb achievement")
    func greenThumbAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.plantsGrown = 5

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "green_thumb" }))
    }

    @Test("User with 10 plants unlocks both plant_parent and green_thumb")
    func plantParentUnlocksGreenThumbToo() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.plantsGrown = 10

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "plant_parent" }))
        #expect(unlocked.contains(where: { $0.id == "green_thumb" }))
    }

    // MARK: - Harvest Achievements

    @Test("User with 1 harvest unlocks first_harvest achievement")
    func firstHarvestAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.plantsHarvested = 1

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "first_harvest" }))
    }

    // MARK: - Streak Achievements

    @Test("User with 7 streak days unlocks week_warrior achievement")
    func weekWarriorAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.streakDays = 7

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "week_warrior" }))
    }

    // MARK: - Learning Achievements

    @Test("User with 5 completed tutorials unlocks tutorial_explorer achievement")
    func tutorialExplorerAchievement() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        user.completedTutorials = ["t1", "t2", "t3", "t4", "t5"]

        let unlocked = service.unlockedAchievements(for: user)
        #expect(unlocked.contains(where: { $0.id == "tutorial_explorer" }))
    }

    // MARK: - totalPoints Tests

    @Test("totalPoints returns zero for a brand new user")
    func totalPointsNewUser() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        user.plantsGrown = 0
        user.plantsHarvested = 0
        user.streakDays = 0
        user.completedTutorials = []
        user.gardens = []
        user.journalEntries = []

        let service = AchievementService()
        #expect(service.totalPoints(for: user) == 0)
    }

    @Test("totalPoints sums only unlocked achievement pointsValues")
    func totalPointsSumsUnlockedOnly() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        // Unlock exactly: first_plant (10pts) and green_thumb (25pts) = 35 pts
        // No harvest, no streak, no journal, no garden — avoid seasonal unlocks
        user.plantsGrown = 5
        user.plantsHarvested = 0
        user.streakDays = 0
        user.completedTutorials = []
        user.gardens = []
        user.journalEntries = []

        let unlocked = service.unlockedAchievements(for: user)
        let expectedPoints = unlocked.reduce(0) { $0 + $1.pointsValue }
        #expect(service.totalPoints(for: user) == expectedPoints)
    }

    @Test("totalPoints increases when more achievements are unlocked")
    func totalPointsIncreasesWithMoreAchievements() throws {
        let container = try makeContainer()
        let service = AchievementService()

        let user1 = makeUser(in: container)
        user1.plantsGrown = 1

        let user2 = makeUser(in: container)
        user2.plantsGrown = 10

        #expect(service.totalPoints(for: user2) > service.totalPoints(for: user1))
    }

    // MARK: - progressByCategory Tests

    @Test("progressByCategory groups achievements by category with correct counts")
    func progressByCategoryGrouping() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        let grouped = service.progressByCategory(for: user)

        // All 6 categories must be represented
        #expect(grouped.count == AchievementCategory.allCases.count)

        // Each group's items should match the achievements for that category
        for group in grouped {
            let expected = AchievementService.allAchievements.count(where: { $0.category == group.category })
            #expect(group.items.count == expected)
        }
    }

    @Test("progressByCategory item categories match their group's category")
    func progressByCategoryCategoryConsistency() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        let grouped = service.progressByCategory(for: user)
        for group in grouped {
            for item in group.items {
                #expect(item.achievement.category == group.category)
            }
        }
    }

    // MARK: - Progress Ratio Tests

    @Test("Progress ratio is clamped to 1.0 when current value exceeds requirement")
    func progressRatioClampedAtOne() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        // first_plant has requirement of 1 — set plantsGrown to 100
        user.plantsGrown = 100

        let progress = service.calculateProgress(for: user)
        let firstPlant = try #require(progress.first(where: { $0.id == "first_plant" }))
        #expect(firstPlant.progress <= 1.0)
        #expect(firstPlant.progress == 1.0)
    }

    @Test("Progress ratio for zero-requirement achievements does not divide by zero")
    func progressRatioSafeForZeroRequirement() throws {
        // The service uses max(requirement, 1) — even if requirement were 0, no crash.
        // We test this indirectly: all real achievements have requirement >= 1.
        let allRequirements = AchievementService.allAchievements.map(\.requirement)
        for req in allRequirements {
            #expect(req >= 1)
        }

        // And progress computation on a new user returns valid (non-NaN) ratios
        let container = try makeContainer()
        let user = makeUser(in: container)
        user.plantsGrown = 0
        user.plantsHarvested = 0
        user.streakDays = 0
        user.completedTutorials = []
        user.gardens = []
        user.journalEntries = []

        let service = AchievementService()
        let progress = service.calculateProgress(for: user)
        for item in progress {
            #expect(!item.progress.isNaN)
            #expect(item.progress >= 0.0)
            #expect(item.progress <= 1.0)
        }
    }

    @Test("Partial progress is between 0 and 1 when user has some but not full requirement")
    func partialProgressInRange() throws {
        let container = try makeContainer()
        let user = makeUser(in: container)
        let service = AchievementService()

        // plant_parent requires 10; set 5 for exactly 50% progress
        user.plantsGrown = 5

        let progress = service.calculateProgress(for: user)
        let plantParent = try #require(progress.first(where: { $0.id == "plant_parent" }))
        #expect(plantParent.progress > 0.0)
        #expect(plantParent.progress < 1.0)
        #expect(plantParent.isUnlocked == false)
        #expect(abs(plantParent.progress - 0.5) < 0.001)
    }
}
