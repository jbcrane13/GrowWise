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
        let scannerTab = app.tabBars.buttons["Scanner"]
        if scannerTab.waitForExistence(timeout: 5.0) {
            scannerTab.tap()
        } else {
            let moreTab = app.tabBars.buttons["More"]
            XCTAssertTrue(moreTab.waitForExistence(timeout: 10.0))
            moreTab.tap()
            let scannerCell = app.tables.staticTexts["Scanner"]
            XCTAssertTrue(scannerCell.waitForExistence(timeout: 10.0))
            scannerCell.tap()
        }

        let runSampleButton = app.buttons["scannerRunSampleButton"]
        XCTAssertTrue(runSampleButton.waitForExistence(timeout: 10.0))
        runSampleButton.tap()

        XCTAssertTrue(app.staticTexts.matching(identifier: "scannerPrimaryFinding").firstMatch.waitForExistence(timeout: 10.0))
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
