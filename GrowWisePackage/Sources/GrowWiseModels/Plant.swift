import Foundation
import SwiftData

@Model
public final class Plant {
    public var id: UUID? = UUID() // CloudKit: made optional or with default value
    public var name: String? // CloudKit: made optional or with default value
    public var scientificName: String? // CloudKit: made optional or with default value
    public var plantType: PlantType? = PlantType.vegetable // CloudKit: made optional or with default value
    public var difficultyLevel: DifficultyLevel? = DifficultyLevel.beginner // CloudKit: made optional or with default value
    public var isUserPlant: Bool? = true // CloudKit: made optional or with default value

    // Growing information
    public var plantingDate: Date? // CloudKit: made optional or with default value
    public var harvestDate: Date? // CloudKit: made optional or with default value
    public var sunlightRequirement: SunlightLevel? = SunlightLevel.fullSun // CloudKit: made optional or with default value
    public var wateringFrequency: WateringFrequency? = WateringFrequency.daily // CloudKit: made optional or with default value
    public var spaceRequirement: SpaceRequirement? = SpaceRequirement.small // CloudKit: made optional or with default value
    public var growthStage: GrowthStage? = GrowthStage.seedling // CloudKit: made optional or with default value

    // Care tracking
    public var lastWatered: Date? // CloudKit: made optional or with default value
    public var lastFertilized: Date? // CloudKit: made optional or with default value
    public var lastPruned: Date? // CloudKit: made optional or with default value
    public var healthStatus: HealthStatus? = HealthStatus.healthy // CloudKit: made optional or with default value

    /// Frost sensitivity — used for weather alert filtering. nil = unknown.
    public var frostSensitivity: FrostSensitivity? // CloudKit: made optional or with default value

    // User notes and photos
    public var notes: String? = "" // CloudKit: made optional or with default value
    public var photoURLs: [String]? = [] // CloudKit: made optional or with default value

    // Location in garden
    public var bed: GardenBed? // nil = Unassigned
    public var containerType: ContainerType? // CloudKit: made optional or with default value

    /// Relationships
    public var garden: Garden? // CloudKit: made optional or with default value
    @Relationship(deleteRule: .cascade, inverse: \PlantReminder.plant)
    public var reminders: [PlantReminder]?
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.plant)
    public var journalEntries: [JournalEntry]?
    public var companionPlants: [String]?
    @Relationship(deleteRule: .cascade, inverse: \SoilLog.plant)
    public var soilLogs: [SoilLog]?
    @Relationship(deleteRule: .cascade, inverse: \Harvest.plant)
    public var harvests: [Harvest]?

    public init(
        name: String,
        plantType: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        isUserPlant: Bool = true
    ) {
        id = UUID()
        self.name = name
        self.plantType = plantType
        self.difficultyLevel = difficultyLevel
        self.isUserPlant = isUserPlant
        sunlightRequirement = .fullSun
        wateringFrequency = .daily
        spaceRequirement = .small
        growthStage = .seedling
        healthStatus = .healthy
        frostSensitivity = nil
        notes = ""
        photoURLs = []
        reminders = []
        journalEntries = []
        companionPlants = []
        soilLogs = []
        harvests = []
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
        case .vegetable: "Vegetable"
        case .herb: "Herb"
        case .flower: "Flower"
        case .houseplant: "Houseplant"
        case .fruit: "Fruit"
        case .succulent: "Succulent"
        case .tree: "Tree"
        case .shrub: "Shrub"
        }
    }
}

public enum DifficultyLevel: String, CaseIterable, Codable, Sendable {
    case beginner
    case intermediate
    case advanced

    public var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    public var description: String {
        switch self {
        case .beginner: "Easy to grow, forgiving"
        case .intermediate: "Some experience helpful"
        case .advanced: "Requires expertise"
        }
    }

    public var colorName: String {
        switch self {
        case .beginner: "green"
        case .intermediate: "orange"
        case .advanced: "red"
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
        case .fullSun: "Full Sun (6+ hours)"
        case .partialSun: "Partial Sun (4-6 hours)"
        case .partialShade: "Partial Shade (2-4 hours)"
        case .fullShade: "Full Shade (< 2 hours)"
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
        case .daily: "Daily"
        case .everyOtherDay: "Every Other Day"
        case .twiceWeekly: "Twice Weekly"
        case .weekly: "Weekly"
        case .biweekly: "Bi-weekly"
        case .monthly: "Monthly"
        case .asNeeded: "As Needed"
        }
    }

    public var days: Int {
        switch self {
        case .daily: 1
        case .everyOtherDay: 2
        case .twiceWeekly: 3
        case .weekly: 7
        case .biweekly: 14
        case .monthly: 30
        case .asNeeded: 0 // Manual timing
        }
    }
}

public enum SpaceRequirement: String, CaseIterable, Codable, Sendable {
    case small // < 1 sq ft
    case medium // 1-4 sq ft
    case large // 4-9 sq ft
    case extraLarge // > 9 sq ft

    public var displayName: String {
        switch self {
        case .small: "Small (< 1 sq ft)"
        case .medium: "Medium (1-4 sq ft)"
        case .large: "Large (4-9 sq ft)"
        case .extraLarge: "Extra Large (> 9 sq ft)"
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
        case .seed: "Seed"
        case .seedling: "Seedling"
        case .vegetative: "Vegetative Growth"
        case .flowering: "Flowering"
        case .fruiting: "Fruiting"
        case .mature: "Mature"
        case .dormant: "Dormant"
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
        case .healthy: "Healthy"
        case .needsAttention: "Needs Attention"
        case .sick: "Sick"
        case .dying: "Dying"
        case .dead: "Dead"
        }
    }

    public var color: String {
        switch self {
        case .healthy: "green"
        case .needsAttention: "yellow"
        case .sick: "orange"
        case .dying: "red"
        case .dead: "gray"
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
        case .inGround: "In Ground"
        case .raisedBed: "Raised Bed"
        case .container: "Container/Pot"
        case .hangingBasket: "Hanging Basket"
        case .windowBox: "Window Box"
        case .greenhouse: "Greenhouse"
        case .indoor: "Indoor"
        }
    }
}

public enum FrostSensitivity: String, CaseIterable, Codable, Sendable {
    case hardy            // Survives heavy frost (below 25°F / -4°C)
    case semiHardy        // Survives light frost (25–32°F / -4 to 0°C)
    case tender           // Damaged by frost above 32°F / 0°C

    public var displayName: String {
        switch self {
        case .hardy: "Hardy"
        case .semiHardy: "Semi-hardy"
        case .tender: "Tender"
        }
    }

    /// Temperature threshold in °F below which damage occurs. nil = no threshold.
    public var damageThresholdFahrenheit: Double? {
        switch self {
        case .hardy: 25.0
        case .semiHardy: 32.0
        case .tender: 50.0
        }
    }
}
