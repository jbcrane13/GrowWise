import Testing
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("LocationService — All Hardiness Zones")
@MainActor
struct LocationServiceAllZonesTests {

    @Test(
        "All 24 hardiness zone boundaries map correctly",
        arguments: [
            (65.0, "1a"),   // >= 64.0
            (61.0, "1b"),   // >= 60.0
            (57.0, "2a"),   // >= 56.0
            (53.0, "2b"),   // >= 52.0
            (49.0, "3a"),   // >= 48.0
            (45.0, "3b"),   // >= 44.0
            (41.0, "4a"),   // >= 40.0
            (37.0, "4b"),   // >= 36.0
            (33.0, "5a"),   // >= 32.0
            (29.0, "5b"),   // >= 28.0
            (25.0, "6a"),   // >= 24.0
            (21.0, "6b"),   // >= 20.0
            (17.0, "7a"),   // >= 16.0
            (13.0, "7b"),   // >= 12.0
            (9.0,  "8a"),   // >= 8.0
            (5.0,  "8b"),   // >= 4.0
            (1.0,  "9a"),   // >= 0.0
            (-2.0, "9b"),   // >= -4.0
            (-6.0, "10a"),  // >= -8.0
            (-10.0, "10b"), // >= -12.0
            (-14.0, "11a"), // >= -16.0
            (-18.0, "11b"), // >= -20.0
            (-22.0, "12a"), // >= -24.0
            (-30.0, "12b")  // < -24.0
        ]
    )
    func allHardinessZonesMappedCorrectly(latitude: Double, expectedZone: String) {
        let service = LocationService()
        let location = CLLocation(latitude: latitude, longitude: 0.0)
        let zone = service.determineHardinessZone(for: location)
        #expect(zone == expectedZone)
    }

    @Test("Zone boundary at exactly 64.0 latitude is 1a")
    func testZoneBoundaryAt64() {
        let service = LocationService()
        let location = CLLocation(latitude: 64.0, longitude: 0.0)
        #expect(service.determineHardinessZone(for: location) == "1a")
    }

    @Test("Zone boundary at exactly 0.0 latitude is 9a")
    func testZoneBoundaryAtEquator() {
        let service = LocationService()
        let location = CLLocation(latitude: 0.0, longitude: 0.0)
        #expect(service.determineHardinessZone(for: location) == "9a")
    }

    @Test("Zone boundary just below -24.0 latitude is 12b")
    func testZoneBoundaryBelowNeg24() {
        let service = LocationService()
        let location = CLLocation(latitude: -24.1, longitude: 0.0)
        #expect(service.determineHardinessZone(for: location) == "12b")
    }
}

@Suite("LocationService — Planting Windows")
@MainActor
struct LocationServicePlantingWindowTests {

    @Test("Herb planting window is non-nil when zone is set")
    func testHerbPlantingWindow() {
        let service = LocationService()
        service.hardinessZone = "5a"
        let window = service.getPlantingWindow(for: .herb)
        #expect(window != nil)
        #expect(window?.description.contains("5a") == true)
        #expect(window?.startDate != nil)
        #expect(window?.endDate != nil)
    }

    @Test("Flower planting window is non-nil when zone is set")
    func testFlowerPlantingWindow() {
        let service = LocationService()
        service.hardinessZone = "7b"
        let window = service.getPlantingWindow(for: .flower)
        #expect(window != nil)
        #expect(window?.description.contains("7b") == true)
    }

    @Test("Houseplant planting window is year-round")
    func testHouseplantPlantingWindowIsYearRound() {
        let service = LocationService()
        service.hardinessZone = "6a"
        let window = service.getPlantingWindow(for: .houseplant)
        #expect(window != nil)
        let desc = window?.description ?? ""
        #expect(desc.lowercased().contains("year-round"))
    }

    @Test("Planting window endDate is after startDate")
    func testPlantingWindowEndAfterStart() {
        let service = LocationService()
        service.hardinessZone = "6a"
        for plantType in [PlantType.vegetable, .herb, .flower] {
            if let window = service.getPlantingWindow(for: plantType) {
                #expect(window.endDate > window.startDate, "endDate should be after startDate for \(plantType)")
            }
        }
    }

    @Test("Unsupported plant types return nil planting window")
    func testUnsupportedPlantTypesReturnNil() {
        let service = LocationService()
        service.hardinessZone = "6a"
        // tree, fruit, succulent, shrub are not explicitly handled
        #expect(service.getPlantingWindow(for: .tree) == nil)
        #expect(service.getPlantingWindow(for: .fruit) == nil)
        #expect(service.getPlantingWindow(for: .succulent) == nil)
        #expect(service.getPlantingWindow(for: .shrub) == nil)
    }
}

@Suite("PlantingWindow Computed Properties")
struct PlantingWindowComputedPropertyTests {

    @Test("isCurrentlyOptimal is true when now is between start and end")
    func testIsCurrentlyOptimalTrue() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400),
            description: "Active window"
        )
        #expect(window.isCurrentlyOptimal == true)
    }

    @Test("isCurrentlyOptimal is false before window starts")
    func testIsCurrentlyOptimalFalseBeforeStart() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(86400),
            endDate: Date().addingTimeInterval(2 * 86400),
            description: "Future window"
        )
        #expect(window.isCurrentlyOptimal == false)
    }

    @Test("isCurrentlyOptimal is false after window ends")
    func testIsCurrentlyOptimalFalseAfterEnd() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(-2 * 86400),
            endDate: Date().addingTimeInterval(-86400),
            description: "Past window"
        )
        #expect(window.isCurrentlyOptimal == false)
    }

    @Test("daysUntilStart returns value when window is in future")
    func testDaysUntilStartFuture() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(3 * 86400),
            endDate: Date().addingTimeInterval(4 * 86400),
            description: "Future window"
        )
        #expect(window.daysUntilStart != nil)
        #expect(window.daysUntilStart! >= 2)
    }

    @Test("daysUntilStart returns nil when window has started")
    func testDaysUntilStartNilWhenStarted() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400),
            description: "Active window"
        )
        #expect(window.daysUntilStart == nil)
    }

    @Test("daysRemaining returns value when window is active")
    func testDaysRemainingActive() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(3 * 86400),
            description: "Active window"
        )
        #expect(window.daysRemaining != nil)
        #expect(window.daysRemaining! >= 2)
    }

    @Test("daysRemaining returns nil when window is past")
    func testDaysRemainingNilWhenPast() {
        let window = PlantingWindow(
            startDate: Date().addingTimeInterval(-2 * 86400),
            endDate: Date().addingTimeInterval(-86400),
            description: "Past window"
        )
        #expect(window.daysRemaining == nil)
    }
}

@Suite("WeatherAlert and LocationError Tests")
struct WeatherAlertTests {

    @Test("WeatherAlert isExpired is true for past expiry date")
    func testWeatherAlertIsExpired() {
        let alert = WeatherAlert(
            type: .frost,
            title: "Frost Warning",
            message: "Temperatures dropping",
            severity: .high,
            expiryDate: Date().addingTimeInterval(-3600)
        )
        #expect(alert.isExpired == true)
    }

    @Test("WeatherAlert isExpired is false for future expiry date")
    func testWeatherAlertIsNotExpired() {
        let alert = WeatherAlert(
            type: .heat,
            title: "Heat Warning",
            message: "High temps expected",
            severity: .medium,
            expiryDate: Date().addingTimeInterval(3600)
        )
        #expect(alert.isExpired == false)
    }

    @Test("WeatherAlertType icon names are non-empty for all cases")
    func testWeatherAlertTypeIconNames() {
        for alertType in WeatherAlertType.allCases {
            #expect(!alertType.iconName.isEmpty, "Icon for \(alertType.rawValue) should not be empty")
        }
    }

    @Test("AlertSeverity raw values match expected strings")
    func testAlertSeverityRawValues() {
        #expect(AlertSeverity.low.rawValue == "low")
        #expect(AlertSeverity.medium.rawValue == "medium")
        #expect(AlertSeverity.high.rawValue == "high")
        #expect(AlertSeverity.critical.rawValue == "critical")
    }

    @Test("LocationError descriptions are non-empty for all cases")
    func testLocationErrorDescriptions() {
        #expect(LocationError.permissionDenied.errorDescription?.isEmpty == false)
        #expect(LocationError.locationUnavailable.errorDescription?.isEmpty == false)
        #expect(LocationError.networkError.errorDescription?.isEmpty == false)
        #expect(LocationError.weatherFetchFailed("test").errorDescription?.isEmpty == false)
        #expect(LocationError.unknown.errorDescription?.isEmpty == false)
    }

    @Test("weatherFetchFailed error description includes the provided message")
    func testWeatherFetchFailedIncludesMessage() {
        let error = LocationError.weatherFetchFailed("connection timed out")
        #expect(error.errorDescription?.contains("connection timed out") == true)
    }

    @Test("checkForWeatherAlerts returns empty when weatherData is nil")
    @MainActor
    func testNoWeatherDataReturnsEmptyAlerts() {
        let service = LocationService()
        // weatherData is nil by default
        let alerts = service.checkForWeatherAlerts()
        #expect(alerts.isEmpty)
    }
}
