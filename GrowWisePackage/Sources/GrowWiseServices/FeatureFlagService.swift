import Foundation
import os

// MARK: - Feature Flags

/// Defines all feature flags for GrowWise.
/// Add new flags here before using them in code.
/// Flags can be enabled per-environment (debug/release) or remotely via remote config.
public enum FeatureFlag: String, CaseIterable, Sendable {
    // MARK: - Gardening Features
    case companionPlantingV2 = "companion_planting_v2"
    case plantHealthDiagnostics = "plant_health_diagnostics"
    case weatherIntegration = "weather_integration"
    case gardenCalendar = "garden_calendar"

    // MARK: - Journal Features
    case journalPhotoEnhancement = "journal_photo_enhancement"
    case journalMarkdown = "journal_markdown"

    // MARK: - Social / Sharing
    case gardenSharing = "garden_sharing"

    // MARK: - Premium / Subscription
    case premiumAnalytics = "premium_analytics"

    // MARK: - Developer / Debug
    case debugOverlay = "debug_overlay"
    case mockData = "mock_data"

    /// Default value when no override is configured
    var defaultValue: Bool {
        switch self {
        case .companionPlantingV2: return true
        case .plantHealthDiagnostics: return false
        case .weatherIntegration: return false
        case .gardenCalendar: return false
        case .journalPhotoEnhancement: return true
        case .journalMarkdown: return false
        case .gardenSharing: return false
        case .premiumAnalytics: return false
        case .debugOverlay: return false
        case .mockData: return false
        }
    }
}

// MARK: - FeatureFlagService

/// Manages feature flag evaluation for GrowWise.
///
/// Features can be toggled via:
/// 1. Default values defined in `FeatureFlag.defaultValue`
/// 2. UserDefaults overrides (for QA and developer testing)
/// 3. Remote configuration (future: CloudKit-backed remote config)
///
/// Usage:
/// ```swift
/// if FeatureFlagService.shared.isEnabled(.journalMarkdown) {
///     // show markdown editor
/// }
/// ```
@MainActor
@Observable
public final class FeatureFlagService {
    public static let shared = FeatureFlagService()

    private let logger = Logger(subsystem: "com.growwise", category: "FeatureFlags")
    private let userDefaults: UserDefaults
    private let overrideKeyPrefix = "feature_flag_override_"

    // Remote configuration store (CloudKit-backed, future)
    private var remoteFlags: [String: Bool] = [:]

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public API

    /// Returns whether a feature flag is enabled.
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        // 1. Check for developer override (UserDefaults)
        let overrideKey = overrideKeyPrefix + flag.rawValue
        if userDefaults.object(forKey: overrideKey) != nil {
            let override = userDefaults.bool(forKey: overrideKey)
            logger.debug("Flag '\(flag.rawValue, privacy: .public)' overridden to \(override, privacy: .public)")
            return override
        }

        // 2. Check remote configuration
        if let remoteValue = remoteFlags[flag.rawValue] {
            return remoteValue
        }

        // 3. Fall back to default
        return flag.defaultValue
    }

    /// Override a flag for development/testing purposes.
    /// Call with `nil` to remove the override and return to default.
    public func setOverride(_ flag: FeatureFlag, enabled: Bool?) {
        let overrideKey = overrideKeyPrefix + flag.rawValue
        if let enabled {
            userDefaults.set(enabled, forKey: overrideKey)
            logger.info("Flag '\(flag.rawValue, privacy: .public)' override set to \(enabled, privacy: .public)")
        } else {
            userDefaults.removeObject(forKey: overrideKey)
            logger.info("Flag '\(flag.rawValue, privacy: .public)' override removed")
        }
    }

    /// Returns the current state of all flags (for diagnostics/debug overlay).
    public func allFlags() -> [(flag: FeatureFlag, enabled: Bool, source: FlagSource)] {
        FeatureFlag.allCases.map { flag in
            let overrideKey = overrideKeyPrefix + flag.rawValue
            if userDefaults.object(forKey: overrideKey) != nil {
                return (flag, userDefaults.bool(forKey: overrideKey), .override)
            }
            if remoteFlags[flag.rawValue] != nil {
                return (flag, remoteFlags[flag.rawValue]!, .remote)
            }
            return (flag, flag.defaultValue, .default)
        }
    }

    // MARK: - Remote Config (Future CloudKit integration)

    /// Updates remote flag values from CloudKit or another remote source.
    /// Called by CloudSyncService when remote configuration is refreshed.
    public func updateRemoteFlags(_ flags: [String: Bool]) {
        remoteFlags = flags
        logger.info("Remote flags updated: \(flags.count, privacy: .public) flags received")
    }

    // MARK: - FlagSource

    public enum FlagSource: String {
        case `default` = "default"
        case override = "override (dev)"
        case remote = "remote"
    }
}
