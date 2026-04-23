import Foundation
import Testing
@testable import GrowWiseModels

@Suite("GardenClub Model Tests")
struct GardenClubTests {
    
    @Test("GardenClub initializes with correct defaults")
    func testInitialization() {
        let club = GardenClub(name: "Test Club", ownerID: "user-123", inviteCode: "TEST42")
        
        #expect(club.name == "Test Club")
        #expect(club.ownerID == "user-123")
        #expect(club.inviteCode == "TEST42")
        #expect(club.memberIDs?.count == 1)
        #expect(club.memberIDs?.contains("user-123") == true)
        #expect(club.sharedGardenIDs?.isEmpty == true)
        #expect(club.isActive == true)
        #expect(club.id != nil)
    }
    
    @Test("GardenClub member count updates correctly")
    func testMemberCount() {
        let club = GardenClub(name: "Garden Friends", ownerID: "owner", inviteCode: "ABC123")
        
        #expect(club.memberIDs?.count == 1)
        
        // Simulate adding members
        club.memberIDs = (club.memberIDs ?? []) + ["member2", "member3"]
        #expect(club.memberIDs?.count == 3)
    }
    
    @Test("GardenClub invite code is unique")
    func testUniqueInviteCode() {
        let club1 = GardenClub(name: "Club 1", ownerID: "user1", inviteCode: "AAAAAA")
        let club2 = GardenClub(name: "Club 2", ownerID: "user2", inviteCode: "BBBBBB")
        
        #expect(club1.inviteCode != club2.inviteCode)
        #expect(club1.id != club2.id)
    }
}

@Suite("ClubActivity Model Tests")
struct ClubActivityTests {
    
    @Test("ClubActivity initializes with correct defaults")
    func testInitialization() {
        let activity = ClubActivity(clubID: UUID(), memberName: "Jane", memberID: "user-1", activityType: "planted", description: "Planted tomatoes")
        
        #expect(activity.activityType == "planted")
        #expect(activity.memberName == "Jane")
        #expect(activity.memberID == "user-1")
        #expect(activity.activityDescription == "Planted tomatoes")
        #expect(activity.timestamp != nil)
        #expect(activity.id != nil)
    }
    
    @Test("ClubActivity supports various activity types")
    func testActivityTypes() {
        let types = ["watered", "harvested", "planted", "journaled", "diagnosed"]
        
        for type in types {
            let activity = ClubActivity(clubID: UUID(), memberName: "Test", memberID: "user", activityType: type, description: "\(type) action")
            #expect(activity.activityType == type)
        }
    }
}

@Suite("ClubMessage Model Tests")
struct ClubMessageTests {
    
    @Test("ClubMessage initializes with text only")
    func testTextMessage() {
        let clubID = UUID()
        let message = ClubMessage(clubID: clubID, senderName: "Alice", senderID: "user-1", text: "Hello everyone!")
        
        #expect(message.clubID == clubID)
        #expect(message.senderName == "Alice")
        #expect(message.senderID == "user-1")
        #expect(message.text == "Hello everyone!")
        #expect(message.photoData == nil)
        #expect(message.timestamp != nil)
    }
    
    @Test("ClubMessage can include photo data")
    func testPhotoMessage() {
        let clubID = UUID()
        let photoData = "fake-image-data".data(using: .utf8)!
        let message = ClubMessage(clubID: clubID, senderName: "Bob", senderID: "user-2", text: "Check out my tomatoes!")
        message.photoData = photoData
        
        #expect(message.photoData == photoData)
        #expect(message.text == "Check out my tomatoes!")
    }
}

@Suite("ClubEvent Model Tests")
struct ClubEventTests {
    
    @Test("ClubEvent initializes with correct defaults")
    func testInitialization() {
        let clubID = UUID()
        let startDate = Date()
        let event = ClubEvent(clubID: clubID, title: "Spring Planting Party", startDate: startDate, createdBy: "user-1")
        
        #expect(event.title == "Spring Planting Party")
        #expect(event.clubID == clubID)
        #expect(event.startDate == startDate)
        #expect(event.endDate == nil)
        #expect(event.eventDescription == nil)
        #expect(event.location == nil)
        #expect(event.createdBy == "user-1")
        #expect(event.rsvpAccepted?.count == 1)
        #expect(event.rsvpAccepted?.contains("user-1") == true)
        #expect(event.rsvpDeclined?.isEmpty == true)
        #expect(event.rsvpMaybe?.isEmpty == true)
    }
    
    @Test("ClubEvent supports location and description")
    func testEventDetails() {
        let event = ClubEvent(clubID: UUID(), title: "Meetup", startDate: Date(), createdBy: "user-1")
        event.eventDescription = "Bring your seeds!"
        event.location = "Community Garden, 123 Main St"
        event.endDate = Date().addingTimeInterval(7200) // 2 hours later
        
        #expect(event.eventDescription == "Bring your seeds!")
        #expect(event.location == "Community Garden, 123 Main St")
        #expect(event.endDate != nil)
    }
    
    @Test("ClubEvent RSVP tracking")
    func testRSVPTracking() {
        let event = ClubEvent(clubID: UUID(), title: "Workshop", startDate: Date(), createdBy: "host")
        
        // Creator is automatically accepted
        #expect(event.rsvpAccepted?.count == 1)
        
        // Add more RSVPs
        event.rsvpAccepted = (event.rsvpAccepted ?? []) + ["user-2", "user-3"]
        event.rsvpMaybe = ["user-4"]
        event.rsvpDeclined = ["user-5"]
        
        #expect(event.rsvpAccepted?.count == 3)
        #expect(event.rsvpMaybe?.count == 1)
        #expect(event.rsvpDeclined?.count == 1)
    }
}