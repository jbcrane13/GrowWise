import Foundation
import SwiftData
import GrowWiseModels

@MainActor
public final class TutorialService: ObservableObject {
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
                return true // Advanced and expert users can see all tutorials
            }
        }
    }
    
    public func getRecommendedTutorials(for user: User) -> [TutorialTopic] {
        let skillLevel = user.skillLevel
        let userGardenType = "container" // Default garden type since User model doesn't have this field yet
        
        return getTutorialsForSkillLevel(skillLevel)
            .filter { tutorial in
                // Prioritize tutorials relevant to user's garden type
                tutorial.relevantGardenTypes.contains(userGardenType) ||
                tutorial.relevantGardenTypes.contains("all")
            }
            .sorted { $0.estimatedDuration < $1.estimatedDuration }
    }
    
    // MARK: - Progress Tracking
    
    public func markStepComplete(tutorialId: String, stepIndex: Int) {
        let key = "tutorial_\(tutorialId)_step_\(stepIndex)"
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.set(Date(), forKey: "\(key)_completed_date")
    }
    
    public func isStepCompleted(tutorialId: String, stepIndex: Int) -> Bool {
        let key = "tutorial_\(tutorialId)_step_\(stepIndex)"
        return UserDefaults.standard.bool(forKey: key)
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
            UserDefaults.standard.set(Date(), forKey: "tutorial_\(tutorialId)_completed")
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
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: "\(key)_completed_date")
        }
        
        UserDefaults.standard.removeObject(forKey: "tutorial_\(tutorialId)_completed")
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

// MARK: - Tutorial Content

public struct TutorialContent {
    public static let allTutorials: [TutorialTopic] = [
        // Tutorial 1: Getting Started with Indoor Plants
        TutorialTopic(
            id: "getting-started-indoor-plants",
            title: "Getting Started with Indoor Plants",
            subtitle: "Perfect for beginners - learn the basics of houseplant care",
            description: "Start your plant journey with easy-to-care-for houseplants. Learn about light, water, and basic care that will set you up for success.",
            difficultyLevel: .beginner,
            estimatedDuration: 25,
            category: .planning,
            relevantGardenTypes: ["all"],
            imageURL: "tutorial-indoor-plants",
            steps: [
                TutorialStep(
                    title: "Choose Your First Plants",
                    content: "Start with proven easy-care houseplants that are forgiving for beginners. Pothos, Snake Plants, and ZZ Plants are virtually indestructible and perfect for learning basic plant care.",
                    imageURL: "step-choose-plants",
                    duration: 5,
                    tips: [
                        "Pothos (Golden Pothos) tolerates low light and infrequent watering",
                        "Snake Plants can survive in almost any light condition",
                        "ZZ Plants are drought-tolerant and thrive on neglect"
                    ],
                    commonMistakes: [
                        "Starting with high-maintenance plants like fiddle leaf figs",
                        "Buying too many plants at once"
                    ]
                ),
                TutorialStep(
                    title: "Find the Right Spot",
                    content: "Placement is crucial for indoor plant success. Most houseplants prefer bright, indirect light near a window but not in direct sun. Observe your home's lighting throughout the day.",
                    imageURL: "step-plant-placement",
                    duration: 8,
                    tips: [
                        "East and north-facing windows provide gentle morning light",
                        "Use sheer curtains to filter intense afternoon sun",
                        "Rotate plants weekly for even growth"
                    ],
                    commonMistakes: [
                        "Placing plants in dark corners",
                        "Putting plants in direct, harsh sunlight"
                    ]
                ),
                TutorialStep(
                    title: "Master the Watering Basics",
                    content: "Overwatering kills more houseplants than underwatering. Learn to check soil moisture with your finger and water only when the top inch feels dry.",
                    imageURL: "step-watering-basics",
                    duration: 7,
                    tips: [
                        "Stick your finger 1-2 inches into the soil",
                        "Water thoroughly until it drains from the bottom",
                        "Empty saucers after 30 minutes to prevent root rot"
                    ],
                    commonMistakes: [
                        "Watering on a fixed schedule",
                        "Giving plants just a little water frequently"
                    ]
                ),
                TutorialStep(
                    title: "Create a Care Routine",
                    content: "Establish a weekly plant check routine. Look for signs of pests, adjust watering based on the season, and enjoy watching your plants grow!",
                    imageURL: "step-care-routine",
                    duration: 5,
                    tips: [
                        "Check plants every weekend at the same time",
                        "Keep a simple plant care journal or use the GrowWise app",
                        "Take photos to track growth progress"
                    ],
                    commonMistakes: [
                        "Neglecting plants for weeks at a time",
                        "Overcomplicating the care routine"
                    ]
                )
            ]
        ),
        
        // Tutorial 2: Watering Your Plants Correctly
        TutorialTopic(
            id: "watering-correctly",
            title: "Watering Your Plants Correctly",
            subtitle: "Essential watering techniques for healthy plants",
            description: "Master the most important skill in gardening - proper watering. Learn when, how, and how much to water different types of plants for optimal health.",
            difficultyLevel: .beginner,
            estimatedDuration: 20,
            category: .care,
            relevantGardenTypes: ["all"],
            imageURL: "tutorial-watering",
            steps: [
                TutorialStep(
                    title: "Understanding Water Needs",
                    content: "Different plants have varying water requirements. Learn to recognize signs of proper hydration, overwatering, and underwatering in your plants.",
                    imageURL: "step-water-needs",
                    duration: 5,
                    tips: [
                        "Check soil moisture with your finger - stick it 1-2 inches deep",
                        "Learn your plants' specific water requirements",
                        "Observe leaf color and texture for hydration clues"
                    ],
                    commonMistakes: [
                        "Watering on a fixed schedule regardless of plant needs",
                        "Assuming all plants need the same amount of water"
                    ]
                ),
                TutorialStep(
                    title: "Best Watering Techniques",
                    content: "Water deeply but less frequently to encourage deep root growth. Water at the soil level rather than on leaves to prevent disease and reduce evaporation.",
                    imageURL: "step-watering-technique",
                    duration: 8,
                    tips: [
                        "Use a watering can with a rose attachment for gentle watering",
                        "Water slowly to allow soil to absorb moisture",
                        "Consider drip irrigation for consistent, efficient watering"
                    ],
                    commonMistakes: [
                        "Watering leaves instead of soil",
                        "Watering too quickly, causing runoff"
                    ]
                ),
                TutorialStep(
                    title: "Timing Your Watering",
                    content: "The best time to water is early morning (6-10 AM) when temperatures are cooler and evaporation is minimal. This gives plants time to dry before evening.",
                    imageURL: "step-watering-timing",
                    duration: 4,
                    tips: [
                        "Avoid watering during the heat of the day",
                        "Evening watering can promote fungal diseases",
                        "Adjust frequency based on weather conditions"
                    ],
                    commonMistakes: [
                        "Watering during midday heat",
                        "Not adjusting watering schedule for weather changes"
                    ]
                ),
                TutorialStep(
                    title: "Recognizing Watering Problems",
                    content: "Learn to identify signs of overwatering (yellowing leaves, mushy stems) and underwatering (wilting, dry soil) to adjust your watering practices.",
                    imageURL: "step-watering-problems",
                    duration: 3,
                    tips: [
                        "Yellow leaves often indicate overwatering",
                        "Wilting in morning coolness suggests underwatering",
                        "Check soil moisture before assuming water problems"
                    ],
                    commonMistakes: [
                        "Overwatering when plants show stress",
                        "Ignoring environmental factors affecting water needs"
                    ]
                )
            ]
        ),
        
        // Tutorial 3: Understanding Light Requirements
        TutorialTopic(
            id: "light-requirements",
            title: "Understanding Light Requirements",
            subtitle: "Light conditions and plant placement guide",
            description: "Learn about different light conditions and how to match plants with their lighting needs. Discover how to assess and optimize light in your growing space.",
            difficultyLevel: .beginner,
            estimatedDuration: 25,
            category: .environment,
            relevantGardenTypes: ["all"],
            imageURL: "tutorial-light",
            steps: [
                TutorialStep(
                    title: "Types of Light Conditions",
                    content: "Understand the difference between full sun (6+ hours), partial sun/shade (3-6 hours), and full shade (less than 3 hours of direct sunlight daily).",
                    imageURL: "step-light-types",
                    duration: 6,
                    tips: [
                        "Track sunlight in your garden area throughout the day",
                        "Consider seasonal changes in sun patterns",
                        "Note the difference between direct and filtered light"
                    ],
                    commonMistakes: [
                        "Estimating light conditions without proper observation",
                        "Not accounting for seasonal sun changes"
                    ]
                ),
                TutorialStep(
                    title: "Assessing Your Garden's Light",
                    content: "Spend a day observing and mapping light patterns in your garden space. Take photos or notes every 2 hours to understand how light moves across your space.",
                    imageURL: "step-light-assessment",
                    duration: 8,
                    tips: [
                        "Use a garden journal to track light patterns",
                        "Consider shadows from buildings, trees, and fences",
                        "Note morning vs. afternoon sun quality"
                    ],
                    commonMistakes: [
                        "Only checking light at one time of day",
                        "Forgetting about seasonal changes in sun angle"
                    ]
                ),
                TutorialStep(
                    title: "Matching Plants to Light Conditions",
                    content: "Learn which plants thrive in your available light conditions. Vegetables like tomatoes need full sun, while lettuce can tolerate partial shade.",
                    imageURL: "step-plant-light-matching",
                    duration: 7,
                    tips: [
                        "Read plant tags carefully for light requirements",
                        "Group plants with similar light needs together",
                        "Consider using shade cloth for sun protection if needed"
                    ],
                    commonMistakes: [
                        "Planting sun-loving plants in shade",
                        "Not utilizing partial shade areas effectively"
                    ]
                ),
                TutorialStep(
                    title: "Managing Light Problems",
                    content: "Learn solutions for common light issues: providing shade for sensitive plants, increasing light with reflective surfaces, or choosing appropriate plant varieties.",
                    imageURL: "step-light-solutions",
                    duration: 4,
                    tips: [
                        "Use shade cloth or umbrellas for temporary shade",
                        "Prune nearby branches to increase light",
                        "Choose heat-tolerant varieties for intense sun areas"
                    ],
                    commonMistakes: [
                        "Not protecting plants from intense afternoon sun",
                        "Giving up on areas with challenging light conditions"
                    ]
                )
            ]
        ),
        
        // Tutorial 4: Soil and Fertilizing Basics
        TutorialTopic(
            id: "soil-fertilizing-basics",
            title: "Soil and Fertilizing Basics",
            subtitle: "Soil types and feeding schedules for healthy growth",
            description: "Understand different soil types, learn how to choose the right potting mix, and discover when and how to fertilize your plants for optimal nutrition.",
            difficultyLevel: .beginner,
            estimatedDuration: 30,
            category: .preparation,
            relevantGardenTypes: ["all"],
            imageURL: "tutorial-soil",
            steps: [
                TutorialStep(
                    title: "Choosing the Right Potting Mix",
                    content: "Not all potting mixes are created equal. Learn to select high-quality potting soil that provides good drainage while retaining moisture. Avoid garden soil for containers.",
                    imageURL: "step-potting-mix",
                    duration: 6,
                    tips: [
                        "Look for mixes containing perlite or vermiculite for drainage",
                        "Choose organic potting mixes with compost",
                        "Avoid mixes that are too heavy or water-retentive"
                    ],
                    commonMistakes: [
                        "Using regular garden soil in containers",
                        "Buying the cheapest potting mix available"
                    ]
                ),
                TutorialStep(
                    title: "Understanding Plant Nutrients",
                    content: "Plants need three main nutrients: Nitrogen (N) for leaves, Phosphorus (P) for roots and flowers, and Potassium (K) for overall health. Learn to read fertilizer labels.",
                    imageURL: "step-nutrients",
                    duration: 8,
                    tips: [
                        "N-P-K numbers on fertilizer show the ratio of main nutrients",
                        "Balanced fertilizers (like 10-10-10) work for most plants",
                        "Organic options include compost, worm castings, and fish emulsion"
                    ],
                    commonMistakes: [
                        "Over-fertilizing, which can burn plants",
                        "Using only chemical fertilizers without organic matter"
                    ]
                ),
                TutorialStep(
                    title: "When and How to Fertilize",
                    content: "Most houseplants need fertilizing during their growing season (spring through early fall). Use a diluted liquid fertilizer every 2-4 weeks or slow-release granules.",
                    imageURL: "step-fertilizing",
                    duration: 10,
                    tips: [
                        "Dilute liquid fertilizer to half the recommended strength",
                        "Water plants before fertilizing to prevent root burn",
                        "Reduce or stop fertilizing in winter when growth slows"
                    ],
                    commonMistakes: [
                        "Fertilizing too frequently or with too strong concentration",
                        "Fertilizing dry or stressed plants"
                    ]
                ),
                TutorialStep(
                    title: "Signs of Nutrient Problems",
                    content: "Learn to recognize signs of nutrient deficiencies and over-fertilization. Yellow leaves, poor growth, or leaf burn can indicate feeding issues.",
                    imageURL: "step-nutrient-problems",
                    duration: 6,
                    tips: [
                        "Yellow lower leaves often indicate nitrogen deficiency",
                        "Brown leaf tips suggest over-fertilization or salt buildup",
                        "Flush soil with water if you suspect over-fertilization"
                    ],
                    commonMistakes: [
                        "Assuming all yellowing is from under-fertilizing",
                        "Not adjusting feeding based on plant's needs"
                    ]
                )
            ]
        ),
        
        // Tutorial 5: Common Plant Problems and Solutions
        TutorialTopic(
            id: "plant-problems-solutions",
            title: "Common Plant Problems and Solutions",
            subtitle: "Troubleshooting guide for healthy plants",
            description: "Learn to identify and solve the most common plant problems. From yellowing leaves to pest issues, develop the skills to keep your plants healthy.",
            difficultyLevel: .beginner,
            estimatedDuration: 35,
            category: .problemSolving,
            relevantGardenTypes: ["all"],
            imageURL: "tutorial-troubleshooting",
            steps: [
                TutorialStep(
                    title: "Yellowing Leaves - The #1 Problem",
                    content: "Yellow leaves are the most common plant complaint. Learn to distinguish between normal aging, overwatering, underwatering, and nutrient deficiencies.",
                    imageURL: "step-yellowing-leaves",
                    duration: 8,
                    tips: [
                        "Old lower leaves naturally yellow and drop - this is normal",
                        "Multiple yellow leaves often indicate overwatering",
                        "Check soil moisture before assuming the cause"
                    ],
                    commonMistakes: [
                        "Panicking over one or two yellow leaves",
                        "Immediately increasing watering for yellow leaves"
                    ]
                ),
                TutorialStep(
                    title: "Identifying Common Houseplant Pests",
                    content: "Spider mites, aphids, mealybugs, and scale insects are the most common indoor pests. Learn to spot them early and treat them effectively.",
                    imageURL: "step-houseplant-pests",
                    duration: 12,
                    tips: [
                        "Check under leaves regularly for tiny moving dots (spider mites)",
                        "White cottony masses indicate mealybugs",
                        "Wipe leaves with alcohol-soaked cotton swabs for small infestations"
                    ],
                    commonMistakes: [
                        "Using harsh chemicals on indoor plants",
                        "Not isolating infested plants"
                    ]
                ),
                TutorialStep(
                    title: "Brown and Crispy Leaf Tips",
                    content: "Brown leaf tips are usually caused by low humidity, over-fertilization, or chlorine in tap water. Learn simple solutions to prevent this common issue.",
                    imageURL: "step-brown-tips",
                    duration: 7,
                    tips: [
                        "Use filtered or distilled water for sensitive plants",
                        "Group plants together to increase humidity",
                        "Trim brown tips with clean scissors just into healthy tissue"
                    ],
                    commonMistakes: [
                        "Cutting entire leaves instead of just brown tips",
                        "Not addressing the underlying cause"
                    ]
                ),
                TutorialStep(
                    title: "When Plants Stop Growing",
                    content: "Slow or stopped growth can indicate several issues: dormancy, pot-bound roots, insufficient light, or nutrient deficiency. Learn to diagnose the cause.",
                    imageURL: "step-slow-growth",
                    duration: 8,
                    tips: [
                        "Check if roots are circling the bottom of the pot",
                        "Most plants slow growth in fall and winter naturally",
                        "Gradually move plants to brighter locations if needed"
                    ],
                    commonMistakes: [
                        "Repotting every time growth slows",
                        "Forcing growth during dormant seasons"
                    ]
                )
            ]
        )
    ]
}

// MARK: - Supporting Types

public struct TutorialTopic: Identifiable, Codable, Sendable {
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

public struct TutorialStep: Identifiable, Codable, Sendable {
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
