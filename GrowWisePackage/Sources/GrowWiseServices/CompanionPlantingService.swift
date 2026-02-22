import Foundation
import GrowWiseModels

// MARK: - Companion Planting Types

/// Represents the relationship between two plants
public enum PlantCompatibility: String, CaseIterable, Sendable {
    case companion      // Plants benefit each other
    case neutral        // No particular effect
    case incompatible   // Plants harm each other or compete
    
    public var displayName: String {
        switch self {
        case .companion: return "Good Companions"
        case .neutral: return "Neutral"
        case .incompatible: return "Incompatible"
        }
    }
    
    public var iconName: String {
        switch self {
        case .companion: return "heart.fill"
        case .neutral: return "minus.circle"
        case .incompatible: return "exclamationmark.triangle.fill"
        }
    }
    
    public var colorName: String {
        switch self {
        case .companion: return "green"
        case .neutral: return "gray"
        case .incompatible: return "red"
        }
    }
}

/// Detailed information about a planting relationship
public struct CompanionPlantingInfo: Sendable, Identifiable {
    public let id = UUID()
    public let plantName: String
    public let compatibility: PlantCompatibility
    public let reason: String
    public let benefits: [String]?
    public let warnings: [String]?
    
    public init(
        plantName: String,
        compatibility: PlantCompatibility,
        reason: String,
        benefits: [String]? = nil,
        warnings: [String]? = nil
    ) {
        self.plantName = plantName
        self.compatibility = compatibility
        self.reason = reason
        self.benefits = benefits
        self.warnings = warnings
    }
}

/// Analysis result for a plant in the context of a garden
public struct GardenCompatibilityAnalysis: Sendable {
    public let plantName: String
    public let overallCompatibility: PlantCompatibility
    public let relationships: [CompanionPlantingInfo]
    public let recommendedCompanions: [String]
    public let incompatiblePlants: [String]
    public let warnings: [String]
    
    public init(
        plantName: String,
        overallCompatibility: PlantCompatibility,
        relationships: [CompanionPlantingInfo],
        recommendedCompanions: [String],
        incompatiblePlants: [String],
        warnings: [String]
    ) {
        self.plantName = plantName
        self.overallCompatibility = overallCompatibility
        self.relationships = relationships
        self.recommendedCompanions = recommendedCompanions
        self.incompatiblePlants = incompatiblePlants
        self.warnings = warnings
    }
    
    public var hasWarnings: Bool {
        !warnings.isEmpty || !incompatiblePlants.isEmpty
    }
}

// MARK: - Companion Planting Service

/// Service for analyzing companion planting relationships
/// Uses a predefined database of plant compatibility relationships
@MainActor
@Observable public final class CompanionPlantingService {
    
    // MARK: - Companion Planting Database
    
    /// Predefined companion planting relationships
    /// Key: Plant name (lowercase), Value: Compatibility info with other plants
    private let companionDatabase: [String: PlantCompatibilityProfile] = [
        // Tomatoes
        "tomato": PlantCompatibilityProfile(
            companions: ["basil", "carrot", "onion", "garlic", "parsley", "spinach", "marigold"],
            incompatibles: ["potato", "fennel", "corn", "kohlrabi"],
            reasons: [
                "basil": "Improves flavor and repels flies and mosquitoes",
                "carrot": "Loosens soil for tomato roots",
                "marigold": "Repels nematodes and other pests"
            ]
        ),
        
        // Basil
        "basil": PlantCompatibilityProfile(
            companions: ["tomato", "pepper", "oregano", "asparagus"],
            incompatibles: ["sage", "rue"],
            reasons: [
                "tomato": "Mutually beneficial - improves growth and flavor",
                "pepper": "Repels aphids and spider mites"
            ]
        ),
        
        // Carrots
        "carrot": PlantCompatibilityProfile(
            companions: ["tomato", "onion", "leek", "lettuce", "peas", "radish"],
            incompatibles: ["dill", "parsnip"],
            reasons: [
                "tomato": "Shades carrot roots, carrots loosen tomato soil",
                "onion": "Repels carrot fly"
            ]
        ),
        
        // Lettuce
        "lettuce": PlantCompatibilityProfile(
            companions: ["carrot", "radish", "strawberry", "cucumber"],
            incompatibles: ["broccoli", "cabbage"],
            reasons: [
                "radish": "Radishes break up soil crust for lettuce",
                "strawberry": "Shade-loving partners"
            ]
        ),
        
        // Peppers
        "pepper": PlantCompatibilityProfile(
            companions: ["basil", "tomato", "spinach", "onion", "garlic"],
            incompatibles: ["fennel", "kohlrabi"],
            reasons: [
                "basil": "Repels pests and improves growth",
                "spinach": "Shades pepper roots and conserves moisture"
            ]
        ),
        
        // Cucumbers
        "cucumber": PlantCompatibilityProfile(
            companions: ["beans", "corn", "peas", "radish", "sunflower"],
            incompatibles: ["potato", "sage", "strong aromatic herbs"],
            reasons: [
                "beans": "Fix nitrogen in soil",
                "corn": "Provides shade and support"
            ]
        ),
        
        // Beans (bush and pole)
        "bean": PlantCompatibilityProfile(
            companions: ["corn", "cucumber", "potato", "strawberry", "spinach"],
            incompatibles: ["onion", "garlic", "fennel", "shallots"],
            reasons: [
                "corn": "Corn provides support for pole beans",
                "spinach": "Spinach benefits from bean shade"
            ]
        ),
        
        // Onions
        "onion": PlantCompatibilityProfile(
            companions: ["carrot", "lettuce", "cabbage", "tomato", "pepper"],
            incompatibles: ["beans", "peas", "asparagus"],
            reasons: [
                "carrot": "Repels carrot fly",
                "cabbage": "Repels cabbage worms"
            ]
        ),
        
        // Garlic
        "garlic": PlantCompatibilityProfile(
            companions: ["rose", "raspberry", "tomato", "pepper"],
            incompatibles: ["beans", "peas", "cabbage", "asparagus"],
            reasons: [
                "rose": "Repels aphids and prevents black spot",
                "raspberry": "Prevents spider mite infestations"
            ]
        ),
        
        // Spinach
        "spinach": PlantCompatibilityProfile(
            companions: ["strawberry", "eggplant", "pepper", "cauliflower"],
            incompatibles: ["potato"],
            reasons: [
                "strawberry": "Living mulch for strawberries",
                "eggplant": "Shade-loving companions"
            ]
        ),
        
        // Radishes
        "radish": PlantCompatibilityProfile(
            companions: ["lettuce", "carrot", "cucumber", "peas", "spinach"],
            incompatibles: ["hyssop", "grape"],
            reasons: [
                "lettuce": "Breaks soil crust for lettuce emergence",
                "cucumber": "Repels cucumber beetles"
            ]
        ),
        
        // Strawberries
        "strawberry": PlantCompatibilityProfile(
            companions: ["lettuce", "spinach", "beans", "borage"],
            incompatibles: ["cabbage", "broccoli", "tomato", "potato"],
            reasons: [
                "borage": "Attracts pollinators and improves flavor",
                "lettuce": "Complementary growth patterns"
            ]
        ),
        
        // Cabbage
        "cabbage": PlantCompatibilityProfile(
            companions: ["onion", "garlic", "dill", "sage", "rosemary"],
            incompatibles: ["strawberry", "tomato", "pole beans", "pepper"],
            reasons: [
                "onion": "Repels cabbage maggots and loopers",
                "dill": "Attracts beneficial wasps"
            ]
        ),
        
        // Broccoli
        "broccoli": PlantCompatibilityProfile(
            companions: ["onion", "garlic", "dill", "celery", "chamomile"],
            incompatibles: ["strawberry", "tomato", "pole beans"],
            reasons: [
                "onion": "Repels cabbage pests",
                "celery": "Complementary growth habits"
            ]
        ),
        
        // Potatoes
        "potato": PlantCompatibilityProfile(
            companions: ["beans", "corn", "cabbage", "marigold"],
            incompatibles: ["tomato", "cucumber", "sunflower", "raspberry"],
            reasons: [
                "beans": "Fixes nitrogen for heavy-feeding potatoes",
                "marigold": "Repels potato beetles"
            ]
        ),
        
        // Roses
        "rose": PlantCompatibilityProfile(
            companions: ["garlic", "onion", "lavender", "sage", "thyme"],
            incompatibles: ["fuchsia"],
            reasons: [
                "garlic": "Natural pest repellent for aphids and black spot",
                "lavender": "Complementary fragrances"
            ]
        ),
        
        // Marigolds
        "marigold": PlantCompatibilityProfile(
            companions: ["tomato", "potato", "eggplant", "pepper", "most vegetables"],
            incompatibles: ["beans"],
            reasons: [
                "tomato": "Repels root knot nematodes and whiteflies",
                "most vegetables": "General pest deterrent"
            ]
        ),
        
        // Corn
        "corn": PlantCompatibilityProfile(
            companions: ["beans", "squash", "cucumber", "peas", "potato"],
            incompatibles: ["tomato", "celery"],
            reasons: [
                "beans": "Three sisters planting - nitrogen fixing",
                "squash": "Three sisters - living mulch"
            ]
        ),
        
        // Squash
        "squash": PlantCompatibilityProfile(
            companions: ["corn", "beans", "radish", "marigold", " nasturtium"],
            incompatibles: ["potato"],
            reasons: [
                "corn": "Three sisters traditional planting",
                "marigold": "Repels squash bugs"
            ]
        ),
        
        // Peas
        "peas": PlantCompatibilityProfile(
            companions: ["carrot", "cucumber", "corn", "turnip", "radish"],
            incompatibles: ["onion", "garlic", "shallots", "chives"],
            reasons: [
                "carrot": "Peas fix nitrogen, carrots use it",
                "corn": "Corn provides support for climbing peas"
            ]
        ),
        
        // Asparagus
        "asparagus": PlantCompatibilityProfile(
            companions: ["tomato", "parsley", "basil"],
            incompatibles: ["onion", "garlic", "potato"],
            reasons: [
                "tomato": "Tomato repels asparagus beetles",
                "basil": "Improves growth and repels pests"
            ]
        ),
        
        // Sage
        "sage": PlantCompatibilityProfile(
            companions: ["cabbage", "carrot", "strawberry"],
            incompatibles: ["cucumber", "basil", "rue"],
            reasons: [
                "cabbage": "Repels cabbage moths and loopers",
                "strawberry": "May improve strawberry health"
            ]
        ),
        
        // Thyme
        "thyme": PlantCompatibilityProfile(
            companions: ["cabbage", "eggplant", "potato", "strawberry"],
            incompatibles: [],
            reasons: [
                "cabbage": "Repels cabbage worms",
                "eggplant": "Repels eggplant pests"
            ]
        ),
        
        // Dill
        "dill": PlantCompatibilityProfile(
            companions: ["cabbage", "broccoli", "corn", "lettuce", "onion"],
            incompatibles: ["carrot", "tomato"],
            reasons: [
                "cabbage": "Attracts beneficial insects",
                "broccoli": "Attracts wasps that prey on pests"
            ]
        ),
        
        // Mint
        "mint": PlantCompatibilityProfile(
            companions: ["cabbage", "tomato", "broccoli"],
            incompatibles: ["parsley", "chamomile", "most herbs"],
            reasons: [
                "cabbage": "Repels cabbage moths (but plant in containers)",
                "tomato": "Repels rodents and may improve flavor"
            ]
        ),
        
        // Oregano
        "oregano": PlantCompatibilityProfile(
            companions: ["broccoli", "cabbage", "cucumber", "grape"],
            incompatibles: [],
            reasons: [
                "broccoli": "General pest deterrent",
                "cabbage": "Repels cabbage pests"
            ]
        ),
        
        // Chives
        "chive": PlantCompatibilityProfile(
            companions: ["carrot", "tomato", "apple", "rose"],
            incompatibles: ["beans", "peas"],
            reasons: [
                "carrot": "Repels carrot fly and improves growth",
                "tomato": "Improves tomato flavor and repels aphids"
            ]
        ),
        
        // Nasturtium
        "nasturtium": PlantCompatibilityProfile(
            companions: ["apple", "cucumber", "squash", "tomato", "radish"],
            incompatibles: [],
            reasons: [
                "cucumber": "Repels cucumber beetles and aphids",
                "tomato": "Repels whiteflies and squash bugs"
            ]
        ),
        
        // Borage
        "borage": PlantCompatibilityProfile(
            companions: ["tomato", "strawberry", "squash", "cucumber"],
            incompatibles: [],
            reasons: [
                "tomato": "Attracts pollinators, improves flavor",
                "strawberry": "Attracts pollinators and deters pests"
            ]
        ),
        
        // Lavender
        "lavender": PlantCompatibilityProfile(
            companions: ["rose", "sage", "thyme", "rosemary"],
            incompatibles: ["impatiens", "camellias"],
            reasons: [
                "rose": "Complementary scents, attracts pollinators",
                "herbs": "Mediterranean plant grouping"
            ]
        ),
        
        // Sunflowers
        "sunflower": PlantCompatibilityProfile(
            companions: ["cucumber", "corn", "melon", "squash"],
            incompatibles: ["potato", "pole beans"],
            reasons: [
                "cucumber": "Provides shade and support",
                "corn": "Attracts pollinators for corn"
            ]
        ),
        
        // Eggplant
        "eggplant": PlantCompatibilityProfile(
            companions: ["spinach", "thyme", "marigold", "oregano"],
            incompatibles: ["fennel", "kohlrabi"],
            reasons: [
                "spinach": "Shades eggplant roots",
                "thyme": "Repels eggplant flea beetles"
            ]
        ),
        
        // Cauliflower
        "cauliflower": PlantCompatibilityProfile(
            companions: ["onion", "garlic", "celery", "spinach", "sage"],
            incompatibles: ["strawberry", "tomato", "pole beans"],
            reasons: [
                "onion": "Repels cabbage pests",
                "spinach": "Complementary cool-season crops"
            ]
        ),
        
        // Celery
        "celery": PlantCompatibilityProfile(
            companions: ["cabbage", "broccoli", "cauliflower", "tomato"],
            incompatibles: ["corn", "potato"],
            reasons: [
                "cabbage": "Repels cabbage butterflies",
                "broccoli": "Complementary growth habits"
            ]
        ),
        
        // Fennel (generally incompatible with most)
        "fennel": PlantCompatibilityProfile(
            companions: ["dill"],  // Only really compatible with dill
            incompatibles: ["tomato", "pepper", "eggplant", "beans", "kohlrabi", "most vegetables"],
            reasons: [
                "most vegetables": "Inhibits growth of many plants - plant separately"
            ]
        ),
        
        // Kohlrabi
        "kohlrabi": PlantCompatibilityProfile(
            companions: ["onion", "garlic", "beet", "cucumber"],
            incompatibles: ["tomato", "pepper", "eggplant", "pole beans"],
            reasons: [
                "onion": "Repels insect pests",
                "beet": "Complementary cool-season crops"
            ]
        ),
        
        // Turnip
        "turnip": PlantCompatibilityProfile(
            companions: ["peas", "beans"],
            incompatibles: ["horseradish", "mustard"],
            reasons: [
                "peas": "Peas fix nitrogen for turnips"
            ]
        ),
        
        // Beets
        "beet": PlantCompatibilityProfile(
            companions: ["onion", "kohlrabi", "lettuce", "cabbage"],
            incompatibles: ["pole beans", "field mustard"],
            reasons: [
                "onion": "Repels insect pests",
                "cabbage": "Complementary cool-season crops"
            ]
        ),
        
        // Parsnip
        "parsnip": PlantCompatibilityProfile(
            companions: ["onion", "garlic", "radish"],
            incompatibles: ["carrot", "celery"],
            reasons: [
                "onion": "Repels root pests",
                "radish": "Loosens soil for parsnips"
            ]
        )
    ]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Check compatibility between two specific plants
    public func checkCompatibility(
        plant1: String,
        plant2: String
    ) -> CompanionPlantingInfo {
        let normalized1 = normalizePlantName(plant1)
        let normalized2 = normalizePlantName(plant2)
        
        // Look up plant1's profile
        guard let profile = companionDatabase[normalized1] else {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .neutral,
                reason: "No compatibility data available for \(plant1)"
            )
        }
        
        // Check direct relationships
        let normalized2Key = normalized2
        
        // Check if plant2 is in companions list
        if profile.companions.contains(normalized2Key) {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .companion,
                reason: profile.reasons[normalized2Key] ?? "These plants grow well together",
                benefits: generateBenefits(for: normalized1, with: normalized2Key)
            )
        }
        
        // Check if plant2 is in incompatibles list
        if profile.incompatibles.contains(normalized2Key) {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .incompatible,
                reason: profile.reasons[normalized2Key] ?? "These plants compete or inhibit each other",
                warnings: generateWarnings(for: normalized1, with: normalized2Key)
            )
        }
        
        // Check reverse relationship (plant2's view of plant1)
        if let profile2 = companionDatabase[normalized2Key] {
            if profile2.incompatibles.contains(normalized1) {
                return CompanionPlantingInfo(
                    plantName: plant2,
                    compatibility: .incompatible,
                    reason: "\(plant2) is negatively affected by \(plant1)",
                    warnings: generateWarnings(for: normalized2Key, with: normalized1)
                )
            }
            if profile2.companions.contains(normalized1) {
                return CompanionPlantingInfo(
                    plantName: plant2,
                    compatibility: .companion,
                    reason: "\(plant2) benefits from being near \(plant1)",
                    benefits: generateBenefits(for: normalized2Key, with: normalized1)
                )
            }
        }
        
        // Default to neutral
        return CompanionPlantingInfo(
            plantName: plant2,
            compatibility: .neutral,
            reason: "No known positive or negative relationship"
        )
    }
    
    /// Analyze how a plant would fit into an existing garden
    public func analyzeGardenCompatibility(
        plantName: String,
        existingPlants: [String]
    ) -> GardenCompatibilityAnalysis {
        var relationships: [CompanionPlantingInfo] = []
        var recommendedCompanions: [String] = []
        var incompatiblePlants: [String] = []
        var warnings: [String] = []
        
        // Check compatibility with each existing plant
        for existingPlant in existingPlants {
            let info = checkCompatibility(plant1: plantName, plant2: existingPlant)
            relationships.append(info)
            
            switch info.compatibility {
            case .companion:
                if !recommendedCompanions.contains(existingPlant) {
                    recommendedCompanions.append(existingPlant)
                }
            case .incompatible:
                incompatiblePlants.append(existingPlant)
                warnings.append("\(plantName) should not be planted near \(existingPlant)")
            case .neutral:
                break
            }
        }
        
        // Get additional companion recommendations from database
        let normalizedName = normalizePlantName(plantName)
        if let profile = companionDatabase[normalizedName] {
            for companion in profile.companions {
                let companionName = denormalizePlantName(companion)
                if !recommendedCompanions.contains(companionName) &&
                   !existingPlants.contains(companionName) {
                    recommendedCompanions.append(companionName)
                }
            }
        }
        
        // Determine overall compatibility
        let overallCompatibility: PlantCompatibility
        if !incompatiblePlants.isEmpty {
            overallCompatibility = .incompatible
        } else if !recommendedCompanions.isEmpty {
            overallCompatibility = .companion
        } else {
            overallCompatibility = .neutral
        }
        
        return GardenCompatibilityAnalysis(
            plantName: plantName,
            overallCompatibility: overallCompatibility,
            relationships: relationships,
            recommendedCompanions: recommendedCompanions,
            incompatiblePlants: incompatiblePlants,
            warnings: warnings
        )
    }
    
    /// Get recommended companion plants for a given plant
    public func getRecommendedCompanions(for plantName: String) -> [String] {
        let normalized = normalizePlantName(plantName)
        guard let profile = companionDatabase[normalized] else {
            return []
        }
        
        return profile.companions.map { denormalizePlantName($0) }
    }
    
    /// Get plants that should be avoided near the given plant
    public func getIncompatiblePlants(for plantName: String) -> [String] {
        let normalized = normalizePlantName(plantName)
        guard let profile = companionDatabase[normalized] else {
            return []
        }
        
        return profile.incompatibles.map { denormalizePlantName($0) }
    }
    
    /// Check if a plant name is in the companion database
    public func isPlantKnown(_ plantName: String) -> Bool {
        let normalized = normalizePlantName(plantName)
        return companionDatabase[normalized] != nil
    }
    
    /// Get all plants in the companion database
    public func getAllKnownPlants() -> [String] {
        return companionDatabase.keys.map { denormalizePlantName($0) }.sorted()
    }
    
    // MARK: - Private Helpers
    
    private func normalizePlantName(_ name: String) -> String {
        return name.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "s$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func denormalizePlantName(_ normalized: String) -> String {
        guard !normalized.isEmpty else { return normalized }
        return normalized.prefix(1).uppercased() + normalized.dropFirst()
    }
    
    private func generateBenefits(for plant1: String, with plant2: String) -> [String]? {
        var benefits: [String] = []
        
        // Check if nitrogen fixation is involved
        let nitrogenFixers = ["bean", "pea"]
        if nitrogenFixers.contains(plant1) || nitrogenFixers.contains(plant2) {
            benefits.append("Nitrogen fixation improves soil fertility")
        }
        
        // Check for pest repellent combinations
        let pestRepellentPairs = [
            ("marigold", "tomato"),
            ("basil", "tomato"),
            ("garlic", "rose"),
            ("nasturtium", "cucumber")
        ]
        if pestRepellentPairs.contains(where: { 
            ($0.0 == plant1 && $0.1 == plant2) || ($0.0 == plant2 && $0.1 == plant1)
        }) {
            benefits.append("Natural pest repellent relationship")
        }
        
        // Check for "three sisters" pattern
        let threeSisters = ["corn", "bean", "squash"]
        if threeSisters.contains(plant1) && threeSisters.contains(plant2) && plant1 != plant2 {
            benefits.append("Traditional 'Three Sisters' companion planting")
        }
        
        return benefits.isEmpty ? nil : benefits
    }
    
    private func generateWarnings(for plant1: String, with plant2: String) -> [String]? {
        var warnings: [String] = []
        
        // Check for allelopathic relationships
        let allelopathicPlants = ["fennel", "black walnut"]
        if allelopathicPlants.contains(plant1) {
            warnings.append("\(plant1.capitalized) produces allelopathic compounds that inhibit growth")
        }
        if allelopathicPlants.contains(plant2) {
            warnings.append("\(plant2.capitalized) produces allelopathic compounds that inhibit growth")
        }
        
        // Check for resource competition
        let heavyFeeders = ["tomato", "corn", "squash", "cucumber"]
        if heavyFeeders.contains(plant1) && heavyFeeders.contains(plant2) && plant1 != plant2 {
            warnings.append("Both plants are heavy feeders - may compete for nutrients")
        }
        
        // Check for disease transmission risk
        let nightshades = ["tomato", "potato", "pepper", "eggplant"]
        if nightshades.contains(plant1) && nightshades.contains(plant2) && plant1 != plant2 {
            warnings.append("Both are nightshades - shared pests and diseases")
        }
        
        return warnings.isEmpty ? nil : warnings
    }
}

// MARK: - Internal Data Structure

private struct PlantCompatibilityProfile: Sendable {
    let companions: [String]
    let incompatibles: [String]
    let reasons: [String: String]
    
    init(
        companions: [String] = [],
        incompatibles: [String] = [],
        reasons: [String: String] = [:]
    ) {
        self.companions = companions
        self.incompatibles = incompatibles
        self.reasons = reasons
    }
}
