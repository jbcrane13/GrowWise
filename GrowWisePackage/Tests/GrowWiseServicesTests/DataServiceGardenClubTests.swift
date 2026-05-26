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

    @Test("createClubPost stores current user's hardiness zone")
    func createClubPostStoresHardinessZone() async throws {
        let service = try await DataService.makeForTesting()
        let user = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)
        user.hardinessZone = "7b"
        _ = try service.createClub(name: "Backyard Growers", ownerID: user.id.uuidString)

        let activity = try service.createClubPost(caption: "Tomatoes are blooming", activityType: "shared")

        #expect(activity.hardinessZone == "7b")
    }

    @Test("followClubMember persists unique followed member IDs")
    func followClubMemberPersistsUniqueIDs() async throws {
        let service = try await DataService.makeForTesting()
        _ = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)

        try service.followClubMember("member-2")
        try service.followClubMember("member-2")
        try service.followClubMember("member-3")

        #expect(service.getCurrentUser()?.followedMemberIDs == ["member-2", "member-3"])
        #expect(service.isFollowingClubMember("member-2") == true)
    }

    @Test("follow lookups normalize member IDs")
    func followLookupNormalizesMemberIDs() async throws {
        let service = try await DataService.makeForTesting()
        _ = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)

        try service.followClubMember(" member-2 ")

        #expect(service.getCurrentUser()?.followedMemberIDs == ["member-2"])
        #expect(service.isFollowingClubMember(" member-2 ") == true)
    }

    @Test("unfollowClubMember removes member ID")
    func unfollowClubMemberRemovesID() async throws {
        let service = try await DataService.makeForTesting()
        _ = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)

        try service.followClubMember("member-2")
        try service.unfollowClubMember("member-2")

        #expect(service.getCurrentUser()?.followedMemberIDs?.isEmpty == true)
        #expect(service.isFollowingClubMember("member-2") == false)
    }

    @Test("sharePlant marks plant as shared with club and unshare keeps owner plant private")
    func sharePlantAndUnsharePlant() async throws {
        let service = try await DataService.makeForTesting()
        let user = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)
        let club = try service.createClub(name: "Backyard Growers", ownerID: user.id.uuidString)
        let plant = try service.createPlant(name: "Tomato", type: .vegetable)

        try service.sharePlant(plant, withClub: club)

        #expect(plant.sharedWithClubID == club.id)
        #expect(plant.sharedOwnerID == user.id.uuidString)
        #expect(plant.isReadOnlySharedPlant(for: user.id.uuidString) == false)

        try service.unsharePlant(plant)

        #expect(plant.sharedWithClubID == nil)
        #expect(plant.sharedOwnerID == nil)
        #expect(service.fetchPlants().contains { $0.id == plant.id })
    }

    @Test("completeReminder posts care activity for shared watering fertilizing and pruning")
    func completeSharedCareReminderPostsClubActivity() async throws {
        let service = try await DataService.makeForTesting()
        let user = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)
        let club = try service.createClub(name: "Backyard Growers", ownerID: user.id.uuidString)
        let plant = try service.createPlant(name: "Basil", type: .herb)
        try service.sharePlant(plant, withClub: club)

        let watering = try service.createReminder(
            title: "Water Basil",
            message: "Water your basil",
            type: .watering,
            frequency: .daily,
            dueDate: Date(),
            plant: plant
        )
        let fertilizing = try service.createReminder(
            title: "Feed Basil",
            message: "Feed your basil",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: Date(),
            plant: plant
        )
        let pruning = try service.createReminder(
            title: "Prune Basil",
            message: "Prune your basil",
            type: .pruning,
            frequency: .weekly,
            dueDate: Date(),
            plant: plant
        )

        try service.completeReminder(watering)
        try service.completeReminder(fertilizing)
        try service.completeReminder(pruning)

        let activityTypes = try service.fetchClubActivities(for: club.id ?? UUID()).compactMap(\.activityType)
        #expect(activityTypes.contains("watered"))
        #expect(activityTypes.contains("fertilized"))
        #expect(activityTypes.contains("pruned"))
    }

    @Test("claimed shared reminders can only be completed by the assignee")
    func claimedSharedReminderCompletionRequiresAssignee() async throws {
        let service = try await DataService.makeForTesting()
        let user = try service.createUser(email: "owner@example.com", displayName: "Owner", skillLevel: .beginner)
        let club = try service.createClub(name: "Backyard Growers", ownerID: user.id.uuidString)
        let plant = try service.createPlant(name: "Rosemary", type: .herb)
        try service.sharePlant(plant, withClub: club)
        let reminder = try service.createReminder(
            title: "Water Rosemary",
            message: "Water your rosemary",
            type: .watering,
            frequency: .daily,
            dueDate: Date(),
            plant: plant
        )

        try service.claimReminder(reminder, memberID: "member-2", memberName: "Alice")

        #expect(throws: ReminderAssignmentError.notAssignedToCurrentMember) {
            try service.completeReminder(reminder)
        }

        try service.releaseReminderAssignment(reminder)
        try service.claimReminder(reminder, memberID: user.id.uuidString, memberName: "Owner")
        try service.completeReminder(reminder)

        #expect(reminder.assignedMemberID == nil)
        #expect(reminder.assignedMemberName == nil)
    }
}
