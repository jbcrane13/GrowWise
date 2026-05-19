import Foundation

// MARK: - RecommendationReason

/// Reasons displayed as chips on plant recommendations.
/// Each reason has a display text and SF Symbol icon for visual clarity.
public enum RecommendationReason: String, CaseIterable, Codable, Sendable {
    case goalFit
    case seasonFit
    case climateFit
    case companionStrategy
    case maintenanceBurden
    case petSafety
    case humanSafety
    case spaceConstraint

    public var displayText: String {
        switch self {
        case .goalFit: return "Goal Fit"
        case .seasonFit: return "Season Fit"
        case .climateFit: return "Climate Match"
        case .companionStrategy: return "Companion"
        case .maintenanceBurden: return "Low Maintenance"
        case .petSafety: return "Pet Safe"
        case .humanSafety: return "Safe to Eat"
        case .spaceConstraint: return "Space Fit"
        }
    }

    public var icon: String {
        switch self {
        case .goalFit: return "target"
        case .seasonFit: return "calendar"
        case .climateFit: return "thermometer.medium"
        case .companionStrategy: return "leaf.fill"
        case .maintenanceBurden: return "clock"
        case .petSafety: return "pawprint.fill"
        case .humanSafety: return "fork.knife"
        case .spaceConstraint: return "square.resize"
        }
    }
}