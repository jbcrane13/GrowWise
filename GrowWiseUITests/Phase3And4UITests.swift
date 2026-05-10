import XCTest

// swiftlint:disable single_test_class

// MARK: - Phase 3 & 4 UI Tests

@MainActor
class Phase3And4UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    // MARK: - Companion Planting Tests

    func testCompanionPlantingWarningsInAddPlantSheet() throws {
        throw XCTSkip("Companion planting not yet integrated in My Garden add-plant flow (only available from Home)")
    }

    func testCompanionPlantingRecommendations() throws {
        throw XCTSkip("Companion planting not yet integrated in My Garden add-plant flow (only available from Home)")
    }

    // MARK: - Soil Management Tests

    func testSoilManagementView() throws {
        // Soil management requires MyGardenView which is replaced by GardenView stub in Task 4.
        // Full plant list and soil management arrive in Phase 3 (Task 6).
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Soil management arrives in Phase 3.")
    }

    func testAddSoilLog() throws {
        // Soil management requires MyGardenView which is replaced by GardenView stub in Task 4.
        // Full plant list and soil management arrive in Phase 3 (Task 6).
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Soil management arrives in Phase 3.")
    }

    // MARK: - Garden Showcase (Public CloudKit) Tests

    func testGardenShowcaseView() throws {
        throw XCTSkip("Garden Showcase remains deferred from the 1.0 Me tab")
    }

    // MARK: - Subscription/Paywall Tests

    func testPaywallView() throws {
        throw XCTSkip("Paywall UI is covered by focused feature tests for the 1.0 Me tab")
    }

    func testRestorePurchases() throws {
        throw XCTSkip("Restore purchases is covered by focused feature tests for the 1.0 Me tab")
    }
}

// MARK: - Performance Tests

@MainActor
class Phase3And4PerformanceTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    func testCompanionPlantingLookupPerformance() throws {
        // Requires MyGardenView plant list — replaced by GardenView stub in Task 4.
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Companion planting arrives in Phase 3.")
    }

    func testSoilLogCreationPerformance() throws {
        // Requires MyGardenView plant list — replaced by GardenView stub in Task 4.
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Soil management arrives in Phase 3.")
    }
}

// swiftlint:enable single_test_class
