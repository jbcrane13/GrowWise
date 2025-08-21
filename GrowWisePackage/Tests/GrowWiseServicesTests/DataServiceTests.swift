import Testing
import Foundation
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("DataService Tests")
struct DataServiceTests {
    
    // MARK: - Test Fixtures
    
    private func createInMemoryDataService() throws -> DataService {
        // Create an in-memory data service for testing
        let schema = Schema([
            Plant.self,
            Garden.self,
            User.self,
            PlantReminder.self,
            JournalEntry.self,
            ReminderSettings.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        return try DataService()
    }
    
    @Test("DataService initialization")
    func testDataServiceInitialization() async throws {
        // Act & Assert - Should not throw
        let dataService = try createInMemoryDataService()
        #expect(dataService != nil)
    }
    
    @Test("Create user with valid data")
    func testCreateUserWithValidData() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let email = "test@example.com"
        let displayName = "Test User"
        let skillLevel = GardeningSkillLevel.intermediate
        
        // Act
        let user = try dataService.createUser(email: email, displayName: displayName, skillLevel: skillLevel)
        
        // Assert
        #expect(user.email == email)
        #expect(user.displayName == displayName)
        #expect(user.skillLevel == skillLevel)
        #expect(user.id != UUID())
    }
    
    @Test("Get current user returns most recent")
    func testGetCurrentUserReturnsMostRecent() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let firstUser = try dataService.createUser(email: "first@example.com", displayName: "First User", skillLevel: .beginner)
        
        // Sleep briefly to ensure different timestamps
        try await Task.sleep(for: .milliseconds(10))
        
        let secondUser = try dataService.createUser(email: "second@example.com", displayName: "Second User", skillLevel: .intermediate)
        
        // Act
        let currentUser = dataService.getCurrentUser()
        
        // Assert
        #expect(currentUser?.id == secondUser.id)
        #expect(currentUser?.email == "second@example.com")
    }
    
    @Test("Update user modifies lastModified timestamp")
    func testUpdateUserModifiesTimestamp() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let user = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let originalTimestamp = user.lastModified
        
        // Sleep to ensure timestamp difference
        try await Task.sleep(for: .milliseconds(10))
        
        // Act
        user.displayName = "Updated Name"
        try dataService.updateUser(user)
        
        // Assert
        #expect(user.lastModified > originalTimestamp)
        #expect(user.displayName == "Updated Name")
    }
    
    @Test("Create garden with valid data")
    func testCreateGardenWithValidData() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let user = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let gardenName = "My Garden"
        let gardenType = GardenType.vegetable
        
        // Act
        let garden = try dataService.createGarden(name: gardenName, type: gardenType, isIndoor: false)
        
        // Assert
        #expect(garden.name == gardenName)
        #expect(garden.gardenType == gardenType)
        #expect(garden.isIndoor == false)
        #expect(garden.user?.id == user.id)
        #expect(user.gardens.contains(where: { $0.id == garden.id }))
    }
    
    @Test("Fetch gardens returns created gardens")
    func testFetchGardensReturnsCreatedGardens() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden1 = try dataService.createGarden(name: "Garden A", type: .vegetable, isIndoor: false)
        let garden2 = try dataService.createGarden(name: "Garden B", type: .herb, isIndoor: true)
        
        // Act
        let fetchedGardens = dataService.fetchGardens()
        
        // Assert
        #expect(fetchedGardens.count == 2)
        #expect(fetchedGardens.contains(where: { $0.id == garden1.id }))
        #expect(fetchedGardens.contains(where: { $0.id == garden2.id }))
    }
    
    @Test("Create plant with valid data")
    func testCreatePlantWithValidData() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .vegetable, isIndoor: false)
        let plantName = "Tomato"
        let plantType = PlantType.vegetable
        
        // Act
        let plant = try dataService.createPlant(name: plantName, type: plantType, garden: garden)
        
        // Assert
        #expect(plant.name == plantName)
        #expect(plant.plantType == plantType)
        #expect(plant.garden?.id == garden.id)
        #expect(garden.plants.contains(where: { $0.id == plant.id }))
    }
    
    @Test("Fetch plants for specific garden")
    func testFetchPlantsForSpecificGarden() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden1 = try dataService.createGarden(name: "Garden 1", type: .vegetable, isIndoor: false)
        let garden2 = try dataService.createGarden(name: "Garden 2", type: .herb, isIndoor: true)
        
        let plant1 = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden1)
        let plant2 = try dataService.createPlant(name: "Basil", type: .herb, garden: garden2)
        let plant3 = try dataService.createPlant(name: "Pepper", type: .vegetable, garden: garden1)
        
        // Act
        let garden1Plants = dataService.fetchPlants(for: garden1)
        let garden2Plants = dataService.fetchPlants(for: garden2)
        
        // Assert
        #expect(garden1Plants.count == 2)
        #expect(garden1Plants.contains(where: { $0.id == plant1.id }))
        #expect(garden1Plants.contains(where: { $0.id == plant3.id }))
        
        #expect(garden2Plants.count == 1)
        #expect(garden2Plants.contains(where: { $0.id == plant2.id }))
    }
    
    @Test("Search plants by name")
    func testSearchPlantsByName() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .vegetable, isIndoor: false)
        
        let _ = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let _ = try dataService.createPlant(name: "Cherry Tomato", type: .vegetable, garden: garden)
        let _ = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        
        // Act
        let tomatoResults = dataService.searchPlants(query: "tomato")
        let basilResults = dataService.searchPlants(query: "basil")
        
        // Assert
        #expect(tomatoResults.count == 2)
        #expect(basilResults.count == 1)
    }
    
    @Test("Filter plants by type")
    func testFilterPlantsByType() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .mixed, isIndoor: false)
        
        let _ = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        let _ = try dataService.createPlant(name: "Basil", type: .herb, garden: garden)
        let _ = try dataService.createPlant(name: "Rose", type: .flower, garden: garden)
        
        // Act
        let vegetables = dataService.filterPlants(by: .vegetable)
        let herbs = dataService.filterPlants(by: .herb)
        let flowers = dataService.filterPlants(by: .flower)
        
        // Assert
        #expect(vegetables.count == 1)
        #expect(herbs.count == 1)
        #expect(flowers.count == 1)
    }
    
    @Test("Create reminder with valid data")
    func testCreateReminderWithValidData() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let user = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .vegetable, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        
        let title = "Water Tomato"
        let message = "Time to water your tomato plant"
        let type = ReminderType.watering
        let frequency = ReminderFrequency.daily
        let dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        
        // Act
        let reminder = try dataService.createReminder(
            title: title,
            message: message,
            type: type,
            frequency: frequency,
            dueDate: dueDate,
            plant: plant
        )
        
        // Assert
        #expect(reminder.title == title)
        #expect(reminder.message == message)
        #expect(reminder.reminderType == type)
        #expect(reminder.frequency == frequency)
        #expect(reminder.nextDueDate == dueDate)
        #expect(reminder.plant?.id == plant.id)
        #expect(reminder.user?.id == user.id)
        #expect(plant.reminders.contains(where: { $0.id == reminder.id }))
        #expect(user.reminders.contains(where: { $0.id == reminder.id }))
    }
    
    @Test("Fetch active reminders")
    func testFetchActiveReminders() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .vegetable, isIndoor: false)
        let plant = try dataService.createPlant(name: "Tomato", type: .vegetable, garden: garden)
        
        // Create reminders with different due dates
        let pastDue = Date().addingTimeInterval(-3600) // 1 hour ago
        let futureDue = Date().addingTimeInterval(3600) // 1 hour from now
        
        let activeReminder = try dataService.createReminder(
            title: "Past Due",
            message: "Should be active",
            type: .watering,
            frequency: .daily,
            dueDate: pastDue,
            plant: plant
        )
        
        let futureReminder = try dataService.createReminder(
            title: "Future Due",
            message: "Should not be active yet",
            type: .watering,
            frequency: .daily,
            dueDate: futureDue,
            plant: plant
        )
        
        // Act
        let activeReminders = dataService.fetchActiveReminders()
        
        // Assert
        #expect(activeReminders.count == 1)
        #expect(activeReminders.first?.id == activeReminder.id)
    }
    
    @Test("Get gardening stats")
    func testGetGardeningStats() async throws {
        // Arrange
        let dataService = try createInMemoryDataService()
        let _ = try dataService.createUser(email: "test@example.com", displayName: "Test User", skillLevel: .beginner)
        let garden = try dataService.createGarden(name: "Test Garden", type: .vegetable, isIndoor: false)
        
        // Create plants with different health statuses
        let healthyPlant = try dataService.createPlant(name: "Healthy Plant", type: .vegetable, garden: garden)
        healthyPlant.healthStatus = .healthy
        
        let sickPlant = try dataService.createPlant(name: "Sick Plant", type: .herb, garden: garden)
        sickPlant.healthStatus = .sick
        
        let needsAttentionPlant = try dataService.createPlant(name: "Needs Attention", type: .flower, garden: garden)
        needsAttentionPlant.healthStatus = .needsAttention
        
        // Act
        let stats = dataService.getGardeningStats()
        
        // Assert
        #expect(stats.totalPlants == 3)
        #expect(stats.healthyPlants == 1)
        #expect(stats.healthPercentage ≈ 33.33, .ulpOfOne.magnitude * 100)
    }
}

// MARK: - Helper Extensions

fileprivate extension Double {
    static func ≈(lhs: Double, rhs: Double, tolerance: Double) -> Bool {
        return abs(lhs - rhs) < tolerance
    }
}