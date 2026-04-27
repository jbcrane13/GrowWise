import Foundation

/// Statistics for the user's gardening progress
public struct GardeningStats: Sendable {
    public let totalPlants: Int
    public let healthyPlants: Int
    public let activeReminders: Int
    public let totalJournalEntries: Int

    public init(
        totalPlants: Int,
        healthyPlants: Int,
        activeReminders: Int,
        totalJournalEntries: Int
    ) {
        self.totalPlants = totalPlants
        self.healthyPlants = healthyPlants
        self.activeReminders = activeReminders
        self.totalJournalEntries = totalJournalEntries
    }

    public var healthPercentage: Double {
        guard totalPlants > 0 else { return 0 }
        return Double(healthyPlants) / Double(totalPlants) * 100
    }

    public static let empty = GardeningStats(
        totalPlants: 0,
        healthyPlants: 0,
        activeReminders: 0,
        totalJournalEntries: 0
    )
}
