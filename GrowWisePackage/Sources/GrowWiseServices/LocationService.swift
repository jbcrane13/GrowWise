import CoreLocation
import Foundation
import GrowWiseModels
import WeatherKit

/// Location and weather service using @Observable pattern
/// Access via @Environment(LocationService.self) in views
/// Singleton pattern removed - injected via environment
@MainActor
@Observable
public final class LocationService: NSObject {
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public var currentLocation: CLLocation?
    public var hardinessZone: String?
    public var weatherData: WeatherData?
    public var isLoading: Bool = false
    public var error: LocationError?
    public var hasLocationPermission: Bool {
        #if os(iOS)
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #elseif os(macOS)
        authorizationStatus == .authorizedAlways
        #else
        false
        #endif
    }

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared

    override public init() {
        super.init()
        locationManager.delegate = self
        // Hardiness zones span ~100 km bands; kilometer accuracy is sufficient and saves battery
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permission Management

    public func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            error = .permissionDenied

        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()

        @unknown default:
            error = .unknown
        }
    }

    public func requestLocation() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        #elseif os(macOS)
        guard authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        #endif

        isLoading = true
        error = nil
        locationManager.requestLocation()
    }

    private func startLocationUpdates() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        #elseif os(macOS)
        guard authorizationStatus == .authorizedAlways else {
            return
        }
        #endif

        isLoading = true
        locationManager.requestLocation()
    }

    // MARK: - Synchronous Handlers (for testing)

    /// Synchronous handler for location updates. Called by delegate method but exposed for testing.
    public func handleLocationUpdate(_ location: CLLocation) async {
        currentLocation = location
        hardinessZone = determineHardinessZone(for: location)
        isLoading = false
        await fetchWeatherData()
    }

    /// Synchronous handler for location errors. Called by delegate method but exposed for testing.
    public func handleLocationError(_ error: Error) {
        isLoading = false

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                self.error = .permissionDenied

            case .locationUnknown:
                self.error = .locationUnavailable

            case .network:
                self.error = .networkError

            default:
                self.error = .unknown
            }
        } else {
            self.error = .unknown
        }
    }

    /// Synchronous handler for authorization changes. Called by delegate method but exposed for testing.
    public func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status

        switch status {
        #if os(iOS)
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        #elseif os(macOS)
        case .authorizedAlways:
            startLocationUpdates()
        #endif

        case .denied, .restricted:
            self.error = .permissionDenied

        case .notDetermined:
            break

        @unknown default:
            self.error = .unknown
        }
    }

    // MARK: - Hardiness Zone Calculation

    // swiftlint:disable:next cyclomatic_complexity
    public func determineHardinessZone(for location: CLLocation) -> String {
        let latitude = location.coordinate.latitude
        _ = location.coordinate.longitude

        // Simplified hardiness zone calculation based on latitude
        // This is a basic implementation - in production, you'd use more sophisticated data

        // US Hardiness Zones (approximate, latitude-based)
        return switch latitude {
        case 64.0...: "1a"
        case 60.0 ..< 64.0: "1b"
        case 56.0 ..< 60.0: "2a"
        case 52.0 ..< 56.0: "2b"
        case 48.0 ..< 52.0: "3a"
        case 44.0 ..< 48.0: "3b"
        case 40.0 ..< 44.0: "4a"
        case 36.0 ..< 40.0: "4b"
        case 32.0 ..< 36.0: "5a"
        case 28.0 ..< 32.0: "5b"
        case 24.0 ..< 28.0: "6a"
        case 20.0 ..< 24.0: "6b"
        case 16.0 ..< 20.0: "7a"
        case 12.0 ..< 16.0: "7b"
        case 8.0 ..< 12.0: "8a"
        case 4.0 ..< 8.0: "8b"
        case 0.0 ..< 4.0: "9a"
        case -4.0 ..< 0.0: "9b"
        case -8.0 ..< -4.0: "10a"
        case -12.0 ..< -8.0: "10b"
        case -16.0 ..< -12.0: "11a"
        case -20.0 ..< -16.0: "11b"
        case -24.0 ..< -20.0: "12a"
        default: "12b"
        }
    }

    // MARK: - Weather Integration

    public func fetchWeatherData() async {
        guard let location = currentLocation else {
            error = .locationUnavailable
            return
        }

        do {
            isLoading = true
            let weather = try await weatherService.weather(for: location)

            let currentWeather = weather.currentWeather
            let hourlyForecast = Array(weather.hourlyForecast.prefix(24))
            let dailyForecast = Array(weather.dailyForecast.prefix(10))

            weatherData = WeatherData(
                current: currentWeather,
                hourly: hourlyForecast,
                daily: dailyForecast,
                location: location
            )

            isLoading = false
        } catch {
            self.error = .weatherFetchFailed(error.localizedDescription)
            isLoading = false
        }
    }

    // MARK: - Planting Recommendations

    public func getPlantingWindow(for plantType: PlantType) -> PlantingWindow? {
        guard let zone = hardinessZone else { return nil }

        // Basic planting windows based on hardiness zones
        // In production, this would be a comprehensive database

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        switch plantType {
        case .vegetable:
            return getVegetablePlantingWindow(zone: zone, year: currentYear)

        case .herb:
            return getHerbPlantingWindow(zone: zone, year: currentYear)

        case .flower:
            return getFlowerPlantingWindow(zone: zone, year: currentYear)

        case .houseplant:
            return PlantingWindow(
                startDate: Date(), // Year-round for houseplants
                endDate: calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                description: "Year-round planting for houseplants"
            )

        default:
            return nil
        }
    }

    private func getVegetablePlantingWindow(zone: String, year: Int) -> PlantingWindow {
        let calendar = Calendar.current

        // Simplified logic - varies by specific vegetables and zone
        let zoneNumber = Int(zone.prefix(1)) ?? 5

        let startMonth = max(3, 6 - zoneNumber) // Earlier in warmer zones
        let endMonth = min(6, startMonth + 2)

        let startDate = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let endDate = calendar.date(from: DateComponents(year: year, month: endMonth, day: 30)) ?? Date()

        return PlantingWindow(
            startDate: startDate,
            endDate: endDate,
            description: "Optimal vegetable planting window for zone \(zone)"
        )
    }

    private func getHerbPlantingWindow(zone: String, year: Int) -> PlantingWindow {
        let calendar = Calendar.current

        // Herbs generally have a longer planting season
        let zoneNumber = Int(zone.prefix(1)) ?? 5

        let startMonth = max(2, 5 - zoneNumber)
        let endMonth = min(9, startMonth + 4)

        let startDate = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let endDate = calendar.date(from: DateComponents(year: year, month: endMonth, day: 30)) ?? Date()

        return PlantingWindow(
            startDate: startDate,
            endDate: endDate,
            description: "Herb planting season for zone \(zone)"
        )
    }

    private func getFlowerPlantingWindow(zone: String, year: Int) -> PlantingWindow {
        let calendar = Calendar.current

        let zoneNumber = Int(zone.prefix(1)) ?? 5

        let startMonth = max(3, 6 - zoneNumber)
        let endMonth = min(8, startMonth + 3)

        let startDate = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let endDate = calendar.date(from: DateComponents(year: year, month: endMonth, day: 30)) ?? Date()

        return PlantingWindow(
            startDate: startDate,
            endDate: endDate,
            description: "Flower planting season for zone \(zone)"
        )
    }

    // MARK: - Weather Alerts

    public func checkForWeatherAlerts() -> [WeatherAlert] {
        guard let weather = weatherData else { return [] }

        var alerts: [WeatherAlert] = []

        // Frost warning
        if let minTemp = weather.daily.first?.lowTemperature.value,
           minTemp <= 32.0
        { // Fahrenheit
            alerts.append(WeatherAlert(
                type: .frost,
                title: "Frost Warning",
                message: "Temperatures expected to drop to \(Int(minTemp))°F. Protect sensitive plants.",
                severity: .high,
                expiryDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ))
        }

        // Heat warning
        if let maxTemp = weather.daily.first?.highTemperature.value,
           maxTemp >= 95.0
        { // Fahrenheit
            alerts.append(WeatherAlert(
                type: .heat,
                title: "Heat Warning",
                message: "High temperatures expected (\(Int(maxTemp))°F). Increase watering frequency.",
                severity: .medium,
                expiryDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ))
        }

        // Heavy rain
        if let precipitation = weather.daily.first?.precipitationAmount.value,
           precipitation > 0.5
        { // Inches
            alerts.append(WeatherAlert(
                type: .heavyRain,
                title: "Heavy Rain Expected",
                message: "Heavy rainfall expected (\(String(format: "%.1f", precipitation)) inches). Check drainage.",
                severity: .medium,
                expiryDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ))
        }

        return alerts
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { [weak self] in
            await self?.handleLocationUpdate(location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        handleLocationError(error)
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange(status)
    }
}

// MARK: - Supporting Types

public struct WeatherData: Sendable {
    public let current: CurrentWeather
    public let hourly: [HourWeather]
    public let daily: [DayWeather]
    public let location: CLLocation
    public let fetchedAt: Date

    public init(current: CurrentWeather, hourly: [HourWeather], daily: [DayWeather], location: CLLocation) {
        self.current = current
        self.hourly = hourly
        self.daily = daily
        self.location = location
        fetchedAt = Date()
    }
}

public struct PlantingWindow: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let description: String

    public var isCurrentlyOptimal: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    public var daysUntilStart: Int? {
        let now = Date()
        guard now < startDate else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: startDate).day
    }

    public var daysRemaining: Int? {
        let now = Date()
        guard now <= endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: endDate).day
    }
}

public enum AlertSeverity: String, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical
}

public struct WeatherAlert: Sendable, Identifiable {
    public let id = UUID()
    public let type: WeatherAlertType
    public let title: String
    public let message: String
    public let severity: AlertSeverity
    public let expiryDate: Date
    public let createdAt: Date

    public init(type: WeatherAlertType, title: String, message: String, severity: AlertSeverity, expiryDate: Date) {
        self.type = type
        self.title = title
        self.message = message
        self.severity = severity
        self.expiryDate = expiryDate
        createdAt = Date()
    }

    public var isExpired: Bool {
        Date() > expiryDate
    }
}

public enum WeatherAlertType: String, CaseIterable, Sendable {
    case frost
    case heat
    case heavyRain
    case drought
    case wind
    case storm

    public var iconName: String {
        switch self {
        case .frost: "thermometer.snowflake"
        case .heat: "thermometer.sun.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .drought: "sun.max.fill"
        case .wind: "wind"
        case .storm: "cloud.bolt.fill"
        }
    }
}

public enum LocationError: LocalizedError, Sendable {
    case permissionDenied
    case locationUnavailable
    case networkError
    case weatherFetchFailed(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Location permission denied. Please enable location access in Settings."

        case .locationUnavailable:
            "Unable to determine current location."

        case .networkError:
            "Network error while fetching location data."

        case .weatherFetchFailed(let message):
            "Failed to fetch weather data: \(message)"

        case .unknown:
            "An unknown location error occurred."
        }
    }
}
