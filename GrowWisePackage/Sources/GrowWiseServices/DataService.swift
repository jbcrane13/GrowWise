import CloudKit
import Foundation
import GrowWiseModels
import os
import SwiftData

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable file_length function_parameter_count large_tuple type_body_length

/// Modern @Observable data service for SwiftData operations
/// Injected via environment - access with @Environment(DataService.self)
/// No longer uses ObservableObject pattern - automatic observation with @Observable
///
/// DataService is a coordinator that:
/// 1. Owns the ModelContainer and provides ModelContext
/// 2. Manages the cache (SwiftDataCache)
/// 3. Delegates domain operations to repositories
/// 4. Provides the test factory `makeForTesting()`
@MainActor
@Observable
public final class DataService {
    private let modelContainer: ModelContainer
    /// internal — use DataService facade methods from feature layer
    var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Domain Repositories (stored, not re-allocated on each access)

    public let plants: PlantRepository
    public let gardens: GardenRepository
    public let reminders: ReminderRepository
    public let journals: JournalRepository
    public let users: UserRepository
    public let stats: StatsRepository
    public let seeds: SeedRepository

    /// Expose ModelContainer for background operations (e.g., PlantSeedingWorker)
    /// Workers can create their own background ModelContext for safe concurrency
    public nonisolated var container: ModelContainer {
        modelContainer
    }

    /// Performance optimizations
    private let cache = SwiftDataCache()

    /// CloudKit container for sync — nil during UI testing (CKContainer crashes on simulator)
    private let cloudContainer: CKContainer?

    /// Logger for initialization tracking
    private let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")

    // MARK: - Initialization

    /// Legacy synchronous initialization - prefer createAsync() for better performance
    public init() throws {
        let initStartTime = CFAbsoluteTimeGetCurrent()
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")

        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        logger.info("[DataService] Creating ModelContainer (\(isUITesting ? "in-memory" : "CloudKit-backed", privacy: .public) storage)")

        let container = try ModelContainerFactory.make(isUITesting: isUITesting)
        self.modelContainer = container

        if isUITesting {
            self.cloudContainer = nil
        } else {
            self.cloudContainer = CKContainer(identifier: "iCloud.com.growwise.gardening")
        }

        // Initialize repositories with shared context
        let repos = Self.makeRepositories(from: container.mainContext)
        self.plants = repos.plants
        self.gardens = repos.gardens
        self.reminders = repos.reminders
        self.journals = repos.journals
        self.users = repos.users
        self.stats = repos.stats
        self.seeds = repos.seeds

        // Validate storage configuration
        validateStorageConfiguration()
        logger.info("[DataService] Storage validated: persistent=true, allowsSave=true")

        let duration = CFAbsoluteTimeGetCurrent() - initStartTime
        logger.info("[DataService] Initialization completed in \(duration, privacy: .private)s")
    }

    /// True async initialization that moves heavy work off main thread
    /// Moves ModelContainer creation to background thread for better startup performance
    public static func createAsync() async throws -> DataService {
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")

        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        logger.info("[DataService] Starting async initialization on background thread (inMemory=\(isUITesting, privacy: .public))")

        // Create ModelContainer on background thread using Task.detached
        let container = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ModelContainer, Error>) in
            Task.detached(priority: .userInitiated) {
                do {
                    let container = try ModelContainerFactory.make(isUITesting: isUITesting)
                    continuation.resume(returning: container)
                } catch {
                    let errorDesc = error.localizedDescription
                    logger.error("[DataService] Background initialization failed: \(errorDesc, privacy: .public)")
                    continuation.resume(throwing: DataServiceError.initializationFailed(error.localizedDescription))
                }
            }
        }

        // Return to MainActor for final DataService creation
        return await MainActor.run {
            let service = DataService(minimal: container)
            service.validateStorageConfiguration()
            logger.info("[DataService] Async initialization complete - service created on MainActor")
            return service
        }
    }

    /// Async factory method that never throws - returns fallback on error
    /// Convenient for MainAppView and other callers that need guaranteed service
    public static func makeAsync() async -> DataService {
        do {
            return try await createAsync()
        } catch {
            let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")
            logger.error("[DataService] createAsync failed, using fallback: \(error.localizedDescription, privacy: .public)")
            return DataService.createFallback()
        }
    }

    /// Creates a fallback DataService instance with minimal functionality to prevent app crashes
    public static func createFallback() -> DataService {
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Fallback")
        logger.warning("[Fallback] Creating fallback DataService")

        do {
            let fallback = try createFallbackOrThrow()
            logger.info("[Fallback] Fallback DataService created successfully (in-memory)")
            return fallback
        } catch {
            logger.critical("CRITICAL: Cannot create fallback DataService: \(error.localizedDescription, privacy: .public)")
            let emergencyContainer = ModelContainerFactory.makeEmergencyFallback()
            return DataService(minimal: emergencyContainer)
        }
    }

    /// Private minimal initializer for internal factory methods
    private init(minimal container: ModelContainer) {
        self.modelContainer = container
        self.cloudContainer = ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : CKContainer.default()

        let repos = Self.makeRepositories(from: container.mainContext)
        self.plants = repos.plants
        self.gardens = repos.gardens
        self.reminders = repos.reminders
        self.journals = repos.journals
        self.users = repos.users
        self.stats = repos.stats
        self.seeds = repos.seeds
    }

    /// Private initializer that accepts an explicit (possibly nil) CloudKit container.
    /// Used by `makeForTesting()` to avoid CKContainer.default() crashing in swift test.
    private init(testing container: ModelContainer, cloudContainer: CKContainer?) {
        self.modelContainer = container
        self.cloudContainer = cloudContainer

        let repos = Self.makeRepositories(from: container.mainContext)
        self.plants = repos.plants
        self.gardens = repos.gardens
        self.reminders = repos.reminders
        self.journals = repos.journals
        self.users = repos.users
        self.stats = repos.stats
        self.seeds = repos.seeds
    }

    /// Creates all domain repositories from a given ModelContext.
    /// Centralises the wiring that all three initializers need.
    private static func makeRepositories(from context: ModelContext) -> RepositoryBundle {
        RepositoryBundle(context: context)
    }

    // MARK: - User Management

    @discardableResult
    public func createUser(email: String, displayName: String, skillLevel: GardeningSkillLevel) throws -> User {
        try users.create(email: email, displayName: displayName, skillLevel: skillLevel)
    }

    public func getCurrentUser() -> User? {
        users.getCurrent()
    }

    public func updateUser(_ user: User) throws {
        try users.update(user)
    }

    // MARK: - Garden Management

    @discardableResult
    public func createGarden(name: String, type: GardenType, isIndoor: Bool) throws -> Garden {
        let garden = try gardens.create(name: name, type: type, isIndoor: isIndoor, user: getCurrentUser())

        // Ensure garden and plant caches reflect the newly added garden
        cache.invalidateAll(withPrefix: "gardens:")
        cache.invalidateAll(withPrefix: "plants:")

        return garden
    }

    public func fetchGardens(offset: Int = 0, limit: Int = 20) -> [Garden] {
        let clampedOffset = max(0, offset)
        let clampedLimit = max(1, min(limit, 50))

        let cacheKey = "gardens:offset:\(clampedOffset):limit:\(clampedLimit)"

        if let cachedGardens = cache.get(cacheKey, as: [Garden].self) {
            return cachedGardens
        }

        let result: [Garden]
        do {
            result = try gardens.fetchAll(offset: clampedOffset, limit: clampedLimit)
        } catch {
            logger.error("[DataService] Failed to fetch gardens: \(error.localizedDescription, privacy: .public)")
            result = []
        }

        // Cache the result — gardens use medium TTL (5 min).
        // Note: cached @Model objects must be used on the same ModelContext.
        // If the context changes, caches should be invalidated.
        cache.set(cacheKey, value: result, policy: .medium)

        return result
    }

    public func deleteGarden(_ garden: Garden) throws {
        try gardens.delete(garden)
        cache.invalidateAll(withPrefix: "gardens:")
        cache.invalidateAll(withPrefix: "plants:")
        cache.invalidateAll(withPrefix: "stats:count:")
    }

    // MARK: - Plant Management

    @discardableResult
    public func createPlant(
        name: String,
        type: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        garden: Garden? = nil
    ) throws -> Plant {
        let plant = try plants.create(name: name, type: type, difficultyLevel: difficultyLevel, garden: garden)
        cache.invalidateAll(withPrefix: "plants:")
        cache.invalidateAll(withPrefix: "stats:count:")
        return plant
    }

    /// Insert a fully-configured database plant (e.g. from an external API).
    /// Sets `isUserPlant = false` automatically.
    public func insertDatabasePlant(
        name: String,
        scientificName: String?,
        type: PlantType,
        difficulty: DifficultyLevel,
        sunlight: SunlightLevel,
        watering: WateringFrequency,
        space: SpaceRequirement,
        notes: String
    ) throws {
        let plant = Plant(name: name, plantType: type, difficultyLevel: difficulty)
        plant.scientificName = scientificName
        plant.sunlightRequirement = sunlight
        plant.wateringFrequency = watering
        plant.spaceRequirement = space
        plant.isUserPlant = false
        plant.notes = notes
        try plants.add(plant)
    }

    public func fetchPlants(for garden: Garden? = nil, offset: Int = 0, limit: Int = 20) -> [Plant] {
        let cacheKey = "plants:\(garden?.id?.uuidString ?? "all"):offset:\(offset):limit:\(limit)"

        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }

        let result: [Plant]
        do {
            result = try plants.fetchPaginated(for: garden, offset: offset, limit: limit)
        } catch {
            logger.error("[DataService] Failed to fetch plants: \(error.localizedDescription, privacy: .public)")
            result = []
        }

        // Cache the result — user plants use medium TTL (5 min).
        // Note: cached @Model objects are tied to the current ModelContext.
        cache.set(cacheKey, value: result, policy: .medium)

        return result
    }

    public func fetchPlantDatabase(offset: Int? = nil, limit: Int? = nil) -> [Plant] {
        if let offset, let limit {
            return fetchPlantDatabasePage(offset: offset, limit: limit)
        }

        let cacheKey = "plant_database:all"

        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }

        var allPlants: [Plant] = []
        var currentOffset = 0
        let batchSize = 50

        while true {
            let batch = fetchPlantDatabasePage(offset: currentOffset, limit: batchSize)

            if batch.isEmpty { break }

            allPlants.append(contentsOf: batch)

            if batch.count < batchSize { break }

            currentOffset += batchSize
        }

        cache.set(cacheKey, value: allPlants, policy: .long)
        return allPlants
    }

    private func fetchPlantDatabasePage(offset: Int, limit: Int) -> [Plant] {
        let cacheKey = "plant_database:offset:\(offset):limit:\(limit)"

        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }

        let result: [Plant]
        do {
            result = try plants.fetchDatabasePage(offset: offset, limit: limit)
        } catch {
            logger.error("[DataService] Failed to fetch plant database page: \(error.localizedDescription, privacy: .public)")
            result = []
        }
        cache.set(cacheKey, value: result, policy: .long)
        return result
    }

    public func updatePlant(_ plant: Plant) throws {
        if let plantId = plant.id {
            cache.invalidate("plant:\(plantId.uuidString)")
        }
        try plants.update(plant)
    }

    public func deletePlant(_ plant: Plant) throws {
        // Delete associated reminders before deleting the plant
        let activeReminders = try reminders.fetchActive()
        let plantReminders = activeReminders.filter { $0.plantId == plant.id }
        for reminder in plantReminders {
            try reminders.delete(reminder)
        }
        try plants.delete(plant)
        cache.invalidateAll(withPrefix: "plants:")
        cache.invalidateAll(withPrefix: "stats:count:")
        cache.invalidateAll(withPrefix: "reminders:")
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
        let reminder = try reminders.create(
            title: title,
            message: message,
            type: type,
            frequency: frequency,
            dueDate: dueDate,
            plant: plant,
            user: getCurrentUser()
        )

        cache.invalidate("reminders:active")
        if let plantId = plant.id {
            cache.invalidate("plants:\(plantId.uuidString)")
        }

        return reminder
    }

    public func fetchActiveReminders() -> [PlantReminder] {
        let cacheKey = "reminders:active:limit:50"

        if let cachedReminders = cache.get(cacheKey, as: [PlantReminder].self) {
            return cachedReminders
        }

        let result: [PlantReminder]
        do {
            result = try reminders.fetchActive(limit: 50)
        } catch {
            logger.error("[DataService] Failed to fetch active reminders: \(error.localizedDescription, privacy: .public)")
            result = []
        }

        // Active reminders use short TTL (2 min) as they're time-sensitive
        cache.set(cacheKey, value: result, policy: .short)
        return result
    }

    public func fetchUpcomingReminders(days: Int = 7, offset: Int = 0, limit: Int = 50) -> [PlantReminder] {
        let cacheKey = "reminders:upcoming:days:\(days):offset:\(offset):limit:\(limit)"

        if let cachedReminders = cache.get(cacheKey, as: [PlantReminder].self) {
            return cachedReminders
        }

        let result: [PlantReminder]
        do {
            result = try reminders.fetchUpcoming(days: days, offset: offset, limit: limit)
        } catch {
            logger.error("[DataService] Failed to fetch upcoming reminders: \(error.localizedDescription, privacy: .public)")
            result = []
        }
        cache.set(cacheKey, value: result, policy: .short)
        return result
    }

    public func completeReminder(_ reminder: PlantReminder) throws {
        try reminders.complete(reminder)
    }

    public func deleteReminder(_ reminder: PlantReminder) throws {
        try reminders.delete(reminder)
    }

    // MARK: - Journal Management

    @discardableResult
    public func createJournalEntry(
        title: String,
        content: String,
        type: JournalEntryType,
        plant: Plant
    ) throws -> JournalEntry {
        let entry = try journals.create(
            title: title,
            content: content,
            type: type,
            plant: plant,
            user: getCurrentUser()
        )

        invalidateJournalCaches(for: plant)
        return entry
    }

    public func addJournalEntry(_ entry: JournalEntry) throws {
        try journals.add(entry, user: getCurrentUser())

        cache.invalidate("journal:recent")
        if let plant = entry.plant, let plantId = plant.id {
            cache.invalidate("plants:\(plantId.uuidString)")
            cache.invalidate("journal:plant:\(plantId.uuidString)")
        }
    }

    @discardableResult
    public func saveJournalEntry(_ entry: JournalEntry) throws -> JournalEntry {
        try addJournalEntry(entry)
        return entry
    }

    public func deleteJournalEntry(_ entry: JournalEntry) throws {
        let plant = entry.plant
        try journals.delete(entry)

        cache.invalidate("journal:recent")
        if let plant, let plantId = plant.id {
            cache.invalidate("journal:plant:\(plantId.uuidString)")
            cache.invalidate("plants:\(plantId.uuidString)")
        }
    }

    public func fetchJournalEntries(for plant: Plant, offset: Int = 0, limit: Int = 20) -> [JournalEntry] {
        guard let plantId = plant.id else { return [] }

        let cacheKey = "journal:plant:\(plantId.uuidString):offset:\(offset):limit:\(limit)"

        if let cachedEntries = cache.get(cacheKey, as: [JournalEntry].self) {
            return cachedEntries
        }

        let result: [JournalEntry]
        do {
            result = try journals.fetchForPlant(plant, offset: offset, limit: limit)
        } catch {
            logger.error(
                "[DataService] Failed to fetch journal entries for plant: \(error.localizedDescription, privacy: .public)"
            )
            result = []
        }
        cache.set(cacheKey, value: result, policy: .medium)
        return result
    }

    public func fetchRecentJournalEntries(limit: Int = 10) -> [JournalEntry] {
        let safeLimit = min(limit, 10)
        let cacheKey = "recent_journal_entries:limit:\(safeLimit)"

        if let cachedEntries = cache.get(cacheKey, as: [JournalEntry].self) {
            return cachedEntries
        }

        let result: [JournalEntry]
        do {
            result = try journals.fetchRecent(limit: safeLimit)
        } catch {
            logger.error("[DataService] Failed to fetch recent journal entries: \(error.localizedDescription, privacy: .public)")
            result = []
        }
        cache.set(cacheKey, value: result, policy: .medium)
        return result
    }

    // MARK: - Search and Filter

    public func searchPlants(query: String, limit: Int = 20) -> [Plant] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return [] }
        let cacheKey = "plants:search:\(trimmedQuery):limit:\(limit)"
        if let cached = cache.get(cacheKey, as: [Plant].self) { return cached }
        let result: [Plant]
        do {
            result = try plants.search(query: query, limit: limit)
        } catch {
            logger.error("[DataService] Failed to search plants: \(error.localizedDescription, privacy: .public)")
            result = []
        }
        cache.set(cacheKey, value: result, policy: .short)
        return result
    }

    public func filterPlants(
        by type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil,
        offset: Int = 0,
        limit: Int = 20
    ) -> [Plant] {
        let typeKey = type?.rawValue ?? "all"
        let diffKey = difficultyLevel?.rawValue ?? "all"
        let sunKey = sunlightRequirement?.rawValue ?? "all"
        let cacheKey = "plants:filter:\(typeKey):\(diffKey):\(sunKey):limit:\(limit):offset:\(offset)"
        if let cached = cache.get(cacheKey, as: [Plant].self) { return cached }
        let result: [Plant]
        do {
            result = try plants.filter(
                byType: type,
                difficultyLevel: difficultyLevel,
                sunlightRequirement: sunlightRequirement,
                offset: offset,
                limit: limit
            )
        } catch {
            logger.error("[DataService] Failed to filter plants: \(error.localizedDescription, privacy: .public)")
            result = []
        }
        cache.set(cacheKey, value: result, policy: .medium)
        return result
    }

    // MARK: - Statistics

    public func getGardeningStats() -> GardeningStats {
        let cacheKey = "stats:gardening_summary"
        if let cached = cache.get(cacheKey, as: GardeningStats.self) {
            return cached
        }

        do {
            let gardeningStats = try stats.getGardeningStats()
            cache.set(cacheKey, value: gardeningStats, policy: .medium)
            return gardeningStats
        } catch {
            logger.error("[DataService] Failed to fetch gardening stats: \(error.localizedDescription, privacy: .public)")
            return GardeningStats(totalPlants: 0, healthyPlants: 0, activeReminders: 0, totalJournalEntries: 0)
        }
    }

    public func getPlantCount(for garden: Garden? = nil) -> Int {
        let cacheKey = "stats:count:plants:\(garden?.id?.uuidString ?? "all")"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        do {
            let count = try stats.getPlantCount(for: garden)
            cache.set(cacheKey, value: count, policy: .long)
            return count
        } catch {
            logger.error("[DataService] Failed to fetch plant count: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    public func getGardenCount() -> Int {
        let cacheKey = "stats:count:gardens"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        do {
            let count = try stats.getGardenCount()
            cache.set(cacheKey, value: count, policy: .long)
            return count
        } catch {
            logger.error("[DataService] Failed to fetch garden count: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    public func getReminderCount(activeOnly: Bool = false) -> Int {
        let cacheKey = "stats:count:reminders:\(activeOnly)"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        do {
            let count = try stats.getReminderCount(activeOnly: activeOnly)
            cache.set(cacheKey, value: count, policy: .long)
            return count
        } catch {
            logger.error("[DataService] Failed to fetch reminder count: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    public func getJournalEntryCount(for plant: Plant? = nil) -> Int {
        let cacheKey = "stats:count:journals:\(plant?.id?.uuidString ?? "all")"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        do {
            let count = try stats.getJournalEntryCount(for: plant)
            cache.set(cacheKey, value: count, policy: .long)
            return count
        } catch {
            logger.error("[DataService] Failed to fetch journal entry count: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    public func getPlantDatabaseCount() -> Int {
        let cacheKey = "stats:count:plantdatabase"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        do {
            let count = try stats.getPlantDatabaseCount()
            cache.set(cacheKey, value: count, policy: .long)
            return count
        } catch {
            logger.error("[DataService] Failed to fetch plant database count: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - Data Export

    public func getDataSummary() async throws -> Data {
        let user = getCurrentUser()
        let gardenList = fetchGardens()
        let plantList = fetchPlants()
        let reminderList = fetchUpcomingReminders(days: 365)
        let journalList = fetchRecentJournalEntries(limit: 10)

        let userData = UserDataExport(
            userEmail: user?.email,
            totalPlants: plantList.count,
            totalGardens: gardenList.count,
            totalReminders: reminderList.count,
            totalJournalEntries: journalList.count
        )

        return try JSONEncoder().encode(userData)
    }

    /// Alias for backwards compatibility — delegates to `getDataSummary()`.
    public func exportUserData() async throws -> Data {
        try await getDataSummary()
    }

    // MARK: - Batch Operations

    /// Batch load plant relationships to prevent N+1 queries
    /// - Parameter plantIds: Array of plant UUIDs to fetch. If provided, results are ordered to match this array.
    /// - Returns: Array of Plant objects. If plantIds is provided, plants are ordered to match the input array order.
    ///            If plantIds is empty or nil, plants are ordered by name.
    @MainActor
    public func batchLoadPlantRelationships(
        plantIds: [UUID]
    ) async -> [Plant] {
        let startTime = CFAbsoluteTimeGetCurrent()

        if plantIds.count > 50 {
            logger.warning("Batch load requested \(plantIds.count, privacy: .private) plants, limiting to 50")
        }

        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )

        if !plantIds.isEmpty {
            descriptor.fetchLimit = 200
        } else {
            descriptor.fetchLimit = 50
        }

        let fetchedPlants: [Plant]
        do {
            fetchedPlants = try mainContext.fetch(descriptor)
        } catch {
            logger.error("[DataService] Failed to batch load plants: \(error.localizedDescription, privacy: .public)")
            fetchedPlants = []
        }

        let result: [Plant]
        if !plantIds.isEmpty {
            let plantIdSet = Set(plantIds)
            let matchingPlants = fetchedPlants.filter { plant in
                guard let id = plant.id else { return false }
                return plantIdSet.contains(id)
            }

            let plantDict: [UUID: Plant] = Dictionary(uniqueKeysWithValues: matchingPlants.compactMap { plant in
                guard let id = plant.id else { return nil }
                return (id, plant)
            })

            result = plantIds.compactMap { plantDict[$0] }
        } else {
            result = fetchedPlants
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        if duration > 0.5 {
            logger.warning("Slow batch load: \(duration, privacy: .private)s for \(plantIds.count, privacy: .private) plants")
        }

        return result
    }

    // MARK: - Cache Management

    /// Get cache statistics
    public func getCacheStats() -> (hits: Int, misses: Int, size: Int) {
        cache.getStats()
    }

    /// Manually invalidate caches (useful for development/testing)
    public func invalidateAllCaches() {
        cache.clear()
    }

    /// Warm cache with frequently accessed data for better first-load performance
    /// Preloads the 4 most common queries to eliminate initial loading delays
    @MainActor
    public func warmCache() async {
        logger.info("[Cache] Starting cache warming...")
        let startTime = CFAbsoluteTimeGetCurrent()

        let gardenList = fetchGardens(offset: 0, limit: 20)
        logger.info("[Cache] Warmed: gardens (\(gardenList.count, privacy: .private) items)")

        await Task.yield()

        let plantList = fetchPlants(offset: 0, limit: 20)
        logger.info("[Cache] Warmed: plants (\(plantList.count, privacy: .private) items)")

        await Task.yield()

        let reminderList = fetchActiveReminders()
        logger.info("[Cache] Warmed: reminders (\(reminderList.count, privacy: .private) items)")

        await Task.yield()

        let entries = fetchRecentJournalEntries(limit: 5)
        logger.info("[Cache] Warmed: journal (\(entries.count, privacy: .private) items)")

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let cacheStats = cache.getStats()
        logger.info("[Cache] Cache warming complete in \(duration, privacy: .private)s - cache size: \(cacheStats.size, privacy: .private)")
    }

    // MARK: - CloudKit Sync Status

    public func getCloudSyncStatus() async -> CloudSyncStatus {
        guard let cloudContainer else {
            return CloudSyncStatus(isAvailable: false, accountStatus: .couldNotDetermine, lastSync: nil, error: nil)
        }
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

    // MARK: - Private Helpers

    private func invalidateJournalCaches(for plant: Plant) {
        cache.invalidate("journal:recent")
        if let plantId = plant.id {
            cache.invalidate("plants:\(plantId.uuidString)")
            cache.invalidate("journal:plant:\(plantId.uuidString)")
        }
    }

    /// Validates that the DataService is using the correct storage configuration
    private func validateStorageConfiguration() {
        let config = modelContainer.configurations.first
        let isInMemory = config?.isStoredInMemoryOnly ?? true
        let allowsSave = config?.allowsSave ?? false

        logger.info("[Validation] Storage configuration check:")
        logger.info("[Validation]   isStoredInMemoryOnly: \(isInMemory, privacy: .private)")
        logger.info("[Validation]   allowsSave: \(allowsSave, privacy: .private)")

        if isInMemory {
            logger.critical("[Validation] CRITICAL: Production DataService is using IN-MEMORY storage!")
        } else {
            logger.info("[Validation] Storage configuration is correct (persistent storage)")
        }

        if let config {
            if let schema = config.schema {
                logger.info("[Validation] Schema includes: \(schema.entities.map(\.name).joined(separator: ", "), privacy: .private)")
            }
        }
    }
}

// MARK: - Errors

public enum DataServiceError: Error, LocalizedError {
    case criticalInitializationFailure(String)
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .criticalInitializationFailure(let message):
            message

        case .initializationFailed(let message):
            "DataService initialization failed: \(message)"
        }
    }
}

public extension DataService {
    /// A throwing variant of `createFallback()` so callers that can handle errors don't have to rely on emergency stubs.
    static func createFallbackOrThrow() throws -> DataService {
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
            return DataService(minimal: container)
        } catch {
            throw DataServiceError.criticalInitializationFailure("Cannot create fallback DataService: \(error)")
        }
    }

    /// Creates a fully-schema'd in-memory DataService for unit and integration tests.
    ///
    /// Includes all production models (Plant, Garden, User, PlantReminder, JournalEntry,
    /// SoilLog) and does **not** initialise a CloudKit container, making
    /// it safe to call from `swift test` without app entitlements.
    ///
    /// - Returns: A DataService backed by an in-memory SQLite store.
    /// - Throws: `DataServiceError.criticalInitializationFailure` if the container cannot be created.
    static func makeForTesting() throws -> DataService {
        do {
            let container = try ModelContainerFactory.makeForTesting()
            return DataService(testing: container, cloudContainer: nil)
        } catch {
            throw DataServiceError.criticalInitializationFailure("Cannot create test DataService: \(error)")
        }
    }
}

// MARK: - Club Queries

public extension DataService {
    /// Returns the most recently created GardenClub, or nil if none exist.
    func fetchPrimaryClub() -> GardenClub? {
        let fetch = FetchDescriptor<GardenClub>(
            sortBy: [SortDescriptor(\GardenClub.createdDate, order: .reverse)]
        )
        return try? mainContext.fetch(fetch).first
    }

    /// Returns the single most-recent ClubActivity across all clubs.
    /// Used by HomeViewModel to populate the "Your Club" card.
    func fetchLatestClubActivity() throws -> ClubActivity? {
        var descriptor = FetchDescriptor<ClubActivity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try mainContext.fetch(descriptor).first
    }
}

// MARK: - Private Helpers

/// Groups all seven domain repositories so they can be built once from a ModelContext
/// and assigned together in each DataService initializer.
@MainActor
private struct RepositoryBundle {
    let plants: PlantRepository
    let gardens: GardenRepository
    let reminders: ReminderRepository
    let journals: JournalRepository
    let users: UserRepository
    let stats: StatsRepository
    let seeds: SeedRepository

    init(context: ModelContext) {
        plants = PlantRepository(context: context)
        gardens = GardenRepository(context: context)
        reminders = ReminderRepository(context: context)
        journals = JournalRepository(context: context)
        users = UserRepository(context: context)
        stats = StatsRepository(context: context)
        seeds = SeedRepository(context: context)
    }
}

// MARK: - Supporting Types

public struct CloudSyncStatus: Sendable {
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

/// Note: SwiftData models don't automatically conform to Codable
/// For data export, we'll implement a separate export structure in a future iteration
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

// swiftlint:enable file_length function_parameter_count large_tuple type_body_length
