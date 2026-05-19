import Foundation
import GrowWiseModels

// MARK: - StarterPlan (Extended with days)

public struct StarterPlan: Equatable, Sendable {
    public let actions: [StarterPlanAction]
    /// 14-day roadmap keyed by day offset (0 = today, 13 = day 14)
    public let days: [StarterPlanDay]

    public init(actions: [StarterPlanAction] = [], days: [StarterPlanDay] = []) {
        self.actions = actions
        self.days = days
    }
}

/// A single day in the 14-day starter roadmap
public struct StarterPlanDay: Equatable, Identifiable, Sendable {
    public let date: Date
    public let dayOffset: Int
    public let tasks: [CareTask]

    public var id: Date { date }

    public init(date: Date, dayOffset: Int, tasks: [CareTask] = []) {
        self.date = date
        self.dayOffset = dayOffset
        self.tasks = tasks
    }
}

/// A care task within a StarterPlanDay
public struct CareTask: Equatable, Identifiable, Sendable {
    public enum TaskKind: String, Codable, Sendable {
        case water
        case fertilize
        case inspect
        case prune
        case harvest
        case plant
        case setup
        case learn
    }

    public let kind: TaskKind
    public let title: String
    public let detail: String
    public let systemImage: String
    public let plantName: String?

    public var id: String { "\(kind.rawValue)-\(title)" }

    public init(
        kind: TaskKind,
        title: String,
        detail: String,
        systemImage: String,
        plantName: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.plantName = plantName
    }
}

public struct StarterPlanAction: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case createGarden
        case addPlant
        case reviewWateringReminder
        case browseRecommendations
        case startTutorial
    }

    public let kind: Kind
    public let title: String
    public let detail: String
    public let systemImage: String

    public var id: Kind { kind }

    public init(kind: Kind, title: String, detail: String, systemImage: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

// MARK: - StarterPlanSeason Helper

private enum StarterPlanSeason: String {
    case spring
    case summer
    case fall
    case winter

    init(date: Date = Date()) {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3, 4, 5: self = .spring
        case 6, 7, 8: self = .summer
        case 9, 10, 11: self = .fall
        default: self = .winter
        }
    }
}

// MARK: - StarterPlanService

public enum StarterPlanService {
    private static let roadmapLength = 14

    /// Build the full starter plan including the legacy action list AND the 14-day roadmap.
    public static func build(
        user: User?,
        gardens: [Garden],
        plants: [Plant],
        reminders: [PlantReminder],
        referenceDate: Date = Date()
    ) -> StarterPlan {
        let userPlants = plants.filter { $0.isUserPlant != false }
        var actions: [StarterPlanAction] = []

        if gardens.isEmpty {
            actions.append(createGardenAction)
            appendTutorialActionIfNeeded(for: user, to: &actions)
            let days = buildEmptyGardensRoadmap(user: user, referenceDate: referenceDate)
            return StarterPlan(actions: Array(actions.prefix(3)), days: days)
        }

        if userPlants.isEmpty {
            actions.append(addPlantAction)
            appendRecommendationsActionIfUseful(for: user, plantCount: userPlants.count, to: &actions)
            appendTutorialActionIfNeeded(for: user, to: &actions)
            let days = buildNoPlantsRoadmap(user: user, gardens: gardens, referenceDate: referenceDate)
            return StarterPlan(actions: Array(actions.prefix(3)), days: days)
        }

        if let reminder = firstUnreviewedWateringReminder(from: reminders, for: userPlants) {
            actions.append(reviewWateringAction(for: reminder))
        }

        appendRecommendationsActionIfUseful(for: user, plantCount: userPlants.count, to: &actions)
        appendTutorialActionIfNeeded(for: user, to: &actions)

        let firstPlant = userPlants.first
        let garden = gardens.first
        let days = buildActiveRoadmap(
            user: user,
            garden: garden,
            firstPlant: firstPlant,
            plants: userPlants,
            referenceDate: referenceDate
        )
        return StarterPlan(actions: Array(actions.prefix(3)), days: days)
    }

    // MARK: - Roadmap Builders

    private static func buildEmptyGardensRoadmap(
        user: User?,
        referenceDate: Date
    ) -> [StarterPlanDay] {
        let calendar = Calendar.current
        var days: [StarterPlanDay] = []

        // Day 0: Create garden CTA
        days.append(StarterPlanDay(
            date: referenceDate,
            dayOffset: 0,
            tasks: [CareTask(
                kind: .setup,
                title: "Create your first garden",
                detail: "Set up a garden space so your plants have a home to grow in.",
                systemImage: "leaf.circle.fill"
            )]
        ))

        // Days 1-2: Light setup tasks
        if let goal = user?.gardeningGoals?.first {
            let tasks = setupTasksForGoal(goal, dayOffset: 1)
            days.append(StarterPlanDay(
                date: calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate,
                dayOffset: 1,
                tasks: tasks
            ))
        } else {
            days.append(StarterPlanDay(
                date: calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate,
                dayOffset: 1,
                tasks: [CareTask(
                    kind: .learn,
                    title: "Learn garden basics",
                    detail: "Review foundational gardening concepts for beginners.",
                    systemImage: "book.circle.fill"
                )]
            ))
        }

        // Fill remaining days with empty days (placeholder structure)
        for offset in 2..<roadmapLength {
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            days.append(StarterPlanDay(date: date, dayOffset: offset, tasks: []))
        }

        return days
    }

    private static func buildNoPlantsRoadmap(
        user: User?,
        gardens: [Garden],
        referenceDate: Date
    ) -> [StarterPlanDay] {
        let calendar = Calendar.current
        var days: [StarterPlanDay] = []
        let garden = gardens.first

        // Day 0: Add first plant
        var day0Tasks: [CareTask] = [CareTask(
            kind: .plant,
            title: "Add your first plant",
            detail: "Choose a plant from the guide and connect it to your garden.",
            systemImage: "plus.circle.fill"
        )]
        if let goal = user?.gardeningGoals?.first, goal == .growFood {
            day0Tasks.append(CareTask(
                kind: .learn,
                title: "Browse food-friendly plants",
                detail: "Explore vegetables and herbs suited to your goals.",
                systemImage: "sparkles"
            ))
        }
        days.append(StarterPlanDay(date: referenceDate, dayOffset: 0, tasks: day0Tasks))

        // Day 1-2: Setup watering reminder
        days.append(StarterPlanDay(
            date: calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate,
            dayOffset: 1,
            tasks: [CareTask(
                kind: .water,
                title: "Set up your watering schedule",
                detail: "Configure a watering reminder to keep your new plant healthy.",
                systemImage: "drop.circle.fill"
            )]
        ))

        // Day 2-3: Browse recommendations if personalized
        if user?.gardeningGoals?.isEmpty == false || user?.preferredPlantTypes?.isEmpty == false {
            days.append(StarterPlanDay(
                date: calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate,
                dayOffset: 2,
                tasks: [CareTask(
                    kind: .learn,
                    title: "Browse personalized recommendations",
                    detail: "Discover plants matched to your goals and garden setup.",
                    systemImage: "sparkles"
                )]
            ))
        } else {
            days.append(StarterPlanDay(
                date: calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate,
                dayOffset: 2,
                tasks: []
            ))
        }

        // Fill remaining
        for offset in 3..<roadmapLength {
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            days.append(StarterPlanDay(date: date, dayOffset: offset, tasks: []))
        }

        return days
    }

    private static func buildActiveRoadmap(
        user: User?,
        garden: Garden?,
        firstPlant: Plant?,
        plants: [Plant],
        referenceDate: Date
    ) -> [StarterPlanDay] {
        let calendar = Calendar.current
        var days: [StarterPlanDay] = []

        guard let garden = garden else {
            return buildEmptyGardensRoadmap(user: user, referenceDate: referenceDate)
        }

        // Day 0: Check on plant
        var day0Tasks: [CareTask] = []
        if let plant = firstPlant {
            day0Tasks.append(CareTask(
                kind: .inspect,
                title: "Check on \(plant.name ?? "your plant")",
                detail: "Verify your plant's health and recent watering status.",
                systemImage: "eye.circle.fill",
                plantName: plant.name
            ))
        }
        if user?.skillLevel == .beginner {
            day0Tasks.append(CareTask(
                kind: .learn,
                title: "Start a beginner tutorial",
                detail: "Learn the next best skill for your profile.",
                systemImage: "book.circle.fill"
            ))
        }
        days.append(StarterPlanDay(date: referenceDate, dayOffset: 0, tasks: day0Tasks))

        // Day 1: Water
        let waterDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        var day1Tasks: [CareTask] = []
        if let plant = firstPlant {
            day1Tasks.append(CareTask(
                kind: .water,
                title: "Water \(plant.name ?? "your plant")",
                detail: "Follow the watering schedule for healthy growth.",
                systemImage: "drop.fill",
                plantName: plant.name
            ))
        }
        // Add fertilizer reminder if needed
        if let plant = firstPlant, plant.lastFertilized == nil {
            day1Tasks.append(CareTask(
                kind: .fertilize,
                title: "Set up fertilizing schedule",
                detail: "Create a fertilizing reminder for this plant.",
                systemImage: "leaf.fill",
                plantName: plant.name
            ))
        }
        days.append(StarterPlanDay(date: waterDate, dayOffset: 1, tasks: day1Tasks))

        // Day 2: Inspect
        let inspectDate = calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate
        var day2Tasks: [CareTask] = []
        for plant in plants.prefix(3) {
            day2Tasks.append(CareTask(
                kind: .inspect,
                title: "Inspect \(plant.name ?? "plant")",
                detail: "Check for signs of stress, pests, or disease.",
                systemImage: "magnifyingglass",
                plantName: plant.name
            ))
        }
        days.append(StarterPlanDay(date: inspectDate, dayOffset: 2, tasks: day2Tasks))

        // Day 3: Fertilize (if applicable)
        let fertilizeDate = calendar.date(byAdding: .day, value: 3, to: referenceDate) ?? referenceDate
        var day3Tasks: [CareTask] = []
        if let plant = firstPlant {
            day3Tasks.append(CareTask(
                kind: .fertilize,
                title: "Fertilize \(plant.name ?? "your plant")",
                detail: "Apply fertilizer according to the plant's needs.",
                systemImage: "leaf.fill",
                plantName: plant.name
            ))
        }
        // Season-based planting task
        let season = StarterPlanSeason(date: referenceDate)
        if season == .spring, garden.gardenType != .indoor {
            day3Tasks.append(CareTask(
                kind: .plant,
                title: "Plan spring additions",
                detail: "Browse seasonal planting recommendations for your zone.",
                systemImage: "sparkles"
            ))
        }
        days.append(StarterPlanDay(date: fertilizeDate, dayOffset: 3, tasks: day3Tasks))

        // Days 4-5: Recommendations / Prune
        for offset in 4...5 {
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            var tasks: [CareTask] = []
            if offset == 4, user?.gardeningGoals?.isEmpty == false {
                var browseDetail = "Browse plants matched to your goals."
                if user?.gardeningGoals?.contains(.growFood) == true {
                    browseDetail = "Find food-friendly plants that match your selected goal."
                }
                tasks.append(CareTask(
                    kind: .learn,
                    title: "Browse plant recommendations",
                    detail: browseDetail,
                    systemImage: "sparkles"
                ))
            }
            if offset == 5, plants.count > 1 {
                for plant in plants.prefix(2) {
                    tasks.append(CareTask(
                        kind: .prune,
                        title: "Check \(plant.name ?? "plant") for pruning",
                        detail: "Look for dead leaves or overgrown branches to trim.",
                        systemImage: "scissors",
                        plantName: plant.name
                    ))
                }
            }
            days.append(StarterPlanDay(date: date, dayOffset: offset, tasks: tasks))
        }

        // Days 6-13: Weekly maintenance
        for offset in 6..<roadmapLength {
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            var tasks: [CareTask] = []

            // Weekly water reminder
            if offset % 7 == 0, let plant = firstPlant {
                tasks.append(CareTask(
                    kind: .water,
                    title: "Weekly watering for \(plant.name ?? "your plant")",
                    detail: "Time for your regular watering schedule.",
                    systemImage: "drop.fill",
                    plantName: plant.name
                ))
            }

            // Harvest suggestion for food-growing users
            if user?.gardeningGoals?.contains(.growFood) == true,
               let plant = firstPlant,
               plant.plantType == .vegetable || plant.plantType == .fruit {
                if offset == 7 {
                    tasks.append(CareTask(
                        kind: .harvest,
                        title: "Check for ready harvest",
                        detail: "Look for vegetables or fruits ready to harvest.",
                        systemImage: "basket.fill"
                    ))
                }
            }

            days.append(StarterPlanDay(date: date, dayOffset: offset, tasks: tasks))
        }

        return days
    }

    // MARK: - Helper

    private static func setupTasksForGoal(_ goal: GardeningGoal, dayOffset: Int) -> [CareTask] {
        switch goal {
        case .growFood:
            return [CareTask(
                kind: .learn,
                title: "Learn about food gardening",
                detail: "Explore the basics of growing your own vegetables and herbs.",
                systemImage: "leaf.fill"
            )]
        case .beautifySpace:
            return [CareTask(
                kind: .learn,
                title: "Learn about decorative plants",
                detail: "Discover flowers and ornamental plants for visual appeal.",
                systemImage: "camera.macro"
            )]
        case .relaxation:
            return [CareTask(
                kind: .learn,
                title: "Start a mindfulness gardening routine",
                detail: "Learn how gardening can support mental wellbeing.",
                systemImage: "brain.head.profile"
            )]
        default:
            return [CareTask(
                kind: .learn,
                title: "Explore gardening basics",
                detail: "Build foundational knowledge for your gardening journey.",
                systemImage: "book.circle.fill"
            )]
        }
    }

    private static var createGardenAction: StarterPlanAction {
        StarterPlanAction(
            kind: .createGarden,
            title: "Create your first garden",
            detail: "Add the space you are growing in so plants and care tasks have a home.",
            systemImage: "leaf.circle.fill"
        )
    }

    private static var addPlantAction: StarterPlanAction {
        StarterPlanAction(
            kind: .addPlant,
            title: "Add your first plant",
            detail: "Pick a plant from the guide and connect it to this garden.",
            systemImage: "plus.circle.fill"
        )
    }

    private static func reviewWateringAction(for reminder: PlantReminder) -> StarterPlanAction {
        let plantName = reminder.plant?.name ?? "your first plant"
        return StarterPlanAction(
            kind: .reviewWateringReminder,
            title: "Review your watering reminder",
            detail: "Confirm the first watering cadence for \(plantName).",
            systemImage: "drop.circle.fill"
        )
    }

    private static func recommendationsAction(for user: User?) -> StarterPlanAction {
        let detail = if user?.gardeningGoals?.contains(.growFood) == true {
            "Find food-friendly plants that match your selected goal."
        } else if let plantType = user?.preferredPlantTypes?.first {
            "Browse plants that match your \(plantType.displayName.lowercased()) interest."
        } else {
            "Browse plants matched to your garden setup and goals."
        }

        return StarterPlanAction(
            kind: .browseRecommendations,
            title: "Browse plants for your goals",
            detail: detail,
            systemImage: "sparkles"
        )
    }

    private static func tutorialAction(for user: User?) -> StarterPlanAction {
        let title = if user?.skillLevel == .beginner {
            "Start a beginner tutorial"
        } else {
            "Start a focused tutorial"
        }

        return StarterPlanAction(
            kind: .startTutorial,
            title: title,
            detail: "Learn the next best skill for your profile.",
            systemImage: "book.circle.fill"
        )
    }

    private static func appendRecommendationsActionIfUseful(
        for user: User?,
        plantCount: Int,
        to actions: inout [StarterPlanAction]
    ) {
        guard plantCount < 2 else { return }
        let hasPersonalization = user?.gardeningGoals?.isEmpty == false || user?.preferredPlantTypes?.isEmpty == false
        guard hasPersonalization else { return }
        actions.append(recommendationsAction(for: user))
    }

    private static func appendTutorialActionIfNeeded(for user: User?, to actions: inout [StarterPlanAction]) {
        guard user?.completedTutorials.isEmpty != false else { return }
        actions.append(tutorialAction(for: user))
    }

    private static func firstUnreviewedWateringReminder(
        from reminders: [PlantReminder],
        for plants: [Plant]
    ) -> PlantReminder? {
        let plantIDs = Set(plants.compactMap(\.id))
        return reminders.first { reminder in
            reminder.reminderType == .watering &&
                reminder.lastCompletedDate == nil &&
                reminder.plant?.id.map { plantIDs.contains($0) } == true
        }
    }
}