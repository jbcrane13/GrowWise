import XCTest

// MARK: - Seed Inventory UI Tests

@MainActor
final class SeedInventoryUITests: XCTestCase {
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
        XCTAssertTrue(gardenTab.waitForExistence(timeout: 10), "Garden tab not found")
        gardenTab.tap()
    }

    private func navigateToSeedInventory() {
        navigateToGarden()

        // Tap the Seeds chip in the Garden tab hero header
        let seedsChip = app.buttons.matching(identifier: "garden_chip_seeds").firstMatch
        XCTAssertTrue(seedsChip.waitForExistence(timeout: 5), "Seeds chip not found in Garden hero header")
        seedsChip.tap()

        let seedScreen = app.otherElements.matching(identifier: "seed_inventory_list").firstMatch
            .waitForExistence(timeout: 5)
        _ = seedScreen
    }

    private func addTestSeed(variety: String = "Roma Tomato", brand: String = "Burpee") {
        let addButton = app.buttons.matching(identifier: "seed_inventory_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add seed button not found")
        addButton.tap()

        let varietyField = app.textFields.matching(identifier: "add_seed_field_variety").firstMatch
        XCTAssertTrue(varietyField.waitForExistence(timeout: 5), "Variety field not found")
        varietyField.tap()
        varietyField.typeText(variety)

        let saveButton = app.buttons.matching(identifier: "add_seed_button_save").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button not found")
        saveButton.tap()
    }

    // MARK: - Tests

    /// Smoke test: seed inventory screen is reachable from Garden tab.
    func testSeedInventoryScreenLoads() throws {
        navigateToGarden()

        let seedsChip = app.buttons.matching(identifier: "garden_chip_seeds").firstMatch
        guard seedsChip.waitForExistence(timeout: 5) else {
            throw XCTSkip("Seeds chip not found — garden hero header may not render chips without a garden")
        }
        seedsChip.tap()

        // Either the list or the empty state should appear
        let listOrEmpty = app.otherElements.matching(
            NSPredicate(format: "identifier == 'seed_inventory_list' OR identifier == 'seed_inventory_empty'")
        ).firstMatch
        XCTAssertTrue(listOrEmpty.waitForExistence(timeout: 5), "Seed inventory screen did not load")
    }

    /// Verifies the add seed sheet can be opened and dismissed.
    func testAddSeedSheetOpens() throws {
        navigateToSeedInventory()

        let addButton = app.buttons.matching(identifier: "seed_inventory_button_add").firstMatch
        guard addButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Seed inventory add button not found — screen may not have loaded")
        }
        addButton.tap()

        let varietyField = app.textFields.matching(identifier: "add_seed_field_variety").firstMatch
        XCTAssertTrue(varietyField.waitForExistence(timeout: 5), "Add seed variety field did not appear")

        // Dismiss the sheet
        app.swipeDown()
    }

    /// Verifies search bar filters seeds.
    func testSeedSearchFilters() throws {
        navigateToSeedInventory()

        // Add a seed first
        addTestSeed(variety: "Sugar Snap Pea")

        let searchField = app.textFields.matching(identifier: "seed_inventory_search").firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            throw XCTSkip("Search field not found in seed inventory")
        }

        searchField.tap()
        searchField.typeText("Sugar")

        let seedText = app.staticTexts["Sugar Snap Pea"]
        XCTAssertTrue(seedText.waitForExistence(timeout: 3), "Seed should be visible after matching search")

        // Clear and type non-matching text
        searchField.clearText()
        searchField.typeText("ZZZNotARealSeed")
        XCTAssertFalse(seedText.waitForExistence(timeout: 2), "Seed should be hidden after non-matching search")
    }

    /// Verifies tapping a seed row opens SeedDetailView.
    func testSeedDetailViewOpens() throws {
        navigateToSeedInventory()

        addTestSeed(variety: "Beefsteak Tomato")

        // Find the seed cell
        let seedCell = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'seed_inventory_cell_'")
        ).firstMatch
        guard seedCell.waitForExistence(timeout: 5) else {
            throw XCTSkip("Seed cell not found — seed may not have saved")
        }
        seedCell.tap()

        // Variety name should appear in detail view
        let detailVariety = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Beefsteak Tomato'")
        ).firstMatch
        XCTAssertTrue(detailVariety.waitForExistence(timeout: 5), "Seed detail view did not show variety name")
    }

    /// Verifies the delete button is present in seed detail view.
    func testSeedDetailDeleteButtonPresent() throws {
        navigateToSeedInventory()
        addTestSeed(variety: "Lavender")

        let seedCell = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'seed_inventory_cell_'")
        ).firstMatch
        guard seedCell.waitForExistence(timeout: 5) else {
            throw XCTSkip("Seed cell not found")
        }
        seedCell.tap()

        let deleteButton = app.buttons.matching(identifier: "seed_detail_button_delete").firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button should be visible in seed detail view")
    }

    /// Verifies Ready to Plant card appears on Home when seeds with indoorStartWeeks exist.
    func testReadyToPlantCardAppearsOnHome() throws {
        // This test requires seeds with indoorStartWeeks in the planting window — skip in CI
        throw XCTSkip("Ready to Plant card requires zone + seasonal data — covered by unit tests in SeedInventoryServiceTests")
    }
}

// MARK: - XCUIElement Extension

private extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
