import Foundation
import SwiftData

@Model
public final class Garden {
    public var id: UUID
    public var name: String
    public var gardenType: GardenType
    public var isIndoor: Bool
    
    // Location and environment
    public var hardinessZone: String?
    public var latitude: Double?
    public var longitude: Double?
    public var sunExposure: SunExposure
    public var soilType: SoilType
    public var spaceAvailable: SpaceSize
    
    // Garden planning
    public var plantingStartDate: Date?
    public var plantingEndDate: Date?
    public var layout: String? // JSON string for garden layout
    
    // Relationships
    public var plants: [Plant]
    public var user: User?
    
    // Metadata
    public var createdDate: Date
    public var lastModified: Date
    
    public init(
        name: String,
        gardenType: GardenType = .outdoor,
        isIndoor: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.gardenType = gardenType
        self.isIndoor = isIndoor
        self.sunExposure = .fullSun
        self.soilType = .loam
        self.spaceAvailable = .small
        self.plants = []
        self.createdDate = Date()
        self.lastModified = Date()
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
        case .outdoor: return "Outdoor Garden"
        case .indoor: return "Indoor Garden"
        case .container: return "Container Garden"
        case .raised: return "Raised Bed Garden"
        case .hydroponic: return "Hydroponic System"
        case .greenhouse: return "Greenhouse"
        case .balcony: return "Balcony Garden"
        case .windowsill: return "Windowsill Garden"
        }
    }
}

public enum SunExposure: String, CaseIterable, Codable, Sendable {
    case fullSun      // 6+ hours direct sunlight
    case partialSun   // 4-6 hours direct sunlight
    case partialShade // 2-4 hours direct sunlight
    case fullShade    // < 2 hours direct sunlight
    case artificial   // Grow lights
    
    public var displayName: String {
        switch self {
        case .fullSun: return "Full Sun (6+ hours)"
        case .partialSun: return "Partial Sun (4-6 hours)"
        case .partialShade: return "Partial Shade (2-4 hours)"
        case .fullShade: return "Full Shade (< 2 hours)"
        case .artificial: return "Artificial Light"
        }
    }
    
    public var hoursOfSunlight: Int {
        switch self {
        case .fullSun: return 8
        case .partialSun: return 5
        case .partialShade: return 3
        case .fullShade: return 1
        case .artificial: return 12 // Can provide consistent light
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
        case .clay: return "Clay Soil"
        case .loam: return "Loam Soil"
        case .sand: return "Sandy Soil"
        case .silt: return "Silty Soil"
        case .chalk: return "Chalky Soil"
        case .peat: return "Peaty Soil"
        case .potting: return "Potting Mix"
        case .compost: return "Compost"
        case .hydroponic: return "Hydroponic Medium"
        }
    }
    
    public var drainageLevel: DrainageLevel {
        switch self {
        case .clay: return .poor
        case .loam: return .good
        case .sand: return .excellent
        case .silt: return .fair
        case .chalk: return .good
        case .peat: return .poor
        case .potting: return .good
        case .compost: return .good
        case .hydroponic: return .excellent
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
        case .poor: return "Poor Drainage"
        case .fair: return "Fair Drainage"
        case .good: return "Good Drainage"
        case .excellent: return "Excellent Drainage"
        }
    }
}

public enum SpaceSize: String, CaseIterable, Codable, Sendable {
    case tiny     // < 10 sq ft (windowsill, small containers)
    case small    // 10-50 sq ft (balcony, small raised bed)
    case medium   // 50-200 sq ft (large patio, medium garden)
    case large    // 200-500 sq ft (backyard garden)
    case extraLarge // > 500 sq ft (large property)
    
    public var displayName: String {
        switch self {
        case .tiny: return "Tiny (< 10 sq ft)"
        case .small: return "Small (10-50 sq ft)"
        case .medium: return "Medium (50-200 sq ft)"
        case .large: return "Large (200-500 sq ft)"
        case .extraLarge: return "Extra Large (> 500 sq ft)"
        }
    }
    
    public var squareFeet: Int {
        switch self {
        case .tiny: return 5
        case .small: return 30
        case .medium: return 125
        case .large: return 350
        case .extraLarge: return 750
        }
    }
    
    public var recommendedPlantCount: Int {
        switch self {
        case .tiny: return 3
        case .small: return 8
        case .medium: return 20
        case .large: return 40
        case .extraLarge: return 80
        }
    }
}