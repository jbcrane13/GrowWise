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

    @Test("ClubActivity view data carries member garden and zone context")
    func clubActivityViewDataCarriesMemberGardenAndZoneContext() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Avery",
            memberID: "user-1",
            activityType: "shared",
            description: "First tomato flower"
        )
        activity.gardenName = "Backyard Garden"
        activity.hardinessZone = "7b"

        let viewData = GardenClubFeedView.viewData(from: activity)

        #expect(viewData.memberID == "user-1")
        #expect(viewData.gardenName == "Backyard Garden")
        #expect(viewData.hardinessZone == "7b")
    }

    @Test("Nearby feed includes same-zone peers and excludes the current member")
    func nearbyFeedIncludesSameZonePeers() {
        let state = GardenClubFeedView.ClubFeedBetaState(
            posts: [
                makePost(memberID: "current", author: "Current", hardinessZone: "7b"),
                makePost(memberID: "peer", author: "Peer", hardinessZone: "7b"),
                makePost(memberID: "far", author: "Far", hardinessZone: "5a"),
                makePost(memberID: "unknown", author: "Unknown", hardinessZone: nil),
            ],
            currentMemberID: "current",
            currentZone: "7b",
            followedMemberIDs: []
        )

        let nearby = state.posts(for: .nearby)

        #expect(nearby.map(\.authorDisplayName) == ["Peer"])
    }

    @Test("Following feed includes only followed members")
    func followingFeedIncludesOnlyFollowedMembers() {
        let state = GardenClubFeedView.ClubFeedBetaState(
            posts: [
                makePost(memberID: "current", author: "Current", hardinessZone: "7b"),
                makePost(memberID: "followed", author: "Followed", hardinessZone: "7b"),
                makePost(memberID: "other", author: "Other", hardinessZone: "7b"),
            ],
            currentMemberID: "current",
            currentZone: "7b",
            followedMemberIDs: ["followed"]
        )

        let following = state.posts(for: .following)

        #expect(following.map(\.authorDisplayName) == ["Followed"])
    }

    private func makePost(
        memberID: String,
        author: String,
        hardinessZone: String?
    ) -> GardenClubFeedView.ClubActivityViewData {
        GardenClubFeedView.ClubActivityViewData(
            id: UUID(),
            memberID: memberID,
            authorDisplayName: author,
            caption: "Update",
            gardenName: "Backyard Garden",
            hardinessZone: hardinessZone,
            photoURL: nil,
            relativeTimeLabel: nil,
            likeCount: 0,
            commentCount: 0
        )
    }
}
