import Foundation
import GrowWiseModels

// MARK: - SeasonalActivity

public enum SeasonalActivity: String, Sendable, CaseIterable {
    case startIndoors
    case transplant
    case activeGrowing
    case harvest
    case winterPrep
    case pruning
    case fertilize

    public var displayName: String {
        switch self {
        case .startIndoors: "Start Seeds Indoors"
        case .transplant: "Transplant Outdoors"
        case .activeGrowing: "Prime Growing"
        case .harvest: "Harvest Window"
        case .winterPrep: "Prepare for Dormancy"
        case .pruning: "Pruning"
        case .fertilize: "Fertilize"
        }
    }

    public var icon: String {
        switch self {
        case .startIndoors: "light.recessed.3.fill"
        case .transplant: "arrow.up.right.and.arrow.down.left.rectangle.fill"
        case .activeGrowing: "leaf.fill"
        case .harvest: "basket.fill"
        case .winterPrep: "snowflake"
        case .pruning: "scissors"
        case .fertilize: "drop.triangle.fill"
        }
    }
}

// MARK: - PlantActivity

public struct PlantActivity: Identifiable, Sendable {
    public let id: UUID
    public let plantName: String
    public let activityType: SeasonalActivity
    public let description: String
    public let icon: String

    public init(
        id: UUID = UUID(),
        plantName: String,
        activityType: SeasonalActivity,
        description: String,
        icon: String
    ) {
        self.id = id
        self.plantName = plantName
        self.activityType = activityType
        self.description = description
        self.icon = icon
    }
}

// MARK: - FrostDate

public struct FrostDate: Sendable {
    public let lastSpringFrost: Int // month (1-12)
    public let lastSpringFrostDay: Int
    public let firstFallFrost: Int // month (1-12)
    public let firstFallFrostDay: Int

    public var lastSpringFrostDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var components = DateComponents()
        components.month = lastSpringFrost
        components.day = lastSpringFrostDay
        components.year = Calendar.current.component(.year, from: Date())
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(monthName(lastSpringFrost)) \(lastSpringFrostDay)"
    }

    public var firstFallFrostDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var components = DateComponents()
        components.month = firstFallFrost
        components.day = firstFallFrostDay
        components.year = Calendar.current.component(.year, from: Date())
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(monthName(firstFallFrost)) \(firstFallFrostDay)"
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return ""
    }

    /// Zone-based frost date lookup (approximate averages for US zones)
    public static func forZone(_ zone: String?) -> FrostDate? {
        guard let zone else { return nil }
        // Extract numeric zone (e.g. "7a" -> 7, "10b" -> 10)
        let digits = zone.prefix(while: { $0.isNumber })
        guard let zoneNum = Int(digits) else { return nil }

        switch zoneNum {
        case 3: return FrostDate(lastSpringFrost: 5, lastSpringFrostDay: 15, firstFallFrost: 9, firstFallFrostDay: 15)
        case 4: return FrostDate(lastSpringFrost: 5, lastSpringFrostDay: 1, firstFallFrost: 10, firstFallFrostDay: 1)
        case 5: return FrostDate(lastSpringFrost: 4, lastSpringFrostDay: 15, firstFallFrost: 10, firstFallFrostDay: 15)
        case 6: return FrostDate(lastSpringFrost: 4, lastSpringFrostDay: 1, firstFallFrost: 10, firstFallFrostDay: 31)
        case 7: return FrostDate(lastSpringFrost: 3, lastSpringFrostDay: 22, firstFallFrost: 11, firstFallFrostDay: 7)
        case 8: return FrostDate(lastSpringFrost: 3, lastSpringFrostDay: 10, firstFallFrost: 11, firstFallFrostDay: 20)
        case 9: return FrostDate(lastSpringFrost: 2, lastSpringFrostDay: 15, firstFallFrost: 12, firstFallFrostDay: 1)
        case 10: return FrostDate(lastSpringFrost: 1, lastSpringFrostDay: 31, firstFallFrost: 12, firstFallFrostDay: 15)
        default: return nil
        }
    }
}

// MARK: - SeasonalPlannerService

@MainActor
@Observable
public final class SeasonalPlannerService {
    private let dataService: DataService

    public init(dataService: DataService) {
        self.dataService = dataService
    }

    public func getMonthlyActivities(for month: Int, plants: [Plant], zone: String?) -> [PlantActivity] {
        var activities: [PlantActivity] = []
        let frostDate = FrostDate.forZone(zone)

        for plant in plants {
            let plantName = plant.name ?? "Unknown"
            let plantType = plant.plantType ?? .vegetable

            let plantActivities = activitiesForPlant(
                name: plantName,
                type: plantType,
                month: month,
                zone: zone,
                frostDate: frostDate
            )
            activities.append(contentsOf: plantActivities)
        }

        return activities.sorted { $0.activityType.displayName < $1.activityType.displayName }
    }

    public func getFrostDate(for zone: String?) -> FrostDate? {
        FrostDate.forZone(zone)
    }

    // MARK: - Private

    private func activitiesForPlant(
        name: String,
        type: PlantType,
        month: Int,
        zone: String?,
        frostDate: FrostDate?
    ) -> [PlantActivity] {
        var result: [PlantActivity] = []

        let calendar = plantingCalendar(for: type, zone: zone)

        if calendar.startIndoorsMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .startIndoors,
                description: "Start \(name) seeds indoors under grow lights",
                icon: SeasonalActivity.startIndoors.icon
            ))
        }

        if calendar.transplantMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .transplant,
                description: "Transplant \(name) outdoors after hardening off",
                icon: SeasonalActivity.transplant.icon
            ))
        }

        if calendar.activeGrowingMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .activeGrowing,
                description: "\(name) in active growth — maintain regular care",
                icon: SeasonalActivity.activeGrowing.icon
            ))
        }

        if calendar.harvestMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .harvest,
                description: "Harvest \(name) at peak ripeness",
                icon: SeasonalActivity.harvest.icon
            ))
        }

        if calendar.winterPrepMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .winterPrep,
                description: "Prepare \(name) for winter dormancy",
                icon: SeasonalActivity.winterPrep.icon
            ))
        }

        if calendar.pruningMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .pruning,
                description: "Prune \(name) for shape and health",
                icon: SeasonalActivity.pruning.icon
            ))
        }

        if calendar.fertilizeMonths.contains(month) {
            result.append(PlantActivity(
                plantName: name,
                activityType: .fertilize,
                description: "Apply balanced fertilizer to \(name)",
                icon: SeasonalActivity.fertilize.icon
            ))
        }

        return result
    }

    private struct PlantCalendar {
        var startIndoorsMonths: Set<Int> = []
        var transplantMonths: Set<Int> = []
        var activeGrowingMonths: Set<Int> = []
        var harvestMonths: Set<Int> = []
        var winterPrepMonths: Set<Int> = []
        var pruningMonths: Set<Int> = []
        var fertilizeMonths: Set<Int> = []
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func plantingCalendar(for type: PlantType, zone: String?) -> PlantCalendar {
        let zoneNum = extractZoneNumber(from: zone) ?? 7
        // Shift months earlier for warmer zones, later for colder
        let zoneOffset = max(-2, min(2, 7 - zoneNum))

        var cal = PlantCalendar()

        switch type {
        case .vegetable:
            cal.startIndoorsMonths = shifted([2, 3], by: zoneOffset)
            cal.transplantMonths = shifted([4, 5], by: zoneOffset)
            cal.activeGrowingMonths = shifted([5, 6, 7], by: zoneOffset)
            cal.harvestMonths = shifted([7, 8, 9], by: zoneOffset)
            cal.winterPrepMonths = shifted([10, 11], by: zoneOffset)
            cal.fertilizeMonths = shifted([4, 6, 8], by: zoneOffset)

        case .herb:
            cal.startIndoorsMonths = shifted([3, 4], by: zoneOffset)
            cal.transplantMonths = shifted([5], by: zoneOffset)
            cal.activeGrowingMonths = shifted([5, 6, 7, 8], by: zoneOffset)
            cal.harvestMonths = shifted([6, 7, 8, 9], by: zoneOffset)
            cal.fertilizeMonths = shifted([4, 7], by: zoneOffset)

        case .flower:
            cal.startIndoorsMonths = shifted([2, 3], by: zoneOffset)
            cal.transplantMonths = shifted([4, 5], by: zoneOffset)
            cal.activeGrowingMonths = shifted([5, 6, 7, 8], by: zoneOffset)
            cal.pruningMonths = shifted([3, 9], by: zoneOffset)
            cal.winterPrepMonths = shifted([10, 11], by: zoneOffset)
            cal.fertilizeMonths = shifted([4, 6], by: zoneOffset)

        case .fruit:
            cal.activeGrowingMonths = shifted([4, 5, 6, 7], by: zoneOffset)
            cal.harvestMonths = shifted([6, 7, 8, 9], by: zoneOffset)
            cal.pruningMonths = shifted([1, 2, 12], by: zoneOffset)
            cal.winterPrepMonths = shifted([10, 11], by: zoneOffset)
            cal.fertilizeMonths = shifted([3, 6], by: zoneOffset)

        case .houseplant:
            cal.activeGrowingMonths = Set(3 ... 9)
            cal.fertilizeMonths = Set(4 ... 8)
            cal.pruningMonths = [3, 4]

        case .succulent:
            cal.activeGrowingMonths = Set(4 ... 9)
            cal.fertilizeMonths = [5, 7]

        case .tree:
            cal.activeGrowingMonths = shifted([4, 5, 6, 7, 8], by: zoneOffset)
            cal.pruningMonths = shifted([1, 2, 12], by: zoneOffset)
            cal.winterPrepMonths = shifted([10, 11], by: zoneOffset)
            cal.fertilizeMonths = shifted([3, 6], by: zoneOffset)

        case .shrub:
            cal.activeGrowingMonths = shifted([4, 5, 6, 7], by: zoneOffset)
            cal.pruningMonths = shifted([2, 3, 8], by: zoneOffset)
            cal.winterPrepMonths = shifted([10, 11], by: zoneOffset)
            cal.fertilizeMonths = shifted([4, 6], by: zoneOffset)
        }

        return cal
    }

    private func extractZoneNumber(from zone: String?) -> Int? {
        guard let zone else { return nil }
        let digits = zone.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private func shifted(_ months: [Int], by offset: Int) -> Set<Int> {
        Set(months.map { month in
            var shifted = month + offset
            if shifted < 1 { shifted += 12 }
            if shifted > 12 { shifted -= 12 }
            return shifted
        })
    }
}
