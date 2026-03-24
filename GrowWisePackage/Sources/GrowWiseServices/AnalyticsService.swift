import AmplitudeSwift
import Foundation
import os

// MARK: - Analytics Events

/// All Amplitude events tracked in GrowWise.
/// Adding a new event: add a case here, implement `properties` below.
public enum AnalyticsEvent: Sendable {
    // MARK: Onboarding

    case onboardingStarted
    case onboardingCompleted(daysToComplete: Int)
    case onboardingSkipped(step: String)

    // MARK: Plants

    case plantAdded(plantType: String, source: PlantSource)
    case plantDeleted
    case plantViewed
    case plantDiagnosisViewed

    // MARK: Garden

    case gardenCreated
    case gardenViewed

    // MARK: Journal

    case journalEntryCreated(hasPhoto: Bool, hasWeather: Bool)
    case journalEntryViewed
    case journalEntryDeleted

    // MARK: Reminders

    case reminderCreated(reminderType: String, frequencyDays: Int)
    case reminderCompleted
    case reminderSnoozed
    case reminderDeleted

    // MARK: Companion Planting

    case companionPlantingChecked(isCompatible: Bool)

    // MARK: Subscription

    case subscriptionViewed
    case subscriptionStarted(plan: String)
    case subscriptionRestored

    // MARK: Search

    case plantSearchPerformed(resultCount: Int)
    case plantDatabaseViewed

    // MARK: Settings / Profile

    case profileViewed
    case settingsChanged(setting: String)
    case dataExportRequested

    // MARK: Feature Flags

    case featureFlagExposed(flagName: String, enabled: Bool)

    public enum PlantSource: String, Sendable {
        case database
        case manual
        case scanner
    }

    var eventType: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .onboardingCompleted: "onboarding_completed"
        case .onboardingSkipped: "onboarding_skipped"
        case .plantAdded: "plant_added"
        case .plantDeleted: "plant_deleted"
        case .plantViewed: "plant_viewed"
        case .plantDiagnosisViewed: "plant_diagnosis_viewed"
        case .gardenCreated: "garden_created"
        case .gardenViewed: "garden_viewed"
        case .journalEntryCreated: "journal_entry_created"
        case .journalEntryViewed: "journal_entry_viewed"
        case .journalEntryDeleted: "journal_entry_deleted"
        case .reminderCreated: "reminder_created"
        case .reminderCompleted: "reminder_completed"
        case .reminderSnoozed: "reminder_snoozed"
        case .reminderDeleted: "reminder_deleted"
        case .companionPlantingChecked: "companion_planting_checked"
        case .subscriptionViewed: "subscription_viewed"
        case .subscriptionStarted: "subscription_started"
        case .subscriptionRestored: "subscription_restored"
        case .plantSearchPerformed: "plant_search_performed"
        case .plantDatabaseViewed: "plant_database_viewed"
        case .profileViewed: "profile_viewed"
        case .settingsChanged: "settings_changed"
        case .dataExportRequested: "data_export_requested"
        case .featureFlagExposed: "feature_flag_exposed"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .onboardingStarted, .plantDeleted, .plantViewed, .plantDiagnosisViewed,
             .gardenCreated, .gardenViewed, .journalEntryViewed, .journalEntryDeleted,
             .reminderCompleted, .reminderSnoozed, .reminderDeleted,
             .subscriptionViewed, .subscriptionRestored, .plantDatabaseViewed,
             .profileViewed, .dataExportRequested:
            [:]

        case .onboardingCompleted(let days):
            ["days_to_complete": days]

        case .onboardingSkipped(let step):
            ["step": step]

        case .plantAdded(let plantType, let source):
            ["plant_type": plantType, "source": source.rawValue]

        case .journalEntryCreated(let hasPhoto, let hasWeather):
            ["has_photo": hasPhoto, "has_weather": hasWeather]

        case .reminderCreated(let type, let frequencyDays):
            ["reminder_type": type, "frequency_days": frequencyDays]

        case .companionPlantingChecked(let isCompatible):
            ["is_compatible": isCompatible]

        case .subscriptionStarted(let plan):
            ["plan": plan]

        case .plantSearchPerformed(let resultCount):
            ["result_count_bucket": resultCount < 5 ? "0-4" : resultCount < 20 ? "5-19" : "20+"]

        case .settingsChanged(let setting):
            ["setting": setting]

        case .featureFlagExposed(let flagName, let enabled):
            ["flag_name": flagName, "enabled": enabled]
        }
    }
}

// MARK: - AnalyticsService

/// Wraps Amplitude for product analytics event tracking.
///
/// Privacy rules:
/// - No PII tracked (no names, emails, plant names/notes)
/// - Anonymous user ID only
/// - Opt-out respected via FeatureFlagService or explicit user preference
///
/// Configuration:
///   Set AMPLITUDE_API_KEY in the Xcode scheme environment or via `AnalyticsService.configure(apiKey:)`
@MainActor
@Observable
public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private var amplitude: Amplitude?
    private let logger = Logger(subsystem: "com.growwise", category: "Analytics")
    private(set) var isInitialized = false

    private init() {}

    // MARK: - Setup

    /// Call once on app launch. API key via parameter or AMPLITUDE_API_KEY env var.
    public func configure(apiKey: String? = nil, isDevelopment: Bool = false) {
        guard !isInitialized else { return }

        let resolvedKey = apiKey ?? ProcessInfo.processInfo.environment["AMPLITUDE_API_KEY"] ?? ""
        guard !resolvedKey.isEmpty, resolvedKey != "YOUR_AMPLITUDE_API_KEY" else {
            logger.warning("Amplitude API key not configured — analytics disabled")
            return
        }

        amplitude = Amplitude(
            configuration: Configuration(
                apiKey: resolvedKey,
                flushQueueSize: 30,
                flushIntervalMillis: 30000,
                logLevel: isDevelopment ? .debug : .warn,
                flushEventsOnClose: true,
                autocapture: [.sessions, .appLifecycles]
            )
        )

        isInitialized = true
        logger.info("Amplitude initialized")
    }

    // MARK: - User Identity

    /// Set an anonymous user ID. Never pass real user identity.
    public func setAnonymousUser(stableID: String) {
        amplitude?.setUserId(userId: stableID)
    }

    /// Update user properties with non-PII app state.
    public func updateUserProperties(
        subscriptionTier: String,
        plantCountBucket: String,
        gardenCount: Int,
        daysActive: Int
    ) {
        let identify = Identify()
            .set(property: "subscription_tier", value: subscriptionTier)
            .set(property: "plant_count_bucket", value: plantCountBucket)
            .set(property: "garden_count", value: gardenCount)
        amplitude?.identify(identify: identify)
    }

    public func clearUser() {
        amplitude?.reset()
    }

    // MARK: - Event Tracking

    /// Track a GrowWise analytics event.
    public func track(_ event: AnalyticsEvent) {
        guard let amplitude else { return }

        let props = event.properties
        if props.isEmpty {
            amplitude.track(eventType: event.eventType)
        } else {
            amplitude.track(eventType: event.eventType, eventProperties: props)
        }
    }

    // MARK: - Opt-Out

    public var isOptedOut: Bool {
        get { amplitude?.configuration.optOut ?? true }
        set { amplitude?.configuration.optOut = newValue }
    }
}
