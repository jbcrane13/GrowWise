@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("Starter plan service — #341 14-day roadmap")
struct StarterPlanServiceTests {
    // MARK: - Helpers

    private func makeUser(
        skillLevel: GardeningSkillLevel = .beginner,
        goals: [GardeningGoal] = [],
        preferredTypes: [PlantType] = [],
        completedTutorials: [String] = []
    ) -> User {
        let user = User(
            email: "gardener@example.com",
            displayName: "Gardener",
            skillLevel: skillLevel
        )
        user.gardeningGoals = goals
        user.preferredPlantTypes = preferredTypes
        user.completedTutorials = completedTutorials
        return user
    }

    private func makeGarden(
        type: GardenType = .container,
        isIndoor: Bool = false,
        createdDaysAgo: Int = 30
    ) -> Garden {
        let garden = Garden(name: "Test Garden", gardenType: type, isIndoor: isIndoor)
        garden.createdDate = Calendar.current.date(byAdding: .day, value: -createdDaysAgo, to: Date())
        return garden
    }

    private func makePlant(
        name: String = "Basil",
        type: PlantType = .herb,
        garden: Garden? = nil,
        lastFertilized: Date? = Date(),
        growthStage: GrowthStage = .vegetative,
        isUserPlant: Bool = true
    ) -> Plant {
        let plant = Plant(name: name, plantType: type, difficultyLevel: .beginner, isUserPlant: isUserPlant)
        plant.garden = garden
        plant.lastFertilized = lastFertilized
        plant.growthStage = growthStage
        return plant
    }

    // MARK: - roadmapLength

    @Test("roadmap contains exactly 14 days")
    func roadmapHasFourteenDays() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        #expect(plan.days.count == 14)
    }

    @Test("days span day 0 through day 13")
    func daysSpanZeroToThirteen() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let offsets = plan.days.map(\.dayOffset)
        #expect(offsets.min() == 0)
        #expect(offsets.max() == 13)
    }

    @Test("day offset 0 has today's date")
    func dayOffsetZeroHasToday() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden)
        let today = Date()

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: today
        )

        let day0 = plan.days.first { $0.dayOffset == 0 }
        #expect(day0 != nil)
        #expect(Calendar.current.isDate(day0!.date, inSameDayAs: today))
    }

    @Test("day offsets are sequential with no gaps")
    func dayOffsetsAreSequential() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let offsets = plan.days.map(\.dayOffset).sorted()
        #expect(offsets == Array(0..<14))
    }

    // MARK: - No gardens case

    @Test("no gardens: day 0 has setup task")
    func noGardensDayZeroHasSetupTask() {
        let user = makeUser(goals: [.growFood])

        let plan = StarterPlanService.build(
            user: user,
            gardens: [],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        let day0 = plan.days.first { $0.dayOffset == 0 }
        #expect(day0?.tasks.first?.kind == .setup)
        #expect(day0?.tasks.first?.title.contains("garden") == true)
    }

    @Test("no gardens: legacy actions include createGarden")
    func noGardensLegacyActionsIncludeCreateGarden() {
        let user = makeUser()

        let plan = StarterPlanService.build(
            user: user,
            gardens: [],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        #expect(plan.actions.contains { $0.kind == .createGarden } == true)
    }

    // MARK: - No plants case

    @Test("no plants: day 0 has plant task")
    func noPlantsDayZeroHasPlantTask() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        let day0 = plan.days.first { $0.dayOffset == 0 }
        #expect((day0?.tasks.contains { $0.kind == .plant }) == true)
    }

    @Test("no plants: legacy actions include addPlant")
    func noPlantsLegacyActionsIncludeAddPlant() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [],
            reminders: [],
            referenceDate: Date()
        )

        #expect(plan.actions.contains { $0.kind == .addPlant } == true)
    }

    // MARK: - Active garden with plants

    @Test("active garden: day 0 includes inspection task with plant name")
    func activeGardenDayZeroHasInspectionTask() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(name: "Cherry Tomato", garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day0 = plan.days.first { $0.dayOffset == 0 }
        let inspectTask = day0?.tasks.first { $0.kind == .inspect }
        #expect(inspectTask != nil)
        #expect(inspectTask?.plantName == "Cherry Tomato")
    }

    @Test("active garden with beginner user: day 0 includes learning task")
    func beginnerUserDayZeroHasLearningTask() {
        let user = makeUser(skillLevel: .beginner)
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day0 = plan.days.first { $0.dayOffset == 0 }
        #expect((day0?.tasks.contains { $0.kind == .learn }) == true)
    }

    @Test("active garden: day 1 includes water task")
    func activeGardenDayOneHasWaterTask() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(name: "Basil", garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day1 = plan.days.first { $0.dayOffset == 1 }
        #expect((day1?.tasks.contains { $0.kind == .water }) == true)
    }

    @Test("active garden: day 2 includes inspect task")
    func activeGardenDayTwoHasInspectTask() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day2 = plan.days.first { $0.dayOffset == 2 }
        #expect((day2?.tasks.contains { $0.kind == .inspect }) == true)
    }

    @Test("plant never fertilized: day 1 includes fertilize setup task")
    func unfertilizedPlantDayOneHasFertilizeTask() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden, lastFertilized: nil)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day1 = plan.days.first { $0.dayOffset == 1 }
        #expect((day1?.tasks.contains { $0.kind == .fertilize }) == true)
    }

    @Test("growFood goal: browse recommendations day appears")
    func growFoodGoalShowsBrowseTask() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let hasBrowse = plan.days.contains { day in
            day.tasks.contains { task in
                task.kind == .learn && (
                    task.title.localizedCaseInsensitiveContains("recommendation") ||
                    task.detail.localizedCaseInsensitiveContains("recommendation")
                )
            }
        }
        #expect(hasBrowse == true)
    }

    @Test("multiple plants: day 2 has inspect tasks for all plants")
    func multiplePlantsDayTwoHasInspectForAll() {
        let user = makeUser()
        let garden = makeGarden()
        let basil = makePlant(name: "Basil", garden: garden)
        let mint = makePlant(name: "Mint", garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [basil, mint],
            reminders: [],
            referenceDate: Date()
        )

        let day2 = plan.days.first { $0.dayOffset == 2 }
        #expect(day2!.tasks.count >= 2)
        #expect(day2!.tasks.allSatisfy { $0.kind == .inspect })
    }

    // MARK: - GardenType shaping

    @Test("gardenType container: roadmap contains container-relevant tasks")
    func containerGardenRoadmapContent() {
        let user = makeUser()
        let garden = makeGarden(type: .container, isIndoor: false)
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        // Container gardens need watering setup - day 1 should have water task
        let day1 = plan.days.first { $0.dayOffset == 1 }
        #expect((day1?.tasks.contains { $0.kind == .water }) == true)
    }

    // MARK: - CareTask structure

    @Test("careTask has correct identifier format")
    func careTaskIdentifierFormat() {
        let task = CareTask(
            kind: .water,
            title: "Water Basil",
            detail: "Regular watering",
            systemImage: "drop.fill",
            plantName: "Basil"
        )

        let id = task.id
        #expect(id.contains("water") == true)
        #expect(id.contains("Water Basil") == true)
    }

    @Test("careTask plantName is optional")
    func careTaskPlantNameIsOptional() {
        let task = CareTask(
            kind: .setup,
            title: "Create garden",
            detail: "Set up your garden",
            systemImage: "leaf.circle.fill",
            plantName: nil
        )

        #expect(task.plantName == nil)
    }

    @Test("careTask kinds match expected cases")
    func careTaskKindsAreCorrect() {
        #expect(CareTask.TaskKind.water.rawValue == "water")
        #expect(CareTask.TaskKind.fertilize.rawValue == "fertilize")
        #expect(CareTask.TaskKind.inspect.rawValue == "inspect")
        #expect(CareTask.TaskKind.prune.rawValue == "prune")
        #expect(CareTask.TaskKind.harvest.rawValue == "harvest")
        #expect(CareTask.TaskKind.plant.rawValue == "plant")
        #expect(CareTask.TaskKind.setup.rawValue == "setup")
        #expect(CareTask.TaskKind.learn.rawValue == "learn")
    }

    // MARK: - Reference date

    @Test("custom reference date shifts all days")
    func customReferenceDateShiftsDays() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden)
        let customDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: customDate
        )

        // Day 0 date should equal customDate
        let day0 = plan.days.first { $0.dayOffset == 0 }
        #expect(Calendar.current.isDate(day0!.date, inSameDayAs: customDate))

        // Day 1 date should be customDate + 1
        let day1 = plan.days.first { $0.dayOffset == 1 }
        let expectedDay1 = Calendar.current.date(byAdding: .day, value: 1, to: customDate)!
        #expect(Calendar.current.isDate(day1!.date, inSameDayAs: expectedDay1))
    }

    // MARK: - Actions preserved alongside days

    @Test("starterPlan carries both actions and days")
    func starterPlanCarriesActionsAndDays() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        #expect(plan.actions.isEmpty == false)
        #expect(plan.days.isEmpty == false)
    }

    @Test("existing action logic preserved: watering reminder surfaces in actions")
    func wateringReminderActionSurfaces() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(name: "Basil", garden: garden)
        let reminder = PlantReminder(
            title: "Water Basil",
            message: "Time to water",
            reminderType: .watering,
            frequency: .daily,
            nextDueDate: Date(),
            plant: plant
        )

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [reminder],
            referenceDate: Date()
        )

        #expect(plan.actions.contains { $0.kind == .reviewWateringReminder } == true)
    }

    // MARK: - Edge cases

    @Test("nil user returns valid plan with empty personalization")
    func nilUserReturnsValidPlan() {
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: nil,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        #expect(plan.days.count == 14)
        #expect(plan.actions.isEmpty == false)
    }

    @Test("week 2 (day 7 offset) has water task for plant care")
    func daySevenHasWeeklyWaterTask() {
        let user = makeUser()
        let garden = makeGarden()
        let plant = makePlant(garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day7 = plan.days.first { $0.dayOffset == 7 }
        #expect((day7?.tasks.contains { $0.kind == .water }) == true)
    }

    @Test("growFood goal with vegetable: day 7 has harvest task")
    func growFoodVegetableDaySevenHasHarvest() {
        let user = makeUser(goals: [.growFood])
        let garden = makeGarden()
        let plant = makePlant(type: .vegetable, garden: garden)

        let plan = StarterPlanService.build(
            user: user,
            gardens: [garden],
            plants: [plant],
            reminders: [],
            referenceDate: Date()
        )

        let day7 = plan.days.first { $0.dayOffset == 7 }
        #expect((day7?.tasks.contains { $0.kind == .harvest }) == true)
    }
}