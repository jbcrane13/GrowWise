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
        case .goalFit: "Goal Fit"
        case .seasonFit: "Season Fit"
        case .climateFit: "Climate Match"
        case .companionStrategy: "Companion"
        case .maintenanceBurden: "Low Maintenance"
        case .petSafety: "Pet Safe"
        case .humanSafety: "Safe to Eat"
        case .spaceConstraint: "Space Fit"
        }
    }

    public var icon: String {
        switch self {
        case .goalFit: "target"
        case .seasonFit: "calendar"
        case .climateFit: "thermometer.medium"
        case .companionStrategy: "leaf.fill"
        case .maintenanceBurden: "clock"
        case .petSafety: "pawprint.fill"
        case .humanSafety: "fork.knife"
        case .spaceConstraint: "square.resize"
        }
    }
}
