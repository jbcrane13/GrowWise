import XCTest

final class GrowWiseUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app for UI testing
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - App Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.exists)
        
        // Check for main UI elements
        let mainElement = app.otherElements["MainAppView"]
        let onboardingElement = app.otherElements["OnboardingView"]
        
        // Either main app or onboarding should be visible
        XCTAssertTrue(mainElement.exists || onboardingElement.exists)
    }
    
    @MainActor
    func testAppLaunchPerformance() throws {
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