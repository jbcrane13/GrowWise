import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("Starter roadmap service — 1.1 multi-day plan")
struct StarterRoadmapServiceTests {
    @Test("nil user yields an empty roadmap")
    func emptyForNilUser() {
        let roadmap = StarterRoadmapService.build(
            user: nil,
            gardens: [],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        #expect(roadmap.steps.isEmpty)
    }

    @Test("fully onboarded user gets a multi-step roadmap")
    func fullyOnboardedUserGetsMultiStepRoadmap() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Basil", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        #expect(roadmap.steps.count >= 4)
    }

    @Test("roadmap spans between seven and fourteen days")
    func roadmapSpansSevenToFourteenDays() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Basil", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let offsets = roadmap.steps.map(\.dayOffset)
        let minOffset = offsets.min() ?? 0
        let maxOffset = offsets.max() ?? 0

        #expect(minOffset >= 0)
        #expect(maxOffset >= 6)
        #expect(maxOffset <= 13)
    }

    @Test("steps are ordered by day offset")
    func stepsAreOrderedByDayOffset() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Basil", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let offsets = roadmap.steps.map(\.dayOffset)
        #expect(offsets == offsets.sorted())
    }

    @Test("first plant name appears somewhere in the roadmap")
    func firstPlantNameAppearsInRoadmap() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Cherry Tomato", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let plantMentioned = roadmap.steps.contains { step in
            step.title.localizedCaseInsensitiveContains("Cherry Tomato") ||
                step.detail.localizedCaseInsensitiveContains("Cherry Tomato")
        }
        #expect(plantMentioned)
    }

    @Test("beginner skill level surfaces a learning step")
    func beginnerSkillLevelSurfacesLearningStep() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Basil", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let hasLearningStep = roadmap.steps.contains { step in
            let text = (step.title + " " + step.detail).lowercased()
            return text.contains("tutorial") || text.contains("learn")
        }
        #expect(hasLearningStep)
    }

    @Test("grow-food goal surfaces food-oriented content")
    func growFoodGoalSurfacesFoodContent() {
        let user = makeUser(skillLevel: .intermediate, goals: [.growFood])
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(named: "Basil", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let hasFoodContent = roadmap.steps.contains { step in
            let text = (step.title + " " + step.detail).lowercased()
            return text.contains("food") || text.contains("edible") || text.contains("harvest")
        }
        #expect(hasFoodContent)
    }

    @Test("indoor garden type yields indoor-relevant guidance")
    func indoorGardenTypeYieldsIndoorGuidance() {
        let user = makeUser(skillLevel: .beginner, goals: [.beautifySpace])
        let garden = makeGarden(type: .indoor, isIndoor: true)
        let plant = makePlant(named: "Pothos", in: garden)

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let hasIndoorGuidance = roadmap.steps.contains { step in
            let text = (step.title + " " + step.detail).lowercased()
            return text.contains("light") || text.contains("window") || text.contains("indoor")
        }
        #expect(hasIndoorGuidance)
    }

    @Test("gardenless user starts with create-a-garden on day zero")
    func gardenlessUserStartsWithCreateGardenOnDayZero() {
        let user = makeUser(skillLevel: .beginner, goals: [.growFood])

        let roadmap = StarterRoadmapService.build(
            user: user,
            gardens: [],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        let firstStep = roadmap.steps.first
        #expect(firstStep?.dayOffset == 0)

        let firstTitle = firstStep?.title.lowercased() ?? ""
        #expect(firstTitle.contains("garden"))
    }

    // MARK: - Helpers

    private func makeUser(
        skillLevel: GardeningSkillLevel,
        goals: [GardeningGoal]
    ) -> User {
        let user = User(
            email: "gardener@example.com",
            displayName: "Gardener",
            skillLevel: skillLevel
        )
        user.gardeningGoals = goals
        return user
    }

    private func makeGarden(type: GardenType, isIndoor: Bool) -> Garden {
        Garden(name: "Test Garden", gardenType: type, isIndoor: isIndoor)
    }

    private func makePlant(named name: String, in garden: Garden) -> Plant {
        let plant = Plant(
            name: name,
            plantType: .vegetable,
            difficultyLevel: .beginner,
            isUserPlant: true
        )
        plant.garden = garden
        return plant
    }
}
