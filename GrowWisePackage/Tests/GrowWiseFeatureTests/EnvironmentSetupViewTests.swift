import Foundation
import GrowWiseFeature
import Testing

@Suite("EnvironmentSetupView tests")
struct EnvironmentSetupViewTests {

    @Test("UserProfile has indoor environment fields with correct defaults")
    func testIndoorEnvironmentDefaults() {
        let profile = UserProfile()
        #expect(profile.indoorLightAvailability == .medium)
        #expect(profile.indoorRoomTemp == false)
        #expect(profile.hasPetsInHome == false)
    }

    @Test("UserProfile outdoor environment fields have correct defaults")
    func testOutdoorEnvironmentDefaults() {
        let profile = UserProfile()
        #expect(profile.hardinessZone == "")
        #expect(profile.sunExposure == .fullSun)
        #expect(profile.hasFrostProtection == false)
    }

    @Test("UserProfile hydroponic environment fields have correct defaults")
    func testHydroponicEnvironmentDefaults() {
        let profile = UserProfile()
        #expect(profile.hydroponicSystemType == .dwc)
        #expect(profile.nutrientSchedule == 0.5)
        #expect(profile.phRange == 5.5...6.5)
    }

    @Test("UserProfile indoor fields are settable")
    func testIndoorFieldsSettable() {
        var profile = UserProfile()
        profile.indoorLightAvailability = .high
        profile.indoorRoomTemp = true
        profile.hasPetsInHome = true

        #expect(profile.indoorLightAvailability == .high)
        #expect(profile.indoorRoomTemp == true)
        #expect(profile.hasPetsInHome == true)
    }

    @Test("UserProfile outdoor fields are settable")
    func testOutdoorFieldsSettable() {
        var profile = UserProfile()
        profile.hardinessZone = "7a"
        profile.sunExposure = .partialSun
        profile.hasFrostProtection = true

        #expect(profile.hardinessZone == "7a")
        #expect(profile.sunExposure == .partialSun)
        #expect(profile.hasFrostProtection == true)
    }

    @Test("UserProfile hydroponic fields are settable")
    func testHydroponicFieldsSettable() {
        var profile = UserProfile()
        profile.hydroponicSystemType = .nft
        profile.nutrientSchedule = 0.8
        profile.phRange = 6.0...7.0

        #expect(profile.hydroponicSystemType == .nft)
        #expect(profile.nutrientSchedule == 0.8)
        #expect(profile.phRange == 6.0...7.0)
    }

    @Test("LightAvailability has all four cases")
    func testLightAvailabilityCases() {
        #expect(LightAvailability.allCases.count == 4)
        #expect(LightAvailability.low.displayName == "Low (North-facing / dim)")
        #expect(LightAvailability.medium.displayName == "Medium (East/West-facing)")
        #expect(LightAvailability.high.displayName == "High (South-facing / bright)")
        #expect(LightAvailability.artificial.displayName == "Artificial Grow Lights")
    }

    @Test("HydroponicSystemType has all three cases")
    func testHydroponicSystemTypeCases() {
        #expect(HydroponicSystemType.allCases.count == 3)
        #expect(HydroponicSystemType.dwc.displayName == "DWC (Deep Water Culture)")
        #expect(HydroponicSystemType.nft.displayName == "NFT (Nutrient Film Technique)")
        #expect(HydroponicSystemType.drip.displayName == "Drip System")
    }
}