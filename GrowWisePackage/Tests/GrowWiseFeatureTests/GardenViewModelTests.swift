import Testing
import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
import GrowWiseServices

// MARK: - GardenViewModelTests

@Suite("GardenViewModel Tests")
@MainActor
struct GardenViewModelTests {

    // MARK: - filteredGroups

    @Test("filteredGroups returns all groups when searchText is empty")
    func filteredGroupsReturnsAllWhenSearchTextEmpty() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        plant1.gardenLocation = "Bed A"
        plant2.gardenLocation = "Bed B"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        vm.searchText = ""

        #expect(vm.filteredGroups.count == vm.groupedPlants.count)
        #expect(vm.filteredGroups.flatMap(\.plants).count == 2)
    }

    @Test("filteredGroups filters by plant name case-insensitively")
    func filteredGroupsFiltersByNameCaseInsensitive() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        plant1.gardenLocation = "Bed A"
        plant2.gardenLocation = "Bed A"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        vm.searchText = "TOMATO"

        let allFilteredPlants = vm.filteredGroups.flatMap(\.plants)
        #expect(allFilteredPlants.count == 1)
        #expect(allFilteredPlants.first?.name == "Tomato")
    }

    @Test("filteredGroups filters by scientificName")
    func filteredGroupsFiltersByScientificName() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        plant.gardenLocation = "Bed A"
        plant.scientificName = "Solanum lycopersicum"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        vm.searchText = "solanum"

        let allFilteredPlants = vm.filteredGroups.flatMap(\.plants)
        #expect(allFilteredPlants.count == 1)
        #expect(allFilteredPlants.first?.name == "Tomato")
    }

    @Test("filteredGroups filters by notes")
    func filteredGroupsFiltersByNotes() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        plant.gardenLocation = "Herb Corner"
        plant.notes = "Great for pizza sauce"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        vm.searchText = "pizza"

        let allFilteredPlants = vm.filteredGroups.flatMap(\.plants)
        #expect(allFilteredPlants.count == 1)
        #expect(allFilteredPlants.first?.name == "Basil")
    }

    @Test("filteredGroups returns empty when no search match")
    func filteredGroupsReturnsEmptyWhenNoMatch() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        plant.gardenLocation = "Bed A"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        vm.searchText = "xyznotexist"

        #expect(vm.filteredGroups.isEmpty)
    }

    // MARK: - totalPlantCount

    @Test("totalPlantCount sums plants across all groups")
    func totalPlantCountSumsAllGroups() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        let plant3 = try dataService.createPlant(name: "Mint", type: .herb, garden: garden)
        plant1.gardenLocation = "Bed A"
        plant2.gardenLocation = "Bed B"
        plant3.gardenLocation = "Herb Corner"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.totalPlantCount == 3)
    }

    @Test("totalPlantCount is 0 when no plants exist")
    func totalPlantCountIsZeroForEmpty() async throws {
        let dataService = try DataService.makeForTesting()
        _ = try dataService.createGarden(name: "Empty Garden", type: .outdoor, isIndoor: false)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.totalPlantCount == 0)
    }

    // MARK: - alertCount

    @Test("alertCount counts plants with overdue enabled reminders")
    func alertCountCountsOverdueEnabledReminders() async throws {
        // alertCount checks plant.reminders directly (not via fetchActiveReminders),
        // so past-dated reminders ARE visible here.
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        plant.gardenLocation = "Bed A"

        let pastDate = Date(timeIntervalSinceNow: -86_400) // 24 hours ago
        _ = try dataService.createReminder(
            title: "Water",
            message: "Water the tomato",
            type: .watering,
            frequency: .daily,
            dueDate: pastDate,
            plant: plant
        )

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.alertCount == 1)
    }

    @Test("alertCount ignores future reminders")
    func alertCountIgnoresFutureReminders() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        plant.gardenLocation = "Bed A"

        let futureDate = Date(timeIntervalSinceNow: 86_400) // 24 hours from now
        _ = try dataService.createReminder(
            title: "Fertilize",
            message: "Add fertilizer",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: futureDate,
            plant: plant
        )

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.alertCount == 0)
    }

    @Test("alertCount ignores disabled reminders")
    func alertCountIgnoresDisabledReminders() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        plant.gardenLocation = "Bed A"

        let pastDate = Date(timeIntervalSinceNow: -86_400)
        let reminder = try dataService.createReminder(
            title: "Water",
            message: "Water the plant",
            type: .watering,
            frequency: .daily,
            dueDate: pastDate,
            plant: plant
        )
        reminder.isEnabled = false

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.alertCount == 0)
    }

    // MARK: - load()

    @Test("load() groups plants by gardenLocation")
    func loadGroupsByGardenLocation() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        plant1.gardenLocation = "Bed A"
        plant2.gardenLocation = "Bed B"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.groupedPlants.count == 2)
        let locationKeys = Set(vm.groupedPlants.compactMap(\.locationKey))
        #expect(locationKeys == Set(["Bed A", "Bed B"]))
    }

    @Test("load() places plants with nil or empty gardenLocation into Ungrouped")
    func loadPlacesNilOrEmptyLocationInUngrouped() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)

        // nil gardenLocation (default)
        _ = try dataService.createPlant(name: "Mystery Plant", type: .houseplant, garden: garden)

        // empty gardenLocation
        let plant2 = try dataService.createPlant(name: "Another Plant", type: .flower, garden: garden)
        plant2.gardenLocation = ""

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        let ungrouped = vm.groupedPlants.first(where: { $0.locationKey == nil })
        #expect(ungrouped != nil)
        #expect(ungrouped?.plants.count == 2)
    }

    @Test("load() auto-selects the first garden alphabetically")
    func loadAutoSelectsFirstGarden() async throws {
        let dataService = try DataService.makeForTesting()
        _ = try dataService.createGarden(name: "Beta Garden", type: .outdoor, isIndoor: false)
        _ = try dataService.createGarden(name: "Alpha Garden", type: .outdoor, isIndoor: false)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        // GardenRepository.fetchAll() sorts by name ascending
        #expect(vm.selectedGarden?.name == "Alpha Garden")
    }

    @Test("load() sorts named location groups alphabetically")
    func loadSortsNamedGroupsAlphabetically() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "P1", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "P2", type: .herb, garden: garden)
        let plant3 = try dataService.createPlant(name: "P3", type: .flower, garden: garden)
        plant1.gardenLocation = "Zzz Back"
        plant2.gardenLocation = "Aaa Front"
        plant3.gardenLocation = "Mmm Middle"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        let namedGroups = vm.groupedPlants.filter { $0.locationKey != nil }
        let names = namedGroups.compactMap(\.locationKey)
        #expect(names == ["Aaa Front", "Mmm Middle", "Zzz Back"])
    }

    // MARK: - selectGarden()

    @Test("selectGarden() filters groupedPlants to the selected garden's plants")
    func selectGardenFiltersToSelectedGarden() async throws {
        let dataService = try DataService.makeForTesting()
        let garden1 = try dataService.createGarden(name: "Garden A", type: .outdoor, isIndoor: false)
        let garden2 = try dataService.createGarden(name: "Garden B", type: .indoor, isIndoor: true)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden1)
        let plant2 = try dataService.createPlant(name: "Fern", type: .houseplant, garden: garden2)
        plant1.gardenLocation = "Raised Bed"
        plant2.gardenLocation = "Shelf"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        await vm.selectGarden(garden2, dataService: dataService)

        let allPlants = vm.groupedPlants.flatMap(\.plants)
        #expect(allPlants.count == 1)
        #expect(allPlants.first?.name == "Fern")
    }

    @Test("selectGarden(nil) shows all plants from every garden")
    func selectGardenNilShowsAllPlants() async throws {
        let dataService = try DataService.makeForTesting()
        let garden1 = try dataService.createGarden(name: "Garden A", type: .outdoor, isIndoor: false)
        let garden2 = try dataService.createGarden(name: "Garden B", type: .indoor, isIndoor: true)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden1)
        let plant2 = try dataService.createPlant(name: "Fern", type: .houseplant, garden: garden2)
        plant1.gardenLocation = "Raised Bed"
        plant2.gardenLocation = "Shelf"

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)
        await vm.selectGarden(nil, dataService: dataService)

        let allPlants = vm.groupedPlants.flatMap(\.plants)
        #expect(allPlants.count == 2)
    }

    // MARK: - rebuildGroups (via load)

    @Test("rebuildGroups handles an empty plant list without crashing")
    func rebuildGroupsHandlesEmptyList() async throws {
        let dataService = try DataService.makeForTesting()

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.groupedPlants.isEmpty)
        #expect(vm.totalPlantCount == 0)
        #expect(vm.alertCount == 0)
    }

    // MARK: - PlantGroup.displayName

    @Test("PlantGroup.displayName returns 'Ungrouped' when locationKey is nil")
    func plantGroupDisplayNameReturnsUngroupedForNil() {
        let group = PlantGroup(id: "__ungrouped__", locationKey: nil, plants: [])
        #expect(group.displayName == "Ungrouped")
    }
}
