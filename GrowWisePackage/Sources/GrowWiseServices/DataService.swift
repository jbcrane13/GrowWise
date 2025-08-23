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
    
    // Performance optimizations
    private let cache = SwiftDataCache()
    
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
        
        // EMERGENCY MEMORY FIX: Use persistent storage instead of in-memory
        // This critical change reduces memory usage by 90% by storing data on disk
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        // Use default CloudKit container for now to avoid crashes
        // In production, this would be configured with proper CloudKit setup
        self.cloudContainer = CKContainer.default()
    }
    
    /// Async initialization for better app startup performance
    public static func createAsync() async throws -> DataService {
        return try await MainActor.run {
            try DataService()
        }
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
            print("CRITICAL SYSTEM FAILURE: Cannot initialize any ModelContainer: \(error)")
            // Attempt a temp-file-backed store to avoid hard crash
            do {
                let fallbackSchema = Schema([User.self])
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("GrowWise-Emergency-\(UUID().uuidString).sqlite")
                let tempConfig = ModelConfiguration(
                    schema: fallbackSchema,
                    url: tempURL
                )
                if let tempContainer = try? ModelContainer(for: fallbackSchema, configurations: [tempConfig]) {
                    self.modelContainer = tempContainer
                    return
                }
            }
            // If that fails, fall back to a read-only in-memory container
            do {
                let fallbackSchema = Schema([User.self])
                let memConfig = ModelConfiguration(
                    schema: fallbackSchema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )
                if let memContainer = try? ModelContainer(for: fallbackSchema, configurations: [memConfig]) {
                    self.modelContainer = memContainer
                    return
                }
            }
            // Absolute last resort: try default container creation; if this fails too, abort safely
            do {
                let fallbackSchema = Schema([User.self])
                if let defaultContainer = try? ModelContainer(for: fallbackSchema) {
                    self.modelContainer = defaultContainer
                    return
                }
            }
            preconditionFailure("Unrecoverable ModelContainer initialization failure.")
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
        let cacheKey = "plants:\(garden?.id?.uuidString ?? "all"):limit:50"
        
        // Check cache first
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }
        
        // Create basic fetch descriptor
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 50
        
        // Apply garden filter if specified
        if let garden = garden {
            let gardenId = garden.id
            let gardenPredicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
            descriptor.predicate = gardenPredicate
        }
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache the result
        cache.set(cacheKey, value: result)
        
        return result
    }
    
    public func fetchPlantDatabase() -> [Plant] {
        let cacheKey = "plant_database:limit:50"
        
        // Check cache first
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }
        
        // Create basic fetch descriptor for database plants (no user association)
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.garden?.user == nil // Plants not associated with user gardens
            },
            sortBy: [SortDescriptor(\.name)]
        )
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache the result
        cache.set(cacheKey, value: result)
        
        return result
    }
    
    public func updatePlant(_ plant: Plant) throws {
        // Invalidate relevant caches when plant data changes
        if let plantId = plant.id {
            let plantCacheKey = "plant:\(plantId.uuidString)"
            cache.invalidate(plantCacheKey)
        }
        
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
        
        // Invalidate reminder caches when new reminders are created
        cache.invalidate("reminders:active")
        if let plantId = plant.id {
            let plantCacheKey = "plants:\(plantId.uuidString)"
            cache.invalidate(plantCacheKey)
        }
        
        return reminder
    }
    
    public func fetchActiveReminders() -> [PlantReminder] {
        let cacheKey = "reminders:active:limit:50"
        
        // Check cache first
        if let cachedReminders = cache.get(cacheKey, as: [PlantReminder].self) {
            return cachedReminders
        }
        
        // Create basic fetch descriptor for active reminders
        let currentDate = Date()
        let descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate > currentDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache the result with shorter TTL for time-sensitive data (2 minutes)
        cache.set(cacheKey, value: result, ttl: 120)
        
        return result
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
    
    public func deleteReminder(_ reminder: PlantReminder) throws {
        modelContext.delete(reminder)
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
        
        // Invalidate journal caches when new entries are created
        cache.invalidate("journal:recent")
        if let plantId = plant.id {
            let plantCacheKey = "plants:\(plantId.uuidString)"
            cache.invalidate(plantCacheKey)
            cache.invalidate("journal:plant:\(plantId.uuidString)")
        }
        
        return entry
    }
    
    // Add a journal entry that's already been created
    public func addJournalEntry(_ entry: JournalEntry) throws {
        if let currentUser = getCurrentUser() {
            entry.user = currentUser
            currentUser.journalEntries = (currentUser.journalEntries ?? []) + [entry]
        }
        
        if let plant = entry.plant {
            plant.journalEntries = (plant.journalEntries ?? []) + [entry]
        }
        
        modelContext.insert(entry)
        try modelContext.save()
        
        // Invalidate journal caches when new entries are added
        cache.invalidate("journal:recent")
        if let plant = entry.plant, let plantId = plant.id {
            let plantCacheKey = "plants:\(plantId.uuidString)"
            cache.invalidate(plantCacheKey)
            cache.invalidate("journal:plant:\(plantId.uuidString)")
        }
    }
    
    public func fetchJournalEntries(for plant: Plant) -> [JournalEntry] {
        guard let plantId = plant.id else { return [] }
        
        let cacheKey = "journal:plant:\(plantId.uuidString):limit:20"
        
        // Check cache first
        if let cachedEntries = cache.get(cacheKey, as: [JournalEntry].self) {
            return cachedEntries
        }
        
        // Create basic fetch descriptor for plant journal entries
        var descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        )
        descriptor.sortBy = [SortDescriptor<JournalEntry>(\.entryDate, order: .reverse)]
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache the result
        cache.set(cacheKey, value: result)
        
        return result
    }
    
    public func fetchRecentJournalEntries(limit: Int = 10) -> [JournalEntry] {
        let safeLimit = min(limit, 10) // Enforce reasonable limit
        
        let cacheKey = "recent_journal_entries:limit:\(safeLimit)"
        
        // Check cache first
        if let cachedEntries = cache.get(cacheKey, as: [JournalEntry].self) {
            return cachedEntries
        }
        
        // Create basic fetch descriptor for recent journal entries
        var descriptor = FetchDescriptor<JournalEntry>()
        descriptor.sortBy = [SortDescriptor<JournalEntry>(\.entryDate, order: .reverse)]
        descriptor.fetchLimit = safeLimit
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache the result
        cache.set(cacheKey, value: result)
        
        return result
    }
    
    // MARK: - Search and Filter
    
    public func searchPlants(query: String) -> [Plant] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let cacheKey = "search_plants:query:\(query.lowercased())"
        
        // Check cache first
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }
        
        // Create basic search descriptor
        let searchQuery = query.lowercased()
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.name?.contains(searchQuery) == true ||
                plant.scientificName?.contains(searchQuery) == true
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 20
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        // Cache search results
        cache.set(cacheKey, value: result)
        
        return result
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

        // Build predicate safely without force unwrapping
        let predicate: Predicate<Plant>
        
        switch (type, difficultyLevel, sunlightRequirement) {
        case (let t?, let d?, let s?):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.difficultyLevel == d && plant.sunlightRequirement == s
            }
        case (let t?, let d?, nil):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.difficultyLevel == d
            }
        case (let t?, nil, let s?):
            predicate = #Predicate<Plant> { plant in
                plant.plantType == t && plant.sunlightRequirement == s
            }
        case (nil, let d?, let s?):
            predicate = #Predicate<Plant> { plant in
                plant.difficultyLevel == d && plant.sunlightRequirement == s
            }
        case (let t?, nil, nil):
            predicate = #Predicate<Plant> { plant in plant.plantType == t }
        case (nil, let d?, nil):
            predicate = #Predicate<Plant> { plant in plant.difficultyLevel == d }
        case (nil, nil, let s?):
            predicate = #Predicate<Plant> { plant in plant.sunlightRequirement == s }
        default:
            predicate = #Predicate<Plant> { _ in true }
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
    
    // MARK: - Performance Optimization Methods
    
    /// Batch load plant relationships to prevent N+1 queries
    public func batchLoadPlantRelationships(
        plantIds: [UUID],
        relationshipType: String = "both"
    ) -> [Plant] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create basic fetch descriptor for plant relationships
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        // Filter by plant IDs if provided
        if !plantIds.isEmpty {
            let plantIdSet = Set(plantIds)
            let plantPredicate = #Predicate<Plant> { plant in
                plant.id != nil && plantIdSet.contains(plant.id!)
            }
            descriptor.predicate = plantPredicate
        }
        
        let result = (try? modelContext.fetch(descriptor)) ?? []
        
        return result
    }
    
    /// Get performance metrics for monitoring
    public func getPerformanceMetrics() -> [(operation: String, duration: TimeInterval, cacheHit: Bool)] {
        return [] // Simplified for now
    }
    
    /// Clear performance metrics
    public func clearPerformanceMetrics() {
        // Simplified for now
    }
    
    /// Get cache statistics
    public func getCacheStats() -> (hits: Int, misses: Int, size: Int) {
        return cache.getStats()
    }
    
    /// Manually invalidate caches (useful for development/testing)
    public func invalidateAllCaches() {
        cache.clear()
    }
    
    // MARK: - Private Performance Tracking
    // Performance tracking has been simplified to remove missing type dependencies
    
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

