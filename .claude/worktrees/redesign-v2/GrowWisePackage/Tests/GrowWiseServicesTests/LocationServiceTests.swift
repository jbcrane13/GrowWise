import Testing
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("LocationService Tests")
@MainActor
struct LocationServiceTests {
    @Test(
        "Hardiness zones are mapped from latitude",
        arguments: [
            (64.2, "1a"),
            (40.0, "4a"),
            (8.5, "8a"),
            (-21.0, "12a")
        ]
    )
    func determineHardinessZoneMapsLatitude(latitude: Double, expectedZone: String) {
        let service = LocationService()
        let location = CLLocation(latitude: latitude, longitude: -122.0)

        let zone = service.determineHardinessZone(for: location)

        #expect(zone == expectedZone)
    }

    @Test("fetchWeatherData surfaces location unavailable when location is missing")
    func fetchWeatherDataWithoutLocationSetsError() async {
        let service = LocationService()
        service.currentLocation = nil
        service.error = nil

        await service.fetchWeatherData()

        guard let error = service.error else {
            Issue.record("Expected LocationService.error to be set")
            return
        }

        switch error {
        case .locationUnavailable:
            #expect(true)
        default:
            Issue.record("Expected .locationUnavailable but got \(String(describing: error.errorDescription))")
        }

        #expect(service.isLoading == false)
    }

    @Test("Planting window requires hardiness zone")
    func getPlantingWindowReturnsNilWithoutZone() {
        let service = LocationService()
        service.hardinessZone = nil

        let window = service.getPlantingWindow(for: .vegetable)

        #expect(window == nil)
    }

    @Test("Planting window is generated when hardiness zone is known")
    func getPlantingWindowReturnsWindowForKnownZone() {
        let service = LocationService()
        service.hardinessZone = "6a"

        let window = service.getPlantingWindow(for: .vegetable)

        #expect(window != nil)
        #expect(window?.description.contains("6a") == true)
    }
}
