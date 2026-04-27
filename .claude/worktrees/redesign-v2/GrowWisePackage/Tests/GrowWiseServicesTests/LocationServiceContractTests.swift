import CoreLocation
import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - Hardiness Zone Contract Tests

@Suite(.tags(.integration))
@MainActor
struct HardinessZoneContractTests {
    private let service = LocationService()

    @Test("Arctic latitude (>=64°N) maps to zone 1a")
    func arcticLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 66.0, longitude: -150.0))
        #expect(zone == "1a")
    }

    @Test("Anchorage latitude (~61°N) maps to zone 1b")
    func anchorageLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 61.0, longitude: -150.0))
        #expect(zone == "1b")
    }

    @Test("Minneapolis latitude (~45°N) maps to zone 3b")
    func minneapolisLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 45.0, longitude: -93.3))
        #expect(zone == "3b")
    }

    @Test("New York latitude (~40.7°N) maps to zone 4a")
    func newYorkLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 40.7, longitude: -74.0))
        #expect(zone == "4a")
    }

    @Test("Dallas latitude (~32.8°N) maps to zone 5a")
    func dallasLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 32.8, longitude: -96.8))
        #expect(zone == "5a")
    }

    @Test("Miami latitude (~25.8°N) maps to zone 6a")
    func miamiLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 25.8, longitude: -80.2))
        #expect(zone == "6a")
    }

    @Test("Equator (0°) maps to zone 9a")
    func equatorLatitude() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: 0.0, longitude: 0.0))
        #expect(zone == "9a")
    }

    @Test("Southern hemisphere (-25°) maps to zone 12b")
    func deepSouthernHemisphere() {
        let zone = service.determineHardinessZone(for: CLLocation(latitude: -25.0, longitude: 28.0))
        #expect(zone == "12b")
    }

    @Test("Longitude does not affect zone calculation")
    func longitudeDoesNotAffectZone() {
        let lat = 42.0
        let zone1 = service.determineHardinessZone(for: CLLocation(latitude: lat, longitude: -122.0))
        let zone2 = service.determineHardinessZone(for: CLLocation(latitude: lat, longitude: -74.0))
        let zone3 = service.determineHardinessZone(for: CLLocation(latitude: lat, longitude: 139.0))

        #expect(zone1 == zone2)
        #expect(zone2 == zone3)
    }

    @Test("Zone boundaries are contiguous — every 4° band produces a valid zone")
    func zoneBoundariesAreContiguous() {
        let validZones = Set([
            "1a", "1b", "2a", "2b", "3a", "3b", "4a", "4b",
            "5a", "5b", "6a", "6b", "7a", "7b", "8a", "8b",
            "9a", "9b", "10a", "10b", "11a", "11b", "12a", "12b",
        ])

        // Sweep from -30° to 70° in 2° steps
        for lat in stride(from: -30.0, through: 70.0, by: 2.0) {
            let zone = service.determineHardinessZone(for: CLLocation(latitude: lat, longitude: 0.0))
            #expect(validZones.contains(zone), "Latitude \(lat) produced unexpected zone: \(zone)")
        }
    }
}

// MARK: - Planting Window Contract Tests

@Suite(.tags(.integration))
@MainActor
struct PlantingWindowContractTests {
    private let service = LocationService()

    @Test("Vegetable planting window returns valid date range for zone 5")
    func vegetablePlantingWindow() throws {
        setHardinessZone("5a")
        let window = service.getPlantingWindow(for: .vegetable)

        #expect(window != nil)
        #expect(try #require(window?.startDate) < window!.endDate)
        #expect(try !#require(window?.description.isEmpty))
    }

    @Test("Herb planting window returns valid date range")
    func herbPlantingWindow() throws {
        setHardinessZone("4a")
        let window = service.getPlantingWindow(for: .herb)

        #expect(window != nil)
        #expect(try #require(window?.startDate) < window!.endDate)
    }

    @Test("Flower planting window returns valid date range")
    func flowerPlantingWindow() throws {
        setHardinessZone("6b")
        let window = service.getPlantingWindow(for: .flower)

        #expect(window != nil)
        #expect(try #require(window?.startDate) < window!.endDate)
    }

    @Test("Houseplant planting window is year-round")
    func houseplantPlantingWindowIsYearRound() throws {
        setHardinessZone("5a")
        let window = service.getPlantingWindow(for: .houseplant)

        #expect(window != nil)
        #expect(try #require(window?.description.lowercased().contains("year-round")))
    }

    @Test("Planting window returns nil when no hardiness zone is set")
    func plantingWindowReturnsNilWithoutZone() {
        // Don't set a zone — hardinessZone defaults to nil
        let freshService = LocationService()
        let window = freshService.getPlantingWindow(for: .vegetable)

        #expect(window == nil)
    }

    @Test("Colder zones produce later vegetable start months")
    func colderZonesStartLater() throws {
        // Zone 3: startMonth = max(3, 6-3) = 3
        // Zone 1: startMonth = max(3, 6-1) = 5
        setHardinessZone("3a")
        let warmWindow = service.getPlantingWindow(for: .vegetable)

        setHardinessZone("1a")
        let coldWindow = service.getPlantingWindow(for: .vegetable)

        #expect(warmWindow != nil)
        #expect(coldWindow != nil)
        #expect(try #require(warmWindow?.startDate) < coldWindow!.startDate)
    }

    private func setHardinessZone(_ zone: String) {
        service.hardinessZone = zone
    }
}

// MARK: - PlantingWindow Model Tests

@Suite(.tags(.integration))
struct PlantingWindowModelTests {
    @Test("isCurrentlyOptimal returns true when now is within range")
    func isOptimalWhenWithinRange() {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400),
            description: "Test window"
        )

        #expect(window.isCurrentlyOptimal == true)
    }

    @Test("isCurrentlyOptimal returns false when window is in the future")
    func isNotOptimalWhenFuture() {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: 86400),
            endDate: Date(timeIntervalSinceNow: 172_800),
            description: "Future window"
        )

        #expect(window.isCurrentlyOptimal == false)
    }

    @Test("isCurrentlyOptimal returns false when window has passed")
    func isNotOptimalWhenPast() {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: -172_800),
            endDate: Date(timeIntervalSinceNow: -86400),
            description: "Past window"
        )

        #expect(window.isCurrentlyOptimal == false)
    }

    @Test("daysUntilStart returns nil when window has already started")
    func daysUntilStartNilWhenStarted() {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400),
            description: "Active window"
        )

        #expect(window.daysUntilStart == nil)
    }

    @Test("daysUntilStart returns positive value for future window")
    func daysUntilStartPositiveForFuture() throws {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: 3 * 86400),
            endDate: Date(timeIntervalSinceNow: 10 * 86400),
            description: "Future window"
        )

        #expect(window.daysUntilStart != nil)
        #expect(try #require(window.daysUntilStart) > 0)
    }

    @Test("daysRemaining returns nil when window has ended")
    func daysRemainingNilWhenEnded() {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: -172_800),
            endDate: Date(timeIntervalSinceNow: -86400),
            description: "Past window"
        )

        #expect(window.daysRemaining == nil)
    }

    @Test("daysRemaining returns non-negative value for active window")
    func daysRemainingNonNegativeForActive() throws {
        let window = PlantingWindow(
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 5 * 86400),
            description: "Active window"
        )

        #expect(window.daysRemaining != nil)
        #expect(try #require(window.daysRemaining) >= 0)
    }
}

// MARK: - Weather Alert Model Tests

@Suite(.tags(.integration))
struct WeatherAlertModelTests {
    @Test("WeatherAlert with future expiry is not expired")
    func alertWithFutureExpiryIsNotExpired() {
        let alert = WeatherAlert(
            type: .frost,
            title: "Frost Warning",
            message: "Cover your plants",
            severity: .high,
            expiryDate: Date(timeIntervalSinceNow: 86400)
        )

        #expect(alert.isExpired == false)
    }

    @Test("WeatherAlert with past expiry is expired")
    func alertWithPastExpiryIsExpired() {
        let alert = WeatherAlert(
            type: .heat,
            title: "Heat Warning",
            message: "Water frequently",
            severity: .medium,
            expiryDate: Date(timeIntervalSinceNow: -86400)
        )

        #expect(alert.isExpired == true)
    }

    @Test("Every WeatherAlertType has a non-empty icon")
    func everyAlertTypeHasIcon() {
        for alertType in WeatherAlertType.allCases {
            #expect(!alertType.iconName.isEmpty, "\(alertType.rawValue) has no icon")
        }
    }

    @Test("WeatherAlertType has 6 cases")
    func alertTypeHasSixCases() {
        #expect(WeatherAlertType.allCases.count == 6)
    }

    @Test("AlertSeverity has 4 levels")
    func severityHasFourLevels() {
        #expect(AlertSeverity.allCases.count == 4)
    }

    @Test("LocationError descriptions are non-empty for all cases")
    func locationErrorDescriptions() {
        let errors: [LocationError] = [
            .permissionDenied,
            .locationUnavailable,
            .networkError,
            .weatherFetchFailed("timeout"),
            .unknown,
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false, "\(error) has empty description")
        }
    }

    @Test("LocationError.weatherFetchFailed includes the provided message")
    func weatherFetchFailedIncludesMessage() {
        let error = LocationError.weatherFetchFailed("server unreachable")
        #expect(error.errorDescription?.contains("server unreachable") == true)
    }
}

// MARK: - WeatherAdjustmentSnapshot Contract Tests

@Suite(.tags(.integration))
struct WeatherAdjustmentSnapshotContractTests {
    @Test("Rain delays watering by one day when precipitation chance >= 60%")
    @MainActor
    func rainDelaysWatering() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.65,
            totalPrecipitationInches: 0.3
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)

        #expect(delta == 1)
    }

    @Test("Heavy precipitation delays watering by one day")
    @MainActor
    func heavyPrecipitationDelaysWatering() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 72,
            maxPrecipitationChance: 0.3,
            totalPrecipitationInches: 0.6
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)

        #expect(delta == 1)
    }

    @Test("Heat advances watering by one day when temp >= 90°F")
    @MainActor
    func heatAdvancesWatering() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 95,
            maxPrecipitationChance: 0.1,
            totalPrecipitationInches: 0
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)

        #expect(delta == -1)
    }

    @Test("Normal conditions keep the base date unchanged")
    @MainActor
    func normalConditionsUnchanged() {
        let baseDate = Date()
        let snapshot = WeatherAdjustmentSnapshot(
            maxTemperatureF: 75,
            maxPrecipitationChance: 0.2,
            totalPrecipitationInches: 0.1
        )

        let adjusted = ReminderService.adjustedWateringDate(baseDate: baseDate, snapshot: snapshot)
        let delta = dayDelta(from: baseDate, to: adjusted)

        #expect(delta == 0)
    }

    private func dayDelta(from startDate: Date, to endDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
