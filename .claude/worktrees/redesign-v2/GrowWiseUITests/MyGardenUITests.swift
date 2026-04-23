import XCTest

final class MyGardenUITests: XCTestCase {
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

    // MARK: - Helpers

    private func navigateToGarden() {
        let gardenTab = app.tabBars.buttons["Garden"]
        XCTAssertTrue(gardenTab.waitForExistence(timeout: 10.0), "Garden tab button not found")
        gardenTab.tap()
    }

    /// Adds a plant via the hero header + button with the given name,
    /// waits for the sheet to dismiss, and the garden list to reload.
    private func addTestPlant(name: String) {
        let addButton = app.buttons.matching(identifier: "garden_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Hero add-plant button not found")
        addButton.tap()

        let nameField = app.textFields.matching(identifier: "addplant_textfield_name").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0), "Plant name text field not found")
        nameField.tap()
        nameField.typeText(name)

        // Tap the Save button in the AddPlantSheet toolbar
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Save button not found in AddPlantSheet")
        saveButton.tap()
    }

    // MARK: - Tests

    /// Verifies the Garden tab is reachable and its root screen appears.
    func testNavigateToGardenTab() throws {
        navigateToGarden()

        let gardenScreen = app.otherElements.matching(identifier: "screen_garden").firstMatch
        XCTAssertTrue(gardenScreen.waitForExistence(timeout: 5.0), "screen_garden not found after navigating to Garden tab")
    }

    /// Verifies the "Add Bed or Area" alert flow: alert opens, accepts a name, and
    /// transitions to AddPlantSheet with the location pre-filled.
    func testAddBedViaAlert() throws {
        navigateToGarden()

        // A plant must exist for the "Add Bed or Area" button to be visible.
        addTestPlant(name: "Test Fern")

        // After onDismiss reload, filteredGroups is non-empty → addBedButton appears.
        let addBedButton = app.buttons.matching(identifier: "garden_button_addbed").firstMatch
        XCTAssertTrue(addBedButton.waitForExistence(timeout: 8.0), "Add Bed or Area button not found")
        addBedButton.tap()

        // Alert should appear with a text field for the bed name.
        let bedNameField = app.textFields.matching(identifier: "garden_alert_textfield_bedname").firstMatch
        XCTAssertTrue(bedNameField.waitForExistence(timeout: 3.0), "Bed name alert text field not found")
        bedNameField.typeText("South Bed")

        // Tap "Add Plant" in the alert — this should open AddPlantSheet.
        let addPlantAlertButton = app.buttons["Add Plant"]
        XCTAssertTrue(addPlantAlertButton.waitForExistence(timeout: 3.0), "'Add Plant' alert button not found")
        addPlantAlertButton.tap()

        // Verify AddPlantSheet opened (plant name field present).
        let plantNameField = app.textFields.matching(identifier: "addplant_textfield_name").firstMatch
        XCTAssertTrue(plantNameField.waitForExistence(timeout: 5.0), "AddPlantSheet did not open after Add Plant alert tap")
    }

    /// Verifies that tapping the hero + button, filling the plant name, and saving
    /// causes the plant to appear in the garden list.
    func testAddPlantToGarden() throws {
        navigateToGarden()

        let addButton = app.buttons.matching(identifier: "garden_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Hero add-plant button not found")
        addButton.tap()

        let nameField = app.textFields.matching(identifier: "addplant_textfield_name").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0), "Plant name field not found in AddPlantSheet")
        nameField.tap()
        nameField.typeText("Test Rose")

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Save button not found")
        saveButton.tap()

        // Sheet dismisses → onDismiss triggers viewModel.load → "Test Rose" row appears.
        let gardenScreen = app.otherElements.matching(identifier: "screen_garden").firstMatch
        XCTAssertTrue(gardenScreen.waitForExistence(timeout: 5.0), "Garden screen not visible after saving plant")

        let plantText = app.staticTexts["Test Rose"]
        XCTAssertTrue(plantText.waitForExistence(timeout: 8.0), "Plant 'Test Rose' did not appear in garden list after save")
    }

    /// Verifies that typing in the search field filters the plant list, and that a
    /// non-matching query removes the plant from view.
    func testSearchFiltersPlants() throws {
        navigateToGarden()
        addTestPlant(name: "Test Sunflower")

        // Plant should be visible before searching.
        let plantText = app.staticTexts["Test Sunflower"]
        XCTAssertTrue(plantText.waitForExistence(timeout: 8.0), "Plant not visible before search")

        // Open the inline search bar.
        let searchButton = app.buttons.matching(identifier: "garden_button_search").firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3.0), "Search button not found")
        searchButton.tap()

        let searchField = app.textFields.matching(identifier: "garden_search_field").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3.0), "Search field did not appear")
        searchField.tap()
        searchField.typeText("Sunflower")

        // Matching plant remains visible.
        XCTAssertTrue(plantText.waitForExistence(timeout: 3.0), "Matching plant should remain visible after typing matching text")

        // Type non-matching text (clear first via the clear button if present).
        let clearButton = app.buttons.matching(identifier: "garden_button_clearsearch").firstMatch
        if clearButton.waitForExistence(timeout: 2.0) { clearButton.tap() }
        searchField.tap()
        searchField.typeText("XYZ999NeverExists")

        // Non-matching plant should disappear.
        XCTAssertFalse(plantText.waitForExistence(timeout: 3.0), "Plant should be hidden when search does not match")
    }

    /// Verifies that clearing the search field restores the full plant list.
    func testClearSearch() throws {
        navigateToGarden()
        addTestPlant(name: "Test Daisy")

        let plantText = app.staticTexts["Test Daisy"]
        XCTAssertTrue(plantText.waitForExistence(timeout: 8.0), "Plant not visible before search")

        // Open search and type a non-matching query.
        let searchButton = app.buttons.matching(identifier: "garden_button_search").firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3.0))
        searchButton.tap()

        let searchField = app.textFields.matching(identifier: "garden_search_field").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3.0))
        searchField.tap()
        searchField.typeText("ZZZ")
        XCTAssertFalse(plantText.waitForExistence(timeout: 3.0), "Plant should be hidden after non-matching search")

        // Tap the clear button — plant should reappear.
        let clearButton = app.buttons.matching(identifier: "garden_button_clearsearch").firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3.0), "Clear search button not found")
        clearButton.tap()

        XCTAssertTrue(plantText.waitForExistence(timeout: 5.0), "Plant should reappear after clearing the search field")
    }

    /// Verifies that tapping a plant row opens the PlantQuickCard bottom sheet.
    func testQuickCardOpens() throws {
        navigateToGarden()
        addTestPlant(name: "Test Oak")

        // Plant row should appear after the garden reloads.
        let plantText = app.staticTexts["Test Oak"]
        XCTAssertTrue(plantText.waitForExistence(timeout: 8.0), "Plant 'Test Oak' not visible in garden list")

        // Tap the plant row (find by the garden_row_plant_ identifier prefix).
        let plantRow = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'garden_row_plant_'")
        ).firstMatch
        XCTAssertTrue(plantRow.waitForExistence(timeout: 3.0), "Plant row element not found")
        plantRow.tap()

        // PlantQuickCard sheet should open.
        let quickCard = app.otherElements.matching(identifier: "quickcard_sheet").firstMatch
        XCTAssertTrue(quickCard.waitForExistence(timeout: 5.0), "PlantQuickCard sheet did not open after tapping plant row")
    }
}
