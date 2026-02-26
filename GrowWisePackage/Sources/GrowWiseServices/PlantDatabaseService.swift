import Foundation
import SwiftData
import GrowWiseModels

@MainActor
@Observable public final class PlantDatabaseService {
    private let dataService: DataService
    private let seedingWorker: PlantSeedingWorker
    
    public init(dataService: DataService) {
        self.dataService = dataService
        self.seedingWorker = PlantSeedingWorker(modelContainer: dataService.container)
    }
    
    // MARK: - Database Seeding
    
    public func seedPlantDatabase() async throws {
        // Check if database is already seeded
        let existingPlants = dataService.fetchPlantDatabase()
        if !existingPlants.isEmpty {
            return // Already seeded
        }

        print("🌱 Starting plant database seeding")
        let startTime = CFAbsoluteTimeGetCurrent()

        var failures: [PlantDatabaseSeedingError.Failure] = []

        let seedOperations: [(label: SeedCategory, operation: () async throws -> Void)] = [
            (.vegetables, seedVegetables),
            (.herbs, seedHerbs),
            (.flowers, seedFlowers),
            (.houseplants, seedHouseplants),
            (.fruits, seedFruits),
            (.succulents, seedSucculents)
        ]

        for entry in seedOperations {
            do {
                try await entry.operation()
            } catch {
                let failure = PlantDatabaseSeedingError.Failure(category: entry.label.rawValue, underlyingError: error)
                failures.append(failure)
                print("❌ Error seeding \(entry.label.rawValue): \(error)")
            }
        }

        if !failures.isEmpty {
            throw PlantDatabaseSeedingError(failures: failures)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let totalPlants = dataService.fetchPlantDatabase().count
        print("🚀 Seeded \(totalPlants) plants in \(String(format: "%.2f", totalTime))s")
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
                name: "Carrot",
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
            ),
            PlantData(
                name: "Zucchini",
                scientificName: "Cucurbita pepo",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .large,
                description: "Prolific summer squash that produces abundantly through the season",
                careInstructions: ["Direct sow after last frost", "Needs ample space to sprawl", "Harvest when 6-8 inches long for best flavor", "Check daily — squash grow fast"],
                companionPlants: ["Nasturtium", "Beans", "Corn"]
            ),
            PlantData(
                name: "Cucumber",
                scientificName: "Cucumis sativus",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .daily,
                space: .medium,
                description: "Fast-growing vine vegetable that thrives in warm weather",
                careInstructions: ["Plant after soil warms to 60°F", "Train vines on a trellis to save space", "Water deeply and consistently", "Harvest when firm and dark green"],
                companionPlants: ["Beans", "Peas", "Radishes"]
            ),
            PlantData(
                name: "Kale",
                scientificName: "Brassica oleracea var. sabellica",
                type: .vegetable,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .twiceWeekly,
                space: .small,
                description: "Hardy superfood leafy green that withstands frost and cold temperatures",
                careInstructions: ["Plant in early spring or fall", "Flavor improves after frost", "Harvest outer leaves from bottom up", "Very cold-hardy — grows in winter in mild climates"],
                companionPlants: ["Beets", "Herbs", "Onions"]
            )
        ]

        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(vegetables, batchSize: 5, category: .vegetables)
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
                scientificName: "Salvia rosmarinus",
                type: .herb,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .weekly,
                space: .medium,
                description: "Woody perennial herb with needle-like leaves and pine-like fragrance",
                careInstructions: ["Plant in well-draining soil", "Very drought tolerant once established", "Prune lightly after flowering", "Protect from hard frost"],
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
                description: "Fast-growing aromatic herb that spreads readily and repels pests",
                careInstructions: ["Grow in containers to prevent spreading", "Keep soil consistently moist", "Harvest regularly to encourage growth", "Can grow in partial shade"],
                companionPlants: ["Tomatoes", "Cabbage", "Carrots"]
            ),
            PlantData(
                name: "Thyme",
                scientificName: "Thymus vulgaris",
                type: .herb,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .weekly,
                space: .small,
                description: "Low-growing perennial herb with tiny fragrant leaves perfect for culinary use",
                careInstructions: ["Plant in well-draining soil", "Excellent drought tolerance once established", "Trim after flowering to keep compact", "Overwinters well in most climates"],
                companionPlants: ["Rosemary", "Cabbage", "Strawberries"]
            ),
            PlantData(
                name: "Cilantro",
                scientificName: "Coriandrum sativum",
                type: .herb,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .everyOtherDay,
                space: .small,
                description: "Fast-growing herb used in cooking worldwide; leaves are cilantro, seeds are coriander",
                careInstructions: ["Direct sow in cool weather — bolts quickly in heat", "Succession plant every 2-3 weeks for continuous harvest", "Allow some to bolt and self-seed", "Keep soil evenly moist"],
                companionPlants: ["Tomatoes", "Peppers", "Spinach"]
            )
        ]

        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(herbs, batchSize: 5, category: .herbs)
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
                description: "Bright annual flowers that deter garden pests and attract beneficial insects",
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
                description: "Tall annual flowers that track the sun and produce edible seeds",
                careInstructions: ["Direct sow in spring after frost", "Support tall varieties with stakes", "Deep watering encourages strong roots", "Harvest seeds when dried on stalk"],
                companionPlants: ["Corn", "Beans", "Squash"]
            ),
            PlantData(
                name: "Lavender",
                scientificName: "Lavandula angustifolia",
                type: .flower,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .weekly,
                space: .medium,
                description: "Fragrant perennial shrub prized for aromatherapy, culinary use, and pollinator attraction",
                careInstructions: ["Plant in well-draining alkaline soil", "Excellent drought tolerance once established", "Prune by one-third after first bloom to encourage bushiness", "Harvest flower spikes just before fully open for drying"],
                companionPlants: ["Rosemary", "Thyme", "Sage"]
            ),
            PlantData(
                name: "Rose",
                scientificName: "Rosa",
                type: .flower,
                difficulty: .intermediate,
                sunlight: .fullSun,
                watering: .everyOtherDay,
                space: .medium,
                description: "Classic flowering shrub beloved for its fragrant blooms and elegant form",
                careInstructions: ["Plant in fertile, well-draining soil with at least 6 hours of sun", "Water at the base to prevent fungal disease on leaves", "Deadhead spent blooms to encourage reblooming", "Prune in early spring to shape and remove dead wood"],
                companionPlants: ["Lavender", "Marigold", "Garlic"]
            ),
            PlantData(
                name: "Petunia",
                scientificName: "Petunia × atkinsiana",
                type: .flower,
                difficulty: .beginner,
                sunlight: .fullSun,
                watering: .daily,
                space: .small,
                description: "Prolific blooming annual with trumpet-shaped flowers in a wide range of colors",
                careInstructions: ["Plant after last frost in full sun", "Water consistently — they wilt quickly when dry", "Deadhead regularly or pinch stems to prevent legginess", "Fertilize monthly for best bloom performance"],
                companionPlants: ["Marigolds", "Basil", "Vegetables"]
            )
        ]

        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(flowers, batchSize: 5, category: .flowers)
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
                description: "Easy-care trailing vine perfect for beginners; one of the most forgiving houseplants",
                careInstructions: ["Tolerates low to medium light", "Water when top inch of soil is dry", "Trim to maintain shape and propagate cuttings", "Propagates easily in a glass of water"],
                companionPlants: ["Snake Plant", "ZZ Plant"]
            ),
            PlantData(
                name: "Snake Plant",
                scientificName: "Dracaena trifasciata",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .fullShade,
                watering: .biweekly,
                space: .small,
                description: "Extremely low-maintenance upright plant that tolerates neglect and low light",
                careInstructions: ["Tolerates very low light conditions", "Water sparingly — overwatering is the main risk", "Allow soil to dry completely between waterings", "Propagates from leaf cuttings or division"],
                companionPlants: ["ZZ Plant", "Pothos"]
            ),
            PlantData(
                name: "Spider Plant",
                scientificName: "Chlorophytum comosum",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .twiceWeekly,
                space: .medium,
                description: "Fast-growing plant that produces cascading baby plantlets on long runners",
                careInstructions: ["Bright, indirect light preferred", "Keep soil evenly moist but not soggy", "Allow plantlets to root in soil or water", "Non-toxic to pets and children"],
                companionPlants: ["Pothos", "Peace Lily"]
            ),
            PlantData(
                name: "Monstera",
                scientificName: "Monstera deliciosa",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .partialSun,
                watering: .weekly,
                space: .large,
                description: "Iconic tropical plant with large split leaves, also known as Swiss cheese plant",
                careInstructions: ["Bright, indirect light brings out best leaf fenestration", "Water when top 2 inches of soil are dry", "Provide a moss pole or trellis for climbing support", "Wipe leaves with a damp cloth to remove dust"],
                companionPlants: ["Pothos", "Bird of Paradise"]
            ),
            PlantData(
                name: "Peace Lily",
                scientificName: "Spathiphyllum wallisii",
                type: .houseplant,
                difficulty: .beginner,
                sunlight: .fullShade,
                watering: .weekly,
                space: .medium,
                description: "Elegant low-light plant that blooms with white spathes and purifies indoor air",
                careInstructions: ["Tolerates deep shade — great for bathrooms and offices", "Water when leaves just begin to droop slightly", "Mist leaves or use a humidifier for best growth", "Toxic to pets — keep out of reach of cats and dogs"],
                companionPlants: ["Snake Plant", "Spider Plant"]
            )
        ]

        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(houseplants, batchSize: 5, category: .houseplants)
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
        
        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(fruits, batchSize: 5, category: .fruits)
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
        
        // Batch create plants with yielding for better performance
        try await createPlantsInBatches(succulents, batchSize: 5, category: .succulents)
    }
    
    // MARK: - Search and Filter
    
    /// Search plants in the database by name or scientific name
    public func searchPlants(query: String) -> [Plant] {
        let allPlants = dataService.fetchPlantDatabase()
        let lowercaseQuery = query.lowercased()
        
        return allPlants.filter { plant in
            plant.name?.lowercased().contains(lowercaseQuery) ?? false ||
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
        let uniqueTypes = Set(allPlants.compactMap { $0.plantType })
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
    
    /// Optimized batch plant creation with autoreleasepool for aggressive garbage collection
    private func createPlantsInBatches(
        _ plantDataArray: [PlantData],
        batchSize: Int = 5,
        category: SeedCategory
    ) async throws {
        print("   📦 Batching \(plantDataArray.count) \(category.rawValue) (batch size: \(batchSize))")
        let startTime = CFAbsoluteTimeGetCurrent()

        for batchIndex in stride(from: 0, to: plantDataArray.count, by: batchSize) {
            let batchEnd = min(batchIndex + batchSize, plantDataArray.count)
            let batch = Array(plantDataArray[batchIndex..<batchEnd])

            // Perform async plant creation outside autoreleasepool
            for plantData in batch {
                try await createPlantFromData(plantData)
            }

            // Wrap synchronous logging in autoreleasepool for garbage collection
            autoreleasepool {
                // Log batch completion
                print("      ✓ Batch \(batchIndex/batchSize + 1): \(batch.count) plants")
            }

            // Yield control to keep UI responsive
            await Task.yield()
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("   ✅ Seeded \(plantDataArray.count) \(category.rawValue) in \(String(format: "%.3f", duration))s")
    }
    
    private func createPlantFromData(_ plantData: PlantData) async throws {
        try await seedingWorker.insertPlant(from: plantData)
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

    public init(failures: [Failure]) {
        self.failures = failures
    }

    public var errorDescription: String? {
        let categories = failures.map { $0.category }.joined(separator: ", ")
        return "Failed to seed plant categories: \(categories)"
    }

    public var failureReason: String? {
        failures
            .map { "\($0.category): \($0.underlyingErrorDescription)" }
            .joined(separator: " | ")
    }
}

private actor PlantSeedingWorker {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func insertPlant(from plantData: PlantData) async throws {
        // Create background ModelContext for safe concurrent insertions
        let context = ModelContext(modelContainer)

        // Create plant directly without @MainActor
        let plant = Plant(
            name: plantData.name,
            plantType: plantData.type,
            difficultyLevel: plantData.difficulty
        )

        // Set additional properties
        plant.scientificName = plantData.scientificName
        plant.sunlightRequirement = plantData.sunlight
        plant.wateringFrequency = plantData.watering
        plant.spaceRequirement = plantData.space
        plant.isUserPlant = false
        plant.notes = plantData.description + "\n\nCare Instructions:\n" + plantData.careInstructions.joined(separator: "\n• ")

        // Insert and save on background context
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

    public var displayName: String {
        rawValue.capitalized
    }
}

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
