import Foundation
import GrowWiseModels

// MARK: - Achievement Definition

public enum AchievementCategory: String, CaseIterable, Sendable {
    case gettingStarted = "Getting Started"
    case growthMilestones = "Growth Milestones"
    case harvest = "Harvest"
    case streaks = "Streaks"
    case learning = "Learning"
    case seasonal = "Seasonal Challenges"
}

public struct Achievement: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let category: AchievementCategory
    public let requirement: Int
    public let pointsValue: Int

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        category: AchievementCategory,
        requirement: Int,
        pointsValue: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.requirement = requirement
        self.pointsValue = pointsValue
    }
}

// MARK: - Achievement Progress

public struct AchievementProgress: Identifiable, Sendable {
    public let achievement: Achievement
    public let currentValue: Int
    public let isUnlocked: Bool
    public let progress: Double // 0.0 - 1.0

    public var id: String {
        achievement.id
    }
}

// MARK: - Achievement Service

@MainActor
@Observable
public final class AchievementService {
    public init() {}

    // MARK: - All Achievements

    public static let allAchievements: [Achievement] = {
        var list: [Achievement] = []

        // Getting Started
        list.append(Achievement(
            id: "first_plant", name: "First Plant Added",
            description: "Add your first plant to a garden",
            icon: "leaf.fill", category: .gettingStarted,
            requirement: 1, pointsValue: 10
        ))
        list.append(Achievement(
            id: "garden_creator", name: "Garden Creator",
            description: "Create your first garden",
            icon: "square.grid.2x2.fill", category: .gettingStarted,
            requirement: 1, pointsValue: 10
        ))
        list.append(Achievement(
            id: "journal_starter", name: "Journal Starter",
            description: "Write your first journal entry",
            icon: "book.fill", category: .gettingStarted,
            requirement: 1, pointsValue: 10
        ))

        // Growth Milestones
        list.append(Achievement(
            id: "green_thumb", name: "Green Thumb",
            description: "Grow 5 plants across all gardens",
            icon: "hand.thumbsup.fill", category: .growthMilestones,
            requirement: 5, pointsValue: 25
        ))
        list.append(Achievement(
            id: "plant_parent", name: "Plant Parent",
            description: "Grow 10 plants across all gardens",
            icon: "heart.fill", category: .growthMilestones,
            requirement: 10, pointsValue: 50
        ))
        list.append(Achievement(
            id: "urban_farmer", name: "Urban Farmer",
            description: "Grow 25 plants across all gardens",
            icon: "building.2.fill", category: .growthMilestones,
            requirement: 25, pointsValue: 100
        ))
        list.append(Achievement(
            id: "plant_master", name: "Plant Master",
            description: "Grow 50 plants across all gardens",
            icon: "crown.fill", category: .growthMilestones,
            requirement: 50, pointsValue: 200
        ))

        // Harvest
        list.append(Achievement(
            id: "first_harvest", name: "First Harvest",
            description: "Harvest your first plant",
            icon: "basket.fill", category: .harvest,
            requirement: 1, pointsValue: 15
        ))
        list.append(Achievement(
            id: "bountiful_harvest", name: "Bountiful Harvest",
            description: "Harvest 10 plants",
            icon: "shippingbox.fill", category: .harvest,
            requirement: 10, pointsValue: 75
        ))
        list.append(Achievement(
            id: "market_gardener", name: "Market Gardener",
            description: "Harvest 25 plants",
            icon: "storefront.fill", category: .harvest,
            requirement: 25, pointsValue: 150
        ))

        // Streaks
        list.append(Achievement(
            id: "week_warrior", name: "Week Warrior",
            description: "Maintain a 7-day activity streak",
            icon: "flame.fill", category: .streaks,
            requirement: 7, pointsValue: 30
        ))
        list.append(Achievement(
            id: "month_master", name: "Month Master",
            description: "Maintain a 30-day activity streak",
            icon: "flame.circle.fill", category: .streaks,
            requirement: 30, pointsValue: 100
        ))
        list.append(Achievement(
            id: "season_champion", name: "Season Champion",
            description: "Maintain a 90-day activity streak",
            icon: "trophy.fill", category: .streaks,
            requirement: 90, pointsValue: 250
        ))
        list.append(Achievement(
            id: "year_round_gardener", name: "Year-Round Gardener",
            description: "Maintain a 365-day activity streak",
            icon: "star.circle.fill", category: .streaks,
            requirement: 365, pointsValue: 500
        ))

        // Learning
        list.append(Achievement(
            id: "tutorial_explorer", name: "Tutorial Explorer",
            description: "Complete 5 tutorials",
            icon: "lightbulb.fill", category: .learning,
            requirement: 5, pointsValue: 25
        ))
        list.append(Achievement(
            id: "knowledge_seeker", name: "Knowledge Seeker",
            description: "Complete 10 tutorials",
            icon: "brain.head.profile.fill", category: .learning,
            requirement: 10, pointsValue: 75
        ))
        list.append(Achievement(
            id: "garden_scholar", name: "Garden Scholar",
            description: "Complete all available tutorials",
            icon: "graduationcap.fill", category: .learning,
            requirement: 20, pointsValue: 200
        ))

        // Seasonal Challenges
        list.append(Achievement(
            id: "spring_planter", name: "Spring Planter",
            description: "Add a plant during spring",
            icon: "flower.fill", category: .seasonal,
            requirement: 1, pointsValue: 20
        ))
        list.append(Achievement(
            id: "summer_grower", name: "Summer Grower",
            description: "Grow a plant through summer",
            icon: "sun.max.fill", category: .seasonal,
            requirement: 1, pointsValue: 20
        ))
        list.append(Achievement(
            id: "fall_harvester", name: "Fall Harvester",
            description: "Harvest a plant during fall",
            icon: "leaf.arrow.triangle.circlepath", category: .seasonal,
            requirement: 1, pointsValue: 20
        ))
        list.append(Achievement(
            id: "winter_planner", name: "Winter Planner",
            description: "Plan a garden during winter",
            icon: "snowflake", category: .seasonal,
            requirement: 1, pointsValue: 20
        ))

        return list
    }()

    // MARK: - Progress Calculation

    /// Returns progress for all achievements given the current user state.
    public func calculateProgress(for user: User) -> [AchievementProgress] {
        Self.allAchievements.map { achievement in
            let currentValue = currentValue(for: achievement, user: user)
            let ratio = min(Double(currentValue) / Double(max(achievement.requirement, 1)), 1.0)
            return AchievementProgress(
                achievement: achievement,
                currentValue: currentValue,
                isUnlocked: currentValue >= achievement.requirement,
                progress: ratio
            )
        }
    }

    /// Returns only the unlocked achievements for the user.
    public func unlockedAchievements(for user: User) -> [Achievement] {
        calculateProgress(for: user)
            .filter(\.isUnlocked)
            .map(\.achievement)
    }

    /// Returns the total earned points for the user.
    public func totalPoints(for user: User) -> Int {
        unlockedAchievements(for: user)
            .reduce(0) { $0 + $1.pointsValue }
    }

    /// Returns achievements grouped by category.
    public func progressByCategory(for user: User) -> [(category: AchievementCategory, items: [AchievementProgress])] {
        let allProgress = calculateProgress(for: user)
        return AchievementCategory.allCases.compactMap { category in
            let items = allProgress.filter { $0.achievement.category == category }
            guard !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }

    // MARK: - Private

    private func currentValue(for achievement: Achievement, user: User) -> Int {
        switch achievement.id {
        // Getting Started
        case "first_plant":
            min(user.plantsGrown, 1)

        case "garden_creator":
            min(user.gardens?.count ?? 0, 1)

        case "journal_starter":
            min(user.journalEntries?.count ?? 0, 1)

        // Growth Milestones
        case "green_thumb", "plant_parent", "urban_farmer", "plant_master":
            user.plantsGrown

        // Harvest
        case "first_harvest", "bountiful_harvest", "market_gardener":
            user.plantsHarvested

        // Streaks
        case "week_warrior", "month_master", "season_champion", "year_round_gardener":
            user.streakDays

        // Learning
        case "tutorial_explorer", "knowledge_seeker", "garden_scholar":
            user.completedTutorials.count

        // Seasonal — simplified: check if user has at least 1 relevant action
        case "spring_planter", "summer_grower", "fall_harvester", "winter_planner":
            seasonalValue(for: achievement.id, user: user)

        default:
            0
        }
    }

    private func seasonalValue(for achievementID: String, user: User) -> Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())

        switch achievementID {
        case "spring_planter":
            // Spring: March-May
            return (3 ... 5).contains(month) && user.plantsGrown >= 1 ? 1 : 0

        case "summer_grower":
            // Summer: June-August
            return (6 ... 8).contains(month) && user.plantsGrown >= 1 ? 1 : 0

        case "fall_harvester":
            // Fall: September-November
            return (9 ... 11).contains(month) && user.plantsHarvested >= 1 ? 1 : 0

        case "winter_planner":
            // Winter: December-February
            return ([12, 1, 2].contains(month) && (user.gardens?.count ?? 0) >= 1) ? 1 : 0

        default:
            return 0
        }
    }
}
