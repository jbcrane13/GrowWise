import Testing
import Foundation
@testable import GrowWiseServices

@Suite("ReminderService Weather Adjustment Logic")
struct ReminderServiceWeatherLogicExtendedTests {

    // Thresholds from ReminderService.adjustedWateringDate:
    //   Rain delay:  precipitationChance >= 0.6 OR totalPrecipitationInches >= 0.5  → +1 day
    //   Heat advance: maxTemperatureF >= 90                                          → -1 day
    //   Otherwise: no change

    @Test("No rain or heat returns same date (delta 0)")
    @MainActor
    func testNormalConditionsNoAdjustment() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.2,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 0)
    }

    @Test("High precipitation chance triggers delay by 1 day")
    @MainActor
    func testHighPrecipitationChanceDelays() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.6, // exactly at threshold
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 1)
    }

    @Test("High precipitation amount triggers delay by 1 day")
    @MainActor
    func testHighPrecipitationAmountDelays() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.1,
            totalPrecipitationInches: 0.5 // exactly at threshold
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 1)
    }

    @Test("High temperature triggers advance by 1 day (delta -1)")
    @MainActor
    func testHighTemperatureAdvances() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 90, // exactly at threshold
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == -1)
    }

    @Test("Rain takes precedence over heat: both trigger delay not advance")
    @MainActor
    func testRainTakesPrecedenceOverHeat() {
        let base = Date()
        // Both rain and heat conditions met — rain is checked first → delay
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 98,
            maxPrecipitationChance: 0.9,
            totalPrecipitationInches: 0.8
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 1) // rain delay wins
    }

    @Test("Temperature just below threshold (89°F) returns no adjustment")
    @MainActor
    func testTemperatureJustBelowThresholdNoAdjustment() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 89,
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 0)
    }

    @Test("Precipitation chance just below threshold (0.59) returns no adjustment")
    @MainActor
    func testPrecipitationChanceJustBelowThresholdNoAdjustment() {
        let base = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.59,
            totalPrecipitationInches: 0.0
        )
        let adjusted = ReminderService.adjustedWateringDate(baseDate: base, snapshot: snapshot)
        let delta = Calendar.current.dateComponents([.day], from: base, to: adjusted).day ?? 999
        #expect(delta == 0)
    }
}
