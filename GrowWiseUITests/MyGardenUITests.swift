import XCTest

final class MyGardenUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch with UI testing argument to bypass onboarding if needed
        // Also might want to inject a clean database state
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    func testNavigateToMyGarden() throws {
        // Navigate to My Garden tab
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 5.0))
        myGardenTab.tap()
        
        // Verify we are on the My Garden screen by checking the navigation title
        let navTitle = app.navigationBars["My Garden"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2.0))
    }
    
    func testEmptyState() throws {
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 10.0))
        myGardenTab.tap()

        // Should show empty state initially (allow extra time for data loading)
        let startJourneyText = app.staticTexts["Start Your Garden Journey"]
        XCTAssertTrue(startJourneyText.waitForExistence(timeout: 10.0))
        
        // Verify the two primary empty state buttons
        let addPlantButton = app.buttons["Add Your First Plant"]
        XCTAssertTrue(addPlantButton.exists)
        
        let createGardenButton = app.buttons["Create Garden"]
        XCTAssertTrue(createGardenButton.exists)
    }
    
    func testCreateGarden() throws {
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 10.0))
        myGardenTab.tap()

        // Wait for empty state to fully load (allow extra time for data loading)
        let emptyStateText = app.staticTexts["Start Your Garden Journey"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 10.0))

        // Tap "Create Garden" in the empty state
        let createGardenButton = app.buttons["Create Garden"]
        XCTAssertTrue(createGardenButton.exists)
        createGardenButton.tap()
        
        // Verify sheet appears
        let sheetTitle = app.navigationBars["Create Garden"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2.0))
        
        // Fill out the form
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("Front Porch")
        
        // Optional: Toggle indoor/outdoor, pick type...
        
        // Save
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify sheet dismissed and we're back on My Garden
        let navTitle = app.navigationBars["My Garden"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5.0))
    }
    
    func testAddPlantToGarden() throws {
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 10.0))
        myGardenTab.tap()

        // Wait for empty state to fully load (allow extra time for data loading)
        let emptyStateText = app.staticTexts["Start Your Garden Journey"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 10.0))

        // Tap "Add Your First Plant" in the empty state
        let emptyStateAddButton = app.buttons["Add Your First Plant"]
        XCTAssertTrue(emptyStateAddButton.exists)
        emptyStateAddButton.tap()
        
        // Verify Add Plant sheet
        let sheetTitle = app.navigationBars["Add Plant"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2.0))
        
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("Monstera")
        
        // Hide keyboard if necessary (return button or tap elsewhere)
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        }
        
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify sheet dismissed and we're back on My Garden
        let navTitle = app.navigationBars["My Garden"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5.0))
    }
}
