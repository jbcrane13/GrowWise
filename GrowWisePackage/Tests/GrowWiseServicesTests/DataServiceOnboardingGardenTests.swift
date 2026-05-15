@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("DataService onboarding garden creation")
struct DataServiceOnboardingGardenTests {
    @Test("createGarden stores onboarding space and associates the current user")
    func createGardenStoresOnboardingSpaceAndUser() throws {
        let dataService = try DataService.makeForTesting()
        let user = try dataService.createUser(
            email: "gardener@example.com",
            displayName: "Gardener",
            skillLevel: .beginner
        )

        let garden = try dataService.createGarden(
            name: "Patio Starter",
            type: .container,
            isIndoor: false,
            spaceSize: .tiny
        )

        #expect(garden.name == "Patio Starter")
        #expect(garden.gardenType == .container)
        #expect(garden.isIndoor == false)
        #expect(garden.spaceAvailable == .tiny)
        #expect(garden.user?.id == user.id)
    }

    @Test("createGardenBed persists a container in the selected garden")
    func createGardenBedPersistsContainerInGarden() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(
            name: "Patio Starter",
            type: .container,
            isIndoor: false
        )

        let bed = try dataService.createGardenBed(
            name: "Herb Pot",
            bedType: .pot,
            in: garden
        )

        let gardenBeds = garden.beds ?? []
        #expect(bed.name == "Herb Pot")
        #expect(bed.bedType == .pot)
        #expect(bed.garden?.id == garden.id)
        #expect(gardenBeds.contains { $0.id == bed.id })
    }
}
