import XCTest

// MARK: - Phase 3 & 4 UI Tests

@MainActor
class Phase3And4UITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    // MARK: - Companion Planting Tests
    
    func testCompanionPlantingWarningsInAddPlantSheet() throws {
        throw XCTSkip("Companion planting not yet integrated in My Garden add-plant flow (only available from Home)")
    }

    func testCompanionPlantingRecommendations() throws {
        throw XCTSkip("Companion planting not yet integrated in My Garden add-plant flow (only available from Home)")
    }
    
    // MARK: - Soil Management Tests
    
    func testSoilManagementView() throws {
        // Navigate to My Garden
        app.tabBars.buttons["My Garden"].tap()
        
        // Select a plant if exists
        let plantCell = app.cells.firstMatch
        if plantCell.waitForExistence(timeout: 2) {
            plantCell.tap()
            
            // Look for soil management button or scroll to find it
            if app.buttons["Soil Management"].exists {
                app.buttons["Soil Management"].tap()
            } else {
                // Scroll down to find soil section
                app.swipeUp()
                if app.buttons["Soil Management"].exists {
                    app.buttons["Soil Management"].tap()
                }
            }
            
            // Verify soil management view opened
            let soilTitle = app.navigationBars["Soil Management"]
            XCTAssertTrue(soilTitle.waitForExistence(timeout: 2), "Soil Management view should open")
        }
    }
    
    func testAddSoilLog() throws {
        // Navigate to Soil Management
        app.tabBars.buttons["My Garden"].tap()
        
        let plantCell = app.cells.firstMatch
        guard plantCell.waitForExistence(timeout: 2) else {
            XCTSkip("No plants available for testing")
            return
        }
        
        plantCell.tap()
        
        // Navigate to soil management
        if app.buttons["Soil Management"].exists {
            app.buttons["Soil Management"].tap()
        } else {
            app.swipeUp()
            if app.buttons["Soil Management"].exists {
                app.buttons["Soil Management"].tap()
            } else {
                XCTSkip("Soil Management not accessible")
                return
            }
        }
        
        // Tap Add Test button
        let addButton = app.buttons["Add Test"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()
        
        // Verify Add Soil Test sheet opened
        let sheetTitle = app.navigationBars["Add Soil Test"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2), "Add Soil Test sheet should open")
        
        // Enter pH level
        let phField = app.textFields["pH (0-14)"]
        if phField.exists {
            phField.tap()
            phField.typeText("6.5")
        }
        
        // Enter N-P-K values
        let nitrogenField = app.textFields["N"]
        if nitrogenField.exists {
            nitrogenField.tap()
            nitrogenField.typeText("25")
        }
        
        // Save the soil log
        app.buttons["Save"].tap()
        
        // Verify we're back to the soil management view
        let soilManagementTitle = app.navigationBars["Soil Management"]
        XCTAssertTrue(soilManagementTitle.waitForExistence(timeout: 3), "Should return to Soil Management view")
    }
    
    // MARK: - Garden Showcase (Public CloudKit) Tests
    
    func testGardenShowcaseView() throws {
        throw XCTSkip("Garden Showcase feature not implemented — no Profile tab exists")
    }
    
    // MARK: - Subscription/Paywall Tests
    
    func testPaywallView() throws {
        throw XCTSkip("Paywall/Subscription feature not implemented — no Profile tab exists")
    }

    func testRestorePurchases() throws {
        throw XCTSkip("Paywall/Subscription feature not implemented — no Profile tab exists")
    }
}

// MARK: - Performance Tests

@MainActor
class Phase3And4PerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--reset-data"]
        app.launch()
    }

    func testCompanionPlantingLookupPerformance() throws {
        measure {
            // Navigate to My Garden
            app.tabBars.buttons["My Garden"].tap()
            
            // Add Plant
            if app.buttons["Add Plant"].exists {
                app.buttons["Add Plant"].tap()
                
                // Type plant name
                let nameField = app.textFields["Plant name text field"]
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Tomato")
                }
                
                // Cancel
                app.buttons["Cancel"].tap()
            }
        }
    }
    
    func testSoilLogCreationPerformance() throws {
        measure {
            // Navigate through soil log creation flow
            app.tabBars.buttons["My Garden"].tap()
            
            let plantCell = app.cells.firstMatch
            if plantCell.waitForExistence(timeout: 1) {
                plantCell.tap()
                app.swipeUp()
                
                // Navigate back
                if app.buttons["Back"].exists {
                    app.buttons["Back"].tap()
                }
            }
        }
    }
}
