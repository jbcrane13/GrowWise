import XCTest

final class DiscoveryUITests: XCTestCase {
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
    
    func testPlantDatabaseSearch() throws {
        let plantGuideTab = app.tabBars.buttons["Plant Guide"]
        XCTAssertTrue(plantGuideTab.waitForExistence(timeout: 5.0))
        plantGuideTab.tap()
        
        let navTitle = app.navigationBars["Plant Guide"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2.0))
        
        // Find Search Bar
        let searchField = app.searchFields["Search plants..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Fern")
            
            if app.keyboards.buttons["Search"].exists {
                app.keyboards.buttons["Search"].tap()
            }
        }
    }
    
    func testTutorialsFlow() throws {
        let tutorialsTab = app.tabBars.buttons["Learn"]
        XCTAssertTrue(tutorialsTab.waitForExistence(timeout: 5.0))
        tutorialsTab.tap()
        
        let navTitle = app.navigationBars["Learn & Grow"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2.0))
        
        // Find a tutorial card
        let tutorialCard = app.buttons.matching(identifier: "TutorialRow").firstMatch
        if tutorialCard.exists {
            tutorialCard.tap()
            
            // Should be on tutorial detail
            let startButton = app.buttons["Start Reading"]
            if startButton.waitForExistence(timeout: 2.0) {
                startButton.tap()
            }
            
            // Mark step complete
            let completeButton = app.buttons["Mark as Read"]
            if completeButton.waitForExistence(timeout: 2.0) {
                completeButton.tap()
            }
        }
    }
}
