import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("DataService plant template activation")
struct DataServicePlantTemplateTests {
    @Test("createUserPlant copies database-backed care fields into a garden plant")
    func createUserPlantCopiesTemplateFields() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "Kitchen Garden", type: .container, isIndoor: false)
        let template = try createTemplate(dataService: dataService)

        let plant = try dataService.createUserPlant(
            from: template,
            in: garden,
            plantingDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(plant.isUserPlant == true)
        #expect(plant.name == "Basil")
        #expect(plant.scientificName == "Ocimum basilicum")
        #expect(plant.plantType == .herb)
        #expect(plant.difficultyLevel == .beginner)
        #expect(plant.sunlightRequirement == .partialSun)
        #expect(plant.wateringFrequency == .everyOtherDay)
        #expect(plant.spaceRequirement == .small)
        #expect(plant.notes?.contains("Pinch flowers") == true)
        #expect(plant.garden?.id == garden.id)
    }

    @Test("createStarterPlant creates watering reminder from template cadence")
    func createStarterPlantCreatesWateringReminder() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "Kitchen Garden", type: .container, isIndoor: false)
        let template = try createTemplate(dataService: dataService)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let result = try dataService.createStarterPlant(
            from: template,
            in: garden,
            plantingDate: now
        )

        #expect(result.plant.garden?.id == garden.id)
        #expect(result.reminder.title == "Water Basil")
        #expect(result.reminder.frequency == .everyOtherDay)
        #expect(result.reminder.plant?.id == result.plant.id)
    }

    @Test("createStarterPlant assigns the plant to the selected container")
    func createStarterPlantAssignsSelectedContainer() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "Kitchen Garden", type: .container, isIndoor: false)
        let bed = try dataService.createGardenBed(name: "Herb Pot", bedType: .pot, in: garden)
        let template = try createTemplate(dataService: dataService)

        let result = try dataService.createStarterPlant(
            from: template,
            in: garden,
            gardenBed: bed,
            plantingDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let bedPlants = bed.plants ?? []
        #expect(result.plant.garden?.id == garden.id)
        #expect(result.plant.bed?.id == bed.id)
        #expect(bedPlants.contains { $0.id == result.plant.id })
    }

    private func createTemplate(dataService: DataService) throws -> Plant {
        try dataService.insertDatabasePlant(
            name: "Basil",
            scientificName: "Ocimum basilicum",
            type: .herb,
            difficulty: .beginner,
            sunlight: .partialSun,
            watering: .everyOtherDay,
            space: .small,
            notes: "Pinch flowers to keep leaves tender."
        )
        return try #require(dataService.fetchPlantDatabase().first { $0.name == "Basil" })
    }
}
