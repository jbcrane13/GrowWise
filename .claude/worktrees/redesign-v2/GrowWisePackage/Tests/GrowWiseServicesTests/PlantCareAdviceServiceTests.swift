import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - PlantCareAdviceService Tests

@MainActor
struct PlantCareAdviceServiceTests {
    let service = PlantCareAdviceService()

    @Test("Returns non-empty tips for a valid plant")
    func returnsNonEmptyTipsForValidPlant() {
        let plant = Plant(name: "Tomato", plantType: .vegetable)

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        #expect(tips.isEmpty == false)
    }

    @Test("Tips are capped at maximum of 4")
    func tipsCappedAtFour() {
        let plant = Plant(name: "Basil", plantType: .herb)
        plant.growthStage = .seed
        plant.lastWatered = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        plant.wateringFrequency = .daily
        plant.lastFertilized = Calendar.current.date(byAdding: .day, value: -60, to: Date())

        let garden = Garden(name: "Shady Garden")
        garden.sunExposure = .fullShade
        garden.hardinessZone = "5a"

        let user = User(email: "test@example.com", displayName: "Test", skillLevel: .beginner)

        let tips = service.getContextualTips(for: plant, in: garden, user: user)
        #expect(tips.count <= 4)
    }

    @Test("Tips sorted by urgency descending")
    func tipsSortedByUrgencyDescending() {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        plant.lastWatered = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        plant.wateringFrequency = .daily

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        for i in 0 ..< tips.count - 1 {
            #expect(tips[i].urgency >= tips[i + 1].urgency)
        }
    }

    @Test("Sun mismatch tip when full-sun plant in full-shade garden")
    func sunMismatchFullSunInShade() {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        plant.sunlightRequirement = .fullSun

        let garden = Garden(name: "Shade Garden")
        garden.sunExposure = .fullShade

        let tips = service.getContextualTips(for: plant, in: garden, user: nil)
        let mismatchTips = tips.filter { $0.title == "Sun Exposure Mismatch" }
        #expect(mismatchTips.count == 1)
        #expect(mismatchTips.first?.urgency == .warning)
    }

    @Test("No sun mismatch tip when sunlight matches")
    func noSunMismatchWhenMatching() {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        plant.sunlightRequirement = .fullSun

        let garden = Garden(name: "Sunny Garden")
        garden.sunExposure = .fullSun

        let tips = service.getContextualTips(for: plant, in: garden, user: nil)
        let mismatchTips = tips.filter { $0.title == "Sun Exposure Mismatch" }
        #expect(mismatchTips.isEmpty)
    }

    @Test("Growth stage tip for seed stage")
    func growthStageTipForSeed() {
        let plant = Plant(name: "Pepper", plantType: .vegetable)
        plant.growthStage = .seed

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        let germTips = tips.filter { $0.title == "Germination Care" }
        #expect(germTips.count == 1)
        #expect(germTips.first?.urgency == .suggestion)
    }

    @Test("Overdue watering tip when last watered exceeds frequency")
    func overdueWateringTip() {
        let plant = Plant(name: "Basil", plantType: .herb)
        plant.wateringFrequency = .daily
        plant.lastWatered = Calendar.current.date(byAdding: .day, value: -5, to: Date())

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        let overdueWater = tips.filter { $0.title == "Watering Overdue" }
        #expect(overdueWater.count == 1)
        #expect(overdueWater.first?.urgency == .urgent)
    }

    @Test("No overdue watering tip when recently watered")
    func noOverdueTipWhenRecentlyWatered() {
        let plant = Plant(name: "Basil", plantType: .herb)
        plant.wateringFrequency = .weekly
        plant.lastWatered = Date()

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        let overdueWater = tips.filter { $0.title == "Watering Overdue" }
        #expect(overdueWater.isEmpty)
    }

    @Test("Beginner skill level gets beginner tip for succulent")
    func beginnerTipForSucculent() {
        let plant = Plant(name: "Aloe", plantType: .succulent)

        let user = User(email: "test@example.com", displayName: "Test", skillLevel: .beginner)

        let tips = service.getContextualTips(for: plant, in: nil, user: user)
        let beginnerTips = tips.filter { $0.title == "Beginner Tip" }
        #expect(beginnerTips.count == 1)
        #expect(beginnerTips.first?.description.contains("overwatering") == true)
    }

    @Test("Advanced skill level does not get beginner tips")
    func noBeginnerTipForAdvancedUser() {
        let plant = Plant(name: "Aloe", plantType: .succulent)

        let user = User(email: "test@example.com", displayName: "Test", skillLevel: .advanced)

        let tips = service.getContextualTips(for: plant, in: nil, user: user)
        let beginnerTips = tips.filter { $0.title == "Beginner Tip" }
        #expect(beginnerTips.isEmpty)
    }

    @Test("Fertilize overdue tip when last fertilized over 30 days ago")
    func fertilizeOverdueTip() {
        let plant = Plant(name: "Rose", plantType: .flower)
        plant.lastFertilized = Calendar.current.date(byAdding: .day, value: -45, to: Date())

        let tips = service.getContextualTips(for: plant, in: nil, user: nil)
        let fertTips = tips.filter { $0.title == "Time to Fertilize" }
        #expect(fertTips.count == 1)
        #expect(fertTips.first?.urgency == .suggestion)
    }
}

// MARK: - CareTipUrgency Tests

struct CareTipUrgencyTests {
    @Test("Urgency levels compare correctly")
    func urgencyComparison() {
        #expect(CareTipUrgency.info < CareTipUrgency.suggestion)
        #expect(CareTipUrgency.suggestion < CareTipUrgency.warning)
        #expect(CareTipUrgency.warning < CareTipUrgency.urgent)
    }

    @Test("Raw values increase with urgency")
    func rawValues() {
        #expect(CareTipUrgency.info.rawValue == 0)
        #expect(CareTipUrgency.suggestion.rawValue == 1)
        #expect(CareTipUrgency.warning.rawValue == 2)
        #expect(CareTipUrgency.urgent.rawValue == 3)
    }
}
