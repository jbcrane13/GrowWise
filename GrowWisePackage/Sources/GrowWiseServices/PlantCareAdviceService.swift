import Foundation
import GrowWiseModels
import os

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length multiline_literal_brackets trailing_comma

private let logger = Logger(subsystem: "com.growwise", category: "PlantCareAdviceService")

// MARK: - CareTip

public struct CareTip: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let urgency: CareTipUrgency
    public let icon: String

    public init(title: String, description: String, urgency: CareTipUrgency, icon: String) {
        id = UUID()
        self.title = title
        self.description = description
        self.urgency = urgency
        self.icon = icon
    }
}

public enum CareTipUrgency: Int, Sendable, Comparable {
    case info = 0
    case suggestion = 1
    case warning = 2
    case urgent = 3

    public static func < (lhs: CareTipUrgency, rhs: CareTipUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - PlantCareAdviceService

@MainActor
@Observable
public final class PlantCareAdviceService {
    public init() {}

    /// Returns 2-4 contextual care tips for a plant in its garden context.
    public func getContextualTips(
        for plant: Plant,
        in garden: Garden?,
        user: User?
    ) -> [CareTip] {
        var tips: [CareTip] = []

        tips.append(contentsOf: seasonalTips(for: plant, zone: garden?.hardinessZone ?? user?.hardinessZone))
        tips.append(contentsOf: sunMismatchTips(for: plant, in: garden))
        tips.append(contentsOf: growthStageTips(for: plant))
        tips.append(contentsOf: overdueCareNudges(for: plant))
        tips.append(contentsOf: skillAdaptedTips(for: plant, skillLevel: user?.skillLevel ?? .beginner))

        // Sort by urgency (highest first), then limit to 4
        tips.sort { $0.urgency > $1.urgency }
        return Array(tips.prefix(4))
    }

    // MARK: - Seasonal Tips

    private func seasonalTips(for plant: Plant, zone: String?) -> [CareTip] {
        let month = Calendar.current.component(.month, from: Date())
        var tips: [CareTip] = []

        switch month {
        case 3 ... 5: // Spring
            if plant.plantType == .vegetable || plant.plantType == .herb {
                tips.append(CareTip(
                    title: "Spring Feeding Time",
                    description: "Start fertilizing now to fuel strong spring growth. Use a balanced fertilizer every 2-3 weeks.",
                    urgency: .suggestion,
                    icon: "leaf.arrow.circlepath"
                ))
            }
            if plant.growthStage == .dormant {
                tips.append(CareTip(
                    title: "Emerging from Dormancy",
                    description: "Your plant is waking up. Gradually increase watering and watch for new growth.",
                    urgency: .info,
                    icon: "sunrise.fill"
                ))
            }

        case 6 ... 8: // Summer
            tips.append(CareTip(
                title: "Heat Protection",
                description: "Water early morning or evening to reduce evaporation. Watch for wilting during peak heat.",
                urgency: .warning,
                icon: "thermometer.sun.fill"
            ))
            if plant.plantType == .fruit || plant.plantType == .vegetable {
                tips.append(CareTip(
                    title: "Check for Harvest",
                    description: "Summer is peak harvest season. Check regularly for ripe produce to encourage continued growth.",
                    urgency: .suggestion,
                    icon: "basket.fill"
                ))
            }

        case 9 ... 11: // Fall
            if let zoneStr = zone, let zoneNum = Int(zoneStr.prefix(while: \.isNumber)), zoneNum <= 6 {
                tips.append(CareTip(
                    title: "Frost Prep Needed",
                    description: "Your zone may see frost soon. Prepare covers or bring sensitive plants indoors.",
                    urgency: .warning,
                    icon: "snowflake"
                ))
            }
            tips.append(CareTip(
                title: "Reduce Fertilizing",
                description: "Slow down feeding as growth slows. Most plants don\u{2019}t need fertilizer in late fall.",
                urgency: .info,
                icon: "leaf.fill"
            ))

        default: // Winter
            tips.append(CareTip(
                title: "Reduce Watering",
                description: "Most plants need less water in winter. Let soil dry out more between waterings.",
                urgency: .suggestion,
                icon: "drop.degreesign.slash"
            ))
        }

        return tips
    }

    // MARK: - Sun Mismatch

    private func sunMismatchTips(for plant: Plant, in garden: Garden?) -> [CareTip] {
        guard let plantSun = plant.sunlightRequirement,
              let gardenSun = garden?.sunExposure
        else { return [] }

        let isMismatch: Bool
        let detail: String

        switch (plantSun, gardenSun) {
        case (.fullSun, .fullShade), (.fullSun, .partialShade):
            isMismatch = true
            detail = "This plant needs full sun but your garden has \(gardenSun.displayName.lowercased()). Consider moving it to a sunnier spot."

        case (.fullShade, .fullSun), (.partialShade, .fullSun):
            isMismatch = true
            detail = "This plant prefers shade but your garden gets full sun. Add shade cloth or relocate."

        default:
            isMismatch = false
            detail = ""
        }

        if isMismatch {
            return [CareTip(
                title: "Sun Exposure Mismatch",
                description: detail,
                urgency: .warning,
                icon: "exclamationmark.triangle.fill"
            )]
        }
        return []
    }

    // MARK: - Growth Stage Tips

    private func growthStageTips(for plant: Plant) -> [CareTip] {
        guard let stage = plant.growthStage else { return [] }

        switch stage {
        case .seed:
            return [CareTip(
                title: "Germination Care",
                description: "Keep soil consistently moist but not waterlogged. Maintain warm temperature for best germination.",
                urgency: .suggestion,
                icon: "sparkle"
            )]

        case .seedling:
            return [CareTip(
                title: "Seedling Care",
                description: "Handle gently and ensure steady light. Begin hardening off if transplanting outdoors soon.",
                urgency: .suggestion,
                icon: "arrow.up.forward"
            )]

        case .flowering:
            return [CareTip(
                title: "Flowering Support",
                description: "Switch to a phosphorus-rich fertilizer to support blooms. Avoid moving the plant.",
                urgency: .info,
                icon: "camera.macro"
            )]

        case .fruiting:
            return [CareTip(
                title: "Fruiting Support",
                description: "Increase watering slightly and ensure adequate nutrients. Support heavy branches if needed.",
                urgency: .suggestion,
                icon: "leaf.circle"
            )]

        case .vegetative, .mature, .dormant:
            return []
        }
    }

    // MARK: - Overdue Care Nudges

    private func overdueCareNudges(for plant: Plant) -> [CareTip] {
        var tips: [CareTip] = []
        let now = Date()
        let calendar = Calendar.current

        if let lastWatered = plant.lastWatered,
           let wateringDays = plant.wateringFrequency?.days,
           wateringDays > 0
        {
            let daysSince = calendar.dateComponents([.day], from: lastWatered, to: now).day ?? 0
            if daysSince > wateringDays + 1 {
                tips.append(CareTip(
                    title: "Watering Overdue",
                    description: "Last watered \(daysSince) days ago. Your plant needs water every \(wateringDays) days.",
                    urgency: .urgent,
                    icon: "drop.fill"
                ))
            }
        }

        if let lastFertilized = plant.lastFertilized {
            let daysSince = calendar.dateComponents([.day], from: lastFertilized, to: now).day ?? 0
            if daysSince > 30 {
                tips.append(CareTip(
                    title: "Time to Fertilize",
                    description: "It\u{2019}s been \(daysSince) days since the last feeding. Consider a balanced fertilizer.",
                    urgency: .suggestion,
                    icon: "leaf.arrow.circlepath"
                ))
            }
        }

        return tips
    }

    // MARK: - Skill-Adapted Tips

    private func skillAdaptedTips(for plant: Plant, skillLevel: GardeningSkillLevel) -> [CareTip] {
        guard skillLevel == .beginner else { return [] }

        if plant.plantType == .succulent {
            return [CareTip(
                title: "Beginner Tip",
                description: "Succulents thrive on neglect. The #1 mistake is overwatering. Let soil dry completely between waterings.",
                urgency: .info,
                icon: "lightbulb.fill"
            )]
        }

        if plant.plantType == .herb {
            return [CareTip(
                title: "Beginner Tip",
                description: "Harvest herbs regularly by pinching stems above a leaf pair. This encourages bushier growth.",
                urgency: .info,
                icon: "lightbulb.fill"
            )]
        }

        return []
    }
}

// swiftlint:enable line_length multiline_literal_brackets trailing_comma
