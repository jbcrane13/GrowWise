import Foundation
import SwiftData

/// Model for tracking soil conditions and amendments over time
@Model
public final class SoilLog {
    public var id: UUID = UUID()
    public var logDate: Date?
    
    // pH Level (typically 0-14, ideal for most plants 6.0-7.0)
    public var phLevel: Double?
    
    // N-P-K Values (Nitrogen-Phosphorus-Potassium)
    // Stored as ppm (parts per million) or mg/kg
    public var nitrogenLevel: Double?
    public var phosphorusLevel: Double?
    public var potassiumLevel: Double?
    
    // Secondary nutrients
    public var calciumLevel: Double?
    public var magnesiumLevel: Double?
    public var sulfurLevel: Double?
    
    // Micronutrients
    public var ironLevel: Double?
    public var manganeseLevel: Double?
    public var zincLevel: Double?
    public var copperLevel: Double?
    public var boronLevel: Double?
    public var molybdenumLevel: Double?
    
    // Organic matter percentage
    public var organicMatter: Double?
    
    // Fertilizer application
    public var fertilizerApplied: String?
    public var fertilizerAmount: String?
    public var fertilizerType: FertilizerType?
    
    // Notes
    public var notes: String?
    
    // Relationships
    public var garden: Garden?
    public var plant: Plant?
    
    // Metadata
    public var createdDate: Date?
    public var lastModified: Date?
    
    public init(
        logDate: Date = Date(),
        phLevel: Double? = nil,
        nitrogenLevel: Double? = nil,
        phosphorusLevel: Double? = nil,
        potassiumLevel: Double? = nil
    ) {
        self.id = UUID()
        self.logDate = logDate
        self.phLevel = phLevel
        self.nitrogenLevel = nitrogenLevel
        self.phosphorusLevel = phosphorusLevel
        self.potassiumLevel = potassiumLevel
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    /// Convenience computed property for N-P-K display
    public var npkDisplay: String? {
        guard let n = nitrogenLevel,
              let p = phosphorusLevel,
              let k = potassiumLevel else {
            return nil
        }
        return String(format: "%.0f-%.0f-%.0f", n, p, k)
    }
    
    /// Check if pH is in optimal range for most plants (6.0-7.0)
    public var isPHOptimal: Bool? {
        guard let ph = phLevel else { return nil }
        return ph >= 6.0 && ph <= 7.0
    }
    
    /// Get pH status description
    public var phStatus: String? {
        guard let ph = phLevel else { return nil }
        if ph < 5.5 {
            return "Very Acidic"
        } else if ph < 6.0 {
            return "Acidic"
        } else if ph <= 7.0 {
            return "Optimal"
        } else if ph <= 7.5 {
            return "Slightly Alkaline"
        } else {
            return "Alkaline"
        }
    }
}

// MARK: - Fertilizer Types

public enum FertilizerType: String, CaseIterable, Codable, Sendable {
    case organic
    case synthetic
    case slowRelease
    case liquid
    case granular
    case foliar
    case compost
    case manure
    case boneMeal
    case bloodMeal
    case fishEmulsion
    case seaweed
    case custom
    
    public var displayName: String {
        switch self {
        case .organic: return "Organic"
        case .synthetic: return "Synthetic"
        case .slowRelease: return "Slow Release"
        case .liquid: return "Liquid"
        case .granular: return "Granular"
        case .foliar: return "Foliar Spray"
        case .compost: return "Compost"
        case .manure: return "Manure"
        case .boneMeal: return "Bone Meal"
        case .bloodMeal: return "Blood Meal"
        case .fishEmulsion: return "Fish Emulsion"
        case .seaweed: return "Seaweed Extract"
        case .custom: return "Custom Blend"
        }
    }
    
    public var iconName: String {
        switch self {
        case .organic, .compost, .manure:
            return "leaf.fill"
        case .liquid, .foliar, .fishEmulsion, .seaweed:
            return "drop.fill"
        case .granular, .slowRelease:
            return "circle.grid.2x2"
        case .boneMeal, .bloodMeal:
            return "bolt.fill"
        default:
            return "flask.fill"
        }
    }
}

// MARK: - Soil Test Recommendations

public struct SoilRecommendation: Sendable, Identifiable {
    public let id = UUID()
    public let nutrient: String
    public let currentLevel: Double
    public let optimalRange: ClosedRange<Double>
    public let unit: String
    public let recommendation: String
    
    public var isWithinRange: Bool {
        optimalRange.contains(currentLevel)
    }
    
    public var status: SoilNutrientStatus {
        if currentLevel < optimalRange.lowerBound {
            return .low
        } else if currentLevel > optimalRange.upperBound {
            return .high
        } else {
            return .optimal
        }
    }
}

public enum SoilNutrientStatus: String, Sendable {
    case low
    case optimal
    case high
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .optimal: return "Optimal"
        case .high: return "High"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "orange"
        case .optimal: return "green"
        case .high: return "yellow"
        }
    }
}

// MARK: - Soil Test Kit Reference Ranges

public enum SoilTestRanges {
    // pH ranges
    public static let optimalPH = 6.0...7.0
    
    // N-P-K ranges in ppm (parts per million)
    // These are general guidelines and vary by plant type
    public static let nitrogenLow = 0.0...20.0
    public static let nitrogenMedium = 20.0...40.0
    public static let nitrogenHigh = 40.0...100.0
    
    public static let phosphorusLow = 0.0...10.0
    public static let phosphorusMedium = 10.0...25.0
    public static let phosphorusHigh = 25.0...100.0
    
    public static let potassiumLow = 0.0...100.0
    public static let potassiumMedium = 100.0...200.0
    public static let potassiumHigh = 200.0...500.0
    
    /// Get nitrogen status
    public static func nitrogenStatus(_ value: Double) -> SoilNutrientStatus {
        if value < 20 { return .low }
        if value > 40 { return .high }
        return .optimal
    }
    
    /// Get phosphorus status
    public static func phosphorusStatus(_ value: Double) -> SoilNutrientStatus {
        if value < 10 { return .low }
        if value > 25 { return .high }
        return .optimal
    }
    
    /// Get potassium status
    public static func potassiumStatus(_ value: Double) -> SoilNutrientStatus {
        if value < 100 { return .low }
        if value > 200 { return .high }
        return .optimal
    }
}
