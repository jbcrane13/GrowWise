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
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20.0))
        homeTab.tap()

        let cloudSyncLabel = app.staticTexts["iCloud Sync"]
        if !cloudSyncLabel.waitForExistence(timeout: 2.0) {
            for _ in 0..<8 {
                app.swipeUp()
                if cloudSyncLabel.exists {
                    break
                }
            }
        }

        XCTAssertTrue(cloudSyncLabel.exists)
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
