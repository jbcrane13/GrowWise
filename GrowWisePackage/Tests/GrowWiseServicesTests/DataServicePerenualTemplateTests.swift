import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
@Suite("DataService Perenual plant activation")
struct DataServicePerenualTemplateTests {
    @Test("createUserPlant maps a Perenual detail into a garden plant")
    func createUserPlantMapsPerenualDetail() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "Herb Bed", type: .raised, isIndoor: false)
        let detail = try decodeDetail()

        let plant = try dataService.createUserPlant(
            from: detail,
            in: garden,
            plantingDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(plant.isUserPlant == true)
        #expect(plant.name == "Basil")
        #expect(plant.scientificName == "Ocimum basilicum")
        #expect(plant.plantType == .herb)
        #expect(plant.difficultyLevel == .beginner)
        #expect(plant.sunlightRequirement == .fullSun)
        #expect(plant.wateringFrequency == .daily)
        #expect(plant.notes?.contains("Fast-growing culinary herb.") == true)
        #expect(plant.notes?.contains("Watering: Frequent") == true)
        #expect(plant.photoURLs == ["https://example.com/basil.jpg"])
        #expect(plant.garden?.id == garden.id)
    }

    private func decodeDetail() throws -> PerenualSpeciesDetail {
        let json = """
        {
          "id": 42,
          "common_name": "Basil",
          "scientific_name": ["Ocimum basilicum"],
          "type": "Herb",
          "watering": "Frequent",
          "sunlight": ["full sun"],
          "care_level": "Low",
          "description": "Fast-growing culinary herb.",
          "default_image": {
            "medium_url": "https://example.com/basil.jpg"
          }
        }
        """
        return try JSONDecoder().decode(PerenualSpeciesDetail.self, from: Data(json.utf8))
    }
}
