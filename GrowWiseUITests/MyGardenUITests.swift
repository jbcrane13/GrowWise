import XCTest

final class MyGardenUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Launch with UI testing argument to bypass onboarding if needed
        // Also might want to inject a clean database state
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testNavigateToMyGarden() throws {
        // Tab renamed from "My Garden" to "Garden" in 4-tab redesign (Task 4)
        let gardenTab = app.tabBars.buttons["Garden"]
        XCTAssertTrue(gardenTab.waitForExistence(timeout: 5.0))
        gardenTab.tap()

        // Verify we are on the Garden screen by checking the navigation title
        let navTitle = app.navigationBars["Garden"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2.0))
    }

    func testEmptyState() throws {
        // Full My Garden plant list moves to Phase 3 (Task 6).
        // Stub GardenView replaces MyGardenView in the 4-tab redesign.
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Full plant list arrives in Phase 3.")
    }

    func testCreateGarden() throws {
        // Full My Garden plant list moves to Phase 3 (Task 6).
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Full plant list arrives in Phase 3.")
    }

    func testAddPlantToGarden() throws {
        // Full My Garden plant list moves to Phase 3 (Task 6).
        throw XCTSkip("MyGardenView replaced by GardenView stub in Task 4. Full plant list arrives in Phase 3.")
    }
}
