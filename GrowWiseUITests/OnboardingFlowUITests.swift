import XCTest

final class OnboardingFlowUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Reset app state for consistent testing
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Complete Onboarding Flow Tests
    
    func testCompleteOnboardingFlow() throws {
        // Test the complete onboarding flow from start to finish
        
        // 1. Welcome Screen
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)
        getStartedButton.tap()
        
        // 2. Skill Assessment Screen
        let skillTitle = app.staticTexts["What's Your Gardening Experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 2.0))
        
        let beginnerOption = app.buttons["Beginner"]
        XCTAssertTrue(beginnerOption.exists)
        beginnerOption.tap()
        
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()
        
        // 3. Gardening Goals Screen
        let goalsTitle = app.staticTexts["What Are Your Gardening Goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 2.0))
        
        // Select multiple goals
        app.buttons["Grow My Own Food"].tap()
        app.buttons["Learn New Skills"].tap()
        
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        continueButton.tap()
        
        // 4. Location Setup Screen
        let locationTitle = app.staticTexts["Set Your Location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 2.0))
        
        let allowLocationButton = app.buttons["Allow Location Access"]
        if allowLocationButton.exists {
            allowLocationButton.tap()
            
            // Handle system location permission alert
            let systemAlert = app.alerts.firstMatch
            if systemAlert.exists {
                systemAlert.buttons["Allow While Using App"].tap()
            }
        }
        
        // Skip if location not available
        let skipLocationButton = app.buttons["Skip for Now"]
        if skipLocationButton.exists {
            skipLocationButton.tap()
        }
        
        // 5. Notification Permission Screen
        let notificationTitle = app.staticTexts["Stay Connected with Your Plants"]
        XCTAssertTrue(notificationTitle.waitForExistence(timeout: 2.0))
        
        let enableNotificationsButton = app.buttons["Enable Notifications"]
        XCTAssertTrue(enableNotificationsButton.exists)
        enableNotificationsButton.tap()
        
        // Handle system notification permission alert
        let notificationAlert = app.alerts.firstMatch
        if notificationAlert.exists {
            notificationAlert.buttons["Allow"].tap()
        }
        
        // 6. Completion Screen
        let completionTitle = app.staticTexts["You're All Set!"]
        XCTAssertTrue(completionTitle.waitForExistence(timeout: 3.0))
        
        let startGardeningButton = app.buttons["Start Gardening"]
        XCTAssertTrue(startGardeningButton.exists)
        startGardeningButton.tap()
        
        // 7. Verify navigation to main app
        let mainScreenTitle = app.staticTexts["My Garden"]
        XCTAssertTrue(mainScreenTitle.waitForExistence(timeout: 3.0))
    }
    
    func testOnboardingSkipFlow() throws {
        // Test skipping through onboarding quickly
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        // Look for skip button
        let skipButton = app.buttons["Skip"]
        if skipButton.exists {
            skipButton.tap()
            
            // Verify we reach main app
            let mainScreenTitle = app.staticTexts["My Garden"]
            XCTAssertTrue(mainScreenTitle.waitForExistence(timeout: 3.0))
        } else {
            // If no skip button, go through minimal flow
            app.buttons["Get Started"].tap()
            
            // Skip through each screen rapidly
            let screens = [
                "Beginner",
                "Continue",
                "Skip for Now",
                "Maybe Later",
                "Start Gardening"
            ]
            
            for buttonText in screens {
                let button = app.buttons[buttonText]
                if button.waitForExistence(timeout: 2.0) {
                    button.tap()
                }
            }
            
            let mainScreenTitle = app.staticTexts["My Garden"]
            XCTAssertTrue(mainScreenTitle.waitForExistence(timeout: 3.0))
        }
    }
    
    func testOnboardingBackNavigation() throws {
        // Test navigating backwards through onboarding
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        app.buttons["Get Started"].tap()
        
        // Go to skill assessment
        let skillTitle = app.staticTexts["What's Your Gardening Experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 2.0))
        
        app.buttons["Intermediate"].tap()
        app.buttons["Next"].tap()
        
        // Go to goals screen
        let goalsTitle = app.staticTexts["What Are Your Gardening Goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 2.0))
        
        // Navigate back
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
            
            // Verify we're back on skill assessment
            XCTAssertTrue(skillTitle.waitForExistence(timeout: 2.0))
            
            // Go back again
            if backButton.exists {
                backButton.tap()
                
                // Verify we're back on welcome screen
                XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 2.0))
            }
        }
    }
    
    func testOnboardingFormValidation() throws {
        // Test form validation throughout onboarding
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        app.buttons["Get Started"].tap()
        
        // Skill Assessment - try to continue without selection
        let skillTitle = app.staticTexts["What's Your Gardening Experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 2.0))
        
        let nextButton = app.buttons["Next"]
        if nextButton.exists {
            nextButton.tap()
            
            // Should still be on skill screen if validation works
            XCTAssertTrue(skillTitle.exists)
        }
        
        // Select skill level and continue
        app.buttons["Advanced"].tap()
        nextButton.tap()
        
        // Goals screen - try to continue without selection
        let goalsTitle = app.staticTexts["What Are Your Gardening Goals?"]
        XCTAssertTrue(goalsTitle.waitForExistence(timeout: 2.0))
        
        let continueButton = app.buttons["Continue"]
        if continueButton.exists {
            continueButton.tap()
            
            // Should still be on goals screen if validation works
            XCTAssertTrue(goalsTitle.exists)
        }
        
        // Select at least one goal and continue
        app.buttons["Beautify My Space"].tap()
        continueButton.tap()
        
        // Should progress to next screen
        let locationTitle = app.staticTexts["Set Your Location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 2.0))
    }
    
    func testOnboardingAccessibility() throws {
        // Test accessibility features in onboarding
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        // Check accessibility labels and traits
        XCTAssertTrue(welcomeTitle.isAccessibilityElement)
        XCTAssertNotNil(welcomeTitle.label)
        
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.isAccessibilityElement)
        XCTAssertEqual(getStartedButton.elementType, .button)
        XCTAssertNotNil(getStartedButton.label)
        
        getStartedButton.tap()
        
        // Check skill assessment accessibility
        let skillTitle = app.staticTexts["What's Your Gardening Experience?"]
        XCTAssertTrue(skillTitle.waitForExistence(timeout: 2.0))
        XCTAssertTrue(skillTitle.isAccessibilityElement)
        
        let beginnerButton = app.buttons["Beginner"]
        XCTAssertTrue(beginnerButton.isAccessibilityElement)
        XCTAssertEqual(beginnerButton.elementType, .button)
        
        // Test VoiceOver hints if available
        if let hint = beginnerButton.value as? String {
            XCTAssertFalse(hint.isEmpty)
        }
    }
    
    func testOnboardingProgressIndicator() throws {
        // Test that progress indicator updates correctly
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        app.buttons["Get Started"].tap()
        
        // Check initial progress
        let progressIndicator = app.progressIndicators.firstMatch
        if progressIndicator.exists {
            let initialProgress = progressIndicator.value as? String
            
            // Continue through onboarding and check progress updates
            app.buttons["Expert"].tap()
            app.buttons["Next"].tap()
            
            // Progress should have increased
            let updatedProgress = progressIndicator.value as? String
            XCTAssertNotEqual(initialProgress, updatedProgress)
        }
    }
    
    func testOnboardingPerformance() throws {
        // Measure onboarding performance
        
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        
        let welcomeTitle = app.staticTexts["Welcome to GrowWise"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5.0))
        
        // Measure time to complete onboarding
        measure {
            app.buttons["Get Started"].tap()
            
            app.buttons["Beginner"].waitForExistence(timeout: 1.0)
            app.buttons["Beginner"].tap()
            app.buttons["Next"].tap()
            
            app.buttons["Grow My Own Food"].waitForExistence(timeout: 1.0)
            app.buttons["Grow My Own Food"].tap()
            app.buttons["Continue"].tap()
            
            app.buttons["Skip for Now"].waitForExistence(timeout: 1.0)
            app.buttons["Skip for Now"].tap()
            
            app.buttons["Maybe Later"].waitForExistence(timeout: 1.0)
            app.buttons["Maybe Later"].tap()
            
            app.buttons["Start Gardening"].waitForExistence(timeout: 1.0)
            app.buttons["Start Gardening"].tap()
            
            let mainScreen = app.staticTexts["My Garden"]
            XCTAssertTrue(mainScreen.waitForExistence(timeout: 2.0))
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToScreen(_ screenIdentifier: String) {
        // Helper to navigate to specific onboarding screen
        while !app.staticTexts[screenIdentifier].exists {
            let nextButton = app.buttons["Next"]
            let continueButton = app.buttons["Continue"]
            
            if nextButton.exists {
                nextButton.tap()
            } else if continueButton.exists {
                continueButton.tap()
            } else {
                break
            }
        }
    }
    
    private func selectRandomOption(in buttons: [String]) {
        // Helper to select random option from list
        if let randomButton = buttons.randomElement() {
            let button = app.buttons[randomButton]
            if button.exists {
                button.tap()
            }
        }
    }
}