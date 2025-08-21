import Foundation
import GrowWiseModels

@MainActor
public final class MockDataService: ObservableObject {
    
    public init() throws {
        // MockDataService for testing - no longer inherits from DataService
    }
    
    // MARK: - User Management
    
    public func createUser(email: String, displayName: String, skillLevel: GardeningSkillLevel) throws -> User {
        return User(email: email, displayName: displayName, skillLevel: skillLevel)
    }
    
    public func getCurrentUser() -> User? {
        return User(email: "demo@growwise.app", displayName: "Demo User", skillLevel: .beginner)
    }
    
    public func updateUser(_ user: User) throws {
        // Mock implementation
    }
    
    // MARK: - Garden Management
    
    public func createGarden(name: String, type: GardenType, isIndoor: Bool) throws -> Garden {
        return Garden(name: name, gardenType: type, isIndoor: isIndoor)
    }
    
    public func fetchGardens() -> [Garden] {
        return [
            Garden(name: "Herb Garden", gardenType: .outdoor, isIndoor: false),
            Garden(name: "Indoor Plants", gardenType: .container, isIndoor: true)
        ]
    }
    
    public func deleteGarden(_ garden: Garden) throws {
        // Mock implementation
    }
    
    // MARK: - Plant Management
    
    public func createPlant(
        name: String,
        type: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        garden: Garden? = nil
    ) throws -> Plant {
        return Plant(name: name, plantType: type, difficultyLevel: difficultyLevel)
    }
    
    public func fetchPlants(for garden: Garden? = nil) -> [Plant] {
        return [
            Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner),
            Plant(name: "Tomato", plantType: .vegetable, difficultyLevel: .intermediate)
        ]
    }
    
    public func fetchPlantDatabase() -> [Plant] {
        return [
            Plant(name: "Basil", plantType: .herb, difficultyLevel: .beginner),
            Plant(name: "Tomato", plantType: .vegetable, difficultyLevel: .intermediate),
            Plant(name: "Rose", plantType: .flower, difficultyLevel: .advanced),
            Plant(name: "Mint", plantType: .herb, difficultyLevel: .beginner)
        ]
    }
    
    public func updatePlant(_ plant: Plant) throws {
        // Mock implementation
    }
    
    public func deletePlant(_ plant: Plant) throws {
        // Mock implementation
    }
    
    // MARK: - Reminder Management
    
    public func createReminder(
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        dueDate: Date,
        plant: Plant
    ) throws -> PlantReminder {
        return PlantReminder(
            title: title,
            message: message,
            reminderType: type,
            frequency: frequency,
            nextDueDate: dueDate,
            plant: plant
        )
    }
    
    public func fetchActiveReminders() -> [PlantReminder] {
        let plant = Plant(name: "Demo Plant", plantType: .herb, difficultyLevel: .beginner)
        return [
            PlantReminder(
                title: "Water Plants",
                message: "Time to water your herbs",
                reminderType: .watering,
                frequency: .daily,
                nextDueDate: Date(),
                plant: plant
            )
        ]
    }
    
    public func fetchUpcomingReminders(days: Int = 7) -> [PlantReminder] {
        return fetchActiveReminders()
    }
    
    public func completeReminder(_ reminder: PlantReminder) throws {
        // Mock implementation
    }
    
    // MARK: - Journal Management
    
    public func createJournalEntry(
        title: String,
        content: String,
        type: JournalEntryType,
        plant: Plant
    ) throws -> JournalEntry {
        return JournalEntry(title: title, content: content, entryType: type, plant: plant)
    }
    
    public func fetchJournalEntries(for plant: Plant) -> [JournalEntry] {
        return [
            JournalEntry(
                title: "First Planting",
                content: "Planted my first herbs today!",
                entryType: .observation,
                plant: plant
            )
        ]
    }
    
    public func fetchRecentJournalEntries(limit: Int = 10) -> [JournalEntry] {
        let plant = Plant(name: "Demo Plant", plantType: .herb, difficultyLevel: .beginner)
        return fetchJournalEntries(for: plant)
    }
    
    // MARK: - Search and Filter
    
    public func searchPlants(query: String) -> [Plant] {
        return fetchPlantDatabase().filter { plant in
            plant.name.lowercased().contains(query.lowercased())
        }
    }
    
    public func filterPlants(
        by type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil
    ) -> [Plant] {
        var plants = fetchPlantDatabase()
        
        if let type = type {
            plants = plants.filter { $0.plantType == type }
        }
        
        if let difficulty = difficultyLevel {
            plants = plants.filter { $0.difficultyLevel == difficulty }
        }
        
        if let sunlight = sunlightRequirement {
            plants = plants.filter { $0.sunlightRequirement == sunlight }
        }
        
        return plants
    }
    
    // MARK: - Statistics
    
    public func getGardeningStats() -> GardeningStats {
        return GardeningStats(
            totalPlants: 4,
            healthyPlants: 3,
            activeReminders: 2,
            totalJournalEntries: 5
        )
    }
    
    // MARK: - Data Export/Import
    
    public func exportUserData() async throws -> Data {
        let userData = UserDataExport(
            userEmail: "demo@growwise.app",
            totalPlants: 4,
            totalGardens: 2,
            totalReminders: 2,
            totalJournalEntries: 5
        )
        
        return try JSONEncoder().encode(userData)
    }
    
    // MARK: - CloudKit Sync Status
    
    public func getCloudSyncStatus() async -> CloudSyncStatus {
        return CloudSyncStatus(
            isAvailable: false,
            accountStatus: .noAccount,
            lastSync: nil,
            error: "Mock service - CloudKit disabled"
        )
    }
}