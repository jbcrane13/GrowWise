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
        activity.hardinessZone = "7b"
        activity.photoURL = "file:///tmp/club-photo.jpg"
        activity.hardinessZone = "7b"

        let fields = try ClubCloudKitService.recordFields(from: activity)

        #expect(fields.recordName == "11111111-1111-1111-1111-111111111111")
        #expect(fields.clubID == clubID.uuidString)
        #expect(fields.memberName == "Blake")
        #expect(fields.memberID == "member-1")
        #expect(fields.activityType == "shared")
        #expect(fields.activityDescription == "Basil: First harvest")
        #expect(fields.gardenName == "Backyard Garden")
        #expect(fields.hardinessZone == "7b")
        #expect(fields.photoURL == "file:///tmp/club-photo.jpg")
        #expect(fields.hardinessZone == "7b")
    }

    @Test("database scope routes owners to private and invited members to shared")
    func databaseScopeForOwnerAndMember() {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "ABC123")

        #expect(ClubCloudKitService.databaseScope(for: club, memberID: "owner-1") == .ownerPrivate)
        #expect(ClubCloudKitService.databaseScope(for: club, memberID: "member-2") == .sharedParticipant)
        #expect(ClubCloudKitService.databaseScope(for: nil, memberID: "member-2") == .ownerPrivate)
    }

    @Test("shared plant cloud fields reuse club database scope")
    func sharedPlantCloudFieldsIncludeScope() throws {
        let club = GardenClub(name: "Backyard Growers", ownerID: "owner-1", inviteCode: "ABC123")
        let clubID = UUID()
        club.id = clubID

        let plant = Plant(name: "Basil", plantType: .herb)
        plant.id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")
        plant.sharedWithClubID = clubID
        plant.sharedOwnerID = "owner-1"

        let ownerFields = try ClubCloudKitService.recordFields(from: plant, club: club, memberID: "owner-1")
        let participantFields = try ClubCloudKitService.recordFields(from: plant, club: club, memberID: "member-2")

        #expect(ownerFields.recordName == "22222222-2222-2222-2222-222222222222")
        #expect(ownerFields.clubID == clubID.uuidString)
        #expect(ownerFields.ownerID == "owner-1")
        #expect(ownerFields.name == "Basil")
        #expect(ownerFields.plantType == PlantType.herb.rawValue)
        #expect(ownerFields.scope == .ownerPrivate)
        #expect(participantFields.scope == .sharedParticipant)
    }
}
