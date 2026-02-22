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
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 5.0))
        myGardenTab.tap()
        
        // Should show empty state initially
        let startJourneyText = app.staticTexts["Start Your Garden Journey"]
        XCTAssertTrue(startJourneyText.waitForExistence(timeout: 2.0))
        
        // Verify the two primary empty state buttons
        let addPlantButton = app.buttons["Add Your First Plant"]
        XCTAssertTrue(addPlantButton.exists)
        
        let createGardenButton = app.buttons["Create Garden"]
        XCTAssertTrue(createGardenButton.exists)
    }
    
    func testCreateGarden() throws {
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 5.0))
        myGardenTab.tap()
        
        // Tap "Create Garden" in the empty state or toolbar
        let createGardenButton = app.buttons["Create Garden"]
        if createGardenButton.exists {
            createGardenButton.tap()
        } else {
            // Alternative: tap the toolbar icon (we'll need to make sure the ID matches)
            app.navigationBars["My Garden"].buttons["Create Garden"].tap()
        }
        
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
        
        // Verify the new garden chip appears
        let gardenChip = app.buttons["Front Porch"]
        XCTAssertTrue(gardenChip.waitForExistence(timeout: 2.0))
    }
    
    func testAddPlantToGarden() throws {
        let myGardenTab = app.tabBars.buttons["My Garden"]
        XCTAssertTrue(myGardenTab.waitForExistence(timeout: 5.0))
        myGardenTab.tap()
        
        // If empty state Add Plant button exists, use it, else use toolbar
        let emptyStateAddButton = app.buttons["Add Your First Plant"]
        if emptyStateAddButton.exists {
            emptyStateAddButton.tap()
        } else {
            app.navigationBars["My Garden"].buttons["Add"].tap()
        }
        
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
        
        // Verify plant appears in the grid/list
        // Note: we might need a specific accessibility identifier on the plant card
        let plantCardText = app.staticTexts["Monstera"]
        XCTAssertTrue(plantCardText.waitForExistence(timeout: 2.0))
    }
}
