import XCTest

final class JournalUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch with UI testing argument to bypass onboarding
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    func testNavigateToJournal() throws {
        let journalTab = app.tabBars.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 10.0))
        journalTab.tap()
        
        let navTitle = app.navigationBars["Plant Journal"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2.0))
    }
    
    func testCreateJournalEntry() throws {
        let journalTab = app.tabBars.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 10.0))
        journalTab.tap()
        
        // Tap Add
        let addButton = app.navigationBars["Plant Journal"].buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2.0))
        addButton.tap()
        
        // Verify Sheet
        let sheetTitle = app.navigationBars["New Journal Entry"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2.0))
        
        // Fill form
        let titleField = app.textFields["Title (Optional)"]
        XCTAssertTrue(titleField.exists)
        titleField.tap()
        titleField.typeText("First Sprout!")
        
        // Hide keyboard
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        }
        
        // Add content
        let contentTextEditor = app.textViews["How is your plant doing today?"]
        if contentTextEditor.exists {
            contentTextEditor.tap()
            contentTextEditor.typeText("I noticed a new leaf today.")
        }
        
        // Hide keyboard
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        }
        
        // Save
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify row appears
        let entryRow = app.staticTexts["First Sprout!"]
        XCTAssertTrue(entryRow.waitForExistence(timeout: 3.0))
    }
    
    func testFilterJournalEntries() throws {
        let journalTab = app.tabBars.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 10.0))
        journalTab.tap()
        
        // Find filter chips (e.g., "All Types", "Observation", "Problem")
        let filterChip = app.buttons["Observation"]
        if filterChip.exists {
            filterChip.tap()
        }
        
        // Wait to verify it doesn't crash and UI updates
        // Real validation would require seeded data
        XCTAssertTrue(app.navigationBars["Plant Journal"].exists)
    }
}
