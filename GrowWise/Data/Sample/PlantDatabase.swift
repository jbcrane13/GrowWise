import Foundation
import SwiftData
import GrowWiseModels

/// Sample plant database with 25+ common plants for MVP
struct PlantDatabase {
    
    static let samplePlants: [PlantData] = [
        // Herbs
        PlantData(
            name: "Basil",
            scientificName: "Ocimum basilicum",
            description: "Aromatic herb perfect for cooking, easy to grow indoors or outdoors",
            category: "Herb",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 3,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 60,
            temperatureMax: 85,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 8,
            commonProblems: ["aphids", "fungal_leaf_spot", "downy_mildew"],
            careTips: ["Pinch flowers to encourage leaf growth", "Water at soil level", "Harvest regularly"],
            fertilizingFrequencyWeeks: 3,
            pruningFrequencyWeeks: 2,
            companionPlants: ["tomato", "pepper", "oregano"]
        ),
        
        PlantData(
            name: "Mint",
            scientificName: "Mentha",
            description: "Fast-growing herb that thrives in partial shade",
            category: "Herb",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 2,
            sunRequirement: "partial_shade",
            soilType: "moist",
            temperatureMin: 55,
            temperatureMax: 80,
            hardinessZones: "3-9",
            growthStages: ["seedling", "vegetative", "mature"],
            harvestTimeWeeks: 6,
            commonProblems: ["rust", "aphids", "spider_mites"],
            careTips: ["Contains growth with barriers", "Keep soil consistently moist", "Regular harvesting"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 2,
            companionPlants: ["cabbage", "broccoli", "kale"]
        ),
        
        PlantData(
            name: "Rosemary",
            scientificName: "Rosmarinus officinalis",
            description: "Drought-tolerant perennial herb with needle-like leaves",
            category: "Herb",
            difficultyLevel: "intermediate",
            maintenanceLevel: "low",
            wateringFrequencyDays: 7,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 50,
            temperatureMax: 90,
            hardinessZones: "6-10",
            growthStages: ["seedling", "juvenile", "mature"],
            harvestTimeWeeks: 12,
            commonProblems: ["root_rot", "powdery_mildew", "aphids"],
            careTips: ["Avoid overwatering", "Prune after flowering", "Protect from harsh winds"],
            fertilizingFrequencyWeeks: 8,
            pruningFrequencyWeeks: 8,
            companionPlants: ["sage", "thyme", "lavender"]
        ),
        
        PlantData(
            name: "Parsley",
            scientificName: "Petroselinum crispum",
            description: "Biennial herb rich in vitamins, easy to grow",
            category: "Herb",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 3,
            sunRequirement: "partial_sun",
            soilType: "well_draining",
            temperatureMin: 50,
            temperatureMax: 80,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "mature"],
            harvestTimeWeeks: 10,
            commonProblems: ["aphids", "leaf_miners", "crown_rot"],
            careTips: ["Harvest outer leaves first", "Keep soil evenly moist", "Succession plant every 3 weeks"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 3,
            companionPlants: ["tomato", "carrot", "chives"]
        ),
        
        PlantData(
            name: "Oregano",
            scientificName: "Origanum vulgare",
            description: "Hardy perennial herb with strong flavor",
            category: "Herb",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 5,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 55,
            temperatureMax: 85,
            hardinessZones: "4-10",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 8,
            commonProblems: ["spider_mites", "aphids", "root_rot"],
            careTips: ["Pinch flowers for better leaves", "Divide every 3 years", "Harvest before flowering"],
            fertilizingFrequencyWeeks: 6,
            pruningFrequencyWeeks: 4,
            companionPlants: ["basil", "thyme", "tomato"]
        ),
        
        // Vegetables
        PlantData(
            name: "Tomato",
            scientificName: "Solanum lycopersicum",
            description: "Popular warm-season vegetable requiring support",
            category: "Vegetable",
            difficultyLevel: "intermediate",
            maintenanceLevel: "medium",
            wateringFrequencyDays: 2,
            sunRequirement: "full_sun",
            soilType: "rich_loamy",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "fruiting"],
            harvestTimeWeeks: 16,
            commonProblems: ["blight", "aphids", "hornworms", "blossom_end_rot"],
            careTips: ["Provide strong support", "Mulch around base", "Remove suckers"],
            fertilizingFrequencyWeeks: 2,
            pruningFrequencyWeeks: 2,
            companionPlants: ["basil", "marigold", "pepper"]
        ),
        
        PlantData(
            name: "Lettuce",
            scientificName: "Lactuca sativa",
            description: "Cool-season leafy green, quick to harvest",
            category: "Vegetable",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 2,
            sunRequirement: "partial_sun",
            soilType: "well_draining",
            temperatureMin: 45,
            temperatureMax: 75,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "mature"],
            harvestTimeWeeks: 6,
            commonProblems: ["aphids", "slugs", "downy_mildew"],
            careTips: ["Harvest outer leaves", "Succession plant every 2 weeks", "Provide afternoon shade in summer"],
            fertilizingFrequencyWeeks: 3,
            pruningFrequencyWeeks: 0,
            companionPlants: ["carrot", "radish", "chives"]
        ),
        
        PlantData(
            name: "Spinach",
            scientificName: "Spinacia oleracea",
            description: "Nutritious cool-season leafy green",
            category: "Vegetable",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 3,
            sunRequirement: "partial_sun",
            soilType: "rich_loamy",
            temperatureMin: 35,
            temperatureMax: 70,
            hardinessZones: "2-9",
            growthStages: ["seedling", "vegetative", "mature"],
            harvestTimeWeeks: 5,
            commonProblems: ["aphids", "leaf_miners", "downy_mildew"],
            careTips: ["Plant in cool weather", "Harvest before bolting", "Keep soil consistently moist"],
            fertilizingFrequencyWeeks: 3,
            pruningFrequencyWeeks: 0,
            companionPlants: ["strawberry", "peas", "radish"]
        ),
        
        PlantData(
            name: "Carrot",
            scientificName: "Daucus carota",
            description: "Root vegetable requiring deep, loose soil",
            category: "Vegetable",
            difficultyLevel: "intermediate",
            maintenanceLevel: "medium",
            wateringFrequencyDays: 4,
            sunRequirement: "full_sun",
            soilType: "sandy_loam",
            temperatureMin: 55,
            temperatureMax: 75,
            hardinessZones: "3-10",
            growthStages: ["seedling", "vegetative", "root_development", "mature"],
            harvestTimeWeeks: 12,
            commonProblems: ["carrot_fly", "aphids", "forked_roots"],
            careTips: ["Thin seedlings early", "Keep soil loose", "Avoid fresh manure"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 0,
            companionPlants: ["onion", "leek", "rosemary"]
        ),
        
        PlantData(
            name: "Radish",
            scientificName: "Raphanus sativus",
            description: "Fast-growing root vegetable, ready in weeks",
            category: "Vegetable",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 2,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 45,
            temperatureMax: 75,
            hardinessZones: "2-10",
            growthStages: ["seedling", "root_development", "mature"],
            harvestTimeWeeks: 4,
            commonProblems: ["flea_beetles", "root_maggots", "cracking"],
            careTips: ["Plant succession crops", "Harvest promptly", "Keep soil evenly moist"],
            fertilizingFrequencyWeeks: 0,
            pruningFrequencyWeeks: 0,
            companionPlants: ["carrot", "lettuce", "cucumber"]
        ),
        
        // Flowers
        PlantData(
            name: "Marigold",
            scientificName: "Tagetes",
            description: "Bright annual flower that deters pests",
            category: "Flower",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 3,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 60,
            temperatureMax: 90,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 8,
            commonProblems: ["aphids", "spider_mites", "powdery_mildew"],
            careTips: ["Deadhead regularly", "Avoid overwatering", "Plant near vegetables"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 1,
            companionPlants: ["tomato", "pepper", "cabbage"]
        ),
        
        PlantData(
            name: "Sunflower",
            scientificName: "Helianthus annuus",
            description: "Tall annual flower that follows the sun",
            category: "Flower",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 4,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 70,
            temperatureMax: 95,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "seed_production"],
            harvestTimeWeeks: 16,
            commonProblems: ["aphids", "birds", "stalk_borers"],
            careTips: ["Provide support for tall varieties", "Deep watering", "Protect seeds from birds"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 0,
            companionPlants: ["corn", "beans", "squash"]
        ),
        
        PlantData(
            name: "Zinnia",
            scientificName: "Zinnia elegans",
            description: "Colorful annual flower, excellent for cutting",
            category: "Flower",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 3,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 10,
            commonProblems: ["powdery_mildew", "aphids", "spider_mites"],
            careTips: ["Water at soil level", "Deadhead for more blooms", "Good air circulation"],
            fertilizingFrequencyWeeks: 3,
            pruningFrequencyWeeks: 1,
            companionPlants: ["cosmos", "marigold", "nasturtium"]
        ),
        
        PlantData(
            name: "Cosmos",
            scientificName: "Cosmos bipinnatus",
            description: "Delicate annual flower that attracts butterflies",
            category: "Flower",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 4,
            sunRequirement: "full_sun",
            soilType: "poor_to_average",
            temperatureMin: 60,
            temperatureMax: 85,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 12,
            commonProblems: ["aphids", "powdery_mildew", "weak_stems"],
            careTips: ["Avoid rich soil", "Deadhead regularly", "May need staking"],
            fertilizingFrequencyWeeks: 6,
            pruningFrequencyWeeks: 1,
            companionPlants: ["zinnia", "marigold", "sunflower"]
        ),
        
        PlantData(
            name: "Nasturtium",
            scientificName: "Tropaeolum majus",
            description: "Edible flower with peppery taste, climbs or trails",
            category: "Flower",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 5,
            sunRequirement: "full_sun",
            soilType: "poor_to_average",
            temperatureMin: 55,
            temperatureMax: 75,
            hardinessZones: "2-11",
            growthStages: ["seedling", "vegetative", "flowering", "mature"],
            harvestTimeWeeks: 8,
            commonProblems: ["aphids", "flea_beetles", "cucumber_beetles"],
            careTips: ["Poor soil produces more flowers", "Edible flowers and leaves", "Self-seeds readily"],
            fertilizingFrequencyWeeks: 8,
            pruningFrequencyWeeks: 2,
            companionPlants: ["cucumber", "radish", "beans"]
        ),
        
        // Succulents
        PlantData(
            name: "Aloe Vera",
            scientificName: "Aloe barbadensis",
            description: "Medicinal succulent with healing gel",
            category: "Succulent",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 14,
            sunRequirement: "bright_indirect",
            soilType: "succulent_mix",
            temperatureMin: 60,
            temperatureMax: 85,
            hardinessZones: "9-11",
            growthStages: ["pup", "juvenile", "mature"],
            harvestTimeWeeks: 52,
            commonProblems: ["root_rot", "mealybugs", "scale"],
            careTips: ["Water deeply but infrequently", "Ensure good drainage", "Bright light but not direct sun"],
            fertilizingFrequencyWeeks: 12,
            pruningFrequencyWeeks: 0,
            companionPlants: ["jade", "echeveria", "haworthia"]
        ),
        
        PlantData(
            name: "Jade Plant",
            scientificName: "Crassula ovata",
            description: "Easy-care succulent with thick, glossy leaves",
            category: "Succulent",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 10,
            sunRequirement: "bright_indirect",
            soilType: "succulent_mix",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "10-11",
            growthStages: ["cutting", "juvenile", "mature"],
            harvestTimeWeeks: 104,
            commonProblems: ["mealybugs", "root_rot", "aphids"],
            careTips: ["Allow soil to dry between waterings", "Prune to maintain shape", "Can propagate from leaf cuttings"],
            fertilizingFrequencyWeeks: 16,
            pruningFrequencyWeeks: 12,
            companionPlants: ["aloe", "snake_plant", "pothos"]
        ),
        
        PlantData(
            name: "Echeveria",
            scientificName: "Echeveria",
            description: "Rosette-forming succulent with beautiful colors",
            category: "Succulent",
            difficultyLevel: "intermediate",
            maintenanceLevel: "low",
            wateringFrequencyDays: 12,
            sunRequirement: "bright_indirect",
            soilType: "succulent_mix",
            temperatureMin: 60,
            temperatureMax: 80,
            hardinessZones: "9-11",
            growthStages: ["offset", "juvenile", "mature"],
            harvestTimeWeeks: 78,
            commonProblems: ["root_rot", "mealybugs", "aphids"],
            careTips: ["Bottom watering preferred", "Avoid water on leaves", "Propagate from offsets"],
            fertilizingFrequencyWeeks: 16,
            pruningFrequencyWeeks: 0,
            companionPlants: ["sedum", "jade", "haworthia"]
        ),
        
        // Houseplants
        PlantData(
            name: "Pothos",
            scientificName: "Epipremnum aureum",
            description: "Low-light tolerant vine, excellent air purifier",
            category: "Houseplant",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 7,
            sunRequirement: "low_light",
            soilType: "potting_mix",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "10-12",
            growthStages: ["cutting", "trailing", "mature"],
            harvestTimeWeeks: 26,
            commonProblems: ["root_rot", "mealybugs", "spider_mites"],
            careTips: ["Allow soil to dry between waterings", "Trim to encourage bushiness", "Easy to propagate"],
            fertilizingFrequencyWeeks: 8,
            pruningFrequencyWeeks: 8,
            companionPlants: ["snake_plant", "philodendron", "peace_lily"]
        ),
        
        PlantData(
            name: "Snake Plant",
            scientificName: "Sansevieria trifasciata",
            description: "Extremely low-maintenance plant that tolerates neglect",
            category: "Houseplant",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 21,
            sunRequirement: "low_light",
            soilType: "well_draining",
            temperatureMin: 60,
            temperatureMax: 85,
            hardinessZones: "9-11",
            growthStages: ["pup", "juvenile", "mature"],
            harvestTimeWeeks: 52,
            commonProblems: ["root_rot", "mealybugs", "scale"],
            careTips: ["Very drought tolerant", "Propagate by division", "Tolerates low light"],
            fertilizingFrequencyWeeks: 24,
            pruningFrequencyWeeks: 0,
            companionPlants: ["pothos", "philodendron", "rubber_tree"]
        ),
        
        PlantData(
            name: "Peace Lily",
            scientificName: "Spathiphyllum",
            description: "Elegant flowering houseplant that signals watering needs",
            category: "Houseplant",
            difficultyLevel: "intermediate",
            maintenanceLevel: "medium",
            wateringFrequencyDays: 5,
            sunRequirement: "low_light",
            soilType: "potting_mix",
            temperatureMin: 65,
            temperatureMax: 80,
            hardinessZones: "11-12",
            growthStages: ["young", "flowering", "mature"],
            harvestTimeWeeks: 39,
            commonProblems: ["spider_mites", "mealybugs", "brown_tips"],
            careTips: ["Droops when thirsty", "High humidity preferred", "Remove spent flowers"],
            fertilizingFrequencyWeeks: 6,
            pruningFrequencyWeeks: 4,
            companionPlants: ["pothos", "philodendron", "boston_fern"]
        ),
        
        PlantData(
            name: "Rubber Tree",
            scientificName: "Ficus elastica",
            description: "Large-leafed tree plant that makes a statement",
            category: "Houseplant",
            difficultyLevel: "intermediate",
            maintenanceLevel: "medium",
            wateringFrequencyDays: 10,
            sunRequirement: "bright_indirect",
            soilType: "potting_mix",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "10-12",
            growthStages: ["small", "growing", "mature"],
            harvestTimeWeeks: 78,
            commonProblems: ["spider_mites", "scale", "root_rot"],
            careTips: ["Wipe leaves regularly", "Rotate for even growth", "Prune to control size"],
            fertilizingFrequencyWeeks: 8,
            pruningFrequencyWeeks: 12,
            companionPlants: ["monstera", "fiddle_leaf", "philodendron"]
        ),
        
        PlantData(
            name: "Philodendron",
            scientificName: "Philodendron hederaceum",
            description: "Heart-shaped leaves on trailing vines",
            category: "Houseplant",
            difficultyLevel: "beginner",
            maintenanceLevel: "low",
            wateringFrequencyDays: 7,
            sunRequirement: "bright_indirect",
            soilType: "potting_mix",
            temperatureMin: 65,
            temperatureMax: 85,
            hardinessZones: "9-11",
            growthStages: ["cutting", "trailing", "mature"],
            harvestTimeWeeks: 26,
            commonProblems: ["aphids", "mealybugs", "root_rot"],
            careTips: ["Allow soil to dry slightly", "Provide support for climbing", "Easy to propagate"],
            fertilizingFrequencyWeeks: 8,
            pruningFrequencyWeeks: 8,
            companionPlants: ["pothos", "monstera", "peace_lily"]
        ),
        
        // Fruits
        PlantData(
            name: "Strawberry",
            scientificName: "Fragaria × ananassa",
            description: "Sweet berry that produces runners for new plants",
            category: "Fruit",
            difficultyLevel: "intermediate",
            maintenanceLevel: "medium",
            wateringFrequencyDays: 3,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 60,
            temperatureMax: 80,
            hardinessZones: "3-10",
            growthStages: ["transplant", "vegetative", "flowering", "fruiting"],
            harvestTimeWeeks: 12,
            commonProblems: ["slugs", "aphids", "gray_mold"],
            careTips: ["Mulch around plants", "Remove runners unless propagating", "Net to protect from birds"],
            fertilizingFrequencyWeeks: 4,
            pruningFrequencyWeeks: 4,
            companionPlants: ["thyme", "borage", "lettuce"]
        ),
        
        PlantData(
            name: "Blueberry",
            scientificName: "Vaccinium corymbosum",
            description: "Antioxidant-rich shrub requiring acidic soil",
            category: "Fruit",
            difficultyLevel: "advanced",
            maintenanceLevel: "high",
            wateringFrequencyDays: 4,
            sunRequirement: "full_sun",
            soilType: "acidic",
            temperatureMin: 45,
            temperatureMax: 85,
            hardinessZones: "3-9",
            growthStages: ["young_bush", "establishing", "productive", "mature"],
            harvestTimeWeeks: 104,
            commonProblems: ["aphids", "scale", "mummy_berry"],
            careTips: ["Requires acidic soil pH 4.5-5.5", "Mulch with pine needles", "Prune in late winter"],
            fertilizingFrequencyWeeks: 12,
            pruningFrequencyWeeks: 52,
            companionPlants: ["azalea", "rhododendron", "cranberry"]
        ),
        
        PlantData(
            name: "Lemon Tree",
            scientificName: "Citrus limon",
            description: "Fragrant citrus tree that can be grown in containers",
            category: "Fruit",
            difficultyLevel: "advanced",
            maintenanceLevel: "high",
            wateringFrequencyDays: 5,
            sunRequirement: "full_sun",
            soilType: "well_draining",
            temperatureMin: 55,
            temperatureMax: 85,
            hardinessZones: "9-11",
            growthStages: ["young_tree", "growing", "flowering", "fruiting"],
            harvestTimeWeeks: 156,
            commonProblems: ["aphids", "scale", "citrus_canker"],
            careTips: ["Protect from frost", "Ensure good drainage", "Regular feeding required"],
            fertilizingFrequencyWeeks: 6,
            pruningFrequencyWeeks: 12,
            companionPlants: ["lavender", "rosemary", "thyme"]
        )
    ]
    
    /// Load sample plants into SwiftData
    static func loadSamplePlants(into context: ModelContext) {
        for plantData in samplePlants {
            // Map category string to PlantType enum
            let plantType: PlantType = {
                switch plantData.category.lowercased() {
                case "herb": return .herb
                case "vegetable": return .vegetable
                case "flower": return .flower
                case "houseplant": return .houseplant
                case "fruit": return .fruit
                case "succulent": return .succulent
                default: return .herb // Default fallback
                }
            }()
            
            // Map difficulty level string to DifficultyLevel enum
            let difficultyLevel: DifficultyLevel = {
                switch plantData.difficultyLevel.lowercased() {
                case "beginner": return .beginner
                case "intermediate": return .intermediate
                case "advanced": return .advanced
                default: return .beginner // Default fallback
                }
            }()
            
            // Map sun requirement string to SunlightLevel enum
            let sunlightRequirement: SunlightLevel = {
                switch plantData.sunRequirement.lowercased() {
                case "full_sun": return .fullSun
                case "partial_sun": return .partialSun
                case "partial_shade": return .partialShade
                case "full_shade", "low_light": return .fullShade
                case "bright_indirect": return .partialSun
                default: return .fullSun // Default fallback
                }
            }()
            
            // Map watering frequency days to WateringFrequency enum
            let wateringFrequency: WateringFrequency = {
                switch plantData.wateringFrequencyDays {
                case 1: return .daily
                case 2: return .everyOtherDay
                case 3: return .twiceWeekly
                case 7: return .weekly
                case 14: return .biweekly
                case 21...30: return .monthly
                default: return .weekly // Default fallback
                }
            }()
            
            // Create SwiftData Plant model
            let plant = Plant(
                name: plantData.name,
                plantType: plantType,
                difficultyLevel: difficultyLevel,
                isUserPlant: false // This is a database plant, not user's plant
            )
            
            // Set additional properties
            plant.scientificName = plantData.scientificName
            plant.sunlightRequirement = sunlightRequirement
            plant.wateringFrequency = wateringFrequency
            plant.spaceRequirement = .medium // Default value, could be enhanced
            plant.growthStage = .seedling // Default starting stage
            plant.healthStatus = .healthy // Default status
            plant.notes = plantData.description
            
            // Insert the plant into the context
            context.insert(plant)
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving sample plants: \(error)")
        }
    }
}

/// Helper struct for plant data
struct PlantData {
    let name: String
    let scientificName: String?
    let description: String
    let category: String
    let difficultyLevel: String
    let maintenanceLevel: String
    let wateringFrequencyDays: Int
    let sunRequirement: String
    let soilType: String?
    let temperatureMin: Double?
    let temperatureMax: Double?
    let hardinessZones: String?
    let growthStages: [String]
    let harvestTimeWeeks: Int?
    let commonProblems: [String]
    let careTips: [String]
    let fertilizingFrequencyWeeks: Int?
    let pruningFrequencyWeeks: Int?
    let companionPlants: [String]?
}