import Foundation
@testable import GrowWiseModels
import Testing

// MARK: - Harvest Model Tests

struct HarvestModelTests {
    @Test("Harvest initializes with correct defaults")
    func harvestDefaults() {
        let harvest = Harvest()
        #expect(harvest.id != nil)
        #expect(harvest.quantity == 0)
        #expect(harvest.unit == .pieces)
        #expect(harvest.date != nil)
        #expect(harvest.notes == "")
        #expect(harvest.plant == nil)
        #expect(harvest.user == nil)
    }

    @Test("Harvest stores custom values")
    func harvestCustomValues() {
        let harvest = Harvest(
            quantity: 2.5,
            unit: .pounds,
            notes: "Perfect tomatoes"
        )
        #expect(harvest.quantity == 2.5)
        #expect(harvest.unit == .pounds)
        #expect(harvest.notes == "Perfect tomatoes")
    }
}

struct HarvestUnitTests {
    @Test("All units have non-empty display names")
    func displayNames() {
        for unit in HarvestUnit.allCases {
            #expect(unit.displayName.isEmpty == false)
        }
    }

    @Test("Unit enum round-trips through rawValue")
    func roundTrip() {
        let original: HarvestUnit = .kilograms
        let raw = original.rawValue
        let restored = HarvestUnit(rawValue: raw)
        #expect(restored == .kilograms)
    }
}
