import XCTest

final class CultivationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Configure app for UI testing
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() {
        // Test that the app launches successfully
        XCTAssertTrue(app.exists)

        // Verify the app rendered content — either the main tab bar
        // (onboarding complete) or onboarding welcome screen text.
        let tabBar = app.tabBars.firstMatch
        let cultivationText = app.staticTexts["Cultivation"]
        let foundTabBar = tabBar.waitForExistence(timeout: 15.0)
        let foundOnboarding = !foundTabBar && cultivationText.waitForExistence(timeout: 10.0)
        XCTAssertTrue(foundTabBar || foundOnboarding, "Expected tab bar or onboarding screen")
    }

    @MainActor
    func testAppLaunchPerformance() {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    // MARK: - Helper Methods

    private func skipOnboardingIfNeeded() {
        // Skip onboarding if it appears
        let onboardingView = app.otherElements["OnboardingView"]

        if onboardingView.waitForExistence(timeout: 2.0) {
            // Look for skip button
            let skipButton = app.buttons["Skip"]
            if skipButton.exists {
                skipButton.tap()
                return
            }
        }

        // Wait for main app to load
        let mainView = app.otherElements["MainAppView"]
        XCTAssertTrue(mainView.waitForExistence(timeout: 5.0))
    }
}
