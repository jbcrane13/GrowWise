@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("Starter plan service")
struct StarterPlanServiceTests {
    @Test("starter plan asks skipped-garden users to create a garden")
    func starterPlanAsksSkippedGardenUsersToCreateGarden() throws {
        let dataService = try makeDataService()

        let plan = try dataService.buildStarterPlan()

        #expect(plan.actions.map(\.kind) == [.createGarden, .startTutorial])
    }

    @Test("starter plan asks users with a garden but no plants to add and browse")
    func starterPlanAsksGardenOnlyUsersToAddAndBrowse() throws {
        let dataService = try makeDataService(goals: [.growFood])
        _ = try dataService.createGarden(name: "Patio Garden", type: .container, isIndoor: false)

        let plan = try dataService.buildStarterPlan()

        #expect(plan.actions.map(\.kind) == [.addPlant, .browseRecommendations, .startTutorial])
    }

    @Test("starter plan surfaces first watering reminder from persisted state")
    func starterPlanSurfacesFirstWateringReminder() throws {
        let dataService = try makeDataService(goals: [.growFood])
        let garden = try dataService.createGarden(name: "Kitchen Garden", type: .container, isIndoor: false)
        let template = Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner, isUserPlant: false)
        template.wateringFrequency = .weekly
        _ = try dataService.createStarterPlant(from: template, in: garden)

        let plan = try dataService.buildStarterPlan()

        #expect(plan.actions.first?.kind == .reviewWateringReminder)
        #expect(plan.actions.first?.title == "Review your watering reminder")
    }

    @Test("starter plan clears when starter work is complete")
    func starterPlanClearsWhenStarterWorkIsComplete() throws {
        let dataService = try makeDataService(goals: [.growFood])
        let user = try #require(dataService.getCurrentUser())
        let garden = try dataService.createGarden(name: "Kitchen Garden", type: .container, isIndoor: false)
        let template = Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner, isUserPlant: false)
        let result = try dataService.createStarterPlant(from: template, in: garden)
        _ = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        try dataService.completeReminder(result.reminder)
        user.completedTutorials = ["getting-started-indoor-plants"]
        try dataService.updateUser(user)

        let plan = try dataService.buildStarterPlan()

        #expect(plan.actions.isEmpty)
    }

    private func makeDataService(goals: [GardeningGoal] = []) throws -> DataService {
        let dataService = try DataService.makeForTesting()
        let user = try dataService.createUser(
            email: "gardener@example.com",
            displayName: "Gardener",
            skillLevel: .beginner
        )
        try dataService.updateOnboardingProfile(
            for: user,
            gardeningGoals: goals,
            preferredPlantTypes: [.vegetable, .herb]
        )
        return dataService
    }
}
