import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - PlantGroupTests

@Suite("PlantGroup")
struct PlantGroupTests {
    @Test("displayName returns bed name when bed is set")
    func displayNameWithBed() {
        let bed = GardenBed(name: "South Bed", bedType: .raisedBed)
        let group = PlantGroup(id: bed.id?.uuidString ?? "x", bed: bed, plants: [])
        #expect(group.displayName == "South Bed")
    }

    @Test("displayName returns Unassigned when bed is nil")
    func displayNameWithoutBed() {
        let group = PlantGroup(id: "__unassigned__", bed: nil, plants: [])
        #expect(group.displayName == "Unassigned")
    }

    @Test("iconName returns tray for unassigned group")
    func iconNameUnassigned() {
        let group = PlantGroup(id: "__unassigned__", bed: nil, plants: [])
        #expect(group.iconName == "tray")
    }

    @Test("iconName returns bed type icon when bed is set")
    func iconNameWithBed() {
        let bed = GardenBed(name: "Herb Pots", bedType: .pot)
        let group = PlantGroup(id: "x", bed: bed, plants: [])
        #expect(group.iconName == BedType.pot.iconName)
    }
}

// MARK: - GardenViewModelTests

@Suite("GardenViewModel Tests")
@MainActor
struct GardenViewModelTests {
    // NOTE: Search/filter tests removed — search was moved out of GardenViewModel
    // during the redesign. Search is now handled directly in GardenView.
    // (filteredGroups, searchText no longer exist on GardenViewModel)


    // MARK: - totalPlantCount

    @Test("totalPlantCount sums plants across all groups")
    func totalPlantCountSumsAllGroups() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        let plant3 = try dataService.createPlant(name: "Mint", type: .herb, garden: garden)
        let bedA = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        let bedB = GardenBed(name: "Bed B", bedType: .raisedBed, garden: garden)
        let herbCorner = GardenBed(name: "Herb Corner", bedType: .planterBox, garden: garden)
        dataService.mainContext.insert(bedA)
        dataService.mainContext.insert(bedB)
        dataService.mainContext.insert(herbCorner)
        plant1.bed = bedA
        plant2.bed = bedB
        plant3.bed = herbCorner

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
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let bedA = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        dataService.mainContext.insert(bedA)
        plant.bed = bedA

        let oneDay: TimeInterval = 24 * 60 * 60
        let pastDate = Date(timeIntervalSinceNow: -oneDay)
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
        let bedA = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        dataService.mainContext.insert(bedA)
        plant.bed = bedA

        let oneDay: TimeInterval = 24 * 60 * 60
        let futureDate = Date(timeIntervalSinceNow: oneDay)
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
        let bedA = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        dataService.mainContext.insert(bedA)
        plant.bed = bedA

        let oneDay: TimeInterval = 24 * 60 * 60
        let pastDate = Date(timeIntervalSinceNow: -oneDay)
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

    @Test("bloomingCount counts plants in flowering stage")
    func bloomingCountCountsFloweringPlants() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let flowering = try dataService.createPlant(name: "Rose", type: .flower, garden: garden)
        flowering.growthStage = .flowering
        let seedling = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        seedling.growthStage = .seedling

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.bloomingCount == 1)
    }

    // MARK: - load()

    @Test("load() groups plants by GardenBed")
    func loadGroupsByGardenBed() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        let bedA = GardenBed(name: "Bed A", bedType: .raisedBed, garden: garden)
        let bedB = GardenBed(name: "Bed B", bedType: .raisedBed, garden: garden)
        dataService.mainContext.insert(bedA)
        dataService.mainContext.insert(bedB)
        plant1.bed = bedA
        plant2.bed = bedB

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.groupedPlants.count == 2)
        let bedNames = Set(vm.groupedPlants.compactMap { $0.bed?.name })
        #expect(bedNames == Set(["Bed A", "Bed B"]))
    }

    @Test("load() places plants with no bed into Unassigned")
    func loadPlacesNilBedInUnassigned() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)

        _ = try dataService.createPlant(name: "Mystery Plant", type: .houseplant, garden: garden)
        _ = try dataService.createPlant(name: "Another Plant", type: .flower, garden: garden)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        let unassigned = vm.groupedPlants.first(where: { $0.bed == nil })
        #expect(unassigned != nil)
        #expect(unassigned?.plants.count == 2)
        #expect(unassigned?.displayName == "Unassigned")
    }

    @Test("load() auto-selects the first garden alphabetically")
    func loadAutoSelectsFirstGarden() async throws {
        let dataService = try DataService.makeForTesting()
        _ = try dataService.createGarden(name: "Beta Garden", type: .outdoor, isIndoor: false)
        _ = try dataService.createGarden(name: "Alpha Garden", type: .outdoor, isIndoor: false)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.selectedGarden?.name == "Alpha Garden")
    }

    @Test("load() sorts named bed groups alphabetically")
    func loadSortsNamedGroupsAlphabetically() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "P1", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "P2", type: .herb, garden: garden)
        let plant3 = try dataService.createPlant(name: "P3", type: .flower, garden: garden)
        let zzzBack = GardenBed(name: "Zzz Back", bedType: .inGroundRow, garden: garden)
        let aaaFront = GardenBed(name: "Aaa Front", bedType: .raisedBed, garden: garden)
        let mmmMiddle = GardenBed(name: "Mmm Middle", bedType: .planterBox, garden: garden)
        dataService.mainContext.insert(zzzBack)
        dataService.mainContext.insert(aaaFront)
        dataService.mainContext.insert(mmmMiddle)
        plant1.bed = zzzBack
        plant2.bed = aaaFront
        plant3.bed = mmmMiddle

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        let namedGroups = vm.groupedPlants.filter { $0.bed != nil }
        let names = namedGroups.compactMap { $0.bed?.name }
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
        let raisedBed = GardenBed(name: "Raised Bed", bedType: .raisedBed, garden: garden1)
        let shelf = GardenBed(name: "Shelf", bedType: .pot, garden: garden2)
        dataService.mainContext.insert(raisedBed)
        dataService.mainContext.insert(shelf)
        plant1.bed = raisedBed
        plant2.bed = shelf

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
        let raisedBed = GardenBed(name: "Raised Bed", bedType: .raisedBed, garden: garden1)
        let shelf = GardenBed(name: "Shelf", bedType: .pot, garden: garden2)
        dataService.mainContext.insert(raisedBed)
        dataService.mainContext.insert(shelf)
        plant1.bed = raisedBed
        plant2.bed = shelf

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
}
