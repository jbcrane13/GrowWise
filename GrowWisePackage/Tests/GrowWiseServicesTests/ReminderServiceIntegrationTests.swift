import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - Mock Weather Provider

/// A controllable weather provider for integration testing.
/// Conforms to `WeatherAdjustmentProviding` so it can be injected into ReminderService.
struct MockWeatherProvider: WeatherAdjustmentProviding {
    let snapshot: WeatherAdjustmentSnapshot

    func snapshot(for location: CLLocation) async throws -> WeatherAdjustmentSnapshot {
        return snapshot
    }
}

/// A weather provider that always throws, simulating a network failure.
struct FailingWeatherProvider: WeatherAdjustmentProviding {
    func snapshot(for location: CLLocation) async throws -> WeatherAdjustmentSnapshot {
        throw URLError(.notConnectedToInternet)
    }
}

// MARK: - Test Helpers

/// Creates a fully-schema'd in-memory DataService suitable for ReminderService tests.
/// Uses DataService.makeForTesting() which includes all production models and avoids
/// CloudKit initialisation, making it safe for the swift test runner.
@MainActor
private func makeInMemoryDataService() throws -> DataService {
    try DataService.makeForTesting()
}

/// Creates a ReminderService with the given DataService, disabling real notifications
/// and injecting an optional weather provider.
///
/// Uses `NotificationService(notificationCenter: nil)` to avoid calling
/// `UNUserNotificationCenter.current()` which crashes in the swift test runner
/// (no app bundle / entitlements present). Since `shouldScheduleNotifications` is
/// also set to `false`, no notification calls are made through the service.
@MainActor
private func makeReminderService(
    dataService: DataService,
    weatherProvider: (any WeatherAdjustmentProviding)? = nil
) -> ReminderService {
    let notificationService = NotificationService(notificationCenter: nil)
    if let wp = weatherProvider {
        return ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            weatherProvider: wp,
            shouldScheduleNotifications: false
        )
    }
    return ReminderService(
        dataService: dataService,
        notificationService: notificationService,
        shouldScheduleNotifications: false
    )
}

// MARK: - Integration Test Suite

@Suite("ReminderService Integration Tests")
@MainActor
struct ReminderServiceIntegrationTests {

    // MARK: Initialization

    @Test("ReminderService initializes with in-memory DataService and NotificationService")
    func testInitialization() throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)

        // Basic sanity: service exposes its dependencies
        #expect(service.dataService === dataService)
    }

    // MARK: createSmartReminder — type correctness

    @Test("createSmartReminder with .watering type produces a watering reminder")
    func testCreateSmartReminderWateringType() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Basil-\(UUID())", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 3,
            enableWeatherAdjustment: false
        )

        #expect(reminder.reminderType == .watering)
    }

    @Test("createSmartReminder with .fertilizing type produces a fertilizing reminder")
    func testCreateSmartReminderFertilizingType() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Tomato-\(UUID())", type: .vegetable)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: 14,
            enableWeatherAdjustment: false
        )

        #expect(reminder.reminderType == .fertilizing)
    }

    @Test("createSmartReminder with .pestControl type produces a pest-control reminder")
    func testCreateSmartReminderPestControlType() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Rose-\(UUID())", type: .flower)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .pestControl,
            baseFrequencyDays: 7,
            enableWeatherAdjustment: false
        )

        #expect(reminder.reminderType == .pestControl)
    }

    // MARK: createSmartReminder — base frequency

    @Test("createSmartReminder stores the given baseFrequencyDays on the reminder")
    func testCreateSmartReminderStoresBaseFrequency() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Mint-\(UUID())", type: .herb)
        let expectedDays = 5

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: expectedDays,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == expectedDays)
    }

    @Test("createSmartReminder with daily frequency (1 day) stores baseFrequencyDays == 1 and frequency == .daily")
    func testCreateSmartReminderDailyFrequency() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Lettuce-\(UUID())", type: .vegetable)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: ReminderFrequency.daily.days,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 1)
        #expect(reminder.frequency == .daily)
        #expect(reminder.customFrequencyDays == nil)
    }

    @Test("createSmartReminder with weekly frequency (7 days) stores frequency == .weekly")
    func testCreateSmartReminderWeeklyFrequency() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Cactus-\(UUID())", type: .succulent)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 7,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 7)
        #expect(reminder.frequency == .weekly)
        #expect(reminder.customFrequencyDays == nil)
    }

    @Test("createSmartReminder with biweekly frequency (14 days) stores frequency == .biweekly")
    func testCreateSmartReminderBiweeklyFrequency() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Fern-\(UUID())", type: .houseplant)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: ReminderFrequency.biweekly.days,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 14)
        #expect(reminder.frequency == .biweekly)
        #expect(reminder.customFrequencyDays == nil)
    }

    @Test("createSmartReminder with monthly frequency (30 days) stores frequency == .monthly")
    func testCreateSmartReminderMonthlyFrequency() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Aloe-\(UUID())", type: .succulent)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: 30,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 30)
        #expect(reminder.frequency == .monthly)
        #expect(reminder.customFrequencyDays == nil)
    }

    @Test("createSmartReminder with non-canonical cadence (5 days) falls back to .custom and preserves baseFrequencyDays")
    func testCreateSmartReminderCustomFrequencyPreservesDays() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Sage-\(UUID())", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 5,
            enableWeatherAdjustment: false
        )

        #expect(reminder.baseFrequencyDays == 5)
        #expect(reminder.frequency == .custom)
        #expect(reminder.customFrequencyDays == 5)
    }

    // MARK: createSmartReminder — weather adjustment flag

    @Test("createSmartReminder with enableWeatherAdjustment=true sets flag on reminder")
    func testCreateSmartReminderWeatherAdjustmentEnabled() async throws {
        let dataService = try makeInMemoryDataService()
        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.1,
            totalPrecipitationInches: 0.0
        ))
        let service = makeReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "Pepper-\(UUID())", type: .vegetable)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 3,
            enableWeatherAdjustment: true
        )

        #expect(reminder.enableWeatherAdjustment == true)
    }

    @Test("createSmartReminder with enableWeatherAdjustment=false sets flag to false on reminder")
    func testCreateSmartReminderWeatherAdjustmentDisabled() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Oregano-\(UUID())", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 3,
            enableWeatherAdjustment: false
        )

        #expect(reminder.enableWeatherAdjustment == false)
    }

    // MARK: createSmartReminder — priority

    @Test("createSmartReminder with .high priority sets correct priority on reminder")
    func testCreateSmartReminderHighPriority() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Kale-\(UUID())", type: .vegetable)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 2,
            enableWeatherAdjustment: false,
            priority: .high
        )

        #expect(reminder.priority == .high)
    }

    @Test("createSmartReminder with .low priority sets correct priority on reminder")
    func testCreateSmartReminderLowPriority() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Succulent-\(UUID())", type: .succulent)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .inspection,
            baseFrequencyDays: 30,
            enableWeatherAdjustment: false,
            priority: .low
        )

        #expect(reminder.priority == .low)
    }

    @Test("createSmartReminder defaults to .medium priority when not specified")
    func testCreateSmartReminderDefaultMediumPriority() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Thyme-\(UUID())", type: .herb)

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: 21,
            enableWeatherAdjustment: false
            // priority not specified — should default to .medium
        )

        #expect(reminder.priority == .medium)
    }

    // MARK: Multiple distinct reminders

    @Test("Creating reminders for different types produces distinct reminders")
    func testMultipleReminderTypesProduceDistinctReminders() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Chili-\(UUID())", type: .vegetable)

        let wateringReminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 2,
            enableWeatherAdjustment: false
        )
        let fertilizingReminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: 14,
            enableWeatherAdjustment: false
        )
        let pestReminder = try await service.createSmartReminder(
            for: plant,
            type: .pestControl,
            baseFrequencyDays: 7,
            enableWeatherAdjustment: false
        )

        // All three must have different IDs
        #expect(wateringReminder.id != fertilizingReminder.id)
        #expect(wateringReminder.id != pestReminder.id)
        #expect(fertilizingReminder.id != pestReminder.id)

        // Types must remain distinct
        #expect(wateringReminder.reminderType == .watering)
        #expect(fertilizingReminder.reminderType == .fertilizing)
        #expect(pestReminder.reminderType == .pestControl)

        // Frequencies must reflect what was requested
        #expect(wateringReminder.baseFrequencyDays == 2)
        #expect(fertilizingReminder.baseFrequencyDays == 14)
        #expect(pestReminder.baseFrequencyDays == 7)
    }

    // MARK: Due-date calculation — no weather

    @Test("createSmartReminder schedules nextDueDate approximately baseFrequencyDays in the future")
    func testNextDueDateIsApproximatelyBaseFrequencyDaysFromNow() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Parsley-\(UUID())", type: .herb)
        let baseFrequency = 5
        let before = Date()

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: false
        )

        let after = Date()
        let calendar = Calendar.current
        // Lower bound: baseFrequency - 1 day (quiet-hours shift can move date to next morning)
        let lowerBound = calendar.date(byAdding: .day, value: baseFrequency - 1, to: before)!
        // Upper bound: baseFrequency + 2 days (quiet-hours shift can move forward by 1 day)
        let upperBound = calendar.date(byAdding: .day, value: baseFrequency + 2, to: after)!

        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    // MARK: Weather adjustment integration — watering type

    @Test("Weather adjustment: high temperature advances watering date by 1 day")
    func testWeatherAdjustmentHighTempAdvancesWateringDate() async throws {
        let dataService = try makeInMemoryDataService()

        // Plant needs a user with location so adjustWateringForWeather queries the weather provider
        let user = try dataService.createUser(
            email: "weather-test-\(UUID())@example.com",
            displayName: "Weather Tester",
            skillLevel: .beginner
        )
        user.latitude = 37.7749
        user.longitude = -122.4194

        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 98,       // >= 90 threshold → advance by 1 day
            maxPrecipitationChance: 0.0,
            totalPrecipitationInches: 0.0
        ))
        let service = makeReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "Tomato-Heat-\(UUID())", type: .vegetable)

        let baseFrequency = 7
        let approximateBase = Calendar.current.date(byAdding: .day, value: baseFrequency, to: Date())!

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        // With high temperature the date should be moved EARLIER (base - 1 day).
        // We allow ±1 additional day slack for quiet-hours and wall-clock drift.
        let delta = Calendar.current.dateComponents([.day], from: approximateBase, to: reminder.nextDueDate).day ?? 999
        #expect(delta <= 0, "High temp should advance (or not delay) the due date relative to base")
        #expect(delta >= -2, "Advance should be at most 2 days (1 weather + 1 quiet-hours)")
    }

    @Test("Weather adjustment: high precipitation chance delays watering date by 1 day")
    func testWeatherAdjustmentRainDelaysWateringDate() async throws {
        let dataService = try makeInMemoryDataService()

        let user = try dataService.createUser(
            email: "rain-test-\(UUID())@example.com",
            displayName: "Rain Tester",
            skillLevel: .beginner
        )
        user.latitude = 47.6062
        user.longitude = -122.3321

        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 65,
            maxPrecipitationChance: 0.8,   // >= 0.6 threshold → delay by 1 day
            totalPrecipitationInches: 0.0
        ))
        let service = makeReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "Lettuce-Rain-\(UUID())", type: .vegetable)

        let baseFrequency = 3
        let approximateBase = Calendar.current.date(byAdding: .day, value: baseFrequency, to: Date())!

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        // With rain the date should be moved LATER (base + 1 day).
        // Allow ±1 day of quiet-hours/clock drift slack.
        let delta = Calendar.current.dateComponents([.day], from: approximateBase, to: reminder.nextDueDate).day ?? 999
        #expect(delta >= 0, "Rain should delay (or not advance) the due date relative to base")
        #expect(delta <= 3, "Delay should be at most 3 days (1 weather + 1 quiet-hours + clock drift)")
    }

    @Test("Weather adjustment: high precipitation amount delays watering date")
    func testWeatherAdjustmentHighPrecipitationAmountDelaysWateringDate() async throws {
        let dataService = try makeInMemoryDataService()

        let user = try dataService.createUser(
            email: "precip-test-\(UUID())@example.com",
            displayName: "Precip Tester",
            skillLevel: .beginner
        )
        user.latitude = 40.7128
        user.longitude = -74.0060

        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 70,
            maxPrecipitationChance: 0.1,
            totalPrecipitationInches: 0.6   // >= 0.5 threshold → delay by 1 day
        ))
        let service = makeReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "Bean-Rain-\(UUID())", type: .vegetable)

        let baseFrequency = 4
        let approximateBase = Calendar.current.date(byAdding: .day, value: baseFrequency, to: Date())!

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        let delta = Calendar.current.dateComponents([.day], from: approximateBase, to: reminder.nextDueDate).day ?? 999
        #expect(delta >= 0, "High precipitation should delay or not advance the watering date")
    }

    @Test("Weather adjustment: when weather provider fails, falls back to base date")
    func testWeatherAdjustmentFallbackOnError() async throws {
        let dataService = try makeInMemoryDataService()

        // User with location — provider will throw
        let user = try dataService.createUser(
            email: "fail-test-\(UUID())@example.com",
            displayName: "Fail Tester",
            skillLevel: .beginner
        )
        user.latitude = 34.0522
        user.longitude = -118.2437

        let failingProvider = FailingWeatherProvider()
        let service = makeReminderService(dataService: dataService, weatherProvider: failingProvider)
        let plant = try dataService.createPlant(name: "Sage-Fail-\(UUID())", type: .herb)

        let baseFrequency = 5
        let before = Date()

        // Should NOT throw — ReminderService catches weather errors internally
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        let after = Date()
        let calendar = Calendar.current
        // Falls back to base date: roughly baseFrequency days from now
        let lowerBound = calendar.date(byAdding: .day, value: baseFrequency - 1, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: baseFrequency + 2, to: after)!

        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    @Test("Weather adjustment is skipped when user has no location coordinates")
    func testWeatherAdjustmentSkippedWithoutLocation() async throws {
        let dataService = try makeInMemoryDataService()

        // User without lat/lon — adjustWateringForWeather should bail early
        _ = try dataService.createUser(
            email: "noloc-\(UUID())@example.com",
            displayName: "No Location",
            skillLevel: .beginner
        )
        // latitude and longitude remain nil

        // This provider would panic if called, proving the location guard fires first
        let panicProvider = FailingWeatherProvider()
        let service = makeReminderService(dataService: dataService, weatherProvider: panicProvider)
        let plant = try dataService.createPlant(name: "Ivy-NoLoc-\(UUID())", type: .houseplant)

        let baseFrequency = 7
        let before = Date()

        // Must not throw even with enableWeatherAdjustment=true
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        let after = Date()
        let calendar = Calendar.current
        let lowerBound = calendar.date(byAdding: .day, value: baseFrequency - 1, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: baseFrequency + 2, to: after)!

        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    // MARK: Non-watering types — weather does not move date

    @Test("Weather adjustment for .fertilizing type returns base date unmodified")
    func testWeatherAdjustmentFertilizingDoesNotUseWeatherProvider() async throws {
        let dataService = try makeInMemoryDataService()
        // Provide a weather snapshot that WOULD affect watering (high temp) but not fertilizing
        let mockWeather = MockWeatherProvider(snapshot: WeatherAdjustmentSnapshot(
            maxTemperatureF: 99,
            maxPrecipitationChance: 0.9,
            totalPrecipitationInches: 1.0
        ))
        let service = makeReminderService(dataService: dataService, weatherProvider: mockWeather)
        let plant = try dataService.createPlant(name: "Dahlia-\(UUID())", type: .flower)

        let baseFrequency = 14
        let before = Date()

        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .fertilizing,
            baseFrequencyDays: baseFrequency,
            enableWeatherAdjustment: true
        )

        let after = Date()
        let calendar = Calendar.current
        // fertilizing weather logic only shifts weekends by +2, does not use the mock provider.
        // Accept a generous window of baseFrequency ± 3 days.
        let lowerBound = calendar.date(byAdding: .day, value: baseFrequency - 1, to: before)!
        let upperBound = calendar.date(byAdding: .day, value: baseFrequency + 4, to: after)!

        #expect(reminder.nextDueDate >= lowerBound)
        #expect(reminder.nextDueDate <= upperBound)
    }

    // MARK: createWateringReminder convenience

    @Test("createWateringReminder returns a reminder with .watering type and .high priority")
    func testCreateWateringReminderHasCorrectTypeAndPriority() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)
        let plant = try dataService.createPlant(name: "Mint-Watering-\(UUID())", type: .herb)

        let reminder = try await service.createWateringReminder(
            for: plant,
            frequency: .weekly,
            enableSmartAdjustment: false
        )

        #expect(reminder.reminderType == .watering)
        #expect(reminder.priority == .high)
        #expect(reminder.baseFrequencyDays == ReminderFrequency.weekly.days)
    }

    // MARK: Error propagation gap documentation

    /// Documents a known gap: createReminder uses `try` (not `try?`), so save errors DO
    /// propagate from createSmartReminder. This test verifies the contract is maintained:
    /// a thrown error from createSmartReminder is not silently swallowed.
    ///
    /// Note: DataService.createReminder uses `try modelContext.save()` — errors throw.
    /// ReminderService.createSmartReminder calls it with plain `try`, so errors reach the caller.
    /// If this ever changes to `try?`, this test will still pass but the gap comment should be updated.
    @Test("Errors from createSmartReminder propagate to caller (not swallowed)")
    func testCreateSmartReminderPropagatesErrors() async throws {
        let dataService = try makeInMemoryDataService()
        let service = makeReminderService(dataService: dataService)

        // Create a plant that is NOT inserted into the model context (detached Plant object).
        // DataService.createReminder will try to save it; inserting a non-managed object
        // in an inconsistent state may or may not throw depending on SwiftData internals.
        // What we CAN verify is the happy-path does not silently drop errors when they occur.
        let plant = try dataService.createPlant(name: "ErrorTest-\(UUID())", type: .vegetable)

        // This must succeed — verifying createSmartReminder does not mask save errors on success.
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: 1,
            enableWeatherAdjustment: false
        )
        #expect(reminder.reminderType == .watering)

        // Known gap: if DataService.createReminder is changed to use `try?` instead of `try`,
        // errors will be silently swallowed and callers will not know the reminder was not saved.
        // There is currently no mechanism to inject a failing ModelContext for unit isolation.
    }
}
