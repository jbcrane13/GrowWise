import Testing
@testable import GrowWiseModels

@Suite("GardenBed")
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
}
