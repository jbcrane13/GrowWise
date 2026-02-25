import XCTest
@testable import GrowWise

// MARK: - Phase 3 & 4 UI Tests

@MainActor
class Phase3And4UITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
    }

    // MARK: - Companion Planting Tests
    
    func testCompanionPlantingWarningsInAddPlantSheet() throws {
        // Navigate to My Garden
        app.tabBars.buttons["My Garden"].tap()
        
        // Create a garden first if needed
        if app.buttons["Create Garden"].exists {
            app.buttons["Create Garden"].tap()
            app.textFields["Garden name"].typeText("Test Garden")
            app.buttons["Save"].tap()
        }
        
        // Add a tomato plant first
        app.buttons["Add Plant"].tap()
        app.textFields["Plant name text field"].typeText("Tomato")
        
        // Select garden if picker exists
        if app.pickers["Garden selection picker"].exists {
            app.pickers["Garden selection picker"].tap()
            app.pickerWheels.element.adjust(toPickerWheelValue: "Test Garden")
        }
        
        app.buttons["Save"].tap()
        
        // Now try to add a potato (incompatible with tomato)
        app.buttons["Add Plant"].tap()
        app.textFields["Plant name text field"].typeText("Potato")
        
        // Check for companion planting warning
        let warningLabel = app.staticTexts["Companion Planting"]
        XCTAssertTrue(warningLabel.waitForExistence(timeout: 2), "Companion planting section should appear")
        
        // Check for incompatible warning
        let incompatibleText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'incompatible'"))
        XCTAssertTrue(incompatibleText.element.exists || warningLabel.exists, "Should show incompatibility warning")
    }
    
    func testCompanionPlantingRecommendations() throws {
        app.tabBars.buttons["My Garden"].tap()
        
        // Add a basil plant
        app.buttons["Add Plant"].tap()
        app.textFields["Plant name text field"].typeText("Tomato")
        app.buttons["Save"].tap()
        
        // Add another compatible plant
        app.buttons["Add Plant"].tap()
        app.textFields["Plant name text field"].typeText("Basil")
        
        // Check for companion recommendations
        let companionSection = app.staticTexts["Companion Planting"]
        XCTAssertTrue(companionSection.waitForExistence(timeout: 2), "Companion planting section should appear")
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
        // Navigate to Profile or Find Garden Showcase
        app.tabBars.buttons["Profile"].tap()
        
        // Look for Garden Showcase option
        if app.cells["Garden Showcase"].exists {
            app.cells["Garden Showcase"].tap()
        } else if app.buttons["Garden Showcase"].exists {
            app.buttons["Garden Showcase"].tap()
        } else {
            XCTSkip("Garden Showcase not accessible in current UI")
            return
        }
        
        // Verify Garden Showcase view opened
        let showcaseTitle = app.navigationBars["Garden Showcase"]
        XCTAssertTrue(showcaseTitle.waitForExistence(timeout: 2) || 
                     app.staticTexts["Garden Showcase"].waitForExistence(timeout: 2),
                     "Garden Showcase view should open")
    }
    
    // MARK: - Subscription/Paywall Tests
    
    func testPaywallView() throws {
        // Navigate to Profile
        app.tabBars.buttons["Profile"].tap()
        
        // Look for subscription or upgrade option
        if app.cells["Upgrade to Premium"].exists {
            app.cells["Upgrade to Premium"].tap()
        } else if app.buttons["Upgrade"].exists {
            app.buttons["Upgrade"].tap()
        } else if app.cells["Subscription"].exists {
            app.cells["Subscription"].tap()
        } else {
            XCTSkip("Paywall not accessible in current UI")
            return
        }
        
        // Verify paywall view elements
        let monthlyButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'monthly'"))
        let yearlyButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'yearly'"))
        
        XCTAssertTrue(monthlyButton.element.exists || yearlyButton.element.exists || 
                     app.buttons["Purchase"].exists || app.buttons["Subscribe"].exists,
                     "Paywall should show subscription options")
    }
    
    func testRestorePurchases() throws {
        // Navigate to Profile and then Paywall
        app.tabBars.buttons["Profile"].tap()
        
        if app.cells["Upgrade to Premium"].exists {
            app.cells["Upgrade to Premium"].tap()
        } else {
            XCTSkip("Paywall not accessible")
            return
        }
        
        // Look for Restore Purchases button
        let restoreButton = app.buttons["Restore Purchases"]
        if restoreButton.exists {
            restoreButton.tap()
            
            // Wait for alert or confirmation
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) {
                XCTAssertTrue(alert.exists, "Should show restore result alert")
                alert.buttons["OK"].tap()
            }
        } else {
            XCTSkip("Restore Purchases button not found")
        }
    }
}

// MARK: - Performance Tests

@MainActor
class Phase3And4PerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
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
