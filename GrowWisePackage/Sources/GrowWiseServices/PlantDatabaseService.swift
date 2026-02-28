import Foundation
import SwiftData
import GrowWiseModels

// MARK: - JSON Codable Type for Plant Data

struct PlantData: Codable, Sendable {
    let name: String
    let scientificName: String
    let type: PlantType
    let difficulty: DifficultyLevel
    let sunlight: SunlightLevel
    let watering: WateringFrequency
    let space: SpaceRequirement
    let description: String
    let careInstructions: [String]
    let companionPlants: [String]
}

// MARK: - Plant Database Service

@MainActor
@Observable public final class PlantDatabaseService {
    private let dataService: DataService
    private let seedingWorker: PlantSeedingWorker
    private static let plantDataEntries: [PlantData] = {
        guard let url = Bundle.module.url(forResource: "plant_database", withExtension: "json") else {
            fatalError("Missing plant_database.json in GrowWiseServices bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PlantData].self, from: data)
        } catch {
            fatalError("Failed to decode plant_database.json: \(error)")
        }
    }()

    public init(dataService: DataService) {
        self.dataService = dataService
        self.seedingWorker = PlantSeedingWorker(modelContainer: dataService.container)
    }

    // MARK: - Database Seeding

    public func seedPlantDatabase() async throws {
        let existingPlants = dataService.fetchPlantDatabase()
        if !existingPlants.isEmpty { return }

        print("🌱 Starting plant database seeding")
        let startTime = CFAbsoluteTimeGetCurrent()

        var failures: [PlantDatabaseSeedingError.Failure] = []

        for category in SeedCategory.allCases {
            let entries = Self.plantDataEntries.filter { plantData in
                switch category {
                case .vegetables:  return plantData.type == .vegetable
                case .herbs:       return plantData.type == .herb
                case .flowers:     return plantData.type == .flower
                case .houseplants: return plantData.type == .houseplant
                case .fruits:      return plantData.type == .fruit
                case .succulents:  return plantData.type == .succulent
                }
            }
            do {
                try await createPlantsInBatches(entries, batchSize: 5, category: category)
            } catch {
                let failure = PlantDatabaseSeedingError.Failure(category: category.rawValue, underlyingError: error)
                failures.append(failure)
                print("❌ Error seeding \(category.rawValue): \(error)")
            }
        }

        if !failures.isEmpty { throw PlantDatabaseSeedingError(failures: failures) }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let totalPlants = dataService.fetchPlantDatabase().count
        print("🚀 Seeded \(totalPlants) plants in \(String(format: "%.2f", totalTime))s")
    }

    // MARK: - Search and Filter

    public func searchPlants(query: String) -> [Plant] {
        let allPlants = dataService.fetchPlantDatabase()
        let lowercaseQuery = query.lowercased()
        return allPlants.filter { plant in
            plant.name?.lowercased().contains(lowercaseQuery) ?? false ||
            plant.scientificName?.lowercased().contains(lowercaseQuery) ?? false
        }
    }

    public func filterPlants(
        by type: PlantType? = nil,
        difficulty: DifficultyLevel? = nil,
        sunlight: SunlightLevel? = nil,
        watering: WateringFrequency? = nil,
        space: SpaceRequirement? = nil,
        season: PlantingSeason? = nil
    ) -> [Plant] {
        let allPlants = dataService.fetchPlantDatabase()
        return allPlants.filter { plant in
            var matches = true
            if let type { matches = matches && plant.plantType == type }
            if let difficulty { matches = matches && plant.difficultyLevel == difficulty }
            if let sunlight { matches = matches && plant.sunlightRequirement == sunlight }
            if let watering { matches = matches && plant.wateringFrequency == watering }
            if let space { matches = matches && plant.spaceRequirement == space }
            if let season { matches = matches && isPlantSuitableForSeason(plant: plant, season: season) }
            return matches
        }
    }

    public func getBeginnerFriendlyPlants() -> [Plant] { filterPlants(difficulty: .beginner) }
    public func getPlantsBySeason(_ season: PlantingSeason) -> [Plant] { filterPlants(season: season) }

    public func getCompanionPlants(for plant: Plant) -> [Plant] {
        let allPlants = dataService.fetchPlantDatabase()
        switch plant.plantType {
        case .vegetable: return allPlants.filter { $0.plantType == .herb || $0.plantType == .flower }
        case .herb:      return allPlants.filter { $0.plantType == .vegetable }
        case .flower:    return allPlants.filter { $0.plantType == .vegetable || $0.plantType == .herb }
        default:         return []
        }
    }

    // MARK: - Statistics

    public func getPlantCountByType() -> [PlantType: Int] {
        let allPlants = dataService.fetchPlantDatabase()
        var counts: [PlantType: Int] = [:]
        for type in PlantType.allCases { counts[type] = allPlants.filter { $0.plantType == type }.count }
        return counts
    }

    public func getPlantCountByDifficulty() -> [DifficultyLevel: Int] {
        let allPlants = dataService.fetchPlantDatabase()
        var counts: [DifficultyLevel: Int] = [:]
        for difficulty in DifficultyLevel.allCases { counts[difficulty] = allPlants.filter { $0.difficultyLevel == difficulty }.count }
        return counts
    }

    public func getTotalPlantCount() -> Int { dataService.fetchPlantDatabase().count }

    public func getAvailablePlantTypes() -> [PlantType] {
        let allPlants = dataService.fetchPlantDatabase()
        let uniqueTypes = Set(allPlants.compactMap { $0.plantType })
        return Array(uniqueTypes).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Recommendations

    public func getRecommendedPlants(for userProfile: UserGardenProfile, limit: Int = 10) -> [PlantRecommendation] {
        let allPlants = dataService.fetchPlantDatabase()
        return allPlants.map { plant in
            let score = calculateCompatibilityScore(plant: plant, userProfile: userProfile)
            let reasons = generateRecommendationReasons(plant: plant, userProfile: userProfile, score: score)
            return PlantRecommendation(plant: plant, compatibilityScore: score, reasons: reasons)
        }
        .sorted { $0.compatibilityScore > $1.compatibilityScore }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Private Helpers

    private func createPlantsInBatches(_ plantDataArray: [PlantData], batchSize: Int = 5, category: SeedCategory) async throws {
        print("   📦 Batching \(plantDataArray.count) \(category.rawValue) (batch size: \(batchSize))")
        let startTime = CFAbsoluteTimeGetCurrent()
        for batchIndex in stride(from: 0, to: plantDataArray.count, by: batchSize) {
            let batchEnd = min(batchIndex + batchSize, plantDataArray.count)
            let batch = Array(plantDataArray[batchIndex..<batchEnd])
            for plantData in batch { try await seedingWorker.insertPlant(from: plantData) }
            autoreleasepool { print("      ✓ Batch \(batchIndex/batchSize + 1): \(batch.count) plants") }
            await Task.yield()
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("   ✅ Seeded \(plantDataArray.count) \(category.rawValue) in \(String(format: "%.3f", duration))s")
    }

    private func calculateCompatibilityScore(plant: Plant, userProfile: UserGardenProfile) -> Double {
        var score: Double = 0
        var maxScore: Double = 0

        maxScore += 30
        switch (userProfile.skillLevel, plant.difficultyLevel) {
        case (.beginner, .beginner): score += 30
        case (.beginner, .intermediate): score += 15
        case (.intermediate, .beginner), (.intermediate, .intermediate): score += 30
        case (.intermediate, .advanced): score += 20
        case (.advanced, _): score += 30
        default: score += 0
        }

        maxScore += 25
        if plant.spaceRequirement == userProfile.availableSpace { score += 25 }
        else if (plant.spaceRequirement == .small && userProfile.availableSpace != .small) { score += 20 }
        else { score += 10 }

        maxScore += 25
        let plantCareTime = estimateCareTime(for: plant)
        switch (userProfile.timeCommitment, plantCareTime) {
        case (.minimal, .minimal), (.light, .minimal): score += 25
        case (.minimal, .moderate): score += 10
        case (.light, .moderate), (.moderate, .minimal), (.moderate, .moderate): score += 25
        case (.moderate, .heavy), (.heavy, .minimal), (.heavy, .moderate), (.heavy, .heavy): score += 25
        case (.intensive, _): score += 25
        default: score += 15
        }

        maxScore += 20
        let gardenCompatibility = checkGardenTypeCompatibility(plant: plant, gardenType: userProfile.gardenType)
        score += gardenCompatibility * 20

        return (score / maxScore) * 100
    }

    private func generateRecommendationReasons(plant: Plant, userProfile: UserGardenProfile, score: Double) -> [String] {
        var reasons: [String] = []
        let matchingDifficulty: DifficultyLevel = {
            switch userProfile.skillLevel {
            case .beginner: return .beginner
            case .intermediate: return .intermediate
            case .advanced, .expert: return .advanced
            }
        }()
        if plant.difficultyLevel == matchingDifficulty { reasons.append("Perfect match for your \(userProfile.skillLevel.rawValue) skill level") }
        if plant.spaceRequirement == userProfile.availableSpace { reasons.append("Ideal size for your available space") }
        if estimateCareTime(for: plant) == userProfile.timeCommitment { reasons.append("Matches your time commitment level") }
        if plant.plantType == .herb || plant.plantType == .vegetable { reasons.append("Provides fresh, homegrown food") }
        if plant.difficultyLevel == .beginner { reasons.append("Very forgiving for new gardeners") }
        if reasons.isEmpty { reasons.append("A versatile plant suitable for many garden types") }
        return reasons
    }

    private func estimateCareTime(for plant: Plant) -> UserTimeCommitment {
        if plant.plantType == .succulent || plant.plantType == .houseplant { return .minimal }
        else if plant.plantType == .herb || plant.plantType == .flower { return .moderate }
        else { return .heavy }
    }

    private func isPlantSuitableForSeason(plant: Plant, season: PlantingSeason) -> Bool {
        switch (plant.plantType, season) {
        case (.vegetable, .spring): return ["Lettuce", "Spinach", "Carrots"].contains(plant.name)
        case (.vegetable, .summer): return ["Tomato", "Bell Pepper"].contains(plant.name)
        case (.herb, .spring), (.herb, .summer), (.herb, .fall): return true
        case (.flower, .spring), (.flower, .summer): return true
        case (.houseplant, _), (.succulent, _): return true
        case (.fruit, .spring), (.fruit, .summer): return true
        default: return false
        }
    }

    private func checkGardenTypeCompatibility(plant: Plant, gardenType: String) -> Double {
        switch (plant.plantType, gardenType) {
        case (.houseplant, "indoor"): return 1.0
        case (.succulent, "indoor"), (.succulent, "container"): return 1.0
        case (.herb, "container"), (.herb, "raised_bed"), (.herb, "outdoor"): return 1.0
        case (.vegetable, "raised_bed"), (.vegetable, "outdoor"), (.vegetable, "container"): return 1.0
        case (.flower, "outdoor"), (.flower, "raised_bed"): return 1.0
        case (.fruit, "outdoor"), (.fruit, "container"): return 0.8
        default: return 0.6
        }
    }
}

// MARK: - Seeding Infrastructure

public struct PlantDatabaseSeedingError: Error, LocalizedError, Sendable {
    public struct Failure: Sendable {
        public let category: String
        public let underlyingErrorDescription: String

        public init(category: String, underlyingError: any Error) {
            self.category = category
            self.underlyingErrorDescription = underlyingError.localizedDescription
        }
    }

    public let failures: [Failure]

    public init(failures: [Failure]) { self.failures = failures }

    public var errorDescription: String? {
        let categories = failures.map { $0.category }.joined(separator: ", ")
        return "Failed to seed plant categories: \(categories)"
    }

    public var failureReason: String? {
        failures.map { "\($0.category): \($0.underlyingErrorDescription)" }.joined(separator: " | ")
    }
}

private actor PlantSeedingWorker {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) { self.modelContainer = modelContainer }

    func insertPlant(from plantData: PlantData) async throws {
        let context = ModelContext(modelContainer)
        let plant = Plant(name: plantData.name, plantType: plantData.type, difficultyLevel: plantData.difficulty)
        plant.scientificName = plantData.scientificName
        plant.sunlightRequirement = plantData.sunlight
        plant.wateringFrequency = plantData.watering
        plant.spaceRequirement = plantData.space
        plant.isUserPlant = false
        plant.notes = plantData.description + "\n\nCare Instructions:\n" + plantData.careInstructions.joined(separator: "\n• ")
        context.insert(plant)
        try context.save()
    }
}

// MARK: - Supporting Types

public enum SeedCategory: String, CaseIterable, Sendable {
    case vegetables
    case herbs
    case flowers
    case houseplants
    case fruits
    case succulents

    public var displayName: String { rawValue.capitalized }
}

public struct PlantRecommendation: Identifiable {
    public let id = UUID()
    public let plant: Plant
    public let compatibilityScore: Double
    public let reasons: [String]

    public init(plant: Plant, compatibilityScore: Double, reasons: [String]) {
        self.plant = plant
        self.compatibilityScore = compatibilityScore
        self.reasons = reasons
    }
}

public struct UserGardenProfile {
    public let skillLevel: GardeningSkillLevel
    public let availableSpace: SpaceRequirement
    public let timeCommitment: UserTimeCommitment
    public let gardenType: String

    public init(skillLevel: GardeningSkillLevel, availableSpace: SpaceRequirement, timeCommitment: UserTimeCommitment, gardenType: String) {
        self.skillLevel = skillLevel
        self.availableSpace = availableSpace
        self.timeCommitment = timeCommitment
        self.gardenType = gardenType
    }
}

public typealias UserTimeCommitment = TimeCommitment

public enum PlantingSeason: String, CaseIterable, Codable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"

    public var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall: return "Fall"
        case .winter: return "Winter"
        }
    }

    public var description: String {
        switch self {
        case .spring: return "Cool weather planting season"
        case .summer: return "Warm weather growing season"
        case .fall: return "Fall planting and harvest season"
        case .winter: return "Indoor gardening season"
        }
    }
}
