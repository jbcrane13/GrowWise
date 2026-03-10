import XCTest

final class PhaseOneTwoUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--skip-onboarding",
            "--uitesting-mock-weather",
            "-hasCompletedOnboarding",
            "YES"
        ]
        app.launchEnvironment["UITEST_SKIP_ONBOARDING"] = "1"
        app.launch()
        dismissOnboardingIfNeeded()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testHomeShowsCloudSyncAndWeatherSections() throws {
        // WeatherSection and the iCloud Sync label were absorbed into the HomeHeroHeader
        // in the Task 9 Home redesign. The old sections no longer exist.
        throw XCTSkip("WeatherSection/CloudSync UI removed in Home redesign (Task 9). Needs updated test.")
    }

    func testScannerSampleDiagnosisDisplaysResult() throws {
        // Scanner tab removed in 4-tab navigation redesign (Task 4).
        // PlantScannerView is no longer a top-level tab.
        throw XCTSkip("Scanner tab removed in 4-tab redesign (Task 4). Scanner will be re-integrated in a future phase.")
    }

    private func dismissOnboardingIfNeeded() {
        let continueButton = app.buttons["Continue"]
        var attempts = 0
        while continueButton.waitForExistence(timeout: 1.0) && attempts < 8 {
            continueButton.tap()
            attempts += 1
        }
    }
}
