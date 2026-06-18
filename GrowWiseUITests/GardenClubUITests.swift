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

    private func navigateToGardenTab(file: StaticString = #file, line: UInt = #line) {
        let gardenTab = app.tabBars.buttons["Garden"]
        XCTAssertTrue(gardenTab.waitForExistence(timeout: 5.0), "Garden tab not found", file: file, line: line)
        gardenTab.tap()

        let gardenLoadedMarker = app.descendants(matching: .any).matching(
            NSPredicate(
                format: """
                identifier == 'garden_button_create_first' OR \
                identifier == 'garden_button_add_plant' OR \
                identifier == 'garden_button_add_bed'
                """
            )
        ).firstMatch
        XCTAssertTrue(
            gardenLoadedMarker.waitForExistence(timeout: 5.0),
            "Garden tab did not load",
            file: file,
            line: line
        )
    }

    private func createGardenIfNeeded(file: StaticString = #file, line: UInt = #line) {
        let createFirstButton = app.buttons.matching(identifier: "garden_button_create_first").firstMatch
        guard createFirstButton.waitForExistence(timeout: 1.0) else { return }

        createFirstButton.tap()

        let nameField = app.textFields.matching(identifier: "creategarden_textfield_name").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0), "Create garden name field not found", file: file, line: line)
        nameField.tap()
        nameField.typeText("UI Test Garden")

        let saveButton = app.buttons.matching(identifier: "creategarden_button_save").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Create garden save button not found", file: file, line: line)
        saveButton.tap()

        let doneButton = app.buttons.matching(identifier: "recommended_button_done").firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8.0), "Suggested plants done button not found", file: file, line: line)
        doneButton.tap()

        XCTAssertTrue(
            app.buttons.matching(identifier: "garden_button_add_plant").firstMatch.waitForExistence(timeout: 8.0),
            "Add plant button did not appear after creating a garden",
            file: file,
            line: line
        )
    }

    private func plantRow(named name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'garden_row_plant_' AND label CONTAINS %@",
                name
            )
        ).firstMatch
    }

    private func createClubFromTopLevelClubTab(file: StaticString = #file, line: UInt = #line) {
        let createPromptButton = app.buttons["Create a club"]
        XCTAssertTrue(createPromptButton.waitForExistence(timeout: 3.0), file: file, line: line)
        createPromptButton.tap()

        let nameField = app.textFields.matching(identifier: "create_club_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3.0), file: file, line: line)
        nameField.tap()
        nameField.typeText("Test Garden Club")

        let createButton = app.buttons.matching(identifier: "create_club_button").firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3.0), file: file, line: line)
        createButton.tap()

        XCTAssertTrue(app.staticTexts["Club Created!"].waitForExistence(timeout: 5.0), file: file, line: line)
        let doneButton = app.buttons.matching(identifier: "create_club_done_button").firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3.0), file: file, line: line)
        doneButton.tap()

        XCTAssertTrue(element("club_share_prompt").waitForExistence(timeout: 5.0), file: file, line: line)
    }

    private func addTestPlant(name: String, file: StaticString = #file, line: UInt = #line) {
        createGardenIfNeeded(file: file, line: line)

        let addButton = app.buttons.matching(identifier: "garden_button_add_plant").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Add-plant button not found", file: file, line: line)
        addButton.tap()

        let nameField = app.textFields.matching(identifier: "addplant_textfield_name").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0), "Plant name text field not found", file: file, line: line)
        nameField.tap()
        nameField.typeText(name)

        let gardenPicker = app.descendants(matching: .any)
            .matching(identifier: "addplant_picker_garden")
            .firstMatch
        XCTAssertTrue(
            gardenPicker.waitForExistence(timeout: 5.0),
            "Garden picker did not load before saving the plant",
            file: file,
            line: line
        )

        let saveButton = app.buttons.matching(identifier: "addplant_button_save").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Save button not found in AddPlantSheet", file: file, line: line)
        saveButton.tap()

        let skipWateringButton = app.buttons.matching(identifier: "watering_button_skip").firstMatch
        XCTAssertTrue(
            skipWateringButton.waitForExistence(timeout: 8.0),
            "Watering schedule confirmation did not appear",
            file: file,
            line: line
        )
        skipWateringButton.tap()

        XCTAssertTrue(
            element("addplant_sheet").waitForNonExistence(timeout: 5.0),
            "AddPlantSheet did not dismiss after skipping watering setup",
            file: file,
            line: line
        )

        XCTAssertTrue(
            plantRow(named: name).waitForExistence(timeout: 10.0),
            "Plant did not appear after save",
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

    func testShareComposerFromClubTabPublishesLocalPost() {
        navigateToClubTab()
        createClubFromTopLevelClubTab()

        element("club_share_prompt").tap()
        let captionField = element("share_composer_textfield_caption")
        XCTAssertTrue(captionField.waitForExistence(timeout: 5.0))
        captionField.tap()
        captionField.typeText("First tomato flower from UI")

        let postButton = app.buttons.matching(identifier: "share_composer_button_post").firstMatch
        XCTAssertTrue(postButton.waitForExistence(timeout: 3.0))
        XCTAssertTrue(postButton.isEnabled)
        postButton.tap()

        let offlineAlert = app.alerts["Saved locally"].firstMatch
        if offlineAlert.waitForExistence(timeout: 5.0) {
            app.buttons.matching(identifier: "share_composer_alert_offline").firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["First tomato flower from UI"].waitForExistence(timeout: 8.0))
    }

    func testShareToClubFromPlantDetailShowsPlantContext() {
        navigateToClubTab()
        createClubFromTopLevelClubTab()

        navigateToGardenTab()
        addTestPlant(name: "Club Basil")

        let plantRow = plantRow(named: "Club Basil")
        XCTAssertTrue(plantRow.waitForExistence(timeout: 5.0))
        plantRow.tap()

        let detailsButton = app.buttons.matching(identifier: "quickcard_button_viewdetails").firstMatch
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5.0))
        detailsButton.tap()

        let shareButton = app.buttons.matching(identifier: "plantdetail_button_share_to_club").firstMatch
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5.0))
        shareButton.tap()

        XCTAssertTrue(element("screen_share_composer").waitForExistence(timeout: 5.0))
        XCTAssertTrue(element("share_composer_chip_plant").waitForExistence(timeout: 3.0))
        XCTAssertTrue(app.staticTexts["Club Basil"].waitForExistence(timeout: 3.0))
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
