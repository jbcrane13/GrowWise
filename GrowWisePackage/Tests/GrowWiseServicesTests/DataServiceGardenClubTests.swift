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

    @Test("createClubPost persists selected garden context")
    func createClubPostWithGardenName() async throws {
        let service = try await DataService.makeForTesting()
        let club = try service.createClub(name: "Backyard Growers", ownerID: "u1")

        let activity = try service.createClubPost(
            caption: "First basil harvest",
            activityType: "shared",
            plantName: "Basil",
            gardenName: "Backyard Garden",
            club: club
        )

        #expect(activity.activityDescription == "Basil: First basil harvest")
        #expect(activity.gardenName == "Backyard Garden")
        #expect(activity.clubID == club.id)
    }

    @Test("createClubPost can target an explicit club and persist a photo URL")
    func createClubPostWithExplicitClubAndPhotoURL() async throws {
        let service = try await DataService.makeForTesting()
        let firstClub = try service.createClub(name: "First Club", ownerID: "u1")
        let secondClub = try service.createClub(name: "Second Club", ownerID: "u1")
        let photoURL = "file:///tmp/club-photo.jpg"

        let activity = try service.createClubPost(
            caption: "First tomato flower",
            activityType: "shared",
            club: secondClub,
            photoURL: photoURL
        )

        #expect(activity.clubID == secondClub.id)
        #expect(activity.clubID != firstClub.id)
        #expect(activity.photoURL == photoURL)
    }
}
