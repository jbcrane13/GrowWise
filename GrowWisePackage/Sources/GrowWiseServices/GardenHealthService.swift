import Foundation
import GrowWiseModels

// MARK: - HealthTrend

public enum HealthTrend: String, Sendable {
    case improving
    case declining
    case stable

    public var icon: String {
        switch self {
        case .improving: "arrow.up.right"
        case .declining: "arrow.down.right"
        case .stable: "arrow.right"
        }
    }
}

// MARK: - GardenHealthBreakdown

public struct GardenHealthBreakdown: Sendable {
    public let wateringScore: Int
    public let fertilizingScore: Int
    public let healthScore: Int
    public let careConsistency: Int

    public init(wateringScore: Int, fertilizingScore: Int, healthScore: Int, careConsistency: Int) {
        self.wateringScore = wateringScore
        self.fertilizingScore = fertilizingScore
        self.healthScore = healthScore
        self.careConsistency = careConsistency
    }
}

// MARK: - GardenHealthScore

public struct GardenHealthScore: Sendable {
    public let overallScore: Int
    public let trend: HealthTrend
    public let breakdown: GardenHealthBreakdown

    public init(overallScore: Int, trend: HealthTrend, breakdown: GardenHealthBreakdown) {
        self.overallScore = overallScore
        self.trend = trend
        self.breakdown = breakdown
    }
}

// MARK: - GardenHealthService

@MainActor
@Observable
public final class GardenHealthService {
    private let dataService: DataService

    public init(dataService: DataService) {
        self.dataService = dataService
    }

    public func calculateScore(plants: [Plant], reminders: [PlantReminder]) -> GardenHealthScore {
        let wateringScore = calculateWateringScore(reminders: reminders)
        let fertilizingScore = calculateFertilizingScore(reminders: reminders)
        let healthScore = calculatePlantHealthScore(plants: plants)
        let careConsistency = calculateCareConsistency(reminders: reminders)

        let overall = Int(
            Double(wateringScore) * 0.35
                + Double(healthScore) * 0.30
                + Double(careConsistency) * 0.20
                + Double(fertilizingScore) * 0.15
        )

        let trend = calculateTrend(reminders: reminders)

        let breakdown = GardenHealthBreakdown(
            wateringScore: wateringScore,
            fertilizingScore: fertilizingScore,
            healthScore: healthScore,
            careConsistency: careConsistency
        )

        return GardenHealthScore(
            overallScore: min(100, max(0, overall)),
            trend: trend,
            breakdown: breakdown
        )
    }

    // MARK: - Private Scoring

    private func calculateWateringScore(reminders: [PlantReminder]) -> Int {
        let now = Date()
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let wateringReminders = reminders.filter {
            $0.reminderType == .watering && $0.nextDueDate >= fourteenDaysAgo
        }
        guard !wateringReminders.isEmpty else { return 100 }

        let completed = wateringReminders.filter { $0.lastCompletedDate != nil }
        return Int((Double(completed.count) / Double(wateringReminders.count)) * 100)
    }

    private func calculateFertilizingScore(reminders: [PlantReminder]) -> Int {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        let fertilizingReminders = reminders.filter {
            $0.reminderType == .fertilizing && $0.nextDueDate >= thirtyDaysAgo
        }
        guard !fertilizingReminders.isEmpty else { return 100 }

        let completed = fertilizingReminders.filter { $0.lastCompletedDate != nil }
        return Int((Double(completed.count) / Double(fertilizingReminders.count)) * 100)
    }

    private func calculatePlantHealthScore(plants: [Plant]) -> Int {
        guard !plants.isEmpty else { return 100 }
        let healthyCount = plants.count(where: { ($0.healthStatus ?? .healthy) == .healthy })
        return Int((Double(healthyCount) / Double(plants.count)) * 100)
    }

    private func calculateCareConsistency(reminders: [PlantReminder]) -> Int {
        let now = Date()
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let recentReminders = reminders.filter {
            $0.isEnabled && $0.nextDueDate >= fourteenDaysAgo
        }
        guard !recentReminders.isEmpty else { return 100 }

        // Count consecutive on-time completions (reminders completed before their due date)
        var streakCount = 0
        for reminder in recentReminders {
            if let completedDate = reminder.lastCompletedDate,
               completedDate <= reminder.nextDueDate
            {
                streakCount += 1
            }
        }

        return Int((Double(streakCount) / Double(recentReminders.count)) * 100)
    }

    private func calculateTrend(reminders: [PlantReminder]) -> HealthTrend {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let recentReminders = reminders.filter {
            $0.isEnabled && $0.nextDueDate >= sevenDaysAgo
        }
        let olderReminders = reminders.filter {
            $0.isEnabled && $0.nextDueDate >= fourteenDaysAgo && $0.nextDueDate < sevenDaysAgo
        }

        let recentRate = completionRate(for: recentReminders)
        let olderRate = completionRate(for: olderReminders)

        let diff = recentRate - olderRate
        if diff > 0.1 { return .improving }
        if diff < -0.1 { return .declining }
        return .stable
    }

    private func completionRate(for reminders: [PlantReminder]) -> Double {
        guard !reminders.isEmpty else { return 1.0 }
        let completed = reminders.count(where: { $0.lastCompletedDate != nil })
        return Double(completed) / Double(reminders.count)
    }
}
