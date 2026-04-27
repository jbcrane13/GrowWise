import Foundation
@testable import GrowWiseServices
import Testing

// MARK: - LocalizationService Tests

@Suite("LocalizationService Tests")
@MainActor
struct LocalizationServiceTests {
    // MARK: - UserDefaults Cleanup

    private static let measurementSystemKey = "growwise_preferred_measurement_system"

    init() {
        // Remove any stored preference so each test starts from a clean state.
        UserDefaults.standard.removeObject(forKey: Self.measurementSystemKey)
    }

    // MARK: - MeasurementSystem Enum

    @Test("MeasurementSystem has metric and imperial cases")
    func measurementSystemHasBothCases() {
        let allCases = LocalizationService.MeasurementSystem.allCases
        #expect(allCases.contains(.metric))
        #expect(allCases.contains(.imperial))
        #expect(allCases.count == 2)
    }

    @Test("MeasurementSystem rawValues are correct strings")
    func measurementSystemRawValues() {
        #expect(LocalizationService.MeasurementSystem.metric.rawValue == "metric")
        #expect(LocalizationService.MeasurementSystem.imperial.rawValue == "imperial")
    }

    // MARK: - Formatting — Non-Empty Output

    @Test("formatTemperature returns non-empty string for 72°F")
    func formatTemperatureNonEmpty() {
        let service = LocalizationService()
        let result = service.formatTemperature(72)
        #expect(!result.isEmpty)
    }

    @Test("formatLength returns non-empty string for 12 inches")
    func formatLengthNonEmpty() {
        let service = LocalizationService()
        let result = service.formatLength(12)
        #expect(!result.isEmpty)
    }

    @Test("formatVolume returns non-empty string for 1.5 gallons")
    func formatVolumeNonEmpty() {
        let service = LocalizationService()
        let result = service.formatVolume(1.5)
        #expect(!result.isEmpty)
    }

    // MARK: - Zero Values

    @Test("formatTemperature with zero value returns non-empty string")
    func formatTemperatureZero() {
        let service = LocalizationService()
        let result = service.formatTemperature(0)
        #expect(!result.isEmpty)
    }

    @Test("formatLength with zero value returns non-empty string")
    func formatLengthZero() {
        let service = LocalizationService()
        let result = service.formatLength(0)
        #expect(!result.isEmpty)
    }

    @Test("formatVolume with zero value returns non-empty string")
    func formatVolumeZero() {
        let service = LocalizationService()
        let result = service.formatVolume(0)
        #expect(!result.isEmpty)
    }

    // MARK: - UserDefaults Persistence

    @Test("Setting preferredSystem to metric persists to UserDefaults")
    func setPreferredSystemMetricPersists() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        let stored = UserDefaults.standard.string(forKey: Self.measurementSystemKey)
        #expect(stored == LocalizationService.MeasurementSystem.metric.rawValue)
    }

    @Test("Setting preferredSystem to imperial persists to UserDefaults")
    func setPreferredSystemImperialPersists() {
        let service = LocalizationService()
        service.preferredSystem = .imperial
        let stored = UserDefaults.standard.string(forKey: Self.measurementSystemKey)
        #expect(stored == LocalizationService.MeasurementSystem.imperial.rawValue)
    }

    @Test("preferredSystem reads back the value that was written")
    func preferredSystemRoundTrip() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        #expect(service.preferredSystem == .metric)

        service.preferredSystem = .imperial
        #expect(service.preferredSystem == .imperial)
    }

    // MARK: - Temperature Conversion

    @Test("32°F formats near 0°C in metric")
    func temperature32FIsNear0CInMetric() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        let result = service.formatTemperature(32)
        // Output should contain "0" — formatted as "0 °C" or similar
        #expect(result.contains("0"))
    }

    @Test("212°F formats near 100°C in metric")
    func temperature212FIsNear100CInMetric() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        let result = service.formatTemperature(212)
        // Output should contain "100"
        #expect(result.contains("100"))
    }

    @Test("72°F is returned as-is in imperial (no conversion)")
    func temperature72FImperial() {
        let service = LocalizationService()
        service.preferredSystem = .imperial
        let result = service.formatTemperature(72)
        #expect(result.contains("72"))
    }

    // MARK: - Length Conversion

    @Test("1 inch formats near 2.5 cm in metric")
    func length1InchIsNear2Point5cmInMetric() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        let result = service.formatLength(1)
        // 1 inch = 2.54 cm, formatted with 1 decimal → "2.5 cm"
        #expect(result.contains("2.5"))
    }

    @Test("1 inch is returned as-is in imperial (no conversion)")
    func length1InchImperial() {
        let service = LocalizationService()
        service.preferredSystem = .imperial
        let result = service.formatLength(1)
        #expect(result.contains("1"))
    }

    // MARK: - Volume Conversion

    @Test("1 gallon formats near 3.8 liters in metric")
    func volume1GallonIsNear3Point8LitersInMetric() {
        let service = LocalizationService()
        service.preferredSystem = .metric
        let result = service.formatVolume(1)
        // 1 US gallon = 3.785 L, formatted with 1 decimal → "3.8 L"
        #expect(result.contains("3.8"))
    }

    @Test("1 gallon is returned as-is in imperial (no conversion)")
    func volume1GallonImperial() {
        let service = LocalizationService()
        service.preferredSystem = .imperial
        let result = service.formatVolume(1)
        #expect(result.contains("1"))
    }
}
