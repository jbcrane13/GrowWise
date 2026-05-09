import XCTest

final class GardenClubUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func navigateToClubTab(file: StaticString = #file, line: UInt = #line) {
        let clubTab = app.tabBars.buttons["Club"]
        XCTAssertTrue(clubTab.waitForExistence(timeout: 5.0), "Club tab not found", file: file, line: line)
        clubTab.tap()

        XCTAssertTrue(
            element("club_tab_container").waitForExistence(timeout: 5.0),
            "Club tab did not load",
            file: file,
            line: line
        )
    }

    func testClubTabEmptyStateUsesTopLevelClubNavigation() {
        navigateToClubTab()

        XCTAssertTrue(app.staticTexts["Join a club or start one"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons["Create a club"].waitForExistence(timeout: 3.0))
        XCTAssertTrue(app.buttons["Join a club"].waitForExistence(timeout: 3.0))
    }

    func testCreateClubFlowFromTopLevelClubTab() {
        navigateToClubTab()

        let createPromptButton = app.buttons["Create a club"]
        XCTAssertTrue(createPromptButton.waitForExistence(timeout: 3.0))
        createPromptButton.tap()

        let nameField = app.textFields.matching(identifier: "create_club_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3.0))
        nameField.tap()
        nameField.typeText("Test Garden Club")

        let createButton = app.buttons.matching(identifier: "create_club_button").firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3.0))
        createButton.tap()

        XCTAssertTrue(app.staticTexts["Club Created!"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(element("create_club_invite_code").waitForExistence(timeout: 3.0))
    }

    func testJoinClubFlowFromTopLevelClubTab() {
        navigateToClubTab()

        let joinPromptButton = app.buttons["Join a club"]
        XCTAssertTrue(joinPromptButton.waitForExistence(timeout: 3.0))
        joinPromptButton.tap()

        let codeField = app.textFields.matching(identifier: "join_club_code_field").firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 3.0))
        codeField.tap()
        codeField.typeText("TEST42")

        let joinButton = app.buttons.matching(identifier: "join_club_button").firstMatch
        XCTAssertTrue(joinButton.waitForExistence(timeout: 3.0))
        XCTAssertTrue(joinButton.isEnabled)
    }
}
