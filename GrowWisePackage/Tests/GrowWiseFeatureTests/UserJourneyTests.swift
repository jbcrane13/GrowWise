import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - UserJourneyTests

//
// End-to-end user workflow tests that exercise multiple service layers together.
// These verify user-visible outcomes, not internal implementation details.

@Suite("User Journey Tests", .serialized)
@MainActor
struct UserJourneyTests {
    // MARK: - Plant Creation → Visible in GardenViewModel

    @Test("Plant created via DataService appears in GardenViewModel after load")
    func plantCreationVisibleInGardenViewModel() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        _ = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.totalPlantCount == 1)
        let allPlants = vm.groupedPlants.flatMap(\.plants)
        #expect(allPlants.contains(where: { $0.name == "Tomato" }))
    }

    @Test("Multiple plants in different beds each appear in their correct group")
    func multiplePlantsGroupedByBed() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        let plant2 = try dataService.createPlant(name: "Pepper", type: .vegetable, garden: garden)
        let herb = GardenBed(name: "Herb Bed", bedType: .planterBox, garden: garden)
        let veggie = GardenBed(name: "Veggie Bed", bedType: .raisedBed, garden: garden)
        dataService.mainContext.insert(herb)
        dataService.mainContext.insert(veggie)
        plant1.bed = herb
        plant2.bed = veggie

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.groupedPlants.count == 2)
        let herbGroup = vm.groupedPlants.first(where: { $0.bed?.name == "Herb Bed" })
        let veggieGroup = vm.groupedPlants.first(where: { $0.bed?.name == "Veggie Bed" })
        #expect(herbGroup?.plants.first?.name == "Basil")
        #expect(veggieGroup?.plants.first?.name == "Pepper")
    }

    @Test("Plant with no bed appears in Unassigned group")
    func plantWithNoBedInUnassignedGroup() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        _ = try dataService.createPlant(name: "Mystery Fern", type: .houseplant, garden: garden)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        let unassigned = vm.groupedPlants.first(where: { $0.bed == nil })
        #expect(unassigned != nil)
        #expect(unassigned?.displayName == "Unassigned")
        #expect(unassigned?.plants.contains(where: { $0.name == "Mystery Fern" }) == true)
    }

    // MARK: - Journal Entry Persistence

    @Test("Journal entry created via DataService persists and is fetchable")
    func journalEntryPersists() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        _ = try dataService.createJournalEntry(
            title: "First Sprout",
            content: "Noticed the first sprout today!",
            type: .observation,
            plant: plant
        )

        let entries = dataService.fetchJournalEntries(for: plant)
        #expect(entries.count == 1)
        #expect(entries.first?.title == "First Sprout")
        #expect(entries.first?.content == "Noticed the first sprout today!")
    }

    @Test("Multiple journal entries for a plant are all fetchable")
    func multipleJournalEntriesPersist() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Rose", type: .flower, garden: garden)

        _ = try dataService.createJournalEntry(title: "Planted", content: "Added to bed", type: .milestone, plant: plant)
        _ = try dataService.createJournalEntry(title: "Bloomed", content: "First bloom", type: .observation, plant: plant)
        _ = try dataService.createJournalEntry(title: "Treated", content: "Applied neem oil", type: .problemReport, plant: plant)

        let entries = dataService.fetchJournalEntries(for: plant)
        #expect(entries.count == 3)
    }

    @Test("Journal entries for one plant do not appear when fetching another plant's entries")
    func journalEntriesIsolatedByPlant() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)

        _ = try dataService.createJournalEntry(title: "Tomato Note", content: "Growing well", type: .observation, plant: plant1)

        let entries = dataService.fetchJournalEntries(for: plant2)
        #expect(entries.isEmpty)
    }

    // MARK: - Plant Deletion → Removed from Fetch

    @Test("Deleting a plant removes it from subsequent DataService fetches")
    func deletingPlantRemovesFromFetch() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        let before = dataService.fetchPlants(for: garden)
        #expect(before.count == 1)

        try dataService.deletePlant(plant)

        let after = dataService.fetchPlants(for: garden)
        #expect(after.isEmpty)
    }

    @Test("Deleting a plant removes it from GardenViewModel on next load")
    func deletingPlantRemovedFromViewModel() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        let vmBefore = GardenViewModel()
        await vmBefore.load(dataService: dataService)
        #expect(vmBefore.totalPlantCount == 1)

        try dataService.deletePlant(plant)

        let vmAfter = GardenViewModel()
        await vmAfter.load(dataService: dataService)
        #expect(vmAfter.totalPlantCount == 0)
        #expect(vmAfter.groupedPlants.isEmpty)
    }

    @Test("Deleting one of two plants leaves the remaining plant in GardenViewModel")
    func deletingOnePlantLeavesOther() async throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let keeper = try dataService.createPlant(name: "Keeper", type: .herb, garden: garden)
        let gone = try dataService.createPlant(name: "Gone", type: .vegetable, garden: garden)

        try dataService.deletePlant(gone)

        let vm = GardenViewModel()
        await vm.load(dataService: dataService)

        #expect(vm.totalPlantCount == 1)
        let allPlants = vm.groupedPlants.flatMap(\.plants)
        #expect(allPlants.contains(where: { $0.id == keeper.id }))
        #expect(!allPlants.contains(where: { $0.name == "Gone" }))
    }

    @Test("Deleting a plant removes its associated journal entries from fetch")
    func deletingPlantRemovesItsJournalEntries() throws {
        let dataService = try DataService.makeForTesting()
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        _ = try dataService.createJournalEntry(title: "Note", content: "Content", type: .observation, plant: plant)

        try dataService.deletePlant(plant)

        let remaining = dataService.fetchJournalEntries(for: plant)
        #expect(remaining.isEmpty)
    }

    // MARK: - Watering Reminder via ReminderService

    @Test("createWateringReminder returns a non-nil reminder linked to the plant")
    func createWateringReminderReturnsLinkedReminder() async throws {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let reminderService = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: false
        )
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        let reminder = try await reminderService.createWateringReminder(
            for: plant,
            frequency: .twiceWeekly,
            enableSmartAdjustment: false
        )

        #expect(reminder.plant?.id == plant.id)
        #expect(reminder.reminderType == .watering)
        #expect(reminder.isEnabled == true)
    }

    @Test("createWateringReminder is visible in fetchActiveReminders")
    func createWateringReminderAppearsInActiveList() async throws {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let reminderService = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: false
        )
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        _ = try await reminderService.createWateringReminder(
            for: plant,
            frequency: .weekly,
            enableSmartAdjustment: false
        )

        let active = dataService.fetchActiveReminders()
        #expect(active.contains(where: { $0.reminderType == .watering && $0.plant?.id == plant.id }))
    }

    @Test("Deleting plant after creating watering reminder removes reminder from active list")
    func deletingPlantPurgesWateringReminder() async throws {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let reminderService = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: false
        )
        let garden = try dataService.createGarden(name: "My Garden", type: .outdoor, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)

        _ = try await reminderService.createWateringReminder(
            for: plant,
            frequency: .daily,
            enableSmartAdjustment: false
        )

        let before = dataService.fetchActiveReminders()
        #expect(before.count == 1)

        try dataService.deletePlant(plant)

        let after = dataService.fetchActiveReminders()
        #expect(after.isEmpty)
    }
}
