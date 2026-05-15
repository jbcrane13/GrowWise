import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@Suite("ClubCloudKitService")
@MainActor
struct ClubCloudKitServiceTests {
    @Test("activity cloud fields include garden context and photo URL")
    func activityCloudFieldsIncludeGardenContext() throws {
        let clubID = UUID()
        let activity = ClubActivity(
            clubID: clubID,
            memberName: "Blake",
            memberID: "member-1",
            activityType: "shared",
            description: "Basil: First harvest"
        )
        activity.id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        activity.gardenName = "Backyard Garden"
        activity.photoURL = "file:///tmp/club-photo.jpg"

        let fields = try ClubCloudKitService.recordFields(from: activity)

        #expect(fields.recordName == "11111111-1111-1111-1111-111111111111")
        #expect(fields.clubID == clubID.uuidString)
        #expect(fields.memberName == "Blake")
        #expect(fields.memberID == "member-1")
        #expect(fields.activityType == "shared")
        #expect(fields.activityDescription == "Basil: First harvest")
        #expect(fields.gardenName == "Backyard Garden")
        #expect(fields.photoURL == "file:///tmp/club-photo.jpg")
    }

    @Test("database scope routes owners to private and invited members to shared")
    func databaseScopeForOwnerAndMember() {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "ABC123")

        #expect(ClubCloudKitService.databaseScope(for: club, memberID: "owner-1") == .ownerPrivate)
        #expect(ClubCloudKitService.databaseScope(for: club, memberID: "member-2") == .sharedParticipant)
        #expect(ClubCloudKitService.databaseScope(for: nil, memberID: "member-2") == .ownerPrivate)
    }
}
