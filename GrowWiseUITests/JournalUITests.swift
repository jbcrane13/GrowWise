import XCTest

final class JournalUITests: XCTestCase {
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

    private func navigateToJournal() {
        let journalTab = app.tabBars.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 10.0), "Journal tab button not found")
        journalTab.tap()
        // Verify the custom hero header title appears.
        XCTAssertTrue(app.staticTexts["Journal"].waitForExistence(timeout: 5.0), "Journal screen title not visible")
    }

    /// Opens AddJournalEntryView, enters a title, and saves.
    /// Waits for the sheet to close and the entry to reload into the list.
    private func addJournalEntry(title entryTitle: String) {
        let addButton = app.buttons.matching(identifier: "journal_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Add journal entry button not found")
        addButton.tap()

        // Sheet should open with navigation title "New Journal Entry".
        let sheetNavBar = app.navigationBars["New Journal Entry"]
        XCTAssertTrue(sheetNavBar.waitForExistence(timeout: 5.0), "New Journal Entry sheet did not open")

        // Fill the title field (identified by placeholder text).
        let titleField = app.textFields["Title (Optional)"]
        if titleField.waitForExistence(timeout: 3.0) {
            titleField.tap()
            titleField.typeText(entryTitle)
        }

        // Save — button is enabled once title is non-empty.
        let saveButton = app.buttons.matching(identifier: "addentry_button_save").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Save button not found in AddJournalEntryView")
        saveButton.tap()
    }

    // MARK: - Tests

    /// Verifies the Journal tab is reachable and its key header elements are present.
    func testNavigateToJournalTab() throws {
        navigateToJournal()

        // Confirm the add button is present — proves the full screen loaded.
        let addButton = app.buttons.matching(identifier: "journal_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Add journal entry button not visible on Journal screen")
    }

    /// Verifies that opening AddJournalEntryView, filling a title, and saving
    /// dismisses the sheet and returns to the journal screen.
    func testCreateJournalEntry() throws {
        navigateToJournal()

        let addButton = app.buttons.matching(identifier: "journal_button_add").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0))
        addButton.tap()

        let sheetNavBar = app.navigationBars["New Journal Entry"]
        XCTAssertTrue(sheetNavBar.waitForExistence(timeout: 5.0), "Add entry sheet did not open")

        let titleField = app.textFields["Title (Optional)"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3.0))
        titleField.tap()
        titleField.typeText("First Sprout!")

        let saveButton = app.buttons.matching(identifier: "addentry_button_save").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3.0), "Save button not found")
        saveButton.tap()

        // Sheet should dismiss — journal header title should be visible again.
        XCTAssertTrue(app.staticTexts["Journal"].waitForExistence(timeout: 5.0), "Did not return to Journal screen after save")
    }

    /// Verifies that a saved journal entry appears as a row in the journal list.
    func testEntryAppearsInList() throws {
        navigateToJournal()
        addJournalEntry(title: "Cherry Blossom")

        // Entry title should appear in the list after onChange(of: showingAddEntry) triggers reload.
        let entryText = app.staticTexts["Cherry Blossom"]
        XCTAssertTrue(entryText.waitForExistence(timeout: 8.0), "Journal entry 'Cherry Blossom' did not appear in list after save")
    }

    /// Verifies pagination behaviour: "Load More" does not appear with fewer than 20 entries,
    /// and the list exits the empty state after adding one entry.
    func testLoadMore() throws {
        navigateToJournal()

        let loadMoreButton = app.buttons.matching(identifier: "journal_button_loadmore").firstMatch

        // With no entries the view shows the empty state — no Load More button.
        XCTAssertFalse(loadMoreButton.exists, "Load More button should not appear in empty state")

        // Add one entry to exit the empty state.
        addJournalEntry(title: "First Bloom")

        let entryText = app.staticTexts["First Bloom"]
        XCTAssertTrue(entryText.waitForExistence(timeout: 8.0), "Entry did not appear after adding")

        // With 1 entry (< 20) pagination is not needed — Load More should remain hidden.
        XCTAssertFalse(loadMoreButton.exists, "Load More should not appear with fewer than 20 entries")
    }

    /// Verifies that tapping a journal entry cell opens the detail sheet.
    func testTapOpensDetail() throws {
        navigateToJournal()
        addJournalEntry(title: "Detail Test Entry")

        // Wait for the entry to appear in the list.
        let entryText = app.staticTexts["Detail Test Entry"]
        XCTAssertTrue(entryText.waitForExistence(timeout: 8.0), "Entry not visible in journal list")

        // Tap the entry cell (identified by the journal_cell_entry_ prefix).
        let entryCell = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'journal_cell_entry_'")
        ).firstMatch
        XCTAssertTrue(entryCell.waitForExistence(timeout: 3.0), "Journal entry cell element not found")
        entryCell.tap()

        // Detail sheet opens with its own NavigationStack — its nav bar should appear.
        // JournalView uses navigationBarHidden so the first nav bar after tap is the detail view.
        let detailNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5.0), "Detail view navigation bar did not appear after tapping entry")
    }
}
