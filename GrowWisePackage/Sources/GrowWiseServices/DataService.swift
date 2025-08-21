import Foundation
import SwiftData
import CloudKit
import GrowWiseModels

@MainActor
public final class DataService: ObservableObject {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    // CloudKit container for sync
    private let cloudContainer: CKContainer
    
    public init() throws {
        // Configure SwiftData model container without CloudKit for testing
        let schema = Schema([
            Plant.self,
            Garden.self,
            User.self,
            PlantReminder.self,
            JournalEntry.self
        ])
        
        // Use in-memory storage for testing to avoid CloudKit validation
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        // Use default CloudKit container for now to avoid crashes
        // In production, this would be configured with proper CloudKit setup
        self.cloudContainer = CKContainer.default()
    }
    
    /// Creates a fallback DataService instance with minimal functionality to prevent app crashes
    public static func createFallback() -> DataService {
        // Create a truly minimal DataService that won't crash
        do {
            return try createFallbackOrThrow()
        } catch {
            // Final fallback - log error but return a stub service to prevent crashes
            print("CRITICAL: Cannot create fallback DataService: \(error)")
            print("Creating emergency stub service to prevent app crash")
            return DataService.__allocating_init_emergency_stub()
        }
    }
    
    /// Private minimal initializer for fallback
    private init(minimal container: ModelContainer) {
        self.modelContainer = container
        self.cloudContainer = CKContainer.default()
    }
    
    /// Static factory method for minimal DataService
    private static func __allocating_init_minimal(container: ModelContainer) -> DataService {
        return DataService(minimal: container)
    }
    
    /// Emergency stub service that does nothing but prevents crashes
    private static func __allocating_init_emergency_stub() -> DataService {
        return DataService(emergencyStub: true)
    }
    
    /// Emergency stub initializer
    private init(emergencyStub: Bool) {
        // This is an emergency stub to prevent app crashes
        // Use CKContainer.default() to avoid initialization failures
        self.cloudContainer = CKContainer.default()
        
        // Create a minimal in-memory container with just User
        do {
            let schema = Schema([User.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Last resort - this should never happen but if it does, we'll handle it gracefully
            print("EMERGENCY: Cannot create even minimal ModelContainer: \(error)")
            // We'll initialize with a default container and accept potential issues
            let schema = Schema([User.self])
            do {
                self.modelContainer = try ModelContainer(for: schema)
            } catch {
                // Absolute last resort - use a completely empty container
                fatalError("CRITICAL SYSTEM FAILURE: Cannot initialize any ModelContainer: \(error)")
            }
        }
    }
    
    // MARK: - User Management
    @discardableResult
    public func createUser(email: String, displayName: String, skillLevel: GardeningSkillLevel) throws -> User {
        let user = User(email: email, displayName: displayName, skillLevel: skillLevel)
        modelContext.insert(user)
        try modelContext.save()
        return user
    }
    
    public func getCurrentUser() -> User? {
        let descriptor = FetchDescriptor<User>(
            sortBy: [SortDescriptor(\.lastLoginDate, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    public func updateUser(_ user: User) throws {
        user.lastModified = Date()
        try modelContext.save()
    }
    
    // MARK: - Garden Management
    @discardableResult
    public func createGarden(name: String, type: GardenType, isIndoor: Bool) throws -> Garden {
        let garden = Garden(name: name, gardenType: type, isIndoor: isIndoor)
        
        if let currentUser = getCurrentUser() {
            garden.user = currentUser
            currentUser.gardens = (currentUser.gardens ?? []) + [garden]
        }
        
        modelContext.insert(garden)
        try modelContext.save()
        return garden
    }
    
    public func fetchGardens() -> [Garden] {
        let descriptor = FetchDescriptor<Garden>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func deleteGarden(_ garden: Garden) throws {
        modelContext.delete(garden)
        try modelContext.save()
    }
    
    // MARK: - Plant Management
    @discardableResult
    public func createPlant(
        name: String,
        type: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        garden: Garden? = nil
    ) throws -> Plant {
        let plant = Plant(name: name, plantType: type, difficultyLevel: difficultyLevel)
        
        if let garden = garden {
            plant.garden = garden
            garden.plants = (garden.plants ?? []) + [plant]
        }
        
        modelContext.insert(plant)
        try modelContext.save()
        return plant
    }
    
    public func fetchPlants(for garden: Garden? = nil) -> [Plant] {
        var descriptor: FetchDescriptor<Plant>

        if let garden = garden {
            let gardenId = garden.id
            descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate<Plant> { plant in
                    plant.garden?.id == gardenId
                },
                sortBy: [SortDescriptor(\.name)]
            )
        } else {
            descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate { $0.isUserPlant ?? false == true },
                sortBy: [SortDescriptor(\.name)]
            )
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func fetchPlantDatabase() -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate { $0.isUserPlant ?? false == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func updatePlant(_ plant: Plant) throws {
        try modelContext.save()
    }
    
    public func deletePlant(_ plant: Plant) throws {
        modelContext.delete(plant)
        try modelContext.save()
    }
    
    // MARK: - Reminder Management
    @discardableResult
    public func createReminder(
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        dueDate: Date,
        plant: Plant
    ) throws -> PlantReminder {
        let reminder = PlantReminder(
            title: title,
            message: message,
            reminderType: type,
            frequency: frequency,
            nextDueDate: dueDate,
            plant: plant
        )
        
        if let currentUser = getCurrentUser() {
            reminder.user = currentUser
            currentUser.reminders = (currentUser.reminders ?? []) + [reminder]
        }
        
        plant.reminders = (plant.reminders ?? []) + [reminder]
        modelContext.insert(reminder)
        try modelContext.save()
        return reminder
    }
    
    public func fetchActiveReminders() -> [PlantReminder] {
        let now = Date()
        let descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate { reminder in
                reminder.isEnabled == true && reminder.nextDueDate <= now
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func fetchUpcomingReminders(days: Int = 7) -> [PlantReminder] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        
        let descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate { reminder in
                reminder.isEnabled == true &&
                reminder.nextDueDate > now &&
                reminder.nextDueDate <= futureDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func completeReminder(_ reminder: PlantReminder) throws {
        reminder.markCompleted()
        try modelContext.save()
    }
    
    // MARK: - Journal Management
    @discardableResult
    public func createJournalEntry(
        title: String,
        content: String,
        type: JournalEntryType,
        plant: Plant
    ) throws -> JournalEntry {
        let entry = JournalEntry(title: title, content: content, entryType: type, plant: plant)
        
        if let currentUser = getCurrentUser() {
            entry.user = currentUser
            currentUser.journalEntries = (currentUser.journalEntries ?? []) + [entry]
        }
        
        plant.journalEntries = (plant.journalEntries ?? []) + [entry]
        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }
    
    public func fetchJournalEntries(for plant: Plant) -> [JournalEntry] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            },
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func fetchRecentJournalEntries(limit: Int = 10) -> [JournalEntry] {
        var descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Search and Filter
    
    public func searchPlants(query: String) -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate { plant in
                plant.name?.localizedStandardContains(query) == true ||
                (plant.scientificName?.localizedStandardContains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func filterPlants(
        by type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil
    ) -> [Plant] {
        let noFilters = (type == nil && difficultyLevel == nil && sunlightRequirement == nil)

        if noFilters {
            let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
            return (try? modelContext.fetch(descriptor)) ?? []
        }

        let predicate = #Predicate<Plant> { plant in
            (type == nil || plant.plantType == type!) &&
            (difficultyLevel == nil || plant.difficultyLevel == difficultyLevel!) &&
            (sunlightRequirement == nil || plant.sunlightRequirement == sunlightRequirement!)
        }

        let descriptor = FetchDescriptor<Plant>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Statistics
    
    public func getGardeningStats() -> GardeningStats {
        let plants = fetchPlants()
        let totalPlants = plants.count
        let healthyPlants = plants.reduce(0) { $0 + ($1.healthStatus == .healthy ? 1 : 0) }
        let activeReminders = fetchActiveReminders().count
        let journalEntries = fetchRecentJournalEntries(limit: 1000).count

        return GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: healthyPlants,
            activeReminders: activeReminders,
            totalJournalEntries: journalEntries
        )
    }
    
    // MARK: - Data Export/Import
    
    public func exportUserData() async throws -> Data {
        // Implementation for exporting user data for backup/transfer
        // This would serialize all user data to JSON
        let user = getCurrentUser()
        let gardens = fetchGardens()
        let plants = fetchPlants()
        let reminders = fetchUpcomingReminders(days: 365)
        let journalEntries = fetchRecentJournalEntries(limit: 1000)
        
        let userData = UserDataExport(
            userEmail: user?.email,
            totalPlants: plants.count,
            totalGardens: gardens.count,
            totalReminders: reminders.count,
            totalJournalEntries: journalEntries.count
        )
        
        return try JSONEncoder().encode(userData)
    }
    
    // MARK: - CloudKit Sync Status
    
    public func getCloudSyncStatus() async -> CloudSyncStatus {
        do {
            let accountStatus = try await cloudContainer.accountStatus()
            return CloudSyncStatus(
                isAvailable: accountStatus == .available,
                accountStatus: accountStatus,
                lastSync: UserDefaults.standard.object(forKey: "lastCloudSync") as? Date
            )
        } catch {
            return CloudSyncStatus(
                isAvailable: false,
                accountStatus: .noAccount,
                lastSync: nil,
                error: error.localizedDescription
            )
        }
    }
}
// MARK: - Errors
public enum DataServiceError: Error, LocalizedError {
    case criticalInitializationFailure(String)
    public var errorDescription: String? {
        switch self {
        case .criticalInitializationFailure(let message):
            return message
        }
    }
}

extension DataService {
    /// A throwing variant of `createFallback()` so callers that can handle errors don't have to rely on emergency stubs.
    public static func createFallbackOrThrow() throws -> DataService {
        do {
            let schema = Schema([User.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return DataService.__allocating_init_minimal(container: container)
        } catch {
            throw DataServiceError.criticalInitializationFailure("Cannot create fallback DataService: \(error)")
        }
    }
}
// MARK: - Supporting Types

public struct GardeningStats: Sendable {
    public let totalPlants: Int
    public let healthyPlants: Int
    public let activeReminders: Int
    public let totalJournalEntries: Int
    
    public init(totalPlants: Int, healthyPlants: Int, activeReminders: Int, totalJournalEntries: Int) {
        self.totalPlants = totalPlants
        self.healthyPlants = healthyPlants
        self.activeReminders = activeReminders
        self.totalJournalEntries = totalJournalEntries
    }
    
    public var healthPercentage: Double {
        guard totalPlants > 0 else { return 0 }
        return Double(healthyPlants) / Double(totalPlants) * 100
    }
}

public struct CloudSyncStatus {
    public let isAvailable: Bool
    public let accountStatus: CKAccountStatus
    public let lastSync: Date?
    public let error: String?
    
    public init(isAvailable: Bool, accountStatus: CKAccountStatus, lastSync: Date?, error: String? = nil) {
        self.isAvailable = isAvailable
        self.accountStatus = accountStatus
        self.lastSync = lastSync
        self.error = error
    }
}

// Note: SwiftData models don't automatically conform to Codable
// For data export, we'll implement a separate export structure in a future iteration
public struct UserDataExport: Codable {
    public let exportDate: Date
    public let userEmail: String?
    public let totalPlants: Int
    public let totalGardens: Int
    public let totalReminders: Int
    public let totalJournalEntries: Int
    
    public init(userEmail: String?, totalPlants: Int, totalGardens: Int, totalReminders: Int, totalJournalEntries: Int) {
        self.exportDate = Date()
        self.userEmail = userEmail
        self.totalPlants = totalPlants
        self.totalGardens = totalGardens
        self.totalReminders = totalReminders
        self.totalJournalEntries = totalJournalEntries
    }
}

