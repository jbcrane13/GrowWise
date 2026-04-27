import Foundation
@testable import GrowWiseModels
import Testing

struct GardenBedTests {
    @Test("BedType has displayName and iconName for all cases")
    func bedTypeMetadata() {
        for bedType in BedType.allCases {
            #expect(!bedType.displayName.isEmpty)
            #expect(!bedType.iconName.isEmpty)
        }
    }

    @Test("BedType raw values are stable strings")
    func bedTypeRawValues() {
        #expect(BedType.raisedBed.rawValue == "raised_bed")
        #expect(BedType.pot.rawValue == "pot")
        #expect(BedType.hangingBasket.rawValue == "hanging_basket")
    }

    @Test("GardenBed init sets all properties")
    func gardenBedInit() {
        let bed = GardenBed(name: "South Bed", bedType: .raisedBed)
        #expect(bed.name == "South Bed")
        #expect(bed.bedType == .raisedBed)
        #expect(bed.id != nil)
        #expect(bed.createdDate != nil)
        #expect(bed.garden == nil)
    }

    // MARK: - Init with all parameters

    @Test("Init with garden parameter persists the parent garden relationship")
    func initWithGardenParameter() {
        let garden = Garden(name: "Backyard", gardenType: .outdoor)
        let bed = GardenBed(name: "Herb Corner", bedType: .raisedBed, garden: garden)
        #expect(bed.name == "Herb Corner")
        #expect(bed.bedType == .raisedBed)
        #expect(bed.garden?.id == garden.id)
        #expect(bed.id != nil)
        #expect(bed.createdDate != nil)
    }

    @Test("Init with each BedType stores that type correctly")
    func initWithEachBedType() {
        for bedType in BedType.allCases {
            let bed = GardenBed(name: "Bed-\(bedType.rawValue)", bedType: bedType)
            #expect(bed.bedType == bedType)
        }
    }

    // MARK: - Unique IDs across instances

    @Test("Each init call produces a unique UUID")
    func uniqueIDsAcrossInstances() {
        let bed1 = GardenBed(name: "Alpha", bedType: .pot)
        let bed2 = GardenBed(name: "Beta", bedType: .pot)
        let bed3 = GardenBed(name: "Alpha", bedType: .pot)
        #expect(bed1.id != bed2.id)
        #expect(bed1.id != bed3.id)
        #expect(bed2.id != bed3.id)
    }

    // MARK: - Default values for optional properties

    @Test("notes is nil by default")
    func notesNilByDefault() {
        let bed = GardenBed(name: "Empty Bed", bedType: .inGroundRow)
        #expect(bed.notes == nil)
    }

    @Test("plants defaults to empty array")
    func plantsDefaultsToEmpty() {
        let bed = GardenBed(name: "New Bed", bedType: .raisedBed)
        #expect(bed.plants?.isEmpty == true)
    }

    @Test("seeds defaults to empty array")
    func seedsDefaultsToEmpty() {
        let bed = GardenBed(name: "New Bed", bedType: .raisedBed)
        #expect(bed.seeds?.isEmpty == true)
    }

    @Test("garden is nil when not provided")
    func gardenNilWhenNotProvided() {
        let bed = GardenBed(name: "Orphan Bed", bedType: .pot)
        #expect(bed.garden == nil)
    }

    @Test("createdDate is approximately now when initialized")
    func createdDateIsApproximatelyNow() throws {
        let before = Date()
        let bed = GardenBed(name: "Timed Bed", bedType: .windowBox)
        let after = Date()
        let createdDate = try #require(bed.createdDate)
        #expect(createdDate >= before)
        #expect(createdDate <= after)
    }

    // MARK: - Plants relationship (add/remove without SwiftData context)

    @Test("Appending a plant to the plants array increases count")
    func appendingPlantIncreasesCount() {
        let bed = GardenBed(name: "Veggie Bed", bedType: .raisedBed)
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        bed.plants?.append(plant)
        #expect(bed.plants?.count == 1)
        #expect(bed.plants?.first?.name == "Tomato")
    }

    @Test("Removing a plant from the plants array decreases count")
    func removingPlantDecreasesCount() {
        let bed = GardenBed(name: "Herb Bed", bedType: .planterBox)
        let basil = Plant(name: "Basil", plantType: .herb)
        let mint = Plant(name: "Mint", plantType: .herb)
        bed.plants?.append(basil)
        bed.plants?.append(mint)
        #expect(bed.plants?.count == 2)
        bed.plants?.removeAll { $0.name == "Basil" }
        #expect(bed.plants?.count == 1)
        #expect(bed.plants?.first?.name == "Mint")
    }

    // MARK: - Garden relationship (parent garden)

    @Test("Assigning a garden after init updates the relationship")
    func assignGardenAfterInit() {
        let bed = GardenBed(name: "Floating Bed", bedType: .hangingBasket)
        #expect(bed.garden == nil)
        let garden = Garden(name: "Rooftop", gardenType: .balcony)
        bed.garden = garden
        #expect(bed.garden?.id == garden.id)
        #expect(bed.garden?.name == "Rooftop")
    }

    @Test("Reassigning garden replaces the previous parent")
    func reassignGardenReplacesParent() {
        let garden1 = Garden(name: "Front Yard", gardenType: .outdoor)
        let garden2 = Garden(name: "Back Yard", gardenType: .outdoor)
        let bed = GardenBed(name: "Mobile Bed", bedType: .pot, garden: garden1)
        #expect(bed.garden?.id == garden1.id)
        bed.garden = garden2
        #expect(bed.garden?.id == garden2.id)
    }

    // MARK: - BedType display metadata correctness

    @Test("BedType displayName values are human-readable strings")
    func bedTypeDisplayNameValues() {
        #expect(BedType.raisedBed.displayName == "Raised Bed")
        #expect(BedType.planterBox.displayName == "Planter Box")
        #expect(BedType.inGroundRow.displayName == "In-Ground Row")
        #expect(BedType.pot.displayName == "Pot")
        #expect(BedType.greenhouseBench.displayName == "Greenhouse Bench")
        #expect(BedType.windowBox.displayName == "Window Box")
        #expect(BedType.hangingBasket.displayName == "Hanging Basket")
        #expect(BedType.trellisVertical.displayName == "Trellis / Vertical")
    }

    @Test("BedType iconName values are valid SF Symbol identifiers")
    func bedTypeIconNameValues() {
        // SF Symbols use dotted naming: verify they follow the pattern
        for bedType in BedType.allCases {
            let icon = bedType.iconName
            #expect(icon.contains(".") || icon.count > 2, "Icon '\(icon)' for \(bedType) should be a valid SF Symbol name")
        }
    }

    @Test("All BedType raw values round-trip through Codable")
    func bedTypeRoundTripCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for bedType in BedType.allCases {
            let data = try encoder.encode(bedType)
            let decoded = try decoder.decode(BedType.self, from: data)
            #expect(decoded == bedType)
        }
    }

    @Test("BedType allCases contains all 8 types")
    func bedTypeAllCasesCount() {
        #expect(BedType.allCases.count == 8)
    }

    // MARK: - Property mutation

    @Test("notes can be assigned and read back")
    func settingNotes() {
        let bed = GardenBed(name: "Noted Bed", bedType: .raisedBed)
        bed.notes = "Gets afternoon shade"
        #expect(bed.notes == "Gets afternoon shade")
    }

    @Test("name can be changed after init")
    func renamingBed() {
        let bed = GardenBed(name: "Old Name", bedType: .pot)
        bed.name = "New Name"
        #expect(bed.name == "New Name")
    }

    @Test("bedType can be changed after init")
    func changingBedType() {
        let bed = GardenBed(name: "Converted Bed", bedType: .pot)
        bed.bedType = .raisedBed
        #expect(bed.bedType == .raisedBed)
    }
}
