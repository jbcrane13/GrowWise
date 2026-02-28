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

// MARK: - JSON Codable Type

private struct PlantCompatibilityProfile: Codable, Sendable {
    let companions: [String]
    let incompatibles: [String]
    let reasons: [String: String]

    init(companions: [String] = [], incompatibles: [String] = [], reasons: [String: String] = [:]) {
        self.companions = companions
        self.incompatibles = incompatibles
        self.reasons = reasons
    }
}

// MARK: - Companion Planting Service

@MainActor
@Observable public final class CompanionPlantingService {

    private let companionDatabase: [String: PlantCompatibilityProfile]

    private static let loadedDatabase: [String: PlantCompatibilityProfile] = {
        guard let url = Bundle.module.url(forResource: "companion_planting", withExtension: "json") else {
            fatalError("Missing companion_planting.json in GrowWiseServices bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: PlantCompatibilityProfile].self, from: data)
        } catch {
            fatalError("Failed to decode companion_planting.json: \(error)")
        }
    }()

    // MARK: - Initialization

    public init() {
        self.companionDatabase = Self.loadedDatabase
    }

    // MARK: - Public Methods

    /// Check compatibility between two specific plants
    public func checkCompatibility(plant1: String, plant2: String) -> CompanionPlantingInfo {
        let normalized1 = normalizePlantName(plant1)
        let normalized2 = normalizePlantName(plant2)

        guard let profile = companionDatabase[normalized1] else {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .neutral,
                reason: "No compatibility data available for \(plant1)"
            )
        }

        let normalized2Key = normalized2

        if profile.companions.contains(normalized2Key) {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .companion,
                reason: profile.reasons[normalized2Key] ?? "These plants grow well together",
                benefits: generateBenefits(for: normalized1, with: normalized2Key)
            )
        }

        if profile.incompatibles.contains(normalized2Key) {
            return CompanionPlantingInfo(
                plantName: plant2,
                compatibility: .incompatible,
                reason: profile.reasons[normalized2Key] ?? "These plants compete or inhibit each other",
                warnings: generateWarnings(for: normalized1, with: normalized2Key)
            )
        }

        // Check reverse relationship
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

        return CompanionPlantingInfo(
            plantName: plant2,
            compatibility: .neutral,
            reason: "No known positive or negative relationship"
        )
    }

    /// Analyze how a plant would fit into an existing garden
    public func analyzeGardenCompatibility(plantName: String, existingPlants: [String]) -> GardenCompatibilityAnalysis {
        var relationships: [CompanionPlantingInfo] = []
        var recommendedCompanions: [String] = []
        var incompatiblePlants: [String] = []
        var warnings: [String] = []

        for existingPlant in existingPlants {
            let info = checkCompatibility(plant1: plantName, plant2: existingPlant)
            relationships.append(info)

            switch info.compatibility {
            case .companion:
                if !recommendedCompanions.contains(existingPlant) { recommendedCompanions.append(existingPlant) }
            case .incompatible:
                incompatiblePlants.append(existingPlant)
                warnings.append("\(plantName) should not be planted near \(existingPlant)")
            case .neutral:
                break
            }
        }

        let normalizedName = normalizePlantName(plantName)
        if let profile = companionDatabase[normalizedName] {
            for companion in profile.companions {
                let companionName = denormalizePlantName(companion)
                if !recommendedCompanions.contains(companionName) && !existingPlants.contains(companionName) {
                    recommendedCompanions.append(companionName)
                }
            }
        }

        let overallCompatibility: PlantCompatibility
        if !incompatiblePlants.isEmpty { overallCompatibility = .incompatible }
        else if !recommendedCompanions.isEmpty { overallCompatibility = .companion }
        else { overallCompatibility = .neutral }

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
        guard let profile = companionDatabase[normalized] else { return [] }
        return profile.companions.map { denormalizePlantName($0) }
    }

    /// Get plants that should be avoided near the given plant
    public func getIncompatiblePlants(for plantName: String) -> [String] {
        let normalized = normalizePlantName(plantName)
        guard let profile = companionDatabase[normalized] else { return [] }
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

        let nitrogenFixers = ["bean", "pea"]
        if nitrogenFixers.contains(plant1) || nitrogenFixers.contains(plant2) {
            benefits.append("Nitrogen fixation improves soil fertility")
        }

        let pestRepellentPairs = [
            ("marigold", "tomato"), ("basil", "tomato"),
            ("garlic", "rose"), ("nasturtium", "cucumber")
        ]
        if pestRepellentPairs.contains(where: {
            ($0.0 == plant1 && $0.1 == plant2) || ($0.0 == plant2 && $0.1 == plant1)
        }) {
            benefits.append("Natural pest repellent relationship")
        }

        let threeSisters = ["corn", "bean", "squash"]
        if threeSisters.contains(plant1) && threeSisters.contains(plant2) && plant1 != plant2 {
            benefits.append("Traditional 'Three Sisters' companion planting")
        }

        return benefits.isEmpty ? nil : benefits
    }

    private func generateWarnings(for plant1: String, with plant2: String) -> [String]? {
        var warnings: [String] = []

        let allelopathicPlants = ["fennel", "black walnut"]
        if allelopathicPlants.contains(plant1) {
            warnings.append("\(plant1.capitalized) produces allelopathic compounds that inhibit growth")
        }
        if allelopathicPlants.contains(plant2) {
            warnings.append("\(plant2.capitalized) produces allelopathic compounds that inhibit growth")
        }

        let heavyFeeders = ["tomato", "corn", "squash", "cucumber"]
        if heavyFeeders.contains(plant1) && heavyFeeders.contains(plant2) && plant1 != plant2 {
            warnings.append("Both plants are heavy feeders - may compete for nutrients")
        }

        let nightshades = ["tomato", "potato", "pepper", "eggplant"]
        if nightshades.contains(plant1) && nightshades.contains(plant2) && plant1 != plant2 {
            warnings.append("Both are nightshades - shared pests and diseases")
        }

        return warnings.isEmpty ? nil : warnings
    }
}
