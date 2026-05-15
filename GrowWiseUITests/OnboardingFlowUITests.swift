import XCTest

final class OnboardingFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tapNext(file: StaticString = #file, line: UInt = #line) {
        let nextButton = app.buttons.matching(identifier: "onboarding_nav_next").firstMatch
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5.0), "Onboarding next button not found", file: file, line: line)
        XCTAssertTrue(nextButton.isEnabled, "Onboarding next button is disabled", file: file, line: line)
        nextButton.tap()
    }

    private func selectGoalAndContinue(_ goalIdentifier: String, file: StaticString = #file, line: UInt = #line) {
        let goalButton = element(goalIdentifier)
        XCTAssertTrue(goalButton.waitForExistence(timeout: 3.0), "\(goalIdentifier) not found", file: file, line: line)
        goalButton.tap()

        let nextButton = app.buttons.matching(identifier: "onboarding_nav_next").firstMatch
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3.0), file: file, line: line)
        var attempts = 0
        while !nextButton.isEnabled, attempts < 10 {
            Thread.sleep(forTimeInterval: 0.2)
            attempts += 1
        }
        XCTAssertTrue(nextButton.isEnabled, "Continue not enabled after selecting a goal", file: file, line: line)
        nextButton.tap()
    }

    private func advanceToCompletion(skipGarden: Bool = false, selectFirstPlant: Bool = false) {
        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_skill_beginner").waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_goal_grow_food").waitForExistence(timeout: 5.0))
        selectGoalAndContinue("onboarding_goal_grow_food")

        let gardenToggle = element("onboarding_toggle_create_garden")
        XCTAssertTrue(gardenToggle.waitForExistence(timeout: 5.0))
        if skipGarden {
            gardenToggle.tap()
        }
        tapNext()

        let locationSkip = app.buttons.matching(identifier: "onboarding_location_skip").firstMatch
        XCTAssertTrue(locationSkip.waitForExistence(timeout: 5.0))
        locationSkip.tap()
        tapNext()

        let notificationsSkip = app.buttons.matching(identifier: "onboarding_notifications_skip").firstMatch
        XCTAssertTrue(notificationsSkip.waitForExistence(timeout: 5.0))
        notificationsSkip.tap()
        tapNext()

        XCTAssertTrue(element("onboarding_firstplant_title").waitForExistence(timeout: 5.0))
        if selectFirstPlant {
            let basilCard = element("onboarding_firstplant_card_basil")
            XCTAssertTrue(basilCard.waitForExistence(timeout: 5.0), "Basil starter plant card not found")
            basilCard.tap()
        } else {
            let firstPlantSkip = app.buttons.matching(identifier: "onboarding_firstplant_skip").firstMatch
            XCTAssertTrue(firstPlantSkip.waitForExistence(timeout: 3.0))
            firstPlantSkip.tap()
        }
        tapNext()
    }

    // MARK: - Complete Onboarding Flow Tests

    func testCompleteOnboardingFlow() {
        advanceToCompletion(selectFirstPlant: true)

        XCTAssertTrue(app.staticTexts["Your garden awaits!"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts["First Plant"].waitForExistence(timeout: 3.0))
        XCTAssertTrue(app.staticTexts["Basil"].waitForExistence(timeout: 3.0))
        tapNext()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))

        app.tabBars.buttons["Garden"].tap()
        XCTAssertTrue(app.staticTexts["Basil"].waitForExistence(timeout: 8.0))
        XCTAssertTrue(app.staticTexts["Starter Container"].waitForExistence(timeout: 8.0))
    }

    func testOnboardingSkipGardenFlow() {
        advanceToCompletion(skipGarden: true)

        XCTAssertTrue(app.staticTexts["Your garden awaits!"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts["First Garden"].waitForExistence(timeout: 3.0))
        XCTAssertTrue(app.staticTexts["Skipped"].waitForExistence(timeout: 3.0))
        tapNext()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5.0))
    }

    func testOnboardingBackNavigation() {
        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_skill_beginner").waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_goal_grow_food").waitForExistence(timeout: 5.0))
        let backButton = app.buttons.matching(identifier: "onboarding_nav_back").firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3.0))
        backButton.tap()

        XCTAssertTrue(element("onboarding_skill_beginner").waitForExistence(timeout: 5.0))
    }

    func testOnboardingFormValidation() {
        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_skill_advanced").waitForExistence(timeout: 5.0))
        element("onboarding_skill_advanced").tap()
        tapNext()

        XCTAssertTrue(element("onboarding_goal_beautify_space").waitForExistence(timeout: 5.0))
        let nextButton = app.buttons.matching(identifier: "onboarding_nav_next").firstMatch
        XCTAssertTrue(nextButton.exists)
        XCTAssertFalse(nextButton.isEnabled, "Continue should be disabled without goal selection")

        selectGoalAndContinue("onboarding_goal_beautify_space")
        XCTAssertTrue(element("onboarding_toggle_create_garden").waitForExistence(timeout: 5.0))
    }

    func testOnboardingAccessibility() {
        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_step_skillAssessment").waitForExistence(timeout: 3.0))
        XCTAssertTrue(element("onboarding_skill_intermediate").waitForExistence(timeout: 3.0))
        element("onboarding_skill_intermediate").tap()
        tapNext()

        XCTAssertTrue(element("onboarding_step_goals").waitForExistence(timeout: 3.0))
        XCTAssertTrue(element("onboarding_goal_grow_food").waitForExistence(timeout: 3.0))
    }

    func testOnboardingProgressIndicator() {
        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
        tapNext()

        XCTAssertTrue(element("onboarding_step_skillAssessment").waitForExistence(timeout: 3.0))
        tapNext()

        XCTAssertTrue(element("onboarding_step_goals").waitForExistence(timeout: 3.0))
        selectGoalAndContinue("onboarding_goal_grow_food")

        XCTAssertTrue(element("onboarding_step_gardenSetup").waitForExistence(timeout: 3.0))
    }

    func testOnboardingPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }

        XCTAssertTrue(app.staticTexts["Cultivation"].waitForExistence(timeout: 5.0))
    }
}
