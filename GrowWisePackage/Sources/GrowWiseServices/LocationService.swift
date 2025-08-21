import Foundation
import CoreLocation
import WeatherKit
import GrowWiseModels

@MainActor
public final class LocationService: NSObject, ObservableObject, Sendable {
    public static let shared = LocationService()
    
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var hardinessZone: String?
    @Published public var weatherData: WeatherData?
    @Published public var isLoading: Bool = false
    @Published public var error: LocationError?
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
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
    
    // MARK: - Hardiness Zone Calculation
    
    public func determineHardinessZone(for location: CLLocation) -> String {
        let latitude = location.coordinate.latitude
        let _ = location.coordinate.longitude
        
        // Simplified hardiness zone calculation based on latitude
        // This is a basic implementation - in production, you'd use more sophisticated data
        
        // US Hardiness Zones (approximate)
        if latitude >= 64.0 { return "1a" }
        else if latitude >= 60.0 { return "1b" }
        else if latitude >= 56.0 { return "2a" }
        else if latitude >= 52.0 { return "2b" }
        else if latitude >= 48.0 { return "3a" }
        else if latitude >= 44.0 { return "3b" }
        else if latitude >= 40.0 { return "4a" }
        else if latitude >= 36.0 { return "4b" }
        else if latitude >= 32.0 { return "5a" }
        else if latitude >= 28.0 { return "5b" }
        else if latitude >= 24.0 { return "6a" }
        else if latitude >= 20.0 { return "6b" }
        else if latitude >= 16.0 { return "7a" }
        else if latitude >= 12.0 { return "7b" }
        else if latitude >= 8.0 { return "8a" }
        else if latitude >= 4.0 { return "8b" }
        else if latitude >= 0.0 { return "9a" }
        else if latitude >= -4.0 { return "9b" }
        else if latitude >= -8.0 { return "10a" }
        else if latitude >= -12.0 { return "10b" }
        else if latitude >= -16.0 { return "11a" }
        else if latitude >= -20.0 { return "11b" }
        else if latitude >= -24.0 { return "12a" }
        else { return "12b" }
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
           minTemp <= 32.0 { // Fahrenheit
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
           maxTemp >= 95.0 { // Fahrenheit
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
           precipitation > 0.5 { // Inches
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
        
        currentLocation = location
        hardinessZone = determineHardinessZone(for: location)
        isLoading = false
        
        // Fetch weather data for the new location
        Task {
            await fetchWeatherData()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
            error = .permissionDenied
        case .notDetermined:
            break
        @unknown default:
            error = .unknown
        }
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
        self.fetchedAt = Date()
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
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
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
        self.createdAt = Date()
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
        case .frost: return "thermometer.snowflake"
        case .heat: return "thermometer.sun.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .drought: return "sun.max.fill"
        case .wind: return "wind"
        case .storm: return "cloud.bolt.fill"
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
            return "Location permission denied. Please enable location access in Settings."
        case .locationUnavailable:
            return "Unable to determine current location."
        case .networkError:
            return "Network error while fetching location data."
        case .weatherFetchFailed(let message):
            return "Failed to fetch weather data: \(message)"
        case .unknown:
            return "An unknown location error occurred."
        }
    }
}