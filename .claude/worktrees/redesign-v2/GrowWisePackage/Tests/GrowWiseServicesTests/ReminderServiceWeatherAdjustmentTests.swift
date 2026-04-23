import XCTest
@testable import GrowWiseServices

final class ReminderServiceWeatherAdjustmentTests: XCTestCase {
    @MainActor
    func testRainDelaysWateringReminderByOneDay() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.8,
            totalPrecipitationInches: 0.7
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)
        XCTAssertEqual(delta, 1)
    }

    @MainActor
    func testHeatAdvancesWateringReminderByOneDay() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 98,
            maxPrecipitationChance: 0.1,
            totalPrecipitationInches: 0
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)
        XCTAssertEqual(delta, -1)
    }

    private func dayDelta(from startDate: Date, to endDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
