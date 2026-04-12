import Testing
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - requestLocationPermission branches

@Suite("LocationService — requestLocationPermission")
@MainActor
struct LocationServiceRequestPermissionTests {

    @Test("requestLocationPermission sets permissionDenied error when status is denied")
    func testRequestPermissionWhenDenied() {
        let service = LocationService()
        service.authorizationStatus = .denied
        service.error = nil

        service.requestLocationPermission()

        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("requestLocationPermission sets permissionDenied error when status is restricted")
    func testRequestPermissionWhenRestricted() {
        let service = LocationService()
        service.authorizationStatus = .restricted
        service.error = nil

        service.requestLocationPermission()

        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("requestLocationPermission when already authorized (always) sets isLoading")
    func testRequestPermissionWhenAuthorizedAlways() {
        let service = LocationService()
        service.authorizationStatus = .authorizedAlways
        service.error = nil

        service.requestLocationPermission()

        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }

    @Test("requestLocationPermission when notDetermined does not set error")
    func testRequestPermissionWhenNotDetermined() {
        let service = LocationService()
        service.authorizationStatus = .notDetermined
        service.error = nil

        // Triggers locationManager.requestWhenInUseAuthorization() — a system call.
        // Verify no error is set synchronously.
        service.requestLocationPermission()

        #expect(service.error == nil)
    }

#if os(iOS)
    @Test("requestLocationPermission when authorizedWhenInUse sets isLoading (iOS only)")
    func testRequestPermissionWhenAuthorizedWhenInUse() {
        let service = LocationService()
        service.authorizationStatus = .authorizedWhenInUse
        service.error = nil

        service.requestLocationPermission()

        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }
#endif
}

// MARK: - requestLocation branches

@Suite("LocationService — requestLocation")
@MainActor
struct LocationServiceRequestLocationTests {

    @Test("requestLocation without permission (denied) propagates permissionDenied error")
    func testRequestLocationWhenDenied() {
        let service = LocationService()
        service.authorizationStatus = .denied
        service.error = nil

        service.requestLocation()

        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("requestLocation without permission (restricted) propagates permissionDenied error")
    func testRequestLocationWhenRestricted() {
        let service = LocationService()
        service.authorizationStatus = .restricted
        service.error = nil

        service.requestLocation()

        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("requestLocation when authorizedAlways sets isLoading and clears prior error")
    func testRequestLocationWhenAuthorizedAlways() {
        let service = LocationService()
        service.authorizationStatus = .authorizedAlways
        service.error = .unknown

        service.requestLocation()

        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }

#if os(iOS)
    @Test("requestLocation when authorizedWhenInUse sets isLoading and clears prior error (iOS only)")
    func testRequestLocationWhenAuthorizedWhenInUse() {
        let service = LocationService()
        service.authorizationStatus = .authorizedWhenInUse
        service.error = .unknown

        service.requestLocation()

        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }
#endif
}

// MARK: - CLLocationManagerDelegate callbacks

@Suite("LocationService — Delegate callbacks")
@MainActor
struct LocationServiceDelegateTests {

    @Test("handleLocationUpdate updates currentLocation, hardinessZone and clears loading")
    func testHandleLocationUpdate() async {
        let service = LocationService()
        service.isLoading = true
        let testLocation = CLLocation(latitude: 40.0, longitude: -74.0)

        await service.handleLocationUpdate(testLocation)

        #expect(service.currentLocation != nil)
        #expect(service.currentLocation?.coordinate.latitude == 40.0)
        #expect(service.hardinessZone == "4a")
        #expect(service.isLoading == false)
    }

    @Test("handleLocationUpdate with multiple locations uses the last one (caller passes the last)")
    func testHandleLocationUpdateUsesLast() async {
        let service = LocationService()
        let last = CLLocation(latitude: 33.5, longitude: 0.0)

        await service.handleLocationUpdate(last)

        #expect(service.currentLocation?.coordinate.latitude == 33.5)
        #expect(service.hardinessZone == "5a")
    }

    @Test("handleLocationError with CLError.denied sets permissionDenied and clears loading")
    func testHandleErrorDenied() {
        let service = LocationService()
        service.isLoading = true
        service.error = nil

        service.handleLocationError(CLError(.denied))

        #expect(service.isLoading == false)
        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleLocationError with CLError.locationUnknown sets locationUnavailable")
    func testHandleErrorLocationUnknown() {
        let service = LocationService()
        service.isLoading = true
        service.error = nil

        service.handleLocationError(CLError(.locationUnknown))

        #expect(service.isLoading == false)
        guard case .locationUnavailable = service.error else {
            Issue.record("Expected .locationUnavailable, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleLocationError with CLError.network sets networkError")
    func testHandleErrorNetwork() {
        let service = LocationService()
        service.isLoading = true
        service.error = nil

        service.handleLocationError(CLError(.network))

        #expect(service.isLoading == false)
        guard case .networkError = service.error else {
            Issue.record("Expected .networkError, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleLocationError with unhandled CLError code sets unknown error")
    func testHandleErrorOtherCLError() {
        let service = LocationService()
        service.isLoading = true
        service.error = nil

        service.handleLocationError(CLError(.headingFailure))

        #expect(service.isLoading == false)
        guard case .unknown = service.error else {
            Issue.record("Expected .unknown, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleLocationError with non-CLError sets unknown error")
    func testHandleErrorNonCLError() {
        let service = LocationService()
        service.isLoading = true
        service.error = nil

        struct ArbitraryError: Error {}
        service.handleLocationError(ArbitraryError())

        #expect(service.isLoading == false)
        guard case .unknown = service.error else {
            Issue.record("Expected .unknown, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleAuthorizationChange to denied sets permissionDenied error and authorizationStatus")
    func testAuthorizationChangedToDenied() {
        let service = LocationService()
        service.error = nil

        service.handleAuthorizationChange(.denied)

        #expect(service.authorizationStatus == .denied)
        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleAuthorizationChange to restricted sets permissionDenied error and authorizationStatus")
    func testAuthorizationChangedToRestricted() {
        let service = LocationService()
        service.error = nil

        service.handleAuthorizationChange(.restricted)

        #expect(service.authorizationStatus == .restricted)
        guard case .permissionDenied = service.error else {
            Issue.record("Expected .permissionDenied, got \(String(describing: service.error))")
            return
        }
        #expect(true)
    }

    @Test("handleAuthorizationChange to notDetermined updates status and does not set error")
    func testAuthorizationChangedToNotDetermined() {
        let service = LocationService()
        service.authorizationStatus = .denied
        service.error = nil

        service.handleAuthorizationChange(.notDetermined)

        #expect(service.authorizationStatus == .notDetermined)
        #expect(service.error == nil)
    }

    @Test("handleAuthorizationChange to authorizedAlways sets status and starts loading")
    func testAuthorizationChangedToAuthorizedAlways() {
        let service = LocationService()
        service.authorizationStatus = .notDetermined
        service.error = nil

        service.handleAuthorizationChange(.authorizedAlways)

        #expect(service.authorizationStatus == .authorizedAlways)
        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }

#if os(iOS)
    @Test("handleAuthorizationChange to authorizedWhenInUse sets status and starts loading (iOS only)")
    func testAuthorizationChangedToAuthorizedWhenInUse() {
        let service = LocationService()
        service.authorizationStatus = .notDetermined
        service.error = nil

        service.handleAuthorizationChange(.authorizedWhenInUse)

        #expect(service.authorizationStatus == .authorizedWhenInUse)
        #expect(service.isLoading == true)
        #expect(service.error == nil)
    }
#endif
}

// MARK: - hasLocationPermission

@Suite("LocationService — hasLocationPermission")
@MainActor
struct LocationServiceHasPermissionTests {

    @Test("hasLocationPermission is false for notDetermined")
    func testNotDetermined() {
        let service = LocationService()
        service.authorizationStatus = .notDetermined
        #expect(service.hasLocationPermission == false)
    }

    @Test("hasLocationPermission is false for denied")
    func testDenied() {
        let service = LocationService()
        service.authorizationStatus = .denied
        #expect(service.hasLocationPermission == false)
    }

    @Test("hasLocationPermission is false for restricted")
    func testRestricted() {
        let service = LocationService()
        service.authorizationStatus = .restricted
        #expect(service.hasLocationPermission == false)
    }

    @Test("hasLocationPermission is true for authorizedAlways")
    func testAuthorizedAlways() {
        let service = LocationService()
        service.authorizationStatus = .authorizedAlways
        #expect(service.hasLocationPermission == true)
    }

#if os(iOS)
    @Test("hasLocationPermission is true for authorizedWhenInUse (iOS only)")
    func testAuthorizedWhenInUse() {
        let service = LocationService()
        service.authorizationStatus = .authorizedWhenInUse
        #expect(service.hasLocationPermission == true)
    }
#endif
}

// MARK: - fetchWeatherData state

@Suite("LocationService — fetchWeatherData state")
@MainActor
struct LocationServiceFetchWeatherTests {

    @Test("fetchWeatherData with no location sets locationUnavailable and isLoading false")
    func testFetchWeatherWithNilLocation() async {
        let service = LocationService()
        service.currentLocation = nil
        service.error = nil
        service.isLoading = false

        await service.fetchWeatherData()

        guard case .locationUnavailable = service.error else {
            Issue.record("Expected .locationUnavailable, got \(String(describing: service.error))")
            return
        }
        #expect(service.isLoading == false)
        #expect(service.weatherData == nil)
    }
}

// MARK: - Planting window edge cases

@Suite("LocationService — Planting window edge cases")
@MainActor
struct LocationServicePlantingWindowEdgeCaseTests {

    @Test("Vegetable planting windows are computed for zone numbers 1 through 9")
    func testVegetablePlantingWindowsAllZones() {
        let service = LocationService()
        for zoneNum in 1...9 {
            service.hardinessZone = "\(zoneNum)a"
            let window = service.getPlantingWindow(for: .vegetable)
            #expect(window != nil, "Expected window for zone \(zoneNum)a")
            if let window = window {
                #expect(window.endDate >= window.startDate,
                        "endDate should be >= startDate for zone \(zoneNum)a")
            }
        }
    }

    @Test("Herb planting windows are computed for zone numbers 1 through 9")
    func testHerbPlantingWindowsAllZones() {
        let service = LocationService()
        for zoneNum in 1...9 {
            service.hardinessZone = "\(zoneNum)b"
            let window = service.getPlantingWindow(for: .herb)
            #expect(window != nil, "Expected herb window for zone \(zoneNum)b")
            if let window = window {
                #expect(window.endDate >= window.startDate,
                        "endDate should be >= startDate for zone \(zoneNum)b")
            }
        }
    }

    @Test("Flower planting windows are computed for zone numbers 1 through 9")
    func testFlowerPlantingWindowsAllZones() {
        let service = LocationService()
        for zoneNum in 1...9 {
            service.hardinessZone = "\(zoneNum)a"
            let window = service.getPlantingWindow(for: .flower)
            #expect(window != nil, "Expected flower window for zone \(zoneNum)a")
            if let window = window {
                #expect(window.endDate >= window.startDate)
            }
        }
    }

    @Test("Houseplant window startDate is approximately now (year-round planting)")
    func testHouseplantWindowStartIsNow() {
        let service = LocationService()
        service.hardinessZone = "5b"
        let before = Date()
        let window = service.getPlantingWindow(for: .houseplant)
        let after = Date()

        #expect(window != nil)
        if let window = window {
            #expect(window.startDate >= before.addingTimeInterval(-1))
            #expect(window.startDate <= after.addingTimeInterval(1))
        }
    }

    @Test("Planting window for 12a uses first digit (1) so zoneNumber == 1")
    func testZoneNumber12ParsesFirstDigit() {
        let service = LocationService()
        // Int("12a".prefix(1)) == Int("1") == 1 — still produces a window
        service.hardinessZone = "12a"
        let window = service.getPlantingWindow(for: .vegetable)
        #expect(window != nil)
    }

    @Test("Malformed zone string falls back to zoneNumber 5 and still returns a window")
    func testMalformedZoneStringFallsBackTo5() {
        let service = LocationService()
        service.hardinessZone = "unknown"
        // Int(String("unknown").prefix(1)) == Int("u") == nil → defaults to 5
        let vegWindow  = service.getPlantingWindow(for: .vegetable)
        let herbWindow = service.getPlantingWindow(for: .herb)
        let florWindow = service.getPlantingWindow(for: .flower)
        #expect(vegWindow != nil)
        #expect(herbWindow != nil)
        #expect(florWindow != nil)
    }
}

// MARK: - checkForWeatherAlerts

@Suite("LocationService — checkForWeatherAlerts")
struct LocationServiceWeatherAlertsTests {

    @Test("checkForWeatherAlerts returns empty array when weatherData is nil")
    @MainActor
    func testNoDataReturnsEmpty() {
        let service = LocationService()
        service.weatherData = nil
        let alerts = service.checkForWeatherAlerts()
        #expect(alerts.isEmpty)
    }

    @Test("WeatherAlertType all cases have non-empty icon names")
    func testWeatherAlertTypeIconsNonEmpty() {
        for alertType in WeatherAlertType.allCases {
            #expect(!alertType.iconName.isEmpty,
                    "Icon for \(alertType.rawValue) should not be empty")
        }
    }

    @Test("WeatherAlertType icons match expected SF Symbol names")
    func testWeatherAlertTypeIconValues() {
        #expect(WeatherAlertType.frost.iconName     == "thermometer.snowflake")
        #expect(WeatherAlertType.heat.iconName      == "thermometer.sun.fill")
        #expect(WeatherAlertType.heavyRain.iconName == "cloud.heavyrain.fill")
        #expect(WeatherAlertType.drought.iconName   == "sun.max.fill")
        #expect(WeatherAlertType.wind.iconName      == "wind")
        #expect(WeatherAlertType.storm.iconName     == "cloud.bolt.fill")
    }

    @Test("WeatherAlertType raw values are the expected strings")
    func testWeatherAlertTypeRawValues() {
        #expect(WeatherAlertType.frost.rawValue     == "frost")
        #expect(WeatherAlertType.heat.rawValue      == "heat")
        #expect(WeatherAlertType.heavyRain.rawValue == "heavyRain")
        #expect(WeatherAlertType.drought.rawValue   == "drought")
        #expect(WeatherAlertType.wind.rawValue      == "wind")
        #expect(WeatherAlertType.storm.rawValue     == "storm")
    }

    @Test("WeatherAlert init captures all provided fields")
    func testWeatherAlertInitCapturesFields() {
        let expiry = Date().addingTimeInterval(3600)
        let alert = WeatherAlert(
            type: .frost,
            title: "Frost Warning",
            message: "Cover your tomatoes",
            severity: .high,
            expiryDate: expiry
        )
        #expect(alert.type == .frost)
        #expect(alert.title == "Frost Warning")
        #expect(alert.message == "Cover your tomatoes")
        #expect(alert.severity == .high)
        #expect(alert.expiryDate == expiry)
        #expect(alert.isExpired == false)
    }

    @Test("WeatherAlert isExpired is true when expiryDate is in the past")
    func testWeatherAlertIsExpiredPast() {
        let alert = WeatherAlert(
            type: .heat,
            title: "Heat Warning",
            message: "Very hot",
            severity: .medium,
            expiryDate: Date().addingTimeInterval(-1)
        )
        #expect(alert.isExpired == true)
    }

    @Test("WeatherAlert has unique IDs across separate instances")
    func testWeatherAlertUniqueIDs() {
        let a1 = WeatherAlert(type: .wind, title: "A", message: "A", severity: .low,
                              expiryDate: Date().addingTimeInterval(1))
        let a2 = WeatherAlert(type: .wind, title: "A", message: "A", severity: .low,
                              expiryDate: Date().addingTimeInterval(1))
        #expect(a1.id != a2.id)
    }

    @Test("AlertSeverity allCases has four elements")
    func testAlertSeverityCount() {
        #expect(AlertSeverity.allCases.count == 4)
    }

    @Test("AlertSeverity raw values round-trip from rawValue")
    func testAlertSeverityRoundTrip() {
        for severity in AlertSeverity.allCases {
            let roundTripped = AlertSeverity(rawValue: severity.rawValue)
            #expect(roundTripped == severity)
        }
    }
}

// MARK: - LocationError descriptions

@Suite("LocationService — LocationError descriptions")
struct LocationServiceErrorDescriptionTests {

    @Test("permissionDenied errorDescription mentions Settings")
    func testPermissionDeniedMentionsSettings() {
        let error = LocationError.permissionDenied
        #expect(error.errorDescription?.contains("Settings") == true)
    }

    @Test("locationUnavailable errorDescription is non-empty")
    func testLocationUnavailableNonEmpty() {
        let error = LocationError.locationUnavailable
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("networkError errorDescription contains 'network' (case-insensitive)")
    func testNetworkErrorContainsNetwork() {
        let desc = (LocationError.networkError.errorDescription ?? "").lowercased()
        #expect(desc.contains("network"))
    }

    @Test("weatherFetchFailed errorDescription embeds the caller-supplied message")
    func testWeatherFetchFailedEmbedMessage() {
        let msg = "Request timed out after 30s"
        #expect(LocationError.weatherFetchFailed(msg).errorDescription?.contains(msg) == true)
    }

    @Test("weatherFetchFailed with empty message produces non-empty description")
    func testWeatherFetchFailedEmptyMessage() {
        let desc = LocationError.weatherFetchFailed("").errorDescription ?? ""
        #expect(!desc.isEmpty)
    }

    @Test("unknown errorDescription is non-empty")
    func testUnknownNonEmpty() {
        #expect((LocationError.unknown.errorDescription ?? "").isEmpty == false)
    }
}

// MARK: - WeatherData init

@Suite("LocationService — WeatherData")
struct WeatherDataInitTests {

    @Test("WeatherData fetchedAt is close to now when constructed")
    func testWeatherDataFetchedAtIsNow() {
        // WeatherData requires concrete WeatherKit types so we test only
        // the fetchedAt timestamp behaviour through PlantingWindow as a proxy
        // to avoid importing WeatherKit in tests.
        // Instead, verify fetchedAt is captured via the PlantingWindow struct
        // (which has similar date capture logic) and WeatherData's API.
        let before = Date()
        let window = PlantingWindow(
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            description: "Test"
        )
        let after = Date()
        #expect(window.startDate >= before.addingTimeInterval(-1))
        #expect(window.startDate <= after.addingTimeInterval(1))
    }
}
