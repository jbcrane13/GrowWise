import Foundation
import SwiftData

@Model
public final class Garden {
    public var id: UUID?
    public var name: String?
    public var gardenType: GardenType?
    public var isIndoor: Bool?

    // Location and environment
    public var hardinessZone: String?
    public var latitude: Double?
    public var longitude: Double?
    public var sunExposure: SunExposure?
    public var soilType: SoilType?
    public var spaceAvailable: SpaceSize?

    // Garden planning
    public var plantingStartDate: Date?
    public var plantingEndDate: Date?
    public var layout: String?

    /// Relationships
    @Relationship(deleteRule: .cascade, inverse: \Plant.garden)
    public var plants: [Plant]? = []

    @Relationship(deleteRule: .cascade, inverse: \SoilLog.garden)
    public var soilLogs: [SoilLog]? = []
    public var user: User?

    // Metadata
    public var createdDate: Date?
    public var lastModified: Date?

    public init(
        name: String,
        gardenType: GardenType = GardenType.outdoor,
        isIndoor: Bool = false
    ) {
        id = UUID()
        self.name = name
        self.gardenType = gardenType
        self.isIndoor = isIndoor
        sunExposure = SunExposure.fullSun
        soilType = SoilType.loam
        spaceAvailable = SpaceSize.small
        plants = []
        createdDate = Date()
        lastModified = Date()
    }
}

// MARK: - Supporting Enums

public enum GardenType: String, CaseIterable, Codable, Sendable {
    case outdoor
    case indoor
    case container
    case raised
    case hydroponic
    case greenhouse
    case balcony
    case windowsill

    public var displayName: String {
        switch self {
        case .outdoor: "Outdoor Garden"
        case .indoor: "Indoor Garden"
        case .container: "Container Garden"
        case .raised: "Raised Bed Garden"
        case .hydroponic: "Hydroponic System"
        case .greenhouse: "Greenhouse"
        case .balcony: "Balcony Garden"
        case .windowsill: "Windowsill Garden"
        }
    }
}

public enum SunExposure: String, CaseIterable, Codable, Sendable {
    case fullSun // 6+ hours direct sunlight
    case partialSun // 4-6 hours direct sunlight
    case partialShade // 2-4 hours direct sunlight
    case fullShade // < 2 hours direct sunlight
    case artificial // Grow lights

    public var displayName: String {
        switch self {
        case .fullSun: "Full Sun (6+ hours)"
        case .partialSun: "Partial Sun (4-6 hours)"
        case .partialShade: "Partial Shade (2-4 hours)"
        case .fullShade: "Full Shade (< 2 hours)"
        case .artificial: "Artificial Light"
        }
    }

    public var hoursOfSunlight: Int {
        switch self {
        case .fullSun: 8
        case .partialSun: 5
        case .partialShade: 3
        case .fullShade: 1
        case .artificial: 12 // Can provide consistent light
        }
    }
}

public enum SoilType: String, CaseIterable, Codable, Sendable {
    case clay
    case loam
    case sand
    case silt
    case chalk
    case peat
    case potting
    case compost
    case hydroponic

    public var displayName: String {
        switch self {
        case .clay: "Clay Soil"
        case .loam: "Loam Soil"
        case .sand: "Sandy Soil"
        case .silt: "Silty Soil"
        case .chalk: "Chalky Soil"
        case .peat: "Peaty Soil"
        case .potting: "Potting Mix"
        case .compost: "Compost"
        case .hydroponic: "Hydroponic Medium"
        }
    }

    public var drainageLevel: DrainageLevel {
        switch self {
        case .clay: .poor
        case .loam: .good
        case .sand: .excellent
        case .silt: .fair
        case .chalk: .good
        case .peat: .poor
        case .potting: .good
        case .compost: .good
        case .hydroponic: .excellent
        }
    }
}

public enum DrainageLevel: String, CaseIterable, Codable, Sendable {
    case poor
    case fair
    case good
    case excellent

    public var displayName: String {
        switch self {
        case .poor: "Poor Drainage"
        case .fair: "Fair Drainage"
        case .good: "Good Drainage"
        case .excellent: "Excellent Drainage"
        }
    }
}

public enum SpaceSize: String, CaseIterable, Codable, Sendable {
    case tiny // < 10 sq ft (windowsill, small containers)
    case small // 10-50 sq ft (balcony, small raised bed)
    case medium // 50-200 sq ft (large patio, medium garden)
    case large // 200-500 sq ft (backyard garden)
    case extraLarge // > 500 sq ft (large property)

    public var displayName: String {
        switch self {
        case .tiny: "Tiny (< 10 sq ft)"
        case .small: "Small (10-50 sq ft)"
        case .medium: "Medium (50-200 sq ft)"
        case .large: "Large (200-500 sq ft)"
        case .extraLarge: "Extra Large (> 500 sq ft)"
        }
    }

    public var squareFeet: Int {
        switch self {
        case .tiny: 5
        case .small: 30
        case .medium: 125
        case .large: 350
        case .extraLarge: 750
        }
    }

    public var recommendedPlantCount: Int {
        switch self {
        case .tiny: 3
        case .small: 8
        case .medium: 20
        case .large: 40
        case .extraLarge: 80
        }
    }
}
