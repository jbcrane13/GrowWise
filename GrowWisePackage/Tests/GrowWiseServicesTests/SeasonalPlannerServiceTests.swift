import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - SeasonalPlannerService Tests

@MainActor
struct SeasonalPlannerServiceTests {
    @Test("Vegetable plant returns start-indoors activity in February for zone 7")
    func vegetableStartIndoorsZone7() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Tomato", plantType: .vegetable)

        let activities = service.getMonthlyActivities(for: 2, plants: [plant], zone: "7a")

        let startIndoors = activities.filter { $0.activityType == .startIndoors }
        #expect(startIndoors.isEmpty == false)
        #expect(startIndoors.first?.plantName == "Tomato")
    }

    @Test("Vegetable plant returns harvest activity in summer months for zone 7")
    func vegetableHarvestZone7() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Zucchini", plantType: .vegetable)

        let activities = service.getMonthlyActivities(for: 8, plants: [plant], zone: "7a")

        let harvest = activities.filter { $0.activityType == .harvest }
        #expect(harvest.isEmpty == false)
        #expect(harvest.first?.description.contains("Zucchini") == true)
    }

    @Test("Warmer zone shifts activities earlier than colder zone")
    func zoneOffsetShiftsActivities() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Lettuce", plantType: .vegetable)

        // Zone 9 is warmer — offset shifts months earlier
        let zone9March = service.getMonthlyActivities(for: 3, plants: [plant], zone: "9b")
        // Zone 4 is colder — offset shifts months later
        let zone4March = service.getMonthlyActivities(for: 3, plants: [plant], zone: "4a")

        let zone9Types = Set(zone9March.map(\.activityType))
        let zone4Types = Set(zone4March.map(\.activityType))

        // Warmer zones should have different (earlier-season) activities than cold zones for same month
        #expect(zone9Types != zone4Types)
    }

    @Test("Houseplant ignores zone offset and has fixed active growing months")
    func houseplantFixedSchedule() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Pothos", plantType: .houseplant)

        let juneZone4 = service.getMonthlyActivities(for: 6, plants: [plant], zone: "4a")
        let juneZone9 = service.getMonthlyActivities(for: 6, plants: [plant], zone: "9b")

        // Houseplants have fixed months (3-9 active, 4-8 fertilize) regardless of zone
        let zone4Types = Set(juneZone4.map(\.activityType))
        let zone9Types = Set(juneZone9.map(\.activityType))
        #expect(zone4Types == zone9Types)
        #expect(zone4Types.contains(.activeGrowing))
    }

    @Test("No activities returned for empty plant list")
    func emptyPlantList() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let activities = service.getMonthlyActivities(for: 6, plants: [], zone: "7a")
        #expect(activities.isEmpty)
    }

    @Test("Fruit tree gets pruning in winter months")
    func fruitTreeWinterPruning() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Apple", plantType: .fruit)

        // For zone 7 (offset 0), pruning months are [1, 2, 12]
        let janActivities = service.getMonthlyActivities(for: 1, plants: [plant], zone: "7a")
        let pruning = janActivities.filter { $0.activityType == .pruning }
        #expect(pruning.isEmpty == false)
    }

    @Test("Multiple plants produce activities for each plant")
    func multiplePlantsProduceActivities() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let tomato = Plant(name: "Tomato", plantType: .vegetable)
        let basil = Plant(name: "Basil", plantType: .herb)

        let activities = service.getMonthlyActivities(for: 6, plants: [tomato, basil], zone: "7a")
        let plantNames = Set(activities.map(\.plantName))
        #expect(plantNames.contains("Tomato"))
        #expect(plantNames.contains("Basil"))
    }

    @Test("Activities are sorted by display name")
    func activitiesSortedByDisplayName() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Tomato", plantType: .vegetable)

        // Month 6 for zone 7 should have multiple activity types
        let activities = service.getMonthlyActivities(for: 6, plants: [plant], zone: "7a")
        let displayNames = activities.map(\.activityType.displayName)
        #expect(displayNames == displayNames.sorted())
    }

    @Test("Nil zone defaults to zone 7 behavior")
    func nilZoneDefaultsToZone7() async throws {
        let dataService = try await DataService.makeForTesting()
        let service = SeasonalPlannerService(dataService: dataService)

        let plant = Plant(name: "Tomato", plantType: .vegetable)

        let nilZone = service.getMonthlyActivities(for: 5, plants: [plant], zone: nil)
        let zone7 = service.getMonthlyActivities(for: 5, plants: [plant], zone: "7a")

        let nilTypes = Set(nilZone.map(\.activityType))
        let zone7Types = Set(zone7.map(\.activityType))
        #expect(nilTypes == zone7Types)
    }
}

// MARK: - FrostDate Tests

struct FrostDateTests {
    @Test("forZone returns valid frost dates for known zones")
    func knownZonesReturnFrostDates() throws {
        for zoneNum in 3 ... 10 {
            let frostDate = FrostDate.forZone("\(zoneNum)a")
            #expect(frostDate != nil, "Zone \(zoneNum) should return frost dates")
            let fd = try #require(frostDate)
            #expect(fd.lastSpringFrost >= 1 && fd.lastSpringFrost <= 12)
            #expect(fd.firstFallFrost >= 1 && fd.firstFallFrost <= 12)
        }
    }

    @Test("forZone returns nil for unknown zone numbers")
    func unknownZoneReturnsNil() {
        #expect(FrostDate.forZone("1a") == nil)
        #expect(FrostDate.forZone("2b") == nil)
        #expect(FrostDate.forZone("13a") == nil)
    }

    @Test("forZone returns nil for nil input")
    func nilZoneReturnsNil() {
        #expect(FrostDate.forZone(nil) == nil)
    }

    @Test("forZone extracts numeric portion from zone string with suffix")
    func zoneStringParsing() throws {
        let zone7a = try #require(FrostDate.forZone("7a"))
        let zone7b = try #require(FrostDate.forZone("7b"))

        // Both "7a" and "7b" should return zone 7 data
        #expect(zone7a.lastSpringFrost == zone7b.lastSpringFrost)
        #expect(zone7a.firstFallFrost == zone7b.firstFallFrost)
    }

    @Test("Warmer zones have earlier last spring frost")
    func warmerZonesEarlierSpringFrost() throws {
        let zone5 = try #require(FrostDate.forZone("5a"))
        let zone9 = try #require(FrostDate.forZone("9a"))

        // Zone 9 (warmer) should have earlier last spring frost than zone 5
        let zone5SpringDayOfYear = zone5.lastSpringFrost * 30 + zone5.lastSpringFrostDay
        let zone9SpringDayOfYear = zone9.lastSpringFrost * 30 + zone9.lastSpringFrostDay
        #expect(zone9SpringDayOfYear < zone5SpringDayOfYear)
    }

    @Test("Frost date descriptions are non-empty formatted strings")
    func frostDateDescriptions() throws {
        let frostDate = try #require(FrostDate.forZone("7a"))
        let springDesc = frostDate.lastSpringFrostDescription
        let fallDesc = frostDate.firstFallFrostDescription

        #expect(springDesc.isEmpty == false)
        #expect(fallDesc.isEmpty == false)
    }
}

// MARK: - SeasonalActivity Enum Tests

struct SeasonalActivityEnumTests {
    @Test("All cases have non-empty display names")
    func allDisplayNamesNonEmpty() {
        for activity in SeasonalActivity.allCases {
            #expect(activity.displayName.isEmpty == false)
        }
    }

    @Test("All cases have non-empty icon names")
    func allIconNamesNonEmpty() {
        for activity in SeasonalActivity.allCases {
            #expect(activity.icon.isEmpty == false)
        }
    }
}
