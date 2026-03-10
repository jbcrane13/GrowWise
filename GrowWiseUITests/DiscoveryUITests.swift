import XCTest

final class DiscoveryUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Launch with UI testing argument to bypass onboarding
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testPlantDatabaseSearch() throws {
        // "Plant Guide" tab removed in 4-tab navigation redesign (Task 4).
        // PlantDatabaseView will be re-integrated as part of the Garden tab in Phase 3.
        throw XCTSkip("Plant Guide tab removed in 4-tab redesign (Task 4). Will return in Phase 3.")
    }

    func testTutorialsFlow() throws {
        // "Learn" tab removed in 4-tab navigation redesign (Task 4).
        // TutorialsView will be re-integrated in a future phase.
        throw XCTSkip("Learn tab removed in 4-tab redesign (Task 4). Will return in a future phase.")
    }
}
