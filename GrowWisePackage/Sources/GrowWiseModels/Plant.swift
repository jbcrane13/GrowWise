import Foundation
import SwiftData

@Model
public final class Plant {
    public var id: UUID
    public var name: String
    public var scientificName: String?
    public var plantType: PlantType
    public var difficultyLevel: DifficultyLevel
    public var isUserPlant: Bool // true for user's garden, false for database plants
    
    // Growing information
    public var plantingDate: Date?
    public var harvestDate: Date?
    public var sunlightRequirement: SunlightLevel
    public var wateringFrequency: WateringFrequency
    public var spaceRequirement: SpaceRequirement
    public var growthStage: GrowthStage
    
    // Care tracking
    public var lastWatered: Date?
    public var lastFertilized: Date?
    public var lastPruned: Date?
    public var healthStatus: HealthStatus
    
    // User notes and photos
    public var notes: String
    public var photoURLs: [String] // Local file paths or cloud URLs
    
    // Location in garden
    public var gardenLocation: String?
    public var containerType: ContainerType?
    
    // Relationships
    public var garden: Garden?
    public var reminders: [PlantReminder]
    public var journalEntries: [JournalEntry]
    public var companionPlants: [Plant]
    
    public init(
        name: String,
        plantType: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        isUserPlant: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.plantType = plantType
        self.difficultyLevel = difficultyLevel
        self.isUserPlant = isUserPlant
        self.sunlightRequirement = .fullSun
        self.wateringFrequency = .daily
        self.spaceRequirement = .small
        self.growthStage = .seedling
        self.healthStatus = .healthy
        self.notes = ""
        self.photoURLs = []
        self.reminders = []
        self.journalEntries = []
        self.companionPlants = []
    }
}

// MARK: - Supporting Enums

public enum PlantType: String, CaseIterable, Codable, Sendable {
    case vegetable
    case herb
    case flower
    case houseplant
    case fruit
    case succulent
    case tree
    case shrub
    
    public var displayName: String {
        switch self {
        case .vegetable: return "Vegetable"
        case .herb: return "Herb"
        case .flower: return "Flower"
        case .houseplant: return "Houseplant"
        case .fruit: return "Fruit"
        case .succulent: return "Succulent"
        case .tree: return "Tree"
        case .shrub: return "Shrub"
        }
    }
}

public enum DifficultyLevel: String, CaseIterable, Codable, Sendable {
    case beginner
    case intermediate
    case advanced
    
    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    public var description: String {
        switch self {
        case .beginner: return "Easy to grow, forgiving"
        case .intermediate: return "Some experience helpful"
        case .advanced: return "Requires expertise"
        }
    }
}

public enum SunlightLevel: String, CaseIterable, Codable, Sendable {
    case fullSun
    case partialSun
    case partialShade
    case fullShade
    
    public var displayName: String {
        switch self {
        case .fullSun: return "Full Sun (6+ hours)"
        case .partialSun: return "Partial Sun (4-6 hours)"
        case .partialShade: return "Partial Shade (2-4 hours)"
        case .fullShade: return "Full Shade (< 2 hours)"
        }
    }
}

public enum WateringFrequency: String, CaseIterable, Codable, Sendable {
    case daily
    case everyOtherDay
    case twiceWeekly
    case weekly
    case biweekly
    case monthly
    case asNeeded
    
    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .everyOtherDay: return "Every Other Day"
        case .twiceWeekly: return "Twice Weekly"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .asNeeded: return "As Needed"
        }
    }
    
    public var days: Int {
        switch self {
        case .daily: return 1
        case .everyOtherDay: return 2
        case .twiceWeekly: return 3
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .asNeeded: return 0 // Manual timing
        }
    }
}

public enum SpaceRequirement: String, CaseIterable, Codable, Sendable {
    case small    // < 1 sq ft
    case medium   // 1-4 sq ft
    case large    // 4-9 sq ft
    case extraLarge // > 9 sq ft
    
    public var displayName: String {
        switch self {
        case .small: return "Small (< 1 sq ft)"
        case .medium: return "Medium (1-4 sq ft)"
        case .large: return "Large (4-9 sq ft)"
        case .extraLarge: return "Extra Large (> 9 sq ft)"
        }
    }
}

public enum GrowthStage: String, CaseIterable, Codable, Sendable {
    case seed
    case seedling
    case vegetative
    case flowering
    case fruiting
    case mature
    case dormant
    
    public var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .seedling: return "Seedling"
        case .vegetative: return "Vegetative Growth"
        case .flowering: return "Flowering"
        case .fruiting: return "Fruiting"
        case .mature: return "Mature"
        case .dormant: return "Dormant"
        }
    }
}

public enum HealthStatus: String, CaseIterable, Codable, Sendable {
    case healthy
    case needsAttention
    case sick
    case dying
    case dead
    
    public var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .needsAttention: return "Needs Attention"
        case .sick: return "Sick"
        case .dying: return "Dying"
        case .dead: return "Dead"
        }
    }
    
    public var color: String {
        switch self {
        case .healthy: return "green"
        case .needsAttention: return "yellow"
        case .sick: return "orange"
        case .dying: return "red"
        case .dead: return "gray"
        }
    }
}

public enum ContainerType: String, CaseIterable, Codable, Sendable {
    case inGround
    case raisedBed
    case container
    case hangingBasket
    case windowBox
    case greenhouse
    case indoor
    
    public var displayName: String {
        switch self {
        case .inGround: return "In Ground"
        case .raisedBed: return "Raised Bed"
        case .container: return "Container/Pot"
        case .hangingBasket: return "Hanging Basket"
        case .windowBox: return "Window Box"
        case .greenhouse: return "Greenhouse"
        case .indoor: return "Indoor"
        }
    }
}