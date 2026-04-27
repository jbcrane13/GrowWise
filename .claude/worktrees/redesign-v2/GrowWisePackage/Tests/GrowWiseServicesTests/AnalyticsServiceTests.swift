import Testing
import Foundation
@testable import GrowWiseServices

// MARK: - AnalyticsEvent eventType string tests (parameterized)

@Suite("AnalyticsEvent.eventType strings")
struct AnalyticsEventTypeStringTests {

    // All event cases paired with their expected eventType strings.
    // Parameterized via zip so each pairing runs as a separate test case.
    static let eventSamples: [AnalyticsEvent] = [
        .onboardingStarted,
        .onboardingCompleted(daysToComplete: 1),
        .onboardingSkipped(step: "location"),
        .plantAdded(plantType: "Rose", source: .database),
        .plantDeleted,
        .plantViewed,
        .plantDiagnosisViewed,
        .gardenCreated,
        .gardenViewed,
        .journalEntryCreated(hasPhoto: true, hasWeather: false),
        .journalEntryViewed,
        .journalEntryDeleted,
        .reminderCreated(reminderType: "water", frequencyDays: 3),
        .reminderCompleted,
        .reminderSnoozed,
        .reminderDeleted,
        .companionPlantingChecked(isCompatible: true),
        .subscriptionViewed,
        .subscriptionStarted(plan: "annual"),
        .subscriptionRestored,
        .plantSearchPerformed(resultCount: 10),
        .plantDatabaseViewed,
        .profileViewed,
        .settingsChanged(setting: "notifications"),
        .dataExportRequested,
        .featureFlagExposed(flagName: "new_feature", enabled: true),
    ]

    static let expectedEventTypes: [String] = [
        "onboarding_started",
        "onboarding_completed",
        "onboarding_skipped",
        "plant_added",
        "plant_deleted",
        "plant_viewed",
        "plant_diagnosis_viewed",
        "garden_created",
        "garden_viewed",
        "journal_entry_created",
        "journal_entry_viewed",
        "journal_entry_deleted",
        "reminder_created",
        "reminder_completed",
        "reminder_snoozed",
        "reminder_deleted",
        "companion_planting_checked",
        "subscription_viewed",
        "subscription_started",
        "subscription_restored",
        "plant_search_performed",
        "plant_database_viewed",
        "profile_viewed",
        "settings_changed",
        "data_export_requested",
        "feature_flag_exposed",
    ]

    @Test("eventType string matches expected value", arguments: zip(eventSamples, expectedEventTypes))
    func testEventTypeString(_ event: AnalyticsEvent, _ expected: String) {
        #expect(event.eventType == expected)
    }
}

// MARK: - AnalyticsEvent.properties tests

@Suite("AnalyticsEvent.properties")
struct AnalyticsEventPropertiesTests {

    // MARK: Empty properties

    @Test("Events with no associated values produce empty properties")
    func testNoAssociatedValuesProduceEmptyProperties() {
        let emptyPropertyEvents: [AnalyticsEvent] = [
            .onboardingStarted,
            .plantDeleted,
            .plantViewed,
            .plantDiagnosisViewed,
            .gardenCreated,
            .gardenViewed,
            .journalEntryViewed,
            .journalEntryDeleted,
            .reminderCompleted,
            .reminderSnoozed,
            .reminderDeleted,
            .subscriptionViewed,
            .subscriptionRestored,
            .plantDatabaseViewed,
            .profileViewed,
            .dataExportRequested,
        ]
        for event in emptyPropertyEvents {
            #expect(event.properties.isEmpty, "Expected empty properties for \(event.eventType)")
        }
    }

    // MARK: Onboarding

    @Test("onboardingCompleted properties contain days_to_complete")
    func testOnboardingCompletedProperties() {
        let props = AnalyticsEvent.onboardingCompleted(daysToComplete: 7).properties
        #expect(props["days_to_complete"] as? Int == 7)
        #expect(props.count == 1)
    }

    @Test("onboardingSkipped properties contain step")
    func testOnboardingSkippedProperties() {
        let props = AnalyticsEvent.onboardingSkipped(step: "location_setup").properties
        #expect(props["step"] as? String == "location_setup")
        #expect(props.count == 1)
    }

    // MARK: Plants

    @Test("plantAdded properties contain plant_type and source rawValue")
    func testPlantAddedPropertiesDatabaseSource() {
        let props = AnalyticsEvent.plantAdded(plantType: "Tomato", source: .database).properties
        #expect(props["plant_type"] as? String == "Tomato")
        #expect(props["source"] as? String == "database")
        #expect(props.count == 2)
    }

    @Test("plantAdded with manual source has rawValue 'manual'")
    func testPlantAddedManualSourceRawValue() {
        let props = AnalyticsEvent.plantAdded(plantType: "Basil", source: .manual).properties
        #expect(props["source"] as? String == "manual")
    }

    @Test("plantAdded with scanner source has rawValue 'scanner'")
    func testPlantAddedScannerSourceRawValue() {
        let props = AnalyticsEvent.plantAdded(plantType: "Fern", source: .scanner).properties
        #expect(props["source"] as? String == "scanner")
    }

    // MARK: Journal

    @Test("journalEntryCreated properties contain has_photo and has_weather")
    func testJournalEntryCreatedProperties() {
        let propsWithPhoto = AnalyticsEvent.journalEntryCreated(hasPhoto: true, hasWeather: false).properties
        #expect(propsWithPhoto["has_photo"] as? Bool == true)
        #expect(propsWithPhoto["has_weather"] as? Bool == false)

        let propsWithWeather = AnalyticsEvent.journalEntryCreated(hasPhoto: false, hasWeather: true).properties
        #expect(propsWithWeather["has_photo"] as? Bool == false)
        #expect(propsWithWeather["has_weather"] as? Bool == true)
    }

    // MARK: Reminders

    @Test("reminderCreated properties contain reminder_type and frequency_days")
    func testReminderCreatedProperties() {
        let props = AnalyticsEvent.reminderCreated(reminderType: "fertilize", frequencyDays: 14).properties
        #expect(props["reminder_type"] as? String == "fertilize")
        #expect(props["frequency_days"] as? Int == 14)
        #expect(props.count == 2)
    }

    // MARK: Companion Planting

    @Test("companionPlantingChecked properties contain is_compatible")
    func testCompanionPlantingCheckedProperties() {
        let compatibleProps = AnalyticsEvent.companionPlantingChecked(isCompatible: true).properties
        #expect(compatibleProps["is_compatible"] as? Bool == true)

        let incompatibleProps = AnalyticsEvent.companionPlantingChecked(isCompatible: false).properties
        #expect(incompatibleProps["is_compatible"] as? Bool == false)
    }

    // MARK: Subscription

    @Test("subscriptionStarted properties contain plan")
    func testSubscriptionStartedProperties() {
        let props = AnalyticsEvent.subscriptionStarted(plan: "annual").properties
        #expect(props["plan"] as? String == "annual")
        #expect(props.count == 1)
    }

    // MARK: Plant Search — result_count_bucket

    @Test("plantSearchPerformed bucket is '0-4' for count 0–4")
    func testPlantSearchBucketLow() {
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 0).properties["result_count_bucket"] as? String == "0-4")
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 4).properties["result_count_bucket"] as? String == "0-4")
    }

    @Test("plantSearchPerformed bucket is '5-19' for count 5–19")
    func testPlantSearchBucketMid() {
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 5).properties["result_count_bucket"] as? String == "5-19")
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 19).properties["result_count_bucket"] as? String == "5-19")
    }

    @Test("plantSearchPerformed bucket is '20+' for count >= 20")
    func testPlantSearchBucketHigh() {
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 20).properties["result_count_bucket"] as? String == "20+")
        #expect(AnalyticsEvent.plantSearchPerformed(resultCount: 100).properties["result_count_bucket"] as? String == "20+")
    }

    // MARK: Settings / Feature Flags

    @Test("settingsChanged properties contain setting")
    func testSettingsChangedProperties() {
        let props = AnalyticsEvent.settingsChanged(setting: "dark_mode").properties
        #expect(props["setting"] as? String == "dark_mode")
        #expect(props.count == 1)
    }

    @Test("featureFlagExposed properties contain flag_name and enabled")
    func testFeatureFlagExposedProperties() {
        let propsEnabled = AnalyticsEvent.featureFlagExposed(flagName: "rollout_v2", enabled: true).properties
        #expect(propsEnabled["flag_name"] as? String == "rollout_v2")
        #expect(propsEnabled["enabled"] as? Bool == true)
        #expect(propsEnabled.count == 2)

        let propsDisabled = AnalyticsEvent.featureFlagExposed(flagName: "rollout_v2", enabled: false).properties
        #expect(propsDisabled["enabled"] as? Bool == false)
    }
}

// MARK: - AnalyticsService configure() guard tests

@Suite("AnalyticsService.configure() guards")
@MainActor
struct AnalyticsServiceConfigureTests {

    @Test("configure() with empty API key does not initialize service")
    func testConfigureEmptyKeyDoesNotInitialize() {
        let service = AnalyticsService.shared
        service.configure(apiKey: "")
        #expect(service.isInitialized == false)
    }

    @Test("configure() with placeholder API key does not initialize service")
    func testConfigurePlaceholderKeyDoesNotInitialize() {
        let service = AnalyticsService.shared
        service.configure(apiKey: "YOUR_AMPLITUDE_API_KEY")
        #expect(service.isInitialized == false)
    }

    @Test("configure() is idempotent — repeated calls with invalid key stay uninitialized")
    func testConfigureIdempotentWithInvalidKey() {
        let service = AnalyticsService.shared
        // First call: empty key guard fires, no initialization
        service.configure(apiKey: "")
        #expect(service.isInitialized == false)
        // Second call: same guard fires again, state unchanged
        service.configure(apiKey: "")
        #expect(service.isInitialized == false)
    }

    @Test("configure() with nil key and no env var does not initialize service")
    func testConfigureNilKeyWithoutEnvVarDoesNotInitialize() {
        // ProcessInfo.processInfo.environment["AMPLITUDE_API_KEY"] is not set in test env,
        // so resolvedKey falls back to "", triggering the empty-key guard.
        let service = AnalyticsService.shared
        service.configure(apiKey: nil)
        #expect(service.isInitialized == false)
    }
}

// MARK: - AnalyticsService.track() no-op when uninitialized

@Suite("AnalyticsService.track() when uninitialized")
@MainActor
struct AnalyticsServiceTrackTests {

    @Test("track() does not crash when service is uninitialized")
    func testTrackNoopWhenUninitialized() {
        let service = AnalyticsService.shared
        // Precondition: service must be uninitialized (amplitude == nil)
        // so the `guard let amplitude else { return }` fires.
        #expect(service.isInitialized == false)

        // Should silently no-op — no crash, no assertion failure
        service.track(.plantViewed)
        service.track(.onboardingStarted)
        service.track(.gardenViewed)
        service.track(.journalEntryCreated(hasPhoto: false, hasWeather: false))
        service.track(.reminderCreated(reminderType: "water", frequencyDays: 7))
        service.track(.featureFlagExposed(flagName: "flag", enabled: false))
    }
}
