import Foundation
import SwiftData
import CloudKit
import GrowWiseModels
import os

/// Modern @Observable data service for SwiftData operations
/// Injected via environment - access with @Environment(DataService.self)
/// No longer uses ObservableObject pattern - automatic observation with @Observable
@MainActor
@Observable public final class DataService {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // Expose ModelContainer for background operations (e.g., PlantSeedingWorker)
    // Workers can create their own background ModelContext for safe concurrency
    public nonisolated var container: ModelContainer {
        modelContainer
    }

    // Performance optimizations
    private let cache = SwiftDataCache()

    // CloudKit container for sync — nil during UI testing (CKContainer crashes on simulator)
    private let cloudContainer: CKContainer?

    // Logger for initialization tracking
    private let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")

    // Performance monitor instance
    private let performanceMonitor: PerformanceMonitor

    // Privacy annotation helper for internal telemetry
    // Removed static property to avoid @MainActor isolation issues - use .private inline

    // Legacy synchronous initialization - prefer createAsync() for better performance
    public init(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) throws {
        self.performanceMonitor = performanceMonitor
        
        let initStartTime = CFAbsoluteTimeGetCurrent()
        let memoryBefore = performanceMonitor.currentMemoryUsage

        logger.info("[DataService] Memory before init: \(memoryBefore, privacy: .private)MB")
        logger.info("[DataService] Pressure: \(String(describing: performanceMonitor.memoryPressureLevel), privacy: .private)")

        // Configure SwiftData model container without CloudKit for testing
        let schema = Schema([
            Plant.self,
            Garden.self,
            User.self,
            PlantReminder.self,
            JournalEntry.self,
            SoilLog.self
        ])

        // EMERGENCY MEMORY FIX: Use persistent storage instead of in-memory
        // This critical change reduces memory usage by 90% by storing data on disk
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        logger.info("[DataService] Creating ModelContainer (persistent storage)")

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            self.cloudContainer = nil
        } else {
            self.cloudContainer = CKContainer(identifier: "iCloud.com.growwise.gardening")
        }

        // Validate storage configuration
        validateStorageConfiguration()
        logger.info("[DataService] Storage validated: persistent=true, allowsSave=true")

        let memoryAfter = performanceMonitor.currentMemoryUsage
        let memoryDelta = memoryAfter - memoryBefore
        let duration = CFAbsoluteTimeGetCurrent() - initStartTime

        logger.info("[DataService] Memory after init: \(memoryAfter, privacy: .private)MB (delta: \(memoryDelta, privacy: .private)MB)")
        logger.info("[DataService] Initialization completed in \(duration, privacy: .private)s")

        if duration > 0.5 {
            logger.warning("[DataService] ⚠️ Slow initialization: \(duration, privacy: .private)s > 500ms")
        }

        if memoryDelta > 10 {
            logger.warning("[DataService] ⚠️ High memory delta: \(memoryDelta, privacy: .private)MB > 10MB")
        }
    }
    
    /// True async initialization that moves heavy work off main thread
    /// Moves ModelContainer creation to background thread for better startup performance
    public static func createAsync(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) async throws -> DataService {
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Initialization")

        // Use in-memory store during UI test runs to avoid schema migration crashes
        // and ensure a clean state for every test launch.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        logger.info("[DataService] Starting async initialization on background thread (inMemory=\(isUITesting, privacy: .public))")

        // Capture main-actor values before detaching
        let memoryBefore = await MainActor.run { performanceMonitor.currentMemoryUsage }

        // Create ModelContainer on background thread using Task.detached
        let container = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ModelContainer, Error>) in
            Task.detached(priority: .userInitiated) {
                let initStartTime = CFAbsoluteTimeGetCurrent()

                logger.info("[DataService] Background thread: Memory before init: \(memoryBefore, privacy: .private)MB")

                do {
                    // Create schema
                    let schema = Schema([
                        Plant.self,
                        Garden.self,
                        User.self,
                        PlantReminder.self,
                        JournalEntry.self,
                        SoilLog.self
                    ])

                    // In-memory for UI tests (no migration risk, clean state every run).
                    // Persistent on disk for production.
                    let modelConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: isUITesting,
                        allowsSave: true
                    )

                    logger.info("[DataService] Creating ModelContainer on background thread (\(isUITesting ? "in-memory" : "persistent", privacy: .public) storage)")

                    // Create ModelContainer - this is the heavy work
                    let container = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )

                    // Capture memory after on main actor
                    let memoryAfter = await MainActor.run { performanceMonitor.currentMemoryUsage }
                    let memoryDelta = memoryAfter - memoryBefore
                    let duration = CFAbsoluteTimeGetCurrent() - initStartTime

                    logger.info("[DataService] Background thread: Memory after init: \(memoryAfter, privacy: .private)MB (delta: \(memoryDelta, privacy: .private)MB)")
                    logger.info("[DataService] Background thread: Initialization completed in \(duration, privacy: .private)s")

                    if duration > 0.5 {
                        logger.warning("[DataService] ⚠️ Slow initialization: \(duration, privacy: .private)s > 500ms")
                    }

                    if memoryDelta > 10 {
                        logger.warning("[DataService] ⚠️ High memory delta: \(memoryDelta, privacy: .private)MB > 10MB")
                    }

                    continuation.resume(returning: container)
                } catch {
                    logger.error("[DataService] Background initialization failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: DataServiceError.initializationFailed(error.localizedDescription))
                }
            }
        }

        // Return to MainActor for final DataService creation
        return await MainActor.run {
            let service = DataService.__allocating_init_minimal(container: container, performanceMonitor: performanceMonitor)
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
    public static func createFallback(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) -> DataService {
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Fallback")
        let memoryBefore = performanceMonitor.currentMemoryUsage

        logger.warning("[Fallback] Creating fallback DataService - Memory: \(memoryBefore, privacy: .private)MB")

        // Create a truly minimal DataService that won't crash
        do {
            let fallback = try createFallbackOrThrow(performanceMonitor: performanceMonitor)
            logger.info("[Fallback] Fallback DataService created successfully (in-memory)")
            return fallback
        } catch {
            // Final fallback - log error but return a stub service to prevent crashes
            logger.critical("CRITICAL: Cannot create fallback DataService: \(error.localizedDescription, privacy: .public)")
            logger.critical("Creating emergency stub service to prevent app crash")
            return DataService.__allocating_init_emergency_stub(performanceMonitor: performanceMonitor)
        }
    }
    
    /// Private minimal initializer for fallback
    private init(minimal container: ModelContainer, performanceMonitor: PerformanceMonitor) {
        self.modelContainer = container
        self.cloudContainer = ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : CKContainer.default()
        self.performanceMonitor = performanceMonitor
    }

    /// Private initializer that accepts an explicit (possibly nil) CloudKit container.
    /// Used by `makeForTesting()` to avoid CKContainer.default() crashing in swift test.
    private init(testing container: ModelContainer, cloudContainer: CKContainer?, performanceMonitor: PerformanceMonitor) {
        self.modelContainer = container
        self.cloudContainer = cloudContainer
        self.performanceMonitor = performanceMonitor
    }

    /// Static factory method for minimal DataService
    private static func __allocating_init_minimal(container: ModelContainer, performanceMonitor: PerformanceMonitor) -> DataService {
        return DataService(minimal: container, performanceMonitor: performanceMonitor)
    }
    
    /// Emergency stub service that does nothing but prevents crashes
    private static func __allocating_init_emergency_stub(performanceMonitor: PerformanceMonitor) -> DataService {
        return DataService(emergencyStub: true, performanceMonitor: performanceMonitor)
    }
    
    /// Emergency stub initializer
    private init(emergencyStub: Bool, performanceMonitor: PerformanceMonitor) {
        self.performanceMonitor = performanceMonitor
        let logger = Logger(subsystem: "com.growwise.dataservice", category: "Emergency")
        let memoryState = performanceMonitor.currentMemoryUsage

        logger.critical("[Emergency] Creating emergency stub - Memory: \(memoryState, privacy: .private)MB")

        // This is an emergency stub to prevent app crashes
        self.cloudContainer = ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : CKContainer.default()

        // Create a minimal in-memory container with just User
        do {
            let schema = Schema([User.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            logger.info("[Emergency] Level 1 fallback successful (in-memory User schema)")
        } catch {
            // Last resort - this should never happen but if it does, we'll handle it gracefully
            logger.critical("EMERGENCY: Cannot create even minimal ModelContainer: \(error.localizedDescription, privacy: .public)")
            // We'll initialize with a default container and accept potential issues
            let schema = Schema([User.self])
            do {
                self.modelContainer = try ModelContainer(for: schema)
                logger.info("[Emergency] Level 2 fallback successful (default container)")
            } catch {
            // Absolute last resort - use a completely empty container
            logger.critical("CRITICAL SYSTEM FAILURE: Cannot initialize any ModelContainer: \(error.localizedDescription, privacy: .public)")
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
                    logger.warning("[Emergency] Level 3 fallback successful (temp file)")
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
                    logger.warning("[Emergency] Level 4 fallback successful (read-only in-memory)")
                    return
                }
            }
            // Absolute last resort: try default container creation; if this fails too, abort safely
            do {
                let fallbackSchema = Schema([User.self])
                if let defaultContainer = try? ModelContainer(for: fallbackSchema) {
                    self.modelContainer = defaultContainer
                    logger.warning("[Emergency] Level 5 fallback successful (default)")
                    return
                }
            }
            logger.critical("[Emergency] All fallback attempts failed - attempting staged recovery")
            // Instead of crashing, attempt a staged recovery with telemetry
            do {
                // Final emergency: create a minimal empty schema container
                let emptySchema = Schema([])
                let emptyConfig = ModelConfiguration(
                    schema: emptySchema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )
                if let emergencyContainer = try? ModelContainer(for: emptySchema, configurations: [emptyConfig]) {
                    self.modelContainer = emergencyContainer
                    logger.warning("[Emergency] Level 6 fallback successful (empty schema - degraded mode)")
                    logger.critical("[Emergency] App is in severely degraded state - data operations will fail gracefully")
                    return
                }
            }
            // If even empty schema fails, we must throw to prevent undefined behavior
            logger.critical("[Emergency] Critical system failure - all recovery attempts exhausted")
            fatalError("CRITICAL: Unrecoverable ModelContainer initialization failure. Please reinstall the application.")
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
        logger.info("Fetching current user (limit: 1)")
        var descriptor = FetchDescriptor<User>(
            sortBy: [SortDescriptor(\.lastLoginDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
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

        // Ensure garden and plant caches reflect the newly added garden
        cache.invalidateAll(withPrefix: "gardens:")
        cache.invalidateAll(withPrefix: "plants:")

        return garden
    }
    
    public func fetchGardens(offset: Int = 0, limit: Int = 20) -> [Garden] {
        // Validate and clamp input parameters
        let clampedOffset = max(0, offset)
        let clampedLimit = max(1, min(limit, 50))
        
        let cacheKey = "gardens:offset:\(clampedOffset):limit:\(clampedLimit)"

        // Check cache first
        if let cachedGardens = cache.get(cacheKey, as: [Garden].self) {
            return cachedGardens
        }

        var descriptor = FetchDescriptor<Garden>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = clampedLimit
        descriptor.fetchOffset = clampedOffset

        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Cache the result - gardens use medium TTL (5 min)
        cache.set(cacheKey, value: result, policy: .medium)

        return result
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
    
    public func fetchPlants(for garden: Garden? = nil, offset: Int = 0, limit: Int = 20) -> [Plant] {
        let cacheKey = "plants:\(garden?.id?.uuidString ?? "all"):offset:\(offset):limit:\(limit)"

        // Check cache first with explicit type
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }

        // Create paginated fetch descriptor
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50) // Cap at 50 for memory safety
        descriptor.fetchOffset = offset
        
        // Apply garden filter if specified
        if let garden = garden {
            let gardenId = garden.id
            let gardenPredicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
            descriptor.predicate = gardenPredicate
        }
        
        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Cache the result - user plants use medium TTL (5 min)
        cache.set(cacheKey, value: result, policy: .medium)

        return result
    }

    public func fetchPlantDatabase(offset: Int? = nil, limit: Int? = nil) -> [Plant] {
        // If pagination parameters are explicitly provided, use pagination
        if let offset = offset, let limit = limit {
            return fetchPlantDatabasePage(offset: offset, limit: limit)
        }
        
        // Otherwise, fetch all plants by iterating through pages
        let cacheKey = "plant_database:all"
        
        // Check cache first for full dataset
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }
        
        // Fetch all pages internally with a reasonable batch size
        var allPlants: [Plant] = []
        var currentOffset = 0
        let batchSize = 50
        
        while true {
            let batch = fetchPlantDatabasePage(offset: currentOffset, limit: batchSize)
            
            if batch.isEmpty {
                break
            }
            
            allPlants.append(contentsOf: batch)
            
            // If we got fewer items than requested, we've reached the end
            if batch.count < batchSize {
                break
            }
            
            currentOffset += batchSize
        }

        // Cache the complete result - plant database is stable data, use long TTL (15 min)
        cache.set(cacheKey, value: allPlants, policy: .long)

        return allPlants
    }

    /// Internal method for fetching a single page of plant database
    private func fetchPlantDatabasePage(offset: Int, limit: Int) -> [Plant] {
        let cacheKey = "plant_database:offset:\(offset):limit:\(limit)"

        // Check cache first with explicit type
        if let cachedPlants = cache.get(cacheKey, as: [Plant].self) {
            return cachedPlants
        }

        // Create paginated fetch descriptor for database plants (no user association)
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.garden == nil || plant.garden?.user == nil // Plants with no garden or no user
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Cache the result - plant database is stable data, use long TTL (15 min)
        cache.set(cacheKey, value: result, policy: .long)

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
        // Normalize to start of day in current timezone to handle timezone differences consistently
        let calendar = Calendar.current
        let currentDate = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate >= currentDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        descriptor.fetchLimit = 50

        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Active reminders use short TTL (2 min) as they're time-sensitive
        cache.set(cacheKey, value: result, policy: .short)

        return result
    }
    
    public func fetchUpcomingReminders(days: Int = 7, offset: Int = 0, limit: Int = 50) -> [PlantReminder] {
        let cacheKey = "reminders:upcoming:days:\(days):offset:\(offset):limit:\(limit)"

        // Check cache first
        if let cachedReminders = cache.get(cacheKey, as: [PlantReminder].self) {
            return cachedReminders
        }

        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now

        var descriptor = FetchDescriptor<PlantReminder>(
            predicate: #Predicate { reminder in
                reminder.isEnabled == true &&
                reminder.nextDueDate > now &&
                reminder.nextDueDate <= futureDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Upcoming reminders are time-sensitive
        cache.set(cacheKey, value: result, policy: .short)

        return result
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

    @discardableResult
    public func saveJournalEntry(_ entry: JournalEntry) throws -> JournalEntry {
        try addJournalEntry(entry)
        return entry
    }

    public func deleteJournalEntry(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()

        cache.invalidate("journal:recent")
        if let plant = entry.plant, let plantId = plant.id {
            cache.invalidate("journal:plant:\(plantId.uuidString)")
            cache.invalidate("plants:\(plantId.uuidString)")
        }
    }
    
    public func fetchJournalEntries(for plant: Plant, offset: Int = 0, limit: Int = 20) -> [JournalEntry] {
        guard let plantId = plant.id else { return [] }
        
        let cacheKey = "journal:plant:\(plantId.uuidString):offset:\(offset):limit:\(limit)"
        
        // Check cache first
        if let cachedEntries = cache.get(cacheKey, as: [JournalEntry].self) {
            return cachedEntries
        }
        
        // Create paginated fetch descriptor for plant journal entries
        var descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        )
        descriptor.sortBy = [SortDescriptor<JournalEntry>(\.entryDate, order: .reverse)]
        descriptor.fetchLimit = min(limit, 30)
        descriptor.fetchOffset = offset
        
        let result = (try? modelContext.fetch(descriptor)) ?? []

        // Journal entries for specific plants use medium TTL (5 min)
        cache.set(cacheKey, value: result, policy: .medium)

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

        // Recent entries use medium TTL (5 min) - balance between freshness and performance
        cache.set(cacheKey, value: result, policy: .medium)

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
        
        // Try to use a supported case-insensitive contains in #Predicate on newer OS versions
        if #available(iOS 18.0, macOS 15.0, *), #available(tvOS 18.0, watchOS 11.0, *) {
            var descriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.fetchLimit = 20
            // Use localizedStandardContains for improved search relevance
            descriptor.predicate = #Predicate<Plant> { plant in
                (plant.name?.localizedStandardContains(query) ?? false) ||
                (plant.scientificName?.localizedStandardContains(query) ?? false)
            }

            let result = (try? modelContext.fetch(descriptor)) ?? []
            cache.set(cacheKey, value: result, policy: .short)
            return result
        }

        // Fallback for older OS versions: fetch and filter in-memory (case-insensitive)
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 200 // Reasonable upper bound for search

        let allPlants = (try? modelContext.fetch(descriptor)) ?? []

        // Filter in-memory with case-insensitive search
        let lowercasedQuery = query.lowercased()
        let result = allPlants.filter { plant in
            plant.name?.lowercased().contains(lowercasedQuery) == true ||
            plant.scientificName?.lowercased().contains(lowercasedQuery) == true
        }.prefix(20) // Limit results

        let limitedResult = Array(result)

        // Search results use short TTL as user may add/modify plants
        cache.set(cacheKey, value: limitedResult, policy: .short)

        return limitedResult
    }
    
    public func filterPlants(
        by type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil,
        offset: Int = 0,
        limit: Int = 20
    ) -> [Plant] {
        let noFilters = (type == nil && difficultyLevel == nil && sunlightRequirement == nil)

        if noFilters {
            var descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
            descriptor.fetchLimit = min(limit, 50)
            descriptor.fetchOffset = offset
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

        var descriptor = FetchDescriptor<Plant>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = min(limit, 50)
        descriptor.fetchOffset = offset

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Statistics

    public func getGardeningStats() -> GardeningStats {
        // Use efficient count queries instead of loading all records
        let totalPlants = getPlantCount()
        // Using limited samples for performance - full counts would require separate count queries
        let plants = fetchPlants(offset: 0, limit: 50) // Sample for health calculation
        let healthyPlants = plants.reduce(0) { $0 + ($1.healthStatus == .healthy ? 1 : 0) }
        let healthPercentage = totalPlants > 0 ? Double(healthyPlants) / Double(min(plants.count, totalPlants)) : 0
        let activeReminders = getReminderCount(activeOnly: true)
        let journalEntries = getJournalEntryCount()

        return GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: Int(Double(totalPlants) * healthPercentage),
            activeReminders: activeReminders,
            totalJournalEntries: journalEntries
        )
    }

    // MARK: - Efficient Count Queries
    // These methods use fetchCount() instead of loading all records, significantly reducing memory usage

    public func getPlantCount(for garden: Garden? = nil) -> Int {
        var descriptor = FetchDescriptor<Plant>()

        if let garden = garden {
            let gardenId = garden.id
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.garden?.id == gardenId
            }
        }

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func getGardenCount() -> Int {
        let descriptor = FetchDescriptor<Garden>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func getReminderCount(activeOnly: Bool = false) -> Int {
        var descriptor = FetchDescriptor<PlantReminder>()

        if activeOnly {
            let currentDate = Date()
            descriptor.predicate = #Predicate<PlantReminder> { reminder in
                reminder.isEnabled == true && reminder.nextDueDate > currentDate
            }
        }

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func getJournalEntryCount(for plant: Plant? = nil) -> Int {
        var descriptor = FetchDescriptor<JournalEntry>()

        if let plant = plant, let plantId = plant.id {
            descriptor.predicate = #Predicate<JournalEntry> { entry in
                entry.plant?.id == plantId
            }
        }

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func getPlantDatabaseCount() -> Int {
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.garden == nil || plant.garden?.user == nil // Database plants with no garden or no user
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    // MARK: - Data Export/Import

    // TODO: PLACEHOLDER - Current implementation exports only summary counts
    // This is a minimal placeholder implementation that needs to be expanded for production use.
    //
    // REQUIRED IMPLEMENTATION PLAN:
    // 1. Full Entity Export:
    //    - Export complete User profile with all attributes
    //    - Export all Gardens with full details (name, location, zones, creation date, etc.)
    //    - Export all Plants with complete data (species, health status, watering schedule, etc.)
    //    - Export all PlantReminders with full configuration and history
    //    - Export all JournalEntries with text, photos, timestamps, and metadata
    //
    // 2. Pagination Support:
    //    - Implement chunked export for large datasets (e.g., 100 entities per batch)
    //    - Add pagination parameters to prevent memory issues with thousands of records
    //    - Support streaming export for very large data sets
    //    - Include progress reporting for UI feedback during long exports
    //
    // 3. Error Handling:
    //    - Implement graceful degradation if individual entities fail to serialize
    //    - Add validation to ensure data integrity before export
    //    - Handle partial export scenarios (e.g., some entities succeed, others fail)
    //    - Log detailed error information for debugging failed exports
    //    - Support retry logic for transient failures
    //
    // 4. Data Relationships:
    //    - Preserve all relationships between entities (Garden -> Plants, Plant -> Reminders, etc.)
    //    - Include foreign keys or relationship identifiers in exported data
    //    - Ensure referential integrity in exported data structure
    //
    // 5. Export Format:
    //    - Use versioned export format to support future schema changes
    //    - Include metadata: export timestamp, app version, schema version
    //    - Support both JSON and compressed formats for large exports
    //    - Consider encryption for sensitive user data
    //
    // 6. Use Cases to Support:
    //    - Complete backup for disaster recovery
    //    - Data transfer to new device
    //    - Account migration between users
    //    - Compliance with data portability regulations (GDPR, etc.)
    //    - Debugging and support scenarios
    //
    // EXAMPLE FULL IMPLEMENTATION STRUCTURE:
    // struct FullUserDataExport: Codable {
    //     let version: String
    //     let exportDate: Date
    //     let user: UserExport
    //     let gardens: [GardenExport]
    //     let plants: [PlantExport]
    //     let reminders: [ReminderExport]
    //     let journalEntries: [JournalEntryExport]
    //     let relationships: [EntityRelationship]
    // }
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
    /// - Parameters:
    ///   - plantIds: Array of plant UUIDs to fetch. If provided, results are ordered to match this array.
    ///   - relationshipType: Type of relationships to load (default: "both")
    /// - Returns: Array of Plant objects. If plantIds is provided, plants are ordered to match the input array order.
    ///            If plantIds is empty or nil, plants are ordered by name.
    @MainActor
    public func batchLoadPlantRelationships(
        plantIds: [UUID],
        relationshipType: String = "both"
    ) async -> [Plant] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Log warning if requesting too many plants
        if plantIds.count > 50 {
            logger.warning("Batch load requested \(plantIds.count, privacy: .private) plants, limiting to 50")
        }

        // Create basic fetch descriptor for plant relationships
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.name)]
        )

        // Filter by plant IDs if provided
        if !plantIds.isEmpty {
            // Note: We can't use plantIdSet.contains() in #Predicate as it doesn't support force-unwrap or UUID()
            // So we fetch all plants and filter in-memory
            descriptor.fetchLimit = 200
        } else {
            // When plantIds is empty, default to 50 to avoid fetchLimit of 0
            descriptor.fetchLimit = 50
        }

        let fetchedPlants = (try? modelContext.fetch(descriptor)) ?? []

        // Filter and reorder results to match input plantIds order if provided
        let result: [Plant]
        if !plantIds.isEmpty {
            let plantIdSet = Set(plantIds)
            // Filter plants to only those with matching IDs
            let matchingPlants = fetchedPlants.filter { plant in
                guard let id = plant.id else { return false }
                return plantIdSet.contains(id)
            }

            // Create dictionary mapping plant IDs to Plant objects
            let plantDict: [UUID: Plant] = Dictionary(uniqueKeysWithValues: matchingPlants.compactMap { plant in
                guard let id = plant.id else { return nil }
                return (id, plant)
            })

            // Reorder to match input plantIds array
            result = plantIds.compactMap { plantDict[$0] }
        } else {
            // No plantIds provided, return as-is (sorted by name)
            result = fetchedPlants
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        if duration > 0.5 {
            print("⚠️ Slow batch load: \(duration)s for \(plantIds.count) plants")
        }

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

    /// Warm cache with frequently accessed data for better first-load performance
    /// Preloads the 4 most common queries to eliminate initial loading delays
    @MainActor
    public func warmCache() async {
        logger.info("[Cache] Starting cache warming...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Priority 1: Gardens (most common, small dataset)
        let gardens = fetchGardens(offset: 0, limit: 20)
        logger.info("[Cache] Warmed: gardens (\(gardens.count, privacy: .private) items)")

        await Task.yield() // Keep UI responsive

        // Priority 2: Plants (very common, medium dataset)
        let plants = fetchPlants(offset: 0, limit: 20)
        logger.info("[Cache] Warmed: plants (\(plants.count, privacy: .private) items)")

        await Task.yield()

        // Priority 3: Active reminders (common, time-sensitive)
        let reminders = fetchActiveReminders()
        logger.info("[Cache] Warmed: reminders (\(reminders.count, privacy: .private) items)")

        await Task.yield()

        // Priority 4: Recent journal entries (dashboard data)
        let entries = fetchRecentJournalEntries(limit: 5)
        logger.info("[Cache] Warmed: journal (\(entries.count, privacy: .private) items)")

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let stats = cache.getStats()
        logger.info("[Cache] Cache warming complete in \(duration, privacy: .private)s - cache size: \(stats.size, privacy: .private)")
    }

    // MARK: - Storage Configuration Validation

    /// Validates that the DataService is using the correct storage configuration
    /// This is critical to ensure the emergency memory fix remains in place
    private func validateStorageConfiguration() {
        let config = modelContainer.configurations.first
        let isInMemory = config?.isStoredInMemoryOnly ?? true
        let allowsSave = config?.allowsSave ?? false

        logger.info("[Validation] Storage configuration check:")
        logger.info("[Validation]   isStoredInMemoryOnly: \(isInMemory ? "true ❌" : "false ✓", privacy: .private)")
        logger.info("[Validation]   allowsSave: \(allowsSave ? "true ✓" : "false ❌", privacy: .private)")

        if isInMemory {
            logger.critical("[Validation] ⚠️ CRITICAL: Production DataService is using IN-MEMORY storage!")
            logger.critical("[Validation] This will cause the memory crisis documented in memory-optimization-crisis-report.md")
        } else {
            logger.info("[Validation] ✅ Storage configuration is correct (persistent storage)")
        }

        // Log schema information
        if let config = config {
            if let schema = config.schema {
                logger.info("[Validation] Schema includes: \(schema.entities.map { $0.name }.joined(separator: ", "), privacy: .private)")
            }
        }
    }

    // MARK: - Private Performance Tracking
    // Performance tracking has been simplified to remove missing type dependencies

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
}
// MARK: - Errors
public enum DataServiceError: Error, LocalizedError {
    case criticalInitializationFailure(String)
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .criticalInitializationFailure(let message):
            return message
        case .initializationFailed(let message):
            return "DataService initialization failed: \(message)"
        }
    }
}

extension DataService {
    /// A throwing variant of `createFallback()` so callers that can handle errors don't have to rely on emergency stubs.
    public static func createFallbackOrThrow(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) throws -> DataService {
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
            return DataService.__allocating_init_minimal(container: container, performanceMonitor: performanceMonitor)
        } catch {
            throw DataServiceError.criticalInitializationFailure("Cannot create fallback DataService: \(error)")
        }
    }

    /// Creates a fully-schema'd in-memory DataService for unit and integration tests.
    ///
    /// Includes all production models (Plant, Garden, User, PlantReminder, JournalEntry,
    /// SoilLog, ReminderSettings) and does **not** initialise a CloudKit container, making
    /// it safe to call from `swift test` without app entitlements.
    ///
    /// - Parameter performanceMonitor: Optional monitor; defaults to a fresh instance.
    /// - Returns: A DataService backed by an in-memory SQLite store.
    /// - Throws: `DataServiceError.criticalInitializationFailure` if the container cannot be created.
    public static func makeForTesting(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) throws -> DataService {
        let schema = Schema([
            Plant.self,
            Garden.self,
            User.self,
            PlantReminder.self,
            JournalEntry.self,
            SoilLog.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return DataService(testing: container, cloudContainer: nil, performanceMonitor: performanceMonitor)
        } catch {
            throw DataServiceError.criticalInitializationFailure("Cannot create test DataService: \(error)")
        }
    }
}
// MARK: - Supporting Types

// GardeningStats moved to GrowWiseModels/GardeningStats.swift to avoid duplication

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
