import Testing
import Foundation
@testable import GrowWiseServices

// MARK: - FeatureFlagService Tests

@Suite("FeatureFlagService Tests", .serialized)
@MainActor
struct FeatureFlagServiceTests {

    // Use an isolated UserDefaults suite to avoid polluting the shared store.
    // .serialized ensures init()'s cleanup runs to completion between tests so override writes
    // (e.g. setOverride in testOverridePriorityOverRemote) cannot leak across parallel tests.
    let userDefaults = UserDefaults(suiteName: "com.growwise.tests.featureflags")!

    init() {
        // Clean up any leftover test overrides
        userDefaults.removePersistentDomain(forName: "com.growwise.tests.featureflags")
    }

    // MARK: - Default Values

    @Test("Default flag values match expected defaults")
    func testDefaultFlagValues() {
        #expect(FeatureFlag.companionPlantingV2.defaultValue == true)
        #expect(FeatureFlag.plantHealthDiagnostics.defaultValue == false)
        #expect(FeatureFlag.gardenSharing.defaultValue == false)
        #expect(FeatureFlag.debugOverlay.defaultValue == false)
        #expect(FeatureFlag.mockData.defaultValue == false)
    }

    @Test("All flags have a raw string value")
    func testFlagRawValues() {
        for flag in FeatureFlag.allCases {
            #expect(!flag.rawValue.isEmpty)
        }
    }

    @Test("CaseIterable returns all flags")
    func testAllFlagsCount() {
        #expect(FeatureFlag.allCases.count > 0)
    }

    // MARK: - Override Behavior

    @Test("Setting override to true enables a disabled flag")
    func testEnableDisabledFlag() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        // gardenSharing is disabled by default
        service.setOverride(.gardenSharing, enabled: true)
        #expect(service.isEnabled(.gardenSharing) == true)
    }

    @Test("Setting override to false disables an enabled flag")
    func testDisableEnabledFlag() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        // companionPlantingV2 is enabled by default
        service.setOverride(.companionPlantingV2, enabled: false)
        #expect(service.isEnabled(.companionPlantingV2) == false)
    }

    @Test("Removing override reverts to default value")
    func testRemoveOverrideRevertToDefault() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        // Override then remove
        service.setOverride(.gardenSharing, enabled: true)
        service.setOverride(.gardenSharing, enabled: nil)

        #expect(service.isEnabled(.gardenSharing) == FeatureFlag.gardenSharing.defaultValue)
    }

    // MARK: - Remote Config

    @Test("Remote flags override defaults")
    func testRemoteFlagsOverrideDefaults() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        service.updateRemoteFlags(["garden_sharing": true])
        #expect(service.isEnabled(.gardenSharing) == true)
    }

    @Test("UserDefaults override takes priority over remote config")
    func testOverridePriorityOverRemote() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        // Remote says enabled, but local override says disabled
        service.updateRemoteFlags(["garden_sharing": true])
        service.setOverride(.gardenSharing, enabled: false)

        #expect(service.isEnabled(.gardenSharing) == false)
    }

    // MARK: - allFlags()

    @Test("allFlags returns entry for every flag")
    func testAllFlagsReturnsAll() {
        let service = FeatureFlagService(userDefaults: userDefaults)
        let allFlags = service.allFlags()
        #expect(allFlags.count == FeatureFlag.allCases.count)
    }

    @Test("allFlags reports correct source for overridden flag")
    func testAllFlagsReportsOverrideSource() {
        let service = FeatureFlagService(userDefaults: userDefaults)
        service.setOverride(.debugOverlay, enabled: true)

        let entry = service.allFlags().first(where: { $0.flag == .debugOverlay })
        #expect(entry?.source == .override)
        #expect(entry?.enabled == true)
    }

    @Test("allFlags reports default source for unmodified flag")
    func testAllFlagsReportsDefaultSource() {
        let service = FeatureFlagService(userDefaults: userDefaults)

        let entry = service.allFlags().first(where: { $0.flag == .journalMarkdown })
        #expect(entry?.source == .default)
        #expect(entry?.enabled == FeatureFlag.journalMarkdown.defaultValue)
    }
}
