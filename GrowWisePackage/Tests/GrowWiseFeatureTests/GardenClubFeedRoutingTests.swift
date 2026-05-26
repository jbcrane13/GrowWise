import Foundation
@testable import GrowWiseFeature
import GrowWiseModels
import SwiftData
import Testing

@Suite("Garden Club tab routing")
@MainActor
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

    @Test("ClubActivity view data carries garden context")
    func clubActivityViewDataCarriesGardenContext() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Avery",
            memberID: "user-1",
            activityType: "shared",
            description: "First tomato flower"
        )
        activity.gardenName = "Backyard Garden"

        let viewData = GardenClubFeedView.viewData(from: activity)

        #expect(viewData.gardenNameTag == "Backyard Garden")
    }

    @Test("Nearby feed shows same-zone posts from other growers")
    func nearbyFeedFiltersSameZonePosts() {
        let sameZone = clubActivity(
            memberID: "member-2",
            memberName: "Avery",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 300)
        )
        let currentUserPost = clubActivity(
            memberID: "member-1",
            memberName: "Blake",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 400)
        )
        let otherZone = clubActivity(
            memberID: "member-3",
            memberName: "Morgan",
            hardinessZone: "5a",
            timestamp: Date(timeIntervalSince1970: 500)
        )

        let posts = [sameZone, currentUserPost, otherZone].map(GardenClubFeedView.viewData(from:))
        let nearbyPosts = GardenClubFeedView.filteredPosts(
            posts,
            for: .nearby,
            currentZone: "7b",
            followedMemberIDs: [],
            currentMemberID: "member-1"
        )

        #expect(nearbyPosts.map(\.memberID) == ["member-2"])
    }

    @Test("Following feed shows only followed member posts")
    func followingFeedFiltersFollowedMemberPosts() {
        let followed = clubActivity(
            memberID: "member-2",
            memberName: "Avery",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 500)
        )
        let notFollowed = clubActivity(
            memberID: "member-3",
            memberName: "Morgan",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 600)
        )

        let posts = [notFollowed, followed].map(GardenClubFeedView.viewData(from:))
        let followingPosts = GardenClubFeedView.filteredPosts(
            posts,
            for: .following,
            currentZone: "7b",
            followedMemberIDs: ["member-2"],
            currentMemberID: "member-1"
        )

        #expect(followingPosts.map(\.memberID) == ["member-2"])
    }

    @Test("Following feed hides current user's posts even when followed IDs are stale")
    func followingFeedHidesCurrentUserPosts() {
        let currentUserPost = clubActivity(
            memberID: "member-1",
            memberName: "Blake",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 500)
        )
        let followed = clubActivity(
            memberID: "member-2",
            memberName: "Avery",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 600)
        )

        let posts = [currentUserPost, followed].map(GardenClubFeedView.viewData(from:))
        let followingPosts = GardenClubFeedView.filteredPosts(
            posts,
            for: .following,
            currentZone: "7b",
            followedMemberIDs: ["member-1", "member-2"],
            currentMemberID: "member-1"
        )

        #expect(followingPosts.map(\.memberID) == ["member-2"])
    }

    @Test("Following feed normalizes member IDs from persisted and CloudKit sources")
    func followingFeedNormalizesMemberIDs() {
        let followed = clubActivity(
            memberID: " member-2 ",
            memberName: "Avery",
            hardinessZone: "7b",
            timestamp: Date(timeIntervalSince1970: 600)
        )

        let posts = [followed].map(GardenClubFeedView.viewData(from:))
        let followingPosts = GardenClubFeedView.filteredPosts(
            posts,
            for: .following,
            currentZone: "7b",
            followedMemberIDs: ["member-2"],
            currentMemberID: "member-1"
        )

        #expect(followingPosts.count == 1)
    }

    @Test("Follow affordance normalizes current and followed member IDs")
    func followAffordanceNormalizesMemberIDs() {
        #expect(GardenClubFeedView.canFollowMember(" member-1 ", currentMemberID: "member-1") == false)
        #expect(GardenClubFeedView.isFollowingMember(" member-2 ", followedMemberIDs: ["member-2"]) == true)
    }

    private func clubActivity(
        memberID: String,
        memberName: String,
        hardinessZone: String,
        timestamp: Date
    ) -> ClubActivity {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: memberName,
            memberID: memberID,
            activityType: "shared",
            description: "\(memberName) shared a garden update"
        )
        activity.hardinessZone = hardinessZone
        activity.timestamp = timestamp
        return activity
    }
}
