import Foundation
import SwiftData

@Model
public final class JournalEntry {
    public var id = UUID()
    public var title: String = ""
    public var content: String = ""
    public var entryDate = Date()
    public var entryType = JournalEntryType.observation

    // Plant tracking
    public var growthStage: GrowthStage?
    public var healthStatus: HealthStatus?
    public var heightMeasurement: Double? // in inches or cm
    public var widthMeasurement: Double? // in inches or cm

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
    public var photoURLs: [String] = []
    public var videoURLs: [String] = []

    // Relationships
    public var plant: Plant?
    public var user: User?

    // Metadata
    public var isPrivate: Bool = false
    public var tags: [String] = []
    public var mood: PlantMood? // How the plant "looks" - anthropomorphic tracking
    public var lastModified = Date()

    public init(
        title: String = "",
        content: String = "",
        entryType: JournalEntryType = .observation,
        plant: Plant? = nil
    ) {
        id = UUID()
        self.title = title
        self.content = content
        entryDate = Date()
        self.entryType = entryType
        self.plant = plant
        photoURLs = []
        videoURLs = []
        isPrivate = false
        tags = []
        lastModified = Date()
    }

    /// Convenience methods
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
        case .observation: "General Observation"
        case .watering: "Watering Log"
        case .fertilizing: "Fertilizing Log"
        case .pruning: "Pruning Log"
        case .repotting: "Repotting Log"
        case .harvest: "Harvest Log"
        case .planting: "Planting Log"
        case .problemReport: "Problem Report"
        case .milestone: "Growth Milestone"
        case .experiment: "Experiment/Test"
        case .note: "Quick Note"
        }
    }

    public var iconName: String {
        switch self {
        case .observation: "eye.fill"
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .pruning: "scissors"
        case .repotting: "circle.grid.cross.fill"
        case .harvest: "basket.fill"
        case .planting: "sprout.circle"
        case .problemReport: "exclamationmark.triangle.fill"
        case .milestone: "flag.fill"
        case .experiment: "flask.fill"
        case .note: "note.text"
        }
    }

    public var color: String {
        switch self {
        case .observation: "blue"
        case .watering: "cyan"
        case .fertilizing: "green"
        case .pruning: "orange"
        case .repotting: "brown"
        case .harvest: "purple"
        case .planting: "mint"
        case .problemReport: "red"
        case .milestone: "yellow"
        case .experiment: "indigo"
        case .note: "gray"
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
        case .dry: "Dry"
        case .slightlyDry: "Slightly Dry"
        case .moist: "Moist"
        case .wet: "Wet"
        case .waterlogged: "Waterlogged"
        }
    }

    public var description: String {
        switch self {
        case .dry: "Soil feels dry to touch, may need watering"
        case .slightlyDry: "Soil surface dry but slightly moist below"
        case .moist: "Ideal moisture level, soil feels damp"
        case .wet: "Very wet, may need better drainage"
        case .waterlogged: "Standing water, poor drainage"
        }
    }

    public var color: String {
        switch self {
        case .dry: "red"
        case .slightlyDry: "orange"
        case .moist: "green"
        case .wet: "blue"
        case .waterlogged: "purple"
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
        case .sunny: "Sunny"
        case .partlyCloudy: "Partly Cloudy"
        case .cloudy: "Cloudy"
        case .overcast: "Overcast"
        case .lightRain: "Light Rain"
        case .heavyRain: "Heavy Rain"
        case .drizzle: "Drizzle"
        case .thunderstorm: "Thunderstorm"
        case .snow: "Snow"
        case .frost: "Frost"
        case .windy: "Windy"
        case .calm: "Calm"
        }
    }

    public var iconName: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy: "cloud.fill"
        case .overcast: "cloud.fill"
        case .lightRain: "cloud.rain.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .drizzle: "cloud.drizzle.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        case .snow: "cloud.snow.fill"
        case .frost: "thermometer.snowflake"
        case .windy: "wind"
        case .calm: "leaf.fill"
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
        case .thriving: "Thriving"
        case .happy: "Happy"
        case .content: "Content"
        case .stressed: "Stressed"
        case .struggling: "Struggling"
        case .droopy: "Droopy"
        case .perky: "Perky"
        case .vibrant: "Vibrant"
        }
    }

    public var emoji: String {
        switch self {
        case .thriving: "🌟"
        case .happy: "😊"
        case .content: "😌"
        case .stressed: "😰"
        case .struggling: "😢"
        case .droopy: "😴"
        case .perky: "😃"
        case .vibrant: "✨"
        }
    }

    public var color: String {
        switch self {
        case .thriving: "green"
        case .happy: "mint"
        case .content: "blue"
        case .stressed: "yellow"
        case .struggling: "orange"
        case .droopy: "gray"
        case .perky: "cyan"
        case .vibrant: "purple"
        }
    }
}
