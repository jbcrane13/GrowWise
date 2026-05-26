import Testing
import SwiftData
@testable import GrowWiseModels
@testable import GrowWiseServices

@Suite("ClubRepository Tests")
@MainActor
struct ClubRepositoryTests {
    
    @Test("ClubRepository fetches active clubs")
    func testFetchActiveClubs() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        // Create test clubs
        let activeClub = GardenClub(name: "Active Club", ownerID: "user-1", inviteCode: "ACTIVE1")
        let inactiveClub = GardenClub(name: "Inactive Club", ownerID: "user-2", inviteCode: "INACTIV")
        inactiveClub.isActive = false
        
        context.insert(activeClub)
        context.insert(inactiveClub)
        try context.save()
        
        let repo = ClubRepository(context: context)
        let clubs = try repo.fetchActive()
        
        #expect(clubs.count == 1)
        #expect(clubs.first?.name == "Active Club")
    }
    
    @Test("ClubRepository finds club by invite code")
    func testFindByInviteCode() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let club = GardenClub(name: "Secret Garden Club", ownerID: "user-1", inviteCode: "SECRET")
        context.insert(club)
        try context.save()
        
        let repo = ClubRepository(context: context)
        let found = try repo.fetchByInviteCode("SECRET")
        
        #expect(found != nil)
        #expect(found?.name == "Secret Garden Club")
        
        let notFound = try repo.fetchByInviteCode("NOTFOUND")
        #expect(notFound == nil)
    }
    
    @Test("ClubRepository saves and deletes clubs")
    func testSaveAndDelete() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let repo = ClubRepository(context: context)
        
        // Save
        let club = GardenClub(name: "New Club", ownerID: "user-1", inviteCode: "NEWCLB")
        try repo.save(club)
        
        var found = try repo.fetchByInviteCode("NEWCLB")
        #expect(found != nil)
        
        // Delete
        try repo.delete(club)
        found = try repo.fetchByInviteCode("NEWCLB")
        #expect(found == nil)
    }
}

@Suite("ClubActivityRepository Tests")
@MainActor
struct ClubActivityRepositoryIntegrationTests {
    
    @Test("ClubActivityRepository fetches activities by club")
    func testFetchByClub() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let club1ID = UUID()
        let club2ID = UUID()
        
        // Create activities for different clubs
        let activity1 = ClubActivity(clubID: club1ID, memberName: "Alice", memberID: "user-1", activityType: "planted", description: "Planted tomatoes")
        let activity2 = ClubActivity(clubID: club1ID, memberName: "Bob", memberID: "user-2", activityType: "watered", description: "Watered garden")
        let activity3 = ClubActivity(clubID: club2ID, memberName: "Charlie", memberID: "user-3", activityType: "harvested", description: "Harvested basil")
        
        context.insert(activity1)
        context.insert(activity2)
        context.insert(activity3)
        try context.save()
        
        let repo = ClubActivityRepository(context: context)
        let club1Activities = try repo.fetchAll(for: club1ID)
        
        #expect(club1Activities.count == 2)
        #expect(club1Activities.allSatisfy { $0.clubID == club1ID })
    }
}

@Suite("ClubMessageRepository Tests")
@MainActor
struct ClubMessageRepositoryIntegrationTests {
    
    @Test("ClubMessageRepository fetches messages sorted by timestamp")
    func testFetchSorted() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let clubID = UUID()
        
        // Create messages with small time delays
        let msg1 = ClubMessage(clubID: clubID, senderName: "Alice", senderID: "user-1", text: "First")
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let msg2 = ClubMessage(clubID: clubID, senderName: "Bob", senderID: "user-2", text: "Second")
        try? await Task.sleep(nanoseconds: 10_000_000)
        let msg3 = ClubMessage(clubID: clubID, senderName: "Charlie", senderID: "user-3", text: "Third")
        
        context.insert(msg1)
        context.insert(msg2)
        context.insert(msg3)
        try context.save()
        
        let repo = ClubMessageRepository(context: context)
        let messages = try repo.fetchAll(for: clubID)
        
        #expect(messages.count == 3)
        // Messages should be sorted by timestamp ascending (oldest first)
        #expect(messages.first?.text == "First")
        #expect(messages.last?.text == "Third")
    }
    
    @Test("ClubMessageRepository saves and deletes messages")
    func testSaveAndDelete() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let clubID = UUID()
        let repo = ClubMessageRepository(context: context)
        
        let message = ClubMessage(clubID: clubID, senderName: "Test", senderID: "user-1", text: "Hello!")
        try repo.save(message)
        
        var messages = try repo.fetchAll(for: clubID)
        #expect(messages.count == 1)
        
        try repo.delete(message)
        messages = try repo.fetchAll(for: clubID)
        #expect(messages.isEmpty)
    }
}

@Suite("ClubEventRepository Tests")
@MainActor
struct ClubEventRepositoryIntegrationTests {
    
    @Test("ClubEventRepository fetches upcoming events")
    func testFetchUpcoming() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let clubID = UUID()
        let now = Date()
        
        // Past event
        let pastEvent = ClubEvent(clubID: clubID, title: "Past Event", startDate: now.addingTimeInterval(-86400), createdBy: "user-1")
        // Future events
        let future1 = ClubEvent(clubID: clubID, title: "Future 1", startDate: now.addingTimeInterval(3600), createdBy: "user-1")
        let future2 = ClubEvent(clubID: clubID, title: "Future 2", startDate: now.addingTimeInterval(86400), createdBy: "user-1")
        
        context.insert(pastEvent)
        context.insert(future1)
        context.insert(future2)
        try context.save()
        
        let repo = ClubEventRepository(context: context)
        let upcoming = try repo.fetchUpcoming(for: clubID)
        
        #expect(upcoming.count == 2)
        #expect(upcoming.allSatisfy { ($0.startDate ?? .distantPast) >= now })
    }
    
    @Test("ClubEventRepository saves and deletes events")
    func testSaveAndDelete() async throws {
        let container = try ModelContainerFactory.make(isUITesting: true)
        let context = container.mainContext
        
        let clubID = UUID()
        let repo = ClubEventRepository(context: context)
        
        let event = ClubEvent(clubID: clubID, title: "Test Event", startDate: Date(), createdBy: "user-1")
        try repo.save(event)
        
        var events = try repo.fetchAll(for: clubID)
        #expect(events.count == 1)
        
        try repo.delete(event)
        events = try repo.fetchAll(for: clubID)
        #expect(events.isEmpty)
    }
}
