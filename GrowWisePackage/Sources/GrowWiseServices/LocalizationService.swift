import Foundation

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes

/// Service for managing measurement unit preferences and locale-aware formatting.
///
/// Provides temperature, length, and volume formatting that respects
/// the user's preferred measurement system (metric or imperial).
@MainActor @Observable public final class LocalizationService {
    // MARK: - Types

    public enum MeasurementSystem: String, CaseIterable, Codable, Sendable {
        /// Celsius, centimeters, liters
        case metric
        /// Fahrenheit, inches, gallons
        case imperial
    }

    // MARK: - Storage Keys

    private static let measurementSystemKey = "growwise_preferred_measurement_system"

    // MARK: - Properties

    /// The user's preferred measurement system.
    /// Defaults to the system locale preference (metric for most locales, imperial for US/UK).
    public var preferredSystem: MeasurementSystem {
        get {
            if let stored = UserDefaults.standard.string(forKey: Self.measurementSystemKey),
               let system = MeasurementSystem(rawValue: stored)
            {
                return system
            }
            return Self.defaultSystem
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.measurementSystemKey)
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Temperature Formatting

    /// Formats a temperature value for display.
    /// - Parameter fahrenheit: Temperature in Fahrenheit.
    /// - Returns: A formatted string with the appropriate unit (e.g., "72 F" or "22 C").
    public func formatTemperature(_ fahrenheit: Double) -> String {
        switch preferredSystem {
        case .imperial:
            let measurement = Measurement(value: fahrenheit, unit: UnitTemperature.fahrenheit)
            return Self.temperatureFormatter.string(from: measurement)

        case .metric:
            let measurement = Measurement(value: fahrenheit, unit: UnitTemperature.fahrenheit)
            let celsius = measurement.converted(to: .celsius)
            return Self.temperatureFormatter.string(from: celsius)
        }
    }

    /// Formats a length value for display.
    /// - Parameter inches: Length in inches.
    /// - Returns: A formatted string with the appropriate unit (e.g., "12 in" or "30.5 cm").
    public func formatLength(_ inches: Double) -> String {
        switch preferredSystem {
        case .imperial:
            let measurement = Measurement(value: inches, unit: UnitLength.inches)
            return Self.lengthFormatter.string(from: measurement)

        case .metric:
            let measurement = Measurement(value: inches, unit: UnitLength.inches)
            let cm = measurement.converted(to: .centimeters)
            return Self.lengthFormatter.string(from: cm)
        }
    }

    /// Formats a volume value for display.
    /// - Parameter gallons: Volume in gallons.
    /// - Returns: A formatted string with the appropriate unit (e.g., "1.5 gal" or "5.7 L").
    public func formatVolume(_ gallons: Double) -> String {
        switch preferredSystem {
        case .imperial:
            let measurement = Measurement(value: gallons, unit: UnitVolume.gallons)
            return Self.volumeFormatter.string(from: measurement)

        case .metric:
            let measurement = Measurement(value: gallons, unit: UnitVolume.gallons)
            let liters = measurement.converted(to: .liters)
            return Self.volumeFormatter.string(from: liters)
        }
    }

    // MARK: - Private Helpers

    private static var defaultSystem: MeasurementSystem {
        let usesMetric = Locale.current.measurementSystem == .metric
        return usesMetric ? .metric : .imperial
    }

    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let lengthFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let volumeFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()
}

// swiftlint:enable attributes
