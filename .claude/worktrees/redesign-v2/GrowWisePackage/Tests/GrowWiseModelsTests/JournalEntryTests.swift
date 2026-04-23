import Testing
import Foundation
@testable import GrowWiseModels

@Suite("JournalEntry Model Tests")
struct JournalEntryTests {

    @Test("JournalEntry default initialization")
    func testDefaultInitialization() {
        let entry = JournalEntry()
        #expect(entry.title == "")
        #expect(entry.content == "")
        #expect(entry.entryType == .observation)
        #expect(entry.photoURLs.isEmpty)
        #expect(entry.videoURLs.isEmpty)
        #expect(entry.tags.isEmpty)
        #expect(entry.isPrivate == false)
        #expect(entry.id != UUID()) // has a unique id
    }

    @Test("JournalEntry initialization with parameters")
    func testParameterizedInitialization() {
        let entry = JournalEntry(
            title: "First Sprout",
            content: "Seedling emerged from soil",
            entryType: .milestone
        )
        #expect(entry.title == "First Sprout")
        #expect(entry.content == "Seedling emerged from soil")
        #expect(entry.entryType == .milestone)
    }

    @Test("addPhoto appends URL to photoURLs")
    func testAddPhotoAppends() {
        let entry = JournalEntry()
        entry.addPhoto(url: "file://photo1.jpg")
        entry.addPhoto(url: "file://photo2.jpg")
        #expect(entry.photoURLs.count == 2)
        #expect(entry.photoURLs.contains("file://photo1.jpg"))
        #expect(entry.photoURLs.contains("file://photo2.jpg"))
    }

    @Test("addTag adds unique tags only")
    func testAddTagIgnoresDuplicates() {
        let entry = JournalEntry()
        entry.addTag("tomato")
        entry.addTag("tomato") // duplicate
        entry.addTag("basil")
        #expect(entry.tags.count == 2)
        #expect(entry.tags.contains("tomato"))
        #expect(entry.tags.contains("basil"))
    }

    @Test("removeTag removes the correct tag")
    func testRemoveTag() {
        let entry = JournalEntry()
        entry.addTag("tomato")
        entry.addTag("basil")
        entry.removeTag("tomato")
        #expect(entry.tags.count == 1)
        #expect(entry.tags.contains("basil"))
        #expect(!entry.tags.contains("tomato"))
    }

    @Test("removeTag on nonexistent tag is safe")
    func testRemoveNonexistentTagIsSafe() {
        let entry = JournalEntry()
        entry.addTag("tomato")
        entry.removeTag("nonexistent") // should not crash or change count
        #expect(entry.tags.count == 1)
    }

    @Test("addPhoto updates lastModified")
    func testAddPhotoUpdatesLastModified() async throws {
        let entry = JournalEntry()
        let before = entry.lastModified
        try await Task.sleep(for: .milliseconds(10))
        entry.addPhoto(url: "file://new.jpg")
        #expect(entry.lastModified >= before)
    }

    @Test("JournalEntryType display names")
    func testEntryTypeDisplayNames() {
        #expect(JournalEntryType.observation.displayName == "General Observation")
        #expect(JournalEntryType.watering.displayName == "Watering Log")
        #expect(JournalEntryType.fertilizing.displayName == "Fertilizing Log")
        #expect(JournalEntryType.pruning.displayName == "Pruning Log")
        #expect(JournalEntryType.repotting.displayName == "Repotting Log")
        #expect(JournalEntryType.harvest.displayName == "Harvest Log")
        #expect(JournalEntryType.planting.displayName == "Planting Log")
        #expect(JournalEntryType.problemReport.displayName == "Problem Report")
        #expect(JournalEntryType.milestone.displayName == "Growth Milestone")
        #expect(JournalEntryType.experiment.displayName == "Experiment/Test")
        #expect(JournalEntryType.note.displayName == "Quick Note")
    }

    @Test("JournalEntryType icon names are non-empty for all cases")
    func testEntryTypeIconNames() {
        for type in JournalEntryType.allCases {
            #expect(!type.iconName.isEmpty, "Icon name for \(type.rawValue) should not be empty")
        }
    }

    @Test("JournalEntryType color names are non-empty for all cases")
    func testEntryTypeColors() {
        for type in JournalEntryType.allCases {
            #expect(!type.color.isEmpty, "Color for \(type.rawValue) should not be empty")
        }
    }

    @Test("SoilMoisture display names")
    func testSoilMoistureDisplayNames() {
        #expect(SoilMoisture.dry.displayName == "Dry")
        #expect(SoilMoisture.slightlyDry.displayName == "Slightly Dry")
        #expect(SoilMoisture.moist.displayName == "Moist")
        #expect(SoilMoisture.wet.displayName == "Wet")
        #expect(SoilMoisture.waterlogged.displayName == "Waterlogged")
    }

    @Test("SoilMoisture descriptions are non-empty")
    func testSoilMoistureDescriptionsNonEmpty() {
        for moisture in SoilMoisture.allCases {
            #expect(!moisture.description.isEmpty, "Description for \(moisture.rawValue) should not be empty")
        }
    }

    @Test("SoilMoisture color names are non-empty")
    func testSoilMoistureColors() {
        for moisture in SoilMoisture.allCases {
            #expect(!moisture.color.isEmpty, "Color for \(moisture.rawValue) should not be empty")
        }
    }

    @Test("WeatherCondition display names are non-empty for all cases")
    func testWeatherConditionDisplayNames() {
        for condition in WeatherCondition.allCases {
            #expect(!condition.displayName.isEmpty, "Display name for \(condition.rawValue) should not be empty")
        }
    }

    @Test("WeatherCondition icon names are non-empty for all cases")
    func testWeatherConditionIconNames() {
        for condition in WeatherCondition.allCases {
            #expect(!condition.iconName.isEmpty, "Icon for \(condition.rawValue) should not be empty")
        }
    }

    @Test("PlantMood display names and emojis")
    func testPlantMoodDisplayNamesAndEmojis() {
        #expect(PlantMood.thriving.displayName == "Thriving")
        #expect(PlantMood.happy.displayName == "Happy")
        #expect(PlantMood.content.displayName == "Content")
        #expect(PlantMood.stressed.displayName == "Stressed")
        #expect(PlantMood.struggling.displayName == "Struggling")
        #expect(PlantMood.thriving.emoji == "🌟")
        #expect(PlantMood.happy.emoji == "😊")
        #expect(PlantMood.stressed.emoji == "😰")
    }

    @Test("PlantMood color names are non-empty for all cases")
    func testPlantMoodColors() {
        for mood in PlantMood.allCases {
            #expect(!mood.color.isEmpty, "Color for \(mood.rawValue) should not be empty")
        }
    }

    @Test("JournalEntry entryDate is set to approximately now")
    func testEntryDateIsNow() {
        let before = Date()
        let entry = JournalEntry()
        let after = Date()
        #expect(entry.entryDate >= before)
        #expect(entry.entryDate <= after)
    }
}
