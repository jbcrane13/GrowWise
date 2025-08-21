import Foundation
import SwiftData
import GrowWiseModels

@MainActor
public final class PlantDatabaseService: ObservableObject {
    private let dataService: DataService
    
    public init(dataService: DataService) {
        self.dataService = dataService
    }
    
    // MARK: - Database Seeding
    
    public func seedPlantDatabase() async throws {
        // Check if database is already seeded
        let existingPlants = dataService.fetchPlantDatabase()
        if !existingPlants.isEmpty {
            return // Already seeded
        }
        
        try await seedVegetables()
        try await seedHerbs()
        try await seedFlowers()
        try await seedHouseplants()
        try await seedFruits()
        try await seedSucculents()
    }
    
    private func seedVegetables() async throws {
        let vegetables = [
            PlantData(
                name: "Tomato",
                scientificName: "Solanum lycopersicum",
                type: .vegetable,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .medium,
                description: "Popular warm-season vegetable that produces nutritious fruits",
                careInstructions: ["Plant after last frost", "Provide support with stakes or cages", "Water consistently", "Fertilize regularly during growing season"],
                companionPlants: ["Basil", "Oregano", "Parsley", "Marigold"]
            ),
            PlantData(
                name: "Lettuce",
                scientificName: "Lactuca sativa",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .daily,
                space: .small,
                description: "Cool-season leafy green that's easy to grow and harvest",
                careInstructions: ["Plant in cool weather", "Keep soil moist", "Harvest outer leaves first", "Succession plant every 2 weeks"],
                companionPlants: ["Carrots", "Radishes", "Chives"]
            ),
            PlantData(
                name: "Carrots",
                scientificName: "Daucus carota",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .small,
                description: "Root vegetable that grows well in deep, loose soil",
                careInstructions: ["Direct sow seeds", "Thin seedlings to prevent crowding", "Keep soil consistently moist", "Harvest in 70-80 days"],
                companionPlants: ["Lettuce", "Chives", "Leeks"]
            ),
            PlantData(
                name: "Bell Pepper",
                scientificName: "Capsicum annuum",
                type: .vegetable,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .medium,
                description: "Warm-season vegetable producing sweet, colorful peppers",
                careInstructions: ["Start indoors 8-10 weeks before last frost", "Transplant after soil warms", "Provide consistent moisture", "Support with stakes if needed"],
                companionPlants: ["Basil", "Oregano", "Tomatoes"]
            ),
            PlantData(
                name: "Spinach",
                scientificName: "Spinacia oleracea",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .daily,
                space: .small,
                description: "Nutritious cool-season leafy green",
                careInstructions: ["Plant in cool weather", "Keep soil moist", "Harvest young leaves", "Bolt in hot weather"],
                companionPlants: ["Lettuce", "Radishes", "Peas"]
            )
        ]
        
        for plantData in vegetables {
            try await createPlantFromData(plantData)
        }
    }
    
    private func seedHerbs() async throws {
        let herbs = [
            PlantData(
                name: "Basil",
                scientificName: "Ocimum basilicum",
                type: .herb,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .daily,
                space: .small,
                description: "Aromatic herb perfect for cooking and companion planting",
                careInstructions: ["Plant after last frost", "Pinch flowers to encourage leaf growth", "Water at base to prevent leaf diseases", "Harvest regularly"],
                companionPlants: ["Tomatoes", "Peppers", "Oregano"]
            ),
            PlantData(
                name: "Oregano",
                scientificName: "Origanum vulgare",
                type: .herb,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .twiceWeekly,
                space: .small,
                description: "Hardy perennial herb with strong flavor",
                careInstructions: ["Plant in well-draining soil", "Drought tolerant once established", "Trim back after flowering", "Divide plants every 3-4 years"],
                companionPlants: ["Tomatoes", "Peppers", "Basil"]
            ),
            PlantData(
                name: "Parsley",
                scientificName: "Petroselinum crispum",
                type: .herb,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .everyOtherDay,
                space: .small,
                description: "Versatile biennial herb rich in vitamins",
                careInstructions: ["Soak seeds before planting", "Keep soil consistently moist", "Harvest outer stems first", "Overwinters in mild climates"],
                companionPlants: ["Tomatoes", "Carrots", "Chives"]
            ),
            PlantData(
                name: "Chives",
                scientificName: "Allium schoenoprasum",
                type: .herb,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .twiceWeekly,
                space: .small,
                description: "Perennial herb with mild onion flavor and pretty purple flowers",
                careInstructions: ["Very easy to grow", "Cut like grass for harvest", "Flowers are edible", "Divide clumps every few years"],
                companionPlants: ["Carrots", "Tomatoes", "Lettuce"]
            ),
            PlantData(
                name: "Rosemary",
                scientificName: "Rosmarinus officinalis",
                type: .herb,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .weekly,
                space: .medium,
                description: "Woody perennial herb with needle-like leaves",
                careInstructions: ["Plant in well-draining soil", "Very drought tolerant", "Prune lightly after flowering", "Protect from hard frost"],
                companionPlants: ["Sage", "Thyme", "Lavender"]
            ),
            PlantData(
                name: "Mint",
                scientificName: "Mentha spicata",
                type: .herb,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .daily,
                space: .small,
                description: "Fast-growing aromatic herb that spreads readily",
                careInstructions: ["Grow in containers to prevent spreading", "Keep soil consistently moist", "Harvest regularly to encourage growth", "Can grow in partial shade"],
                companionPlants: ["Tomatoes", "Cabbage", "Carrots"]
            )
        ]
        
        for plantData in herbs {
            try await createPlantFromData(plantData)
        }
    }
    
    private func seedFlowers() async throws {
        let flowers = [
            PlantData(
                name: "Marigold",
                scientificName: "Tagetes",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .small,
                description: "Bright annual flowers that deter garden pests",
                careInstructions: ["Direct sow after last frost", "Deadhead for continuous blooms", "Very heat tolerant", "Self-seeds readily"],
                companionPlants: ["Tomatoes", "Peppers", "Beans"]
            ),
            PlantData(
                name: "Sunflower",
                scientificName: "Helianthus annuus",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .large,
                description: "Tall annual flowers that follow the sun",
                careInstructions: ["Direct sow in spring", "Support tall varieties", "Deep watering preferred", "Harvest seeds when mature"],
                companionPlants: ["Corn", "Beans", "Squash"]
            ),
            PlantData(
                name: "Nasturtium",
                scientificName: "Tropaeolum majus",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .medium,
                description: "Edible flowers with peppery flavor",
                careInstructions: ["Direct sow after last frost", "Poor soil produces more flowers", "Both leaves and flowers are edible", "Attracts beneficial insects"],
                companionPlants: ["Tomatoes", "Cucumbers", "Radishes"]
            ),
            PlantData(
                name: "Zinnia",
                scientificName: "Zinnia elegans",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .twiceWeekly,
                space: .small,
                description: "Colorful annual flowers that attract butterflies",
                careInstructions: ["Direct sow after soil warms", "Deadhead for more blooms", "Good air circulation prevents powdery mildew", "Excellent cut flowers"],
                companionPlants: ["Vegetables", "Other annuals"]
            ),
            PlantData(
                name: "Cosmos",
                scientificName: "Cosmos bipinnatus",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .weekly,
                space: .medium,
                description: "Delicate annual flowers with feathery foliage",
                careInstructions: ["Direct sow in spring", "Drought tolerant", "Self-seeds readily", "Attracts beneficial insects"],
                companionPlants: ["Vegetables", "Other wildflowers"]
            )
        ]
        
        for plantData in flowers {
            try await createPlantFromData(plantData)
        }
    }
    
    private func seedHouseplants() async throws {
        let houseplants = [
            PlantData(
                name: "Pothos",
                scientificName: "Epipremnum aureum",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .weekly,
                space: .medium,
                description: "Easy-care trailing vine perfect for beginners",
                careInstructions: ["Low to medium light", "Water when soil is dry", "Trim to maintain shape", "Propagates easily in water"],
                companionPlants: ["Snake Plant", "ZZ Plant"]
            ),
            PlantData(
                name: "Snake Plant",
                scientificName: "Sansevieria trifasciata",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .fullShade,
                watering: .biweekly,
                space: .small,
                description: "Extremely low-maintenance plant with upright leaves",
                careInstructions: ["Tolerates low light", "Water sparingly", "Very drought tolerant", "Propagates from leaf cuttings"],
                companionPlants: ["ZZ Plant", "Pothos"]
            ),
            PlantData(
                name: "Rubber Plant",
                scientificName: "Ficus elastica",
                type: .houseplant,
                difficulty: .intermediate,
                sunlight: .partialSun,
                watering: .weekly,
                space: .large,
                description: "Popular houseplant with glossy green leaves",
                careInstructions: ["Bright, indirect light", "Water when top inch is dry", "Wipe leaves clean regularly", "Can grow quite large"],
                companionPlants: ["Fiddle Leaf Fig", "Monstera"]
            ),
            PlantData(
                name: "ZZ Plant",
                scientificName: "Zamioculcas zamiifolia",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .fullShade,
                watering: .biweekly,
                space: .medium,
                description: "Glossy-leaved plant that tolerates neglect",
                careInstructions: ["Low to bright indirect light", "Water when soil is completely dry", "Very drought tolerant", "Grows slowly"],
                companionPlants: ["Snake Plant", "Pothos"]
            ),
            PlantData(
                name: "Spider Plant",
                scientificName: "Chlorophytum comosum",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .twiceWeekly,
                space: .medium,
                description: "Fast-growing plant that produces baby plantlets",
                careInstructions: ["Bright, indirect light", "Keep soil evenly moist", "Produces 'babies' on runners", "Non-toxic to pets"],
                companionPlants: ["Pothos", "Peace Lily"]
            )
        ]
        
        for plantData in houseplants {
            try await createPlantFromData(plantData)
        }
    }
    
    private func seedFruits() async throws {
        let fruits = [
            PlantData(
                name: "Strawberry",
                scientificName: "Fragaria × ananassa",
                type: .fruit,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .daily,
                space: .medium,
                description: "Sweet berries perfect for containers or garden beds",
                careInstructions: ["Plant in spring", "Keep soil consistently moist", "Remove runners for larger fruit", "Harvest when fully red"],
                companionPlants: ["Thyme", "Borage", "Lettuce"]
            )
        ]
        
        for plantData in fruits {
            try await createPlantFromData(plantData)
        }
    }
    
    private func seedSucculents() async throws {
        let succulents = [
            PlantData(
                name: "Aloe Vera",
                scientificName: "Aloe barbadensis",
                type: .succulent,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .biweekly,
                space: .small,
                description: "Medicinal succulent with healing gel in leaves",
                careInstructions: ["Bright light", "Well-draining soil", "Water deeply but infrequently", "Harvest outer leaves for gel"],
                companionPlants: ["Jade Plant", "Echeveria"]
            ),
            PlantData(
                name: "Jade Plant",
                scientificName: "Crassula ovata",
                type: .succulent,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .biweekly,
                space: .small,
                description: "Popular succulent with thick, glossy leaves",
                careInstructions: ["Bright light", "Water when soil is dry", "Can develop into small tree", "Propagates from leaf or stem cuttings"],
                companionPlants: ["Aloe Vera", "String of Pearls"]
            ),
            PlantData(
                name: "Echeveria",
                scientificName: "Echeveria elegans",
                type: .succulent,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .weekly,
                space: .small,
                description: "Rosette-forming succulent with beautiful symmetry",
                careInstructions: ["Bright light", "Well-draining soil", "Water at soil level", "Produces colorful flower spikes"],
                companionPlants: ["Sedum", "Jade Plant"]
            )
        ]
        
        for plantData in succulents {
            try await createPlantFromData(plantData)
        }
    }
    
    // MARK: - Search and Filter
    
    /// Search plants in the database by name or scientific name
    public func searchPlants(query: String) -> [Plant] {
        let allPlants = dataService.fetchPlantDatabase()
        let lowercaseQuery = query.lowercased()
        
        return allPlants.filter { plant in
            plant.name.lowercased().contains(lowercaseQuery) ||
            plant.scientificName?.lowercased().contains(lowercaseQuery) ?? false
        }
    }
    
    /// Filter plants by multiple criteria
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
            
            if let type = type {
                matches = matches && plant.plantType == type
            }
            
            if let difficulty = difficulty {
                matches = matches && plant.difficultyLevel == difficulty
            }
            
            if let sunlight = sunlight {
                matches = matches && plant.sunlightRequirement == sunlight
            }
            
            if let watering = watering {
                matches = matches && plant.wateringFrequency == watering
            }
            
            if let space = space {
                matches = matches && plant.spaceRequirement == space
            }
            
            if let season = season {
                // Check if plant is suitable for the given season
                matches = matches && isPlantSuitableForSeason(plant: plant, season: season)
            }
            
            return matches
        }
    }
    
    /// Get plants suitable for beginners
    public func getBeginnerFriendlyPlants() -> [Plant] {
        return filterPlants(difficulty: .beginner)
    }
    
    /// Get plants by growing season
    public func getPlantsBySeason(_ season: PlantingSeason) -> [Plant] {
        return filterPlants(season: season)
    }
    
    /// Get companion plants for a given plant
    public func getCompanionPlants(for plant: Plant) -> [Plant] {
        // Note: This would require a companion plant relationship system
        // For now, return plants of complementary types
        let allPlants = dataService.fetchPlantDatabase()
        
        switch plant.plantType {
        case .vegetable:
            return allPlants.filter { $0.plantType == .herb || $0.plantType == .flower }
        case .herb:
            return allPlants.filter { $0.plantType == .vegetable }
        case .flower:
            return allPlants.filter { $0.plantType == .vegetable || $0.plantType == .herb }
        default:
            return []
        }
    }
    
    // MARK: - Plant Statistics and Categories
    
    /// Get count of plants by type
    public func getPlantCountByType() -> [PlantType: Int] {
        let allPlants = dataService.fetchPlantDatabase()
        var counts: [PlantType: Int] = [:]
        
        for type in PlantType.allCases {
            counts[type] = allPlants.filter { $0.plantType == type }.count
        }
        
        return counts
    }
    
    /// Get count of plants by difficulty
    public func getPlantCountByDifficulty() -> [DifficultyLevel: Int] {
        let allPlants = dataService.fetchPlantDatabase()
        var counts: [DifficultyLevel: Int] = [:]
        
        for difficulty in DifficultyLevel.allCases {
            counts[difficulty] = allPlants.filter { $0.difficultyLevel == difficulty }.count
        }
        
        return counts
    }
    
    /// Get total number of plants in database
    public func getTotalPlantCount() -> Int {
        return dataService.fetchPlantDatabase().count
    }
    
    /// Get all plant types available in the database
    public func getAvailablePlantTypes() -> [PlantType] {
        let allPlants = dataService.fetchPlantDatabase()
        let uniqueTypes = Set(allPlants.map { $0.plantType })
        return Array(uniqueTypes).sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Plant Recommendations
    
    public func getRecommendedPlants(for userProfile: UserGardenProfile, limit: Int = 10) -> [PlantRecommendation] {
        let allPlants = dataService.fetchPlantDatabase()
        var recommendations: [PlantRecommendation] = []
        
        for plant in allPlants {
            let compatibilityScore = calculateCompatibilityScore(plant: plant, userProfile: userProfile)
            let reasons = generateRecommendationReasons(plant: plant, userProfile: userProfile, score: compatibilityScore)
            
            let recommendation = PlantRecommendation(
                plant: plant,
                compatibilityScore: compatibilityScore,
                reasons: reasons
            )
            recommendations.append(recommendation)
        }
        
        // Sort by compatibility score and return top recommendations
        return recommendations
            .sorted { $0.compatibilityScore > $1.compatibilityScore }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Helper Methods
    
    private func createPlantFromData(_ plantData: PlantData) async throws {
        let plant = try dataService.createPlant(
            name: plantData.name,
            type: plantData.type,
            difficultyLevel: plantData.difficulty,
            garden: nil
        )
        
        // Set additional properties
        plant.scientificName = plantData.scientificName
        plant.sunlightRequirement = plantData.sunlight
        plant.wateringFrequency = plantData.watering
        plant.spaceRequirement = plantData.space
        plant.isUserPlant = false // Database plants
        plant.notes = plantData.description + "\n\nCare Instructions:\n" + plantData.careInstructions.joined(separator: "\n• ")
        // Note: companionPlants property needs to be added to Plant model or removed from PlantData
        
        try dataService.updatePlant(plant)
    }
    
    private func calculateCompatibilityScore(plant: Plant, userProfile: UserGardenProfile) -> Double {
        var score: Double = 0
        var maxScore: Double = 0
        
        // Difficulty level compatibility (30%)
        maxScore += 30
        switch (userProfile.skillLevel, plant.difficultyLevel) {
        case (.beginner, .beginner):
            score += 30
        case (.beginner, .intermediate):
            score += 15
        case (.intermediate, .beginner), (.intermediate, .intermediate):
            score += 30
        case (.intermediate, .advanced):
            score += 20
        case (.advanced, _):
            score += 30
        default:
            score += 0
        }
        
        // Space compatibility (25%)
        maxScore += 25
        if plant.spaceRequirement == userProfile.availableSpace {
            score += 25
        } else if (plant.spaceRequirement == .small && userProfile.availableSpace != .small) {
            score += 20 // Small plants fit in larger spaces
        } else {
            score += 10
        }
        
        // Care time compatibility (25%)
        maxScore += 25
        let plantCareTime = estimateCareTime(for: plant)
        switch (userProfile.timeCommitment, plantCareTime) {
        case (.minimal, .minimal), (.light, .minimal):
            score += 25
        case (.minimal, .moderate):
            score += 10
        case (.light, .moderate), (.moderate, .minimal), (.moderate, .moderate):
            score += 25
        case (.moderate, .heavy), (.heavy, .minimal), (.heavy, .moderate), (.heavy, .heavy):
            score += 25
        case (.intensive, _):
            score += 25
        default:
            score += 15
        }
        
        // Garden type compatibility (20%)
        maxScore += 20
        let gardenCompatibility = checkGardenTypeCompatibility(plant: plant, gardenType: userProfile.gardenType)
        score += gardenCompatibility * 20
        
        return (score / maxScore) * 100
    }
    
    private func generateRecommendationReasons(plant: Plant, userProfile: UserGardenProfile, score: Double) -> [String] {
        var reasons: [String] = []
        
        // Convert GardeningSkillLevel to DifficultyLevel for comparison
        let matchingDifficulty: DifficultyLevel = {
            switch userProfile.skillLevel {
            case .beginner: return .beginner
            case .intermediate: return .intermediate
            case .advanced, .expert: return .advanced
            }
        }()
        
        if plant.difficultyLevel == matchingDifficulty {
            reasons.append("Perfect match for your \(userProfile.skillLevel.rawValue) skill level")
        }
        
        if plant.spaceRequirement == userProfile.availableSpace {
            reasons.append("Ideal size for your available space")
        }
        
        let careTime = estimateCareTime(for: plant)
        if careTime == userProfile.timeCommitment {
            reasons.append("Matches your time commitment level")
        }
        
        if plant.plantType == .herb || plant.plantType == .vegetable {
            reasons.append("Provides fresh, homegrown food")
        }
        
        if plant.difficultyLevel == .beginner {
            reasons.append("Very forgiving for new gardeners")
        }
        
        if reasons.isEmpty {
            reasons.append("A versatile plant suitable for many garden types")
        }
        
        return reasons
    }
    
    private func estimateCareTime(for plant: Plant) -> UserTimeCommitment {
        // Estimate based on plant characteristics
        if plant.plantType == .succulent || plant.plantType == .houseplant {
            return .minimal
        } else if plant.plantType == .herb || plant.plantType == .flower {
            return .moderate
        } else {
            return .heavy
        }
    }
    
    private func isPlantSuitableForSeason(plant: Plant, season: PlantingSeason) -> Bool {
        // Determine plant suitability based on type and season
        switch (plant.plantType, season) {
        case (.vegetable, .spring):
            // Cool season vegetables like lettuce, spinach, carrots
            return ["Lettuce", "Spinach", "Carrots"].contains(plant.name)
        case (.vegetable, .summer):
            // Warm season vegetables like tomatoes, peppers
            return ["Tomato", "Bell Pepper"].contains(plant.name)
        case (.herb, .spring), (.herb, .summer), (.herb, .fall):
            // Most herbs can be grown in spring, summer, and fall
            return true
        case (.flower, .spring), (.flower, .summer):
            // Annual flowers for spring and summer
            return true
        case (.houseplant, _), (.succulent, _):
            // Indoor plants can be grown year-round
            return true
        case (.fruit, .spring), (.fruit, .summer):
            // Fruits are typically planted in spring/summer
            return true
        default:
            return false
        }
    }
    
    private func checkGardenTypeCompatibility(plant: Plant, gardenType: String) -> Double {
        switch (plant.plantType, gardenType) {
        case (.houseplant, "indoor"):
            return 1.0
        case (.succulent, "indoor"), (.succulent, "container"):
            return 1.0
        case (.herb, "container"), (.herb, "raised_bed"), (.herb, "outdoor"):
            return 1.0
        case (.vegetable, "raised_bed"), (.vegetable, "outdoor"), (.vegetable, "container"):
            return 1.0
        case (.flower, "outdoor"), (.flower, "raised_bed"):
            return 1.0
        case (.fruit, "outdoor"), (.fruit, "container"):
            return 0.8
        default:
            return 0.6
        }
    }
}

// MARK: - Supporting Types

struct PlantData {
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
    public let gardenType: String // "indoor", "outdoor", "container", "raised_bed"
    
    public init(skillLevel: GardeningSkillLevel, availableSpace: SpaceRequirement, timeCommitment: UserTimeCommitment, gardenType: String) {
        self.skillLevel = skillLevel
        self.availableSpace = availableSpace
        self.timeCommitment = timeCommitment
        self.gardenType = gardenType
    }
}

// Alias for the TimeCommitment from User model to avoid conflicts
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