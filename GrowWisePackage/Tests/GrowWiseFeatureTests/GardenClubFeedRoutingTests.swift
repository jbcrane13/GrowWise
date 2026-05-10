import Foundation
@testable import GrowWiseFeature
import GrowWiseModels
import SwiftData
import Testing

@Suite("Garden Club tab routing")
struct GardenClubFeedRoutingTests {
    @Test("Zero clubs routes to join/create prompt")
    func zeroClubsRoutesToJoinPrompt() {
        let route = GardenClubTabRoute.resolve(clubs: [])
        #expect(route == .joinOrCreate)
    }

    @Test("Exactly one club routes to its feed")
    func oneClubRoutesToFeed() {
        let club = GardenClub(name: "Test Club", ownerID: "user-1", inviteCode: "ABC123")
        let route = GardenClubTabRoute.resolve(clubs: [club])
        guard case .feed(let resolvedClub) = route else {
            Issue.record("expected .feed route, got \(route)")
            return
        }
        #expect(resolvedClub.name == "Test Club")
    }

    @Test("Multiple clubs routes to list")
    func multipleClubsRoutesToList() {
        let firstClub = GardenClub(name: "A", ownerID: "user-1", inviteCode: "AAAAAA")
        let secondClub = GardenClub(name: "B", ownerID: "user-1", inviteCode: "BBBBBB")
        let route = GardenClubTabRoute.resolve(clubs: [firstClub, secondClub])
        guard case .list(let clubs) = route else {
            Issue.record("expected .list route, got \(route)")
            return
        }
        #expect(clubs.count == 2)
    }

    @Test("ClubActivity view data carries optional photo URL")
    func clubActivityViewDataCarriesPhotoURL() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Avery",
            memberID: "user-1",
            activityType: "shared",
            description: "First tomato flower"
        )
        activity.photoURL = "file:///tmp/tomato.jpg"

        let viewData = GardenClubFeedView.viewData(from: activity)

        #expect(viewData.photoURL == "file:///tmp/tomato.jpg")
    }
}
