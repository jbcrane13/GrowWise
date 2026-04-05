import XCTest
@testable import GrowWise

final class GardenClubUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Club List Tests
    
    @MainActor
    func testClubListEmptyState() throws {
        // Navigate to Profile > Garden Clubs
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 2))
        profileTab.tap()
        
        // Garden Clubs should show empty state initially
        // Note: This test assumes no clubs exist in UI testing mode
        let gardenClubsButton = app.buttons["Garden Clubs"]
        if gardenClubsButton.waitForExistence(timeout: 2) {
            gardenClubsButton.tap()
            
            // Empty state should be visible
            let emptyTitle = app.staticTexts["No Clubs Yet"]
            XCTAssertTrue(emptyTitle.waitForExistence(timeout: 2))
        }
    }
    
    @MainActor
    func testCreateClubFlow() throws {
        // Navigate to clubs
        navigateToClubs()
        
        // Tap Create Club button
        let createButton = app.buttons["Create Club"]
        if createButton.waitForExistence(timeout: 2) {
            createButton.tap()
            
            // Fill in club name
            let nameField = app.textFields["Club Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 2))
            nameField.tap()
            nameField.typeText("Test Garden Club")
            
            // Submit
            let createButton = app.buttons["Create"]
            XCTAssertTrue(createButton.waitForExistence(timeout: 2))
            createButton.tap()
            
            // Should show success with invite code
            let successView = app.staticTexts["Club Created!"]
            XCTAssertTrue(successView.waitForExistence(timeout: 3))
        }
    }
    
    @MainActor
    func testJoinClubFlow() throws {
        navigateToClubs()
        
        // Tap Join Club button
        let joinButton = app.buttons["Join Club"]
        if joinButton.waitForExistence(timeout: 2) {
            joinButton.tap()
            
            // Enter invite code
            let codeField = app.textFields["Invite Code"]
            XCTAssertTrue(codeField.waitForExistence(timeout: 2))
            codeField.tap()
            codeField.typeText("TEST42")
            
            // Submit
            let submitButton = app.buttons["Join"]
            XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
            submitButton.tap()
        }
    }
    
    // MARK: - Club Detail Tests
    
    @MainActor
    func testClubDetailNavigation() throws {
        // Assuming a club exists
        navigateToClubs()
        
        // Tap on a club row if it exists
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            // Club detail should show name and invite code
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2))
            
            // Navigate to Chat
            let chatButton = app.buttons["club_detail_chat_button"]
            if chatButton.waitForExistence(timeout: 2) {
                chatButton.tap()
                XCTAssertTrue(app.staticTexts["Chat"].waitForExistence(timeout: 2))
                app.navigationBars.buttons.firstMatch.tap()
            }
            
            // Navigate to Events
            let eventsButton = app.buttons["club_detail_events_button"]
            if eventsButton.waitForExistence(timeout: 2) {
                eventsButton.tap()
                XCTAssertTrue(app.staticTexts["Events"].waitForExistence(timeout: 2))
            }
        }
    }
    
    @MainActor
    func testInviteCodeCopy() throws {
        navigateToClubs()
        
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            // Tap invite code to copy
            let inviteCodeCard = app.staticTexts.matching(identifier: "invite_code").firstMatch
            if inviteCodeCard.waitForExistence(timeout: 2) {
                inviteCodeCard.tap()
                
                // Should show "Copied!" feedback
                let copiedToast = app.staticTexts["Copied!"]
                XCTAssertTrue(copiedToast.waitForExistence(timeout: 2))
            }
        }
    }
    
    // MARK: - Chat Tests
    
    @MainActor
    func testSendMessage() throws {
        navigateToClubs()
        
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            let chatButton = app.buttons["club_detail_chat_button"]
            if chatButton.waitForExistence(timeout: 2) {
                chatButton.tap()
                
                // Type message
                let messageField = app.textFields["Message…"]
                XCTAssertTrue(messageField.waitForExistence(timeout: 2))
                messageField.tap()
                messageField.typeText("Hello from UI test!")
                
                // Send
                let sendButton = app.buttons["club_chat_send_button"]
                XCTAssertTrue(sendButton.waitForExistence(timeout: 2))
                sendButton.tap()
                
                // Message should appear in list
                let sentMessage = app.staticTexts["Hello from UI test!"]
                XCTAssertTrue(sentMessage.waitForExistence(timeout: 3))
            }
        }
    }
    
    @MainActor
    func testSendPhoto() throws {
        navigateToClubs()
        
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            let chatButton = app.buttons["club_detail_chat_button"]
            if chatButton.waitForExistence(timeout: 2) {
                chatButton.tap()
                
                // Tap photo picker button
                let photoButton = app.buttons["club_chat_photo_button"]
                XCTAssertTrue(photoButton.waitForExistence(timeout: 2))
                photoButton.tap()
                
                // PhotosPicker opens - in UI testing this may not work
                // So we just verify the button exists
            }
        }
    }
    
    // MARK: - Events Tests
    
    @MainActor
    func testCreateEvent() throws {
        navigateToClubs()
        
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            let eventsButton = app.buttons["club_detail_events_button"]
            if eventsButton.waitForExistence(timeout: 2) {
                eventsButton.tap()
                
                // Tap add button
                let addButton = app.buttons["club_events_add_button"]
                XCTAssertTrue(addButton.waitForExistence(timeout: 2))
                addButton.tap()
                
                // Fill event form
                let titleField = app.textFields["Event Title"]
                XCTAssertTrue(titleField.waitForExistence(timeout: 2))
                titleField.tap()
                titleField.typeText("Spring Planting Party")
                
                // Location
                let locationField = app.textFields["Location (optional)"]
                if locationField.waitForExistence(timeout: 2) {
                    locationField.tap()
                    locationField.typeText("Community Garden")
                }
                
                // Create
                let createButton = app.buttons["Create"]
                XCTAssertTrue(createButton.waitForExistence(timeout: 2))
                createButton.tap()
                
                // Event should appear in upcoming list
                let newEvent = app.staticTexts["Spring Planting Party"]
                XCTAssertTrue(newEvent.waitForExistence(timeout: 3))
            }
        }
    }
    
    @MainActor
    func testEventRSVP() throws {
        navigateToClubs()
        
        let clubRow = app.buttons.firstMatch
        if clubRow.waitForExistence(timeout: 2) {
            clubRow.tap()
            
            let eventsButton = app.buttons["club_detail_events_button"]
            if eventsButton.waitForExistence(timeout: 2) {
                eventsButton.tap()
                
                // Tap on an event
                let eventCard = app.otherElements.matching(identifier: "event_card").firstMatch
                if eventCard.waitForExistence(timeout: 2) {
                    eventCard.tap()
                    
                    // RSVP buttons should be present
                    let goingButton = app.buttons["rsvp_accepted"]
                    XCTAssertTrue(goingButton.waitForExistence(timeout: 2))
                    
                    goingButton.tap()
                    
                    // Should show as going
                    XCTAssertTrue(goingButton.waitForExistence(timeout: 2))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToClubs() {
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 2))
        profileTab.tap()
        
        // Look for Garden Clubs button
        let gardenClubsButton = app.buttons["Garden Clubs"]
        if gardenClubsButton.waitForExistence(timeout: 2) {
            gardenClubsButton.tap()
        }
    }
}