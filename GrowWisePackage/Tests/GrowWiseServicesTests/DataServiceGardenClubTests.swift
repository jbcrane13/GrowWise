@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@Suite("DataService — createClubPost")
@MainActor
struct DataServiceGardenClubTests {
    @Test("createClubPost throws noClub when user has no club")
    func createClubPostThrowsWhenNoClub() async throws {
        let service = try await DataService.makeForTesting()
        #expect(throws: CreateClubPostError.noClub) {
            try service.createClubPost(caption: "Hello", activityType: "shared")
        }
    }

    @Test("createClubPost saves activity with caption when club exists")
    func createClubPostSavesActivity() async throws {
        let service = try await DataService.makeForTesting()

        let club = try service.createClub(name: "Test Club", ownerID: "u1")
        _ = club // ensure it's in SwiftData

        let activity = try service.createClubPost(caption: "Tomatoes are coming in!", activityType: "shared")
        #expect(activity.activityDescription == "Tomatoes are coming in!")
        #expect(activity.activityType == "shared")
        #expect(activity.clubID == club.id)
    }

    @Test("createClubPost prefixes plant name when provided")
    func createClubPostWithPlantName() async throws {
        let service = try await DataService.makeForTesting()
        _ = try service.createClub(name: "Herb Garden Club", ownerID: "u1")

        let activity = try service.createClubPost(
            caption: "Looking healthy!",
            activityType: "shared",
            plantName: "Basil"
        )
        #expect(activity.activityDescription == "Basil: Looking healthy!")
    }
}
