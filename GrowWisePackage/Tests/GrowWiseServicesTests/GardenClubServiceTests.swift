@testable import GrowWiseServices
import Testing

@Suite("GardenClubService Tests")
@MainActor
struct GardenClubServiceTests {
    @Test("createClub generates non-ambiguous six-character invite code")
    func createClubGeneratesInviteCode() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let service = GardenClubService(context: container.mainContext)

        let club = try service.createClub(name: "Backyard Growers", ownerID: "owner-1")
        let code = try #require(club.inviteCode)
        let allowedCharacters = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        #expect(code.count == 6)
        #expect(code.allSatisfy { allowedCharacters.contains($0) })
    }
}
