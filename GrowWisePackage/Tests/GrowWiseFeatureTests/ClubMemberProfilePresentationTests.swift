import Foundation
@testable import GrowWiseFeature
import GrowWiseModels
import Testing

@Suite("Club Member Profile Presentation")
struct ClubMemberProfilePresentationTests {
    @Test("Public member profile exposes opted-in profile details")
    func publicMemberProfileExposesOptedInDetails() {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "GROW42")
        let joinedDate = Date(timeIntervalSince1970: 1_700_000_000)
        club.createdDate = joinedDate

        let user = User(email: "avery@example.com", displayName: "Avery Brooks")
        user.isProfilePublic = true
        user.bio = "Seed saver and patio tomato person."
        user.hardinessZone = "7b"

        let garden = Garden(name: "Patio Garden", gardenType: .container)
        let plant = Plant(name: "Sungold Tomato", plantType: .vegetable)
        garden.plants = [plant]
        user.gardens = [garden]
        club.memberIDs = ["owner-1", user.id.uuidString]
        club.sharedGardenIDs = [garden.id?.uuidString ?? "missing"]

        let activities = makeActivities(
            clubID: club.id ?? UUID(),
            memberID: user.id.uuidString,
            memberName: "Avery Brooks"
        )

        let profile = ClubMemberProfile(
            memberID: user.id.uuidString,
            club: club,
            user: user,
            activities: activities,
            currentUserID: "other-member",
            followedMemberIDs: [user.id.uuidString]
        )

        #expect(profile.canShowPublicDetails)
        #expect(profile.displayName == "Avery Brooks")
        #expect(profile.avatarLetters == "AB")
        #expect(profile.bio == "Seed saver and patio tomato person.")
        #expect(profile.hardinessZone == "7b")
        #expect(profile.memberSinceDate == joinedDate)
        #expect(profile.plantCount == 1)
        #expect(profile.publicGardenCount == 1)
        #expect(profile.isFollowed)
        #expect(profile.recentContributions.map { $0.activityDescription ?? "" } == [
            "Newest update",
            "Second update",
            "Third update",
        ])
    }

    @Test("Private member profile hides details from other members")
    func privateMemberProfileHidesDetailsFromOtherMembers() {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "GROW42")
        let user = User(email: "mina@example.com", displayName: "Mina Patel")
        user.isProfilePublic = false
        user.bio = "Likes peppers."
        user.hardinessZone = "9a"
        user.gardens = [Garden(name: "Pepper Patch", gardenType: .raised)]
        // Use a fixed memberID so the expected avatar letter is deterministic.
        // First alphanumeric of "bce-member-99" is 'B'.
        let fixedMemberID = "bce-member-99"

        let profile = ClubMemberProfile(
            memberID: fixedMemberID,
            club: club,
            user: user,
            activities: [],
            currentUserID: "other-member",
            followedMemberIDs: []
        )

        #expect(!profile.canShowPublicDetails)
        #expect(profile.displayName == "Club member")
        #expect(profile.avatarLetters == "B")
        #expect(profile.bio == nil)
        #expect(profile.hardinessZone == nil)
        #expect(profile.plantCount == nil)
        #expect(profile.publicGardenCount == nil)
        #expect(profile.recentContributions.isEmpty)
    }

    @Test("Current user can view their own private profile")
    func currentUserCanViewOwnPrivateProfile() {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "GROW42")
        let user = User(email: "sam@example.com", displayName: "Sam Rivera")
        user.isProfilePublic = false
        user.hardinessZone = "6a"

        let profile = ClubMemberProfile(
            memberID: user.id.uuidString,
            club: club,
            user: user,
            activities: [],
            currentUserID: user.id.uuidString,
            followedMemberIDs: [user.id.uuidString]
        )

        #expect(profile.canShowPublicDetails)
        #expect(profile.displayName == "Sam Rivera")
        #expect(profile.hardinessZone == "6a")
        #expect(profile.isCurrentUser)
        #expect(!profile.isFollowed)
    }

    private func makeActivities(
        clubID: UUID,
        memberID: String,
        memberName: String
    ) -> [ClubActivity] {
        let descriptions = [
            "Oldest update",
            "Third update",
            "Second update",
            "Newest update",
        ]

        return descriptions.enumerated().map { offset, description in
            let activity = ClubActivity(
                clubID: clubID,
                memberName: memberName,
                memberID: memberID,
                activityType: "shared",
                description: description
            )
            activity.timestamp = Date(timeIntervalSince1970: TimeInterval(offset))
            return activity
        }
    }
}
