import Testing
import Foundation
@testable import GrowWiseModels

@Suite("GardeningStats Model Tests")
struct GardeningStatsTests {

    // MARK: - Initialization

    @Test("Custom initialization stores all values")
    func testCustomInitialization() {
        let stats = GardeningStats(
            totalPlants: 10,
            healthyPlants: 8,
            activeReminders: 3,
            totalJournalEntries: 12
        )

        #expect(stats.totalPlants == 10)
        #expect(stats.healthyPlants == 8)
        #expect(stats.activeReminders == 3)
        #expect(stats.totalJournalEntries == 12)
    }

    // MARK: - healthPercentage

    @Test("healthPercentage is 0 when there are no plants")
    func testHealthPercentageNoPlants() {
        let stats = GardeningStats(
            totalPlants: 0,
            healthyPlants: 0,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        #expect(stats.healthPercentage == 0.0)
    }

    @Test("healthPercentage is 0 when no plants are healthy")
    func testHealthPercentageNoneHealthy() {
        let stats = GardeningStats(
            totalPlants: 5,
            healthyPlants: 0,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        #expect(stats.healthPercentage == 0.0)
    }

    @Test("healthPercentage is 50 when half are healthy")
    func testHealthPercentageHalf() {
        let stats = GardeningStats(
            totalPlants: 10,
            healthyPlants: 5,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        #expect(stats.healthPercentage == 50.0)
    }

    @Test("healthPercentage is 100 when all plants are healthy")
    func testHealthPercentageAllHealthy() {
        let stats = GardeningStats(
            totalPlants: 10,
            healthyPlants: 10,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        #expect(stats.healthPercentage == 100.0)
    }

    @Test("healthPercentage computes correctly for arbitrary ratios")
    func testHealthPercentageArbitraryRatio() {
        let stats = GardeningStats(
            totalPlants: 3,
            healthyPlants: 1,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        // 1/3 * 100 ≈ 33.333...
        #expect(abs(stats.healthPercentage - 33.3333) < 0.001)
    }

    @Test("healthPercentage avoids division by zero guard")
    func testHealthPercentageZeroTotalNonzeroHealthy() {
        // Logically inconsistent but should not crash — guard fires on totalPlants == 0
        let stats = GardeningStats(
            totalPlants: 0,
            healthyPlants: 5,
            activeReminders: 0,
            totalJournalEntries: 0
        )
        #expect(stats.healthPercentage == 0.0)
    }

    // MARK: - empty static property

    @Test("empty static property has all-zero values")
    func testEmptyStaticProperty() {
        let empty = GardeningStats.empty
        #expect(empty.totalPlants == 0)
        #expect(empty.healthyPlants == 0)
        #expect(empty.activeReminders == 0)
        #expect(empty.totalJournalEntries == 0)
    }

    @Test("empty static property healthPercentage is 0")
    func testEmptyHealthPercentage() {
        #expect(GardeningStats.empty.healthPercentage == 0.0)
    }

    @Test("empty static returns identical values on repeated access")
    func testEmptyIsStable() {
        let first = GardeningStats.empty
        let second = GardeningStats.empty
        #expect(first.totalPlants == second.totalPlants)
        #expect(first.healthyPlants == second.healthyPlants)
        #expect(first.activeReminders == second.activeReminders)
        #expect(first.totalJournalEntries == second.totalJournalEntries)
    }

    // MARK: - Sendable conformance (compile-time, but exercised at runtime)

    @Test("GardeningStats can be passed across concurrency domains")
    func testSendable() async {
        let stats = GardeningStats(
            totalPlants: 5,
            healthyPlants: 3,
            activeReminders: 2,
            totalJournalEntries: 7
        )
        let result = await Task.detached {
            stats.healthPercentage
        }.value
        #expect(abs(result - 60.0) < 0.001)
    }
}
