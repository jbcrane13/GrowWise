import Foundation
import GrowWiseModels

public struct StarterPlan: Equatable, Sendable {
    public let actions: [StarterPlanAction]

    public init(actions: [StarterPlanAction] = []) {
        self.actions = actions
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

    public var id: Kind {
        kind
    }

    public init(kind: Kind, title: String, detail: String, systemImage: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

public enum StarterPlanService {
    public static func build(
        user: User?,
        gardens: [Garden],
        plants: [Plant],
        reminders: [PlantReminder]
    ) -> StarterPlan {
        let userPlants = plants.filter { $0.isUserPlant != false }
        var actions: [StarterPlanAction] = []

        if gardens.isEmpty {
            actions.append(createGardenAction)
            appendTutorialActionIfNeeded(for: user, to: &actions)
            return StarterPlan(actions: Array(actions.prefix(3)))
        }

        if userPlants.isEmpty {
            actions.append(addPlantAction)
            appendRecommendationsActionIfUseful(for: user, plantCount: userPlants.count, to: &actions)
            appendTutorialActionIfNeeded(for: user, to: &actions)
            return StarterPlan(actions: Array(actions.prefix(3)))
        }

        if let reminder = firstUnreviewedWateringReminder(from: reminders, for: userPlants) {
            actions.append(reviewWateringAction(for: reminder))
        }

        appendRecommendationsActionIfUseful(for: user, plantCount: userPlants.count, to: &actions)
        appendTutorialActionIfNeeded(for: user, to: &actions)

        return StarterPlan(actions: Array(actions.prefix(3)))
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
