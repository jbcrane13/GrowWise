import Foundation
import SwiftData
import GrowWiseModels

@MainActor
@Observable public final class TutorialService {
    private let dataService: DataService

    public init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Tutorial Management

    public func getAllTutorials() -> [TutorialTopic] {
        return TutorialContent.allTutorials
    }

    public func getTutorial(by id: String) -> TutorialTopic? {
        return TutorialContent.allTutorials.first { $0.id == id }
    }

    public func getTutorialsForSkillLevel(_ skillLevel: GardeningSkillLevel) -> [TutorialTopic] {
        return TutorialContent.allTutorials.filter { tutorial in
            switch skillLevel {
            case .beginner:
                return tutorial.difficultyLevel == .beginner
            case .intermediate:
                return tutorial.difficultyLevel == .beginner || tutorial.difficultyLevel == .intermediate
            case .advanced, .expert:
                return true
            }
        }
    }

    public func getRecommendedTutorials(for user: User) -> [TutorialTopic] {
        let skillLevel = user.skillLevel
        let userGardenType = "container"

        return getTutorialsForSkillLevel(skillLevel)
            .filter { tutorial in
                tutorial.relevantGardenTypes.contains(userGardenType) ||
                tutorial.relevantGardenTypes.contains("all")
            }
            .sorted { $0.estimatedDuration < $1.estimatedDuration }
    }

    // MARK: - Progress Tracking

    public func markStepComplete(tutorialId: String, stepIndex: Int) {
        let key = "tutorial_\(tutorialId)_step_\(stepIndex)"
        try? KeychainService.shared.storeBool(true, for: key)
        if let dateData = try? JSONEncoder().encode(Date()) {
            try? KeychainService.shared.store(dateData, for: "\(key)_completed_date")
        }
    }

    public func isStepCompleted(tutorialId: String, stepIndex: Int) -> Bool {
        let key = "tutorial_\(tutorialId)_step_\(stepIndex)"
        return (try? KeychainService.shared.retrieveBool(for: key)) ?? false
    }

    public func getTutorialProgress(tutorialId: String) -> TutorialProgress {
        guard let tutorial = getTutorial(by: tutorialId) else {
            return TutorialProgress(tutorialId: tutorialId, completedSteps: 0, totalSteps: 0, isCompleted: false)
        }

        let completedSteps = tutorial.steps.enumerated().filter { index, _ in
            isStepCompleted(tutorialId: tutorialId, stepIndex: index)
        }.count

        let isCompleted = completedSteps == tutorial.steps.count

        if isCompleted {
            if let dateData = try? JSONEncoder().encode(Date()) {
                try? KeychainService.shared.store(dateData, for: "tutorial_\(tutorialId)_completed")
            }
        }

        return TutorialProgress(
            tutorialId: tutorialId,
            completedSteps: completedSteps,
            totalSteps: tutorial.steps.count,
            isCompleted: isCompleted
        )
    }

    public func resetTutorialProgress(tutorialId: String) {
        guard let tutorial = getTutorial(by: tutorialId) else { return }

        for index in 0..<tutorial.steps.count {
            let key = "tutorial_\(tutorialId)_step_\(index)"
            try? KeychainService.shared.delete(for: key)
            try? KeychainService.shared.delete(for: "\(key)_completed_date")
        }

        try? KeychainService.shared.delete(for: "tutorial_\(tutorialId)_completed")
    }

    // MARK: - Analytics

    public func getTutorialAnalytics() -> TutorialAnalytics {
        let allTutorials = getAllTutorials()
        let completedTutorials = allTutorials.filter { tutorial in
            getTutorialProgress(tutorialId: tutorial.id).isCompleted
        }

        let totalSteps = allTutorials.reduce(0) { $0 + $1.steps.count }
        let completedSteps = allTutorials.reduce(0) { total, tutorial in
            total + getTutorialProgress(tutorialId: tutorial.id).completedSteps
        }

        return TutorialAnalytics(
            totalTutorials: allTutorials.count,
            completedTutorials: completedTutorials.count,
            totalSteps: totalSteps,
            completedSteps: completedSteps,
            completionRate: totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
        )
    }
}

// MARK: - Tutorial Content (loaded from JSON)

public struct TutorialContent {
    public static let allTutorials: [TutorialTopic] = {
        guard let url = Bundle.module.url(forResource: "tutorials", withExtension: "json") else {
            fatalError("Missing tutorials.json in GrowWiseServices bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TutorialTopic].self, from: data)
        } catch {
            fatalError("Failed to decode tutorials.json: \(error)")
        }
    }()
}

// MARK: - Supporting Types

public struct TutorialTopic: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let description: String
    public let difficultyLevel: DifficultyLevel
    public let estimatedDuration: Int // minutes
    public let category: TutorialCategory
    public let relevantGardenTypes: [String]
    public let imageURL: String
    public let steps: [TutorialStep]

    public init(id: String, title: String, subtitle: String, description: String, difficultyLevel: DifficultyLevel, estimatedDuration: Int, category: TutorialCategory, relevantGardenTypes: [String], imageURL: String, steps: [TutorialStep]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.difficultyLevel = difficultyLevel
        self.estimatedDuration = estimatedDuration
        self.category = category
        self.relevantGardenTypes = relevantGardenTypes
        self.imageURL = imageURL
        self.steps = steps
    }
}

public struct TutorialStep: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let title: String
    public let content: String
    public let imageURL: String
    public let duration: Int // minutes
    public let tips: [String]
    public let commonMistakes: [String]

    public init(title: String, content: String, imageURL: String, duration: Int, tips: [String], commonMistakes: [String]) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.imageURL = imageURL
        self.duration = duration
        self.tips = tips
        self.commonMistakes = commonMistakes
    }

    // Custom CodingKeys: decode `id` if present, otherwise generate a new UUID
    private enum CodingKeys: String, CodingKey {
        case id, title, content, imageURL, duration, tips, commonMistakes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.imageURL = try container.decode(String.self, forKey: .imageURL)
        self.duration = try container.decode(Int.self, forKey: .duration)
        self.tips = try container.decode([String].self, forKey: .tips)
        self.commonMistakes = try container.decode([String].self, forKey: .commonMistakes)
    }
}

public enum TutorialCategory: String, CaseIterable, Codable, Sendable {
    case planning = "planning"
    case preparation = "preparation"
    case care = "care"
    case environment = "environment"
    case problemSolving = "problemSolving"

    public var displayName: String {
        switch self {
        case .planning: return "Garden Planning"
        case .preparation: return "Soil & Setup"
        case .care: return "Plant Care"
        case .environment: return "Environment"
        case .problemSolving: return "Problem Solving"
        }
    }
}

public struct TutorialProgress: Codable {
    public let tutorialId: String
    public let completedSteps: Int
    public let totalSteps: Int
    public let isCompleted: Bool

    public var progressPercentage: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps) * 100
    }

    public init(tutorialId: String, completedSteps: Int, totalSteps: Int, isCompleted: Bool) {
        self.tutorialId = tutorialId
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.isCompleted = isCompleted
    }
}

public struct TutorialAnalytics: Codable {
    public let totalTutorials: Int
    public let completedTutorials: Int
    public let totalSteps: Int
    public let completedSteps: Int
    public let completionRate: Double

    public init(totalTutorials: Int, completedTutorials: Int, totalSteps: Int, completedSteps: Int, completionRate: Double) {
        self.totalTutorials = totalTutorials
        self.completedTutorials = completedTutorials
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.completionRate = completionRate
    }
}
