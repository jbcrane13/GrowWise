import XCTest

final class OnboardingFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Reset app state for consistent testing
        app.launchArguments = ["--uitesting", "--reset-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    /// Waits for the Continue button to exist and taps it.
    private func tapContinue(file: StaticString = #file, line: UInt = #line) {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5.0), "Continue button not found", file: file, line: line)
        continueButton.tap()
    }

    /// Selects a goal by label, then taps Continue (which requires enabled state).
    private func selectGoalAndContinue(_ goalLabel: String, file: StaticString = #file, line: UInt = #line) {
        let goalButton = app.buttons[goalLabel]
        XCTAssertTrue(goalButton.waitForExistence(timeout: 3.0), "\(goalLabel) goal not found", file: file, line: line)
        goalButton.tap()

        // Wait a beat for the disabled state to update after goal selection
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3.0), file: file, line: line)
        // Poll briefly for enabled state
        var attempts = 0
        while !continueButton.isEnabled && attempts < 10 {
            Thread.sleep(forTimeInterval: 0.2)
            attempts += 1
        }
        XCTAssertTrue(continueButton.isEnabled, "Continue not enabled after selecting goal", file: file, line: line)
        continueButton.tap()
    }

    // MARK: - Complete Onboarding Flow Tests

    func testCompleteOnboardingFlow() throws {
        // 1. Welcome Screen
        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        tapContinue() // welcome → skill

        // 2. Skill Assessment Screen (Beginner is selected by default)
        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        tapContinue() // skill → goals

        // 3. Gardening Goals Screen — select a goal and continue
        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))

        selectGoalAndContinue("Grow My Own Food") // goals → location

        // 4. Location Setup Screen
        let locationTitle = app.staticTexts["Help us know your location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 5.0))

        let skipLocationButton = app.buttons["Skip for Now"]
        if skipLocationButton.exists {
            skipLocationButton.tap()
        }

        tapContinue() // location → notifications

        // 5. Notification Permission Screen
        let notificationTitle = app.staticTexts["Stay connected to your garden"]
        XCTAssertTrue(notificationTitle.waitForExistence(timeout: 5.0))

        let maybeLaterButton = app.buttons["Maybe Later"]
        if maybeLaterButton.exists {
            maybeLaterButton.tap()
        }

        tapContinue() // notifications → completion

        // 6. Completion Screen
        let completionTitle = app.staticTexts["Welcome to GrowWise!"]
        XCTAssertTrue(completionTitle.waitForExistence(timeout: 5.0))

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3.0))
        getStartedButton.tap()

        // 7. Verify navigation to main app (tab bar should appear)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
    }

    func testOnboardingSkipFlow() throws {
        // Test skipping through onboarding as quickly as possible

        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        tapContinue() // welcome → skill

        // Skill Assessment: Beginner is already selected by default
        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))
        tapContinue() // skill → goals

        // Goals: select one goal to enable Continue
        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))
        selectGoalAndContinue("Grow My Own Food") // goals → location

        // Location: skip and continue
        let locationTitle = app.staticTexts["Help us know your location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 5.0))
        let skipButton = app.buttons["Skip for Now"]
        if skipButton.exists { skipButton.tap() }
        tapContinue() // location → notifications

        // Notifications: skip and continue
        let notifTitle = app.staticTexts["Stay connected to your garden"]
        XCTAssertTrue(notifTitle.waitForExistence(timeout: 5.0))
        let maybeLater = app.buttons["Maybe Later"]
        if maybeLater.exists { maybeLater.tap() }
        tapContinue() // notifications → completion

        // Completion: finish
        let completionTitle = app.staticTexts["Welcome to GrowWise!"]
        XCTAssertTrue(completionTitle.waitForExistence(timeout: 5.0))
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3.0))
        getStartedButton.tap()

        // Verify main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
    }

    func testOnboardingBackNavigation() throws {
        // Test navigating backwards through onboarding

        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        tapContinue() // welcome → skill

        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        // Select a non-default skill level
        let intermediateButton = app.buttons["Intermediate"]
        XCTAssertTrue(intermediateButton.waitForExistence(timeout: 3.0))
        intermediateButton.tap()
        tapContinue() // skill → goals

        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))

        // Navigate back to skill assessment
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.exists)
        backButton.tap()

        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        // Navigate back to welcome
        let backButton2 = app.buttons["Back"]
        if backButton2.exists {
            backButton2.tap()
            XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        }
    }

    func testOnboardingFormValidation() throws {
        // Test form validation throughout onboarding

        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        tapContinue() // welcome → skill

        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        // Select skill level and continue
        let advancedButton = app.buttons["Advanced"]
        XCTAssertTrue(advancedButton.waitForExistence(timeout: 3.0))
        advancedButton.tap()
        tapContinue() // skill → goals

        // Goals screen - Continue should be disabled without goal selection
        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled without goal selection")

        // Select a goal — Continue should become enabled
        selectGoalAndContinue("Beautify My Space") // goals → location

        // Should progress to location screen
        let locationTitle = app.staticTexts["Help us know your location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 5.0))
    }

    func testOnboardingAccessibility() throws {
        // Test that key onboarding elements are present and navigable

        // 1. Welcome screen has title and progress indicator
        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        // Wait for onboarding UI to fully load
        let progressText = app.staticTexts["1 of 6"]
        XCTAssertTrue(progressText.waitForExistence(timeout: 3.0))

        // 2. Skill assessment has title and skill level buttons
        tapContinue() // welcome → skill

        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        let intermediateButton = app.buttons["Intermediate"]
        XCTAssertTrue(intermediateButton.waitForExistence(timeout: 3.0))
        intermediateButton.tap()

        // 3. Goals screen has title and goal buttons
        tapContinue() // skill → goals

        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))

        let goalButton = app.buttons["Grow My Own Food"]
        XCTAssertTrue(goalButton.waitForExistence(timeout: 3.0))
    }

    func testOnboardingProgressIndicator() throws {
        // Test that progress updates as user navigates through onboarding

        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))

        // Check initial progress text (step indicator)
        let initialProgress = app.staticTexts["1 of 6"]
        XCTAssertTrue(initialProgress.waitForExistence(timeout: 3.0))

        tapContinue() // welcome → skill

        // Progress should update to step 2
        let skillTitle = app.staticTexts["What's your gardening experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 5.0))

        let updatedProgress = app.staticTexts["2 of 6"]
        XCTAssertTrue(updatedProgress.waitForExistence(timeout: 3.0))

        // Select a non-default skill and advance to goals
        let expertButton = app.buttons["Expert"]
        XCTAssertTrue(expertButton.waitForExistence(timeout: 3.0))
        expertButton.tap()
        tapContinue() // skill → goals

        let goalsTitle = app.staticTexts["What are your gardening goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 5.0))

        let thirdProgress = app.staticTexts["3 of 6"]
        XCTAssertTrue(thirdProgress.waitForExistence(timeout: 3.0))
    }

    func testOnboardingPerformance() throws {
        // Measure onboarding launch performance

        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }

        let welcomeTitle = app.staticTexts["GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
    }
}
