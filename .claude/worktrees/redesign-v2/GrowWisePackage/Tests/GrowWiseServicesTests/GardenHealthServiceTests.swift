import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

// MARK: - GardenHealthService Tests

@MainActor
struct GardenHealthServiceTests {
    // MARK: - Helpers

    private func makeService() throws -> (GardenHealthService, DataService) {
        let dataService = try DataService.makeForTesting()
        let healthService = GardenHealthService(dataService: dataService)
        return (healthService, dataService)
    }

    private func makePlant(name: String, healthStatus: HealthStatus = .healthy) -> Plant {
        let plant = Plant(name: name, plantType: .vegetable)
        plant.healthStatus = healthStatus
        return plant
    }

    private func makeReminder(
        type: ReminderType = .watering,
        dueDate: Date = Date(),
        completedDate: Date? = nil,
        isEnabled: Bool = true
    ) -> PlantReminder {
        let reminder = PlantReminder(
            title: "\(type.displayName) reminder",
            message: type.defaultMessage,
            reminderType: type,
            frequency: .daily,
            nextDueDate: dueDate
        )
        reminder.lastCompletedDate = completedDate
        reminder.isEnabled = isEnabled
        return reminder
    }

    // MARK: - Empty Garden

    @Test("calculateScore with no plants and no reminders returns perfect score")
    func emptyGardenReturnsPerfectScore() throws {
        let (sut, _) = try makeService()
        let score = sut.calculateScore(plants: [], reminders: [])

        #expect(score.overallScore == 100)
        #expect(score.breakdown.wateringScore == 100)
        #expect(score.breakdown.fertilizingScore == 100)
        #expect(score.breakdown.healthScore == 100)
        #expect(score.breakdown.careConsistency == 100)
    }

    // MARK: - Plant Health Score

    @Test("calculateScore with all healthy plants returns 100 health score")
    func allHealthyPlantsScoreMax() throws {
        let (sut, _) = try makeService()
        let plants = [
            makePlant(name: "Tomato"),
            makePlant(name: "Basil"),
            makePlant(name: "Pepper"),
        ]

        let score = sut.calculateScore(plants: plants, reminders: [])
        #expect(score.breakdown.healthScore == 100)
    }

    @Test("calculateScore with mix of healthy and unhealthy plants reflects ratio")
    func mixedHealthStatusReflectsRatio() throws {
        let (sut, _) = try makeService()
        let plants = [
            makePlant(name: "Healthy One", healthStatus: .healthy),
            makePlant(name: "Sick One", healthStatus: .sick),
        ]

        let score = sut.calculateScore(plants: plants, reminders: [])
        // 1 of 2 healthy = 50%
        #expect(score.breakdown.healthScore == 50)
    }

    @Test("calculateScore with all sick plants returns 0 health score")
    func allSickPlantsScoreZero() throws {
        let (sut, _) = try makeService()
        let plants = [
            makePlant(name: "Sick A", healthStatus: .sick),
            makePlant(name: "Sick B", healthStatus: .dying),
            makePlant(name: "Sick C", healthStatus: .dead),
        ]

        let score = sut.calculateScore(plants: plants, reminders: [])
        #expect(score.breakdown.healthScore == 0)
    }

    // MARK: - Watering Score

    @Test("watering score is 100 when all recent watering reminders are completed")
    func allWateringCompletedScoresMax() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let reminders = [
            makeReminder(type: .watering, dueDate: now, completedDate: now),
            makeReminder(type: .watering, dueDate: now, completedDate: now),
        ]

        let score = sut.calculateScore(plants: [], reminders: reminders)
        #expect(score.breakdown.wateringScore == 100)
    }

    @Test("watering score is 0 when no watering reminders are completed")
    func noWateringCompletedScoresZero() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let reminders = [
            makeReminder(type: .watering, dueDate: now, completedDate: nil),
            makeReminder(type: .watering, dueDate: now, completedDate: nil),
        ]

        let score = sut.calculateScore(plants: [], reminders: reminders)
        #expect(score.breakdown.wateringScore == 0)
    }

    // MARK: - Fertilizing Score

    @Test("fertilizing score reflects completion ratio of recent fertilizing reminders")
    func fertilizingScoreReflectsRatio() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let reminders = [
            makeReminder(type: .fertilizing, dueDate: now, completedDate: now),
            makeReminder(type: .fertilizing, dueDate: now, completedDate: nil),
        ]

        let score = sut.calculateScore(plants: [], reminders: reminders)
        // 1 of 2 completed = 50%
        #expect(score.breakdown.fertilizingScore == 50)
    }

    // MARK: - Care Consistency

    @Test("care consistency is 100 when all enabled reminders completed on time")
    func perfectCareConsistency() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let reminders = [
            makeReminder(type: .watering, dueDate: now, completedDate: yesterday, isEnabled: true),
            makeReminder(type: .pruning, dueDate: now, completedDate: yesterday, isEnabled: true),
        ]

        let score = sut.calculateScore(plants: [], reminders: reminders)
        #expect(score.breakdown.careConsistency == 100)
    }

    @Test("care consistency is 0 when no enabled reminders are completed")
    func zeroCareConsistency() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let reminders = [
            makeReminder(type: .watering, dueDate: now, completedDate: nil, isEnabled: true),
            makeReminder(type: .pruning, dueDate: now, completedDate: nil, isEnabled: true),
        ]

        let score = sut.calculateScore(plants: [], reminders: reminders)
        #expect(score.breakdown.careConsistency == 0)
    }

    // MARK: - Overall Score

    @Test("overall score is clamped between 0 and 100")
    func overallScoreClamped() throws {
        let (sut, _) = try makeService()
        let now = Date()

        // All zeros scenario
        let plants = [makePlant(name: "Dead", healthStatus: .dead)]
        let reminders = [
            makeReminder(type: .watering, dueDate: now, completedDate: nil),
            makeReminder(type: .fertilizing, dueDate: now, completedDate: nil),
        ]

        let score = sut.calculateScore(plants: plants, reminders: reminders)
        #expect(score.overallScore >= 0)
        #expect(score.overallScore <= 100)
    }

    @Test("overall score weights components correctly: 35% water, 30% health, 20% care, 15% fertilize")
    func overallScoreWeighting() throws {
        let (sut, _) = try makeService()

        // All perfect scores => overall should be 100
        let perfectScore = sut.calculateScore(plants: [], reminders: [])
        #expect(perfectScore.overallScore == 100)

        // Mixed: create scenario with known component values
        // 2 healthy + 2 sick plants => healthScore = 50
        // No reminders => watering 100, fertilizing 100, care 100
        let plants = [
            makePlant(name: "H1", healthStatus: .healthy),
            makePlant(name: "H2", healthStatus: .healthy),
            makePlant(name: "S1", healthStatus: .sick),
            makePlant(name: "S2", healthStatus: .dying),
        ]
        let score = sut.calculateScore(plants: plants, reminders: [])

        // Expected: 100*0.35 + 50*0.30 + 100*0.20 + 100*0.15 = 35 + 15 + 20 + 15 = 85
        #expect(score.overallScore == 85)
    }

    // MARK: - Trend Calculation

    @Test("trend is stable when no reminders exist")
    func trendStableWithNoReminders() throws {
        let (sut, _) = try makeService()
        let score = sut.calculateScore(plants: [], reminders: [])
        #expect(score.trend == .stable)
    }

    @Test("trend is improving when recent completion rate exceeds older rate by more than 10%")
    func trendImproving() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let threeDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -3, to: now))
        let tenDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -10, to: now))

        // Recent (last 7 days): 2 completed out of 2 = 100%
        let recentReminders = [
            makeReminder(type: .watering, dueDate: threeDaysAgo, completedDate: threeDaysAgo, isEnabled: true),
            makeReminder(type: .pruning, dueDate: threeDaysAgo, completedDate: threeDaysAgo, isEnabled: true),
        ]
        // Older (7-14 days ago): 0 completed out of 2 = 0%
        let olderReminders = [
            makeReminder(type: .watering, dueDate: tenDaysAgo, completedDate: nil, isEnabled: true),
            makeReminder(type: .pruning, dueDate: tenDaysAgo, completedDate: nil, isEnabled: true),
        ]

        let allReminders = recentReminders + olderReminders
        let score = sut.calculateScore(plants: [], reminders: allReminders)
        #expect(score.trend == .improving)
    }

    @Test("trend is declining when recent completion rate is lower than older rate by more than 10%")
    func trendDeclining() throws {
        let (sut, _) = try makeService()
        let now = Date()
        let threeDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -3, to: now))
        let tenDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -10, to: now))

        // Recent (last 7 days): 0 completed out of 2 = 0%
        let recentReminders = [
            makeReminder(type: .watering, dueDate: threeDaysAgo, completedDate: nil, isEnabled: true),
            makeReminder(type: .pruning, dueDate: threeDaysAgo, completedDate: nil, isEnabled: true),
        ]
        // Older (7-14 days ago): 2 completed out of 2 = 100%
        let olderReminders = [
            makeReminder(type: .watering, dueDate: tenDaysAgo, completedDate: tenDaysAgo, isEnabled: true),
            makeReminder(type: .pruning, dueDate: tenDaysAgo, completedDate: tenDaysAgo, isEnabled: true),
        ]

        let allReminders = recentReminders + olderReminders
        let score = sut.calculateScore(plants: [], reminders: allReminders)
        #expect(score.trend == .declining)
    }
}
