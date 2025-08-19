import Foundation
import SwiftData

@Model
public final class JournalEntry {
    public var id: UUID
    public var title: String
    public var content: String
    public var entryDate: Date
    public var entryType: JournalEntryType
    
    // Plant tracking
    public var growthStage: GrowthStage?
    public var healthStatus: HealthStatus?
    public var heightMeasurement: Double? // in inches or cm
    public var widthMeasurement: Double?  // in inches or cm
    
    // Environmental conditions
    public var temperature: Double?
    public var humidity: Double?
    public var soilMoisture: SoilMoisture?
    public var weatherConditions: WeatherCondition?
    
    // Care activities
    public var wateringAmount: Double? // in fluid ounces or ml
    public var fertilizer: String?
    public var fertilizerAmount: String?
    public var pruningNotes: String?
    public var pestObservations: String?
    
    // Media
    public var photoURLs: [String]
    public var videoURLs: [String]
    
    // Relationships
    public var plant: Plant?
    public var user: User?
    
    // Metadata
    public var isPrivate: Bool
    public var tags: [String]
    public var mood: PlantMood? // How the plant "looks" - anthropomorphic tracking
    public var lastModified: Date
    
    public init(
        title: String = "",
        content: String = "",
        entryType: JournalEntryType = .observation,
        plant: Plant? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.entryDate = Date()
        self.entryType = entryType
        self.plant = plant
        self.photoURLs = []
        self.videoURLs = []
        self.isPrivate = false
        self.tags = []
        self.lastModified = Date()
    }
    
    // Convenience methods
    public func addPhoto(url: String) {
        photoURLs.append(url)
        lastModified = Date()
    }
    
    public func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            lastModified = Date()
        }
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        lastModified = Date()
    }
}

// MARK: - Supporting Enums

public enum JournalEntryType: String, CaseIterable, Codable, Sendable {
    case observation
    case watering
    case fertilizing
    case pruning
    case repotting
    case harvest
    case planting
    case problemReport
    case milestone
    case experiment
    case note
    
    public var displayName: String {
        switch self {
        case .observation: return "General Observation"
        case .watering: return "Watering Log"
        case .fertilizing: return "Fertilizing Log"
        case .pruning: return "Pruning Log"
        case .repotting: return "Repotting Log"
        case .harvest: return "Harvest Log"
        case .planting: return "Planting Log"
        case .problemReport: return "Problem Report"
        case .milestone: return "Growth Milestone"
        case .experiment: return "Experiment/Test"
        case .note: return "Quick Note"
        }
    }
    
    public var iconName: String {
        switch self {
        case .observation: return "eye.fill"
        case .watering: return "drop.fill"
        case .fertilizing: return "leaf.fill"
        case .pruning: return "scissors"
        case .repotting: return "circle.grid.cross.fill"
        case .harvest: return "basket.fill"
        case .planting: return "seedling"
        case .problemReport: return "exclamationmark.triangle.fill"
        case .milestone: return "flag.fill"
        case .experiment: return "flask.fill"
        case .note: return "note.text"
        }
    }
    
    public var color: String {
        switch self {
        case .observation: return "blue"
        case .watering: return "cyan"
        case .fertilizing: return "green"
        case .pruning: return "orange"
        case .repotting: return "brown"
        case .harvest: return "purple"
        case .planting: return "mint"
        case .problemReport: return "red"
        case .milestone: return "yellow"
        case .experiment: return "indigo"
        case .note: return "gray"
        }
    }
}

public enum SoilMoisture: String, CaseIterable, Codable, Sendable {
    case dry
    case slightlyDry
    case moist
    case wet
    case waterlogged
    
    public var displayName: String {
        switch self {
        case .dry: return "Dry"
        case .slightlyDry: return "Slightly Dry"
        case .moist: return "Moist"
        case .wet: return "Wet"
        case .waterlogged: return "Waterlogged"
        }
    }
    
    public var description: String {
        switch self {
        case .dry: return "Soil feels dry to touch, may need watering"
        case .slightlyDry: return "Soil surface dry but slightly moist below"
        case .moist: return "Ideal moisture level, soil feels damp"
        case .wet: return "Very wet, may need better drainage"
        case .waterlogged: return "Standing water, poor drainage"
        }
    }
    
    public var color: String {
        switch self {
        case .dry: return "red"
        case .slightlyDry: return "orange"
        case .moist: return "green"
        case .wet: return "blue"
        case .waterlogged: return "purple"
        }
    }
}

public enum WeatherCondition: String, CaseIterable, Codable, Sendable {
    case sunny
    case partlyCloudy
    case cloudy
    case overcast
    case lightRain
    case heavyRain
    case drizzle
    case thunderstorm
    case snow
    case frost
    case windy
    case calm
    
    public var displayName: String {
        switch self {
        case .sunny: return "Sunny"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .overcast: return "Overcast"
        case .lightRain: return "Light Rain"
        case .heavyRain: return "Heavy Rain"
        case .drizzle: return "Drizzle"
        case .thunderstorm: return "Thunderstorm"
        case .snow: return "Snow"
        case .frost: return "Frost"
        case .windy: return "Windy"
        case .calm: return "Calm"
        }
    }
    
    public var iconName: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .overcast: return "cloud.fill"
        case .lightRain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .frost: return "thermometer.snowflake"
        case .windy: return "wind"
        case .calm: return "leaf.fill"
        }
    }
}

public enum PlantMood: String, CaseIterable, Codable, Sendable {
    case thriving
    case happy
    case content
    case stressed
    case struggling
    case droopy
    case perky
    case vibrant
    
    public var displayName: String {
        switch self {
        case .thriving: return "Thriving"
        case .happy: return "Happy"
        case .content: return "Content"
        case .stressed: return "Stressed"
        case .struggling: return "Struggling"
        case .droopy: return "Droopy"
        case .perky: return "Perky"
        case .vibrant: return "Vibrant"
        }
    }
    
    public var emoji: String {
        switch self {
        case .thriving: return "🌟"
        case .happy: return "😊"
        case .content: return "😌"
        case .stressed: return "😰"
        case .struggling: return "😢"
        case .droopy: return "😴"
        case .perky: return "😃"
        case .vibrant: return "✨"
        }
    }
    
    public var color: String {
        switch self {
        case .thriving: return "green"
        case .happy: return "mint"
        case .content: return "blue"
        case .stressed: return "yellow"
        case .struggling: return "orange"
        case .droopy: return "gray"
        case .perky: return "cyan"
        case .vibrant: return "purple"
        }
    }
}