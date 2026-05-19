import CloudKit
import Foundation
import GrowWiseModels
import os.log
import SwiftData

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable function_body_length line_length

/// Factory responsible for vending a valid `ModelContainer`.
///
/// All model types, CloudKit configuration, and the 6-level emergency fallback
/// waterfall live here. `DataService` calls `ModelContainerFactory.make(...)` to
/// get a container instead of duplicating setup logic inline.
///
/// Isolation note: the struct is `@MainActor` so that `sharedSchema` can be used
/// conveniently from view code, but factory methods are `nonisolated` so they are
/// callable from background threads (e.g. `Task.detached` inside `createAsync()`).
@MainActor
public struct ModelContainerFactory {
    private nonisolated static let logger = Logger(subsystem: "com.growwise.dataservice", category: "ModelContainerFactory")

    // MARK: - Schema

    /// The single source of truth for the app's database schema.
    /// Available to any `@MainActor` caller that needs to reference the schema directly.
    public static let sharedSchema = Schema([
        Plant.self,
        Garden.self,
        GardenBed.self,
        User.self,
        PlantReminder.self,
        JournalEntry.self,
        SoilLog.self,
        ShoppingItem.self,
        CompostBatch.self,
        Seed.self,
        GardenClub.self,
        ClubActivity.self,
        ClubMessage.self,
        ClubEvent.self,
        Harvest.self,
    ] as [any PersistentModel.Type])

    // MARK: - Factory Methods

    /// Factory method for normal initialization.
    ///
    /// `nonisolated` so it can be called from background threads without hopping
    /// to the main actor.  Creates its own Schema locally (same types as `sharedSchema`).
    public nonisolated static func make(
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting")
    ) throws -> ModelContainer {
        let schema = Self.makeSchema()
        let modelConfiguration: ModelConfiguration

        if isUITesting {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } else {
            // CRITICAL: For CloudKit sync to work properly, we MUST NOT specify allowsSave explicitly
            // and we MUST configure the group container URL correctly if we are sharing data
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.growwise.gardening")
            )
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // Schema incompatible with persisted store — wipe local SQLite and recreate.
                // Sole developer, no user data at risk. Approved clean-wipe migration strategy.
                logger.warning("⚠️ ModelContainer init failed (likely schema mismatch), wiping local store: \(error.localizedDescription)")
                if let appSupportURL = FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                    .first
                {
                    for filename in ["default.store", "default.store-shm", "default.store-wal"] {
                        try? FileManager.default.removeItem(at: appSupportURL.appending(path: filename))
                    }
                }
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            }
        }
    }

    /// Factory method for testing (in-memory, full schema, no CloudKit).
    ///
    /// `nonisolated` — safe to call from `swift test` without main-actor context.
    public nonisolated static func makeForTesting() throws -> ModelContainer {
        let schema = Self.makeSchema()
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Emergency container factory — 6-level fallback waterfall.
    /// Never throws; always returns a usable (possibly degraded) ModelContainer.
    ///
    /// `nonisolated` — can be called from any context.
    public nonisolated static func makeEmergencyFallback() -> ModelContainer {
        logger.critical("[Emergency] Creating emergency stub container")

        // Level 1: In-memory User schema
        do {
            let schema = Schema([User.self] as [any PersistentModel.Type])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            logger.info("[Emergency] Level 1 fallback successful (in-memory User schema)")
            return container
        } catch {
            logger.critical("EMERGENCY: Cannot create even minimal ModelContainer: \(error.localizedDescription)")

            // Level 2: Default container
            do {
                let schema = Schema([User.self] as [any PersistentModel.Type])
                let container = try ModelContainer(for: schema)
                logger.info("[Emergency] Level 2 fallback successful (default container)")
                return container
            } catch {
                logger.critical("CRITICAL SYSTEM FAILURE: Cannot initialize any ModelContainer: \(error.localizedDescription)")

                // Level 3: Temp-file-backed store
                do {
                    let fallbackSchema = Schema([User.self] as [any PersistentModel.Type])
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Cultivation-Emergency-\(UUID().uuidString).sqlite")
                    let tempConfig = ModelConfiguration(schema: fallbackSchema, url: tempURL)
                    if let tempContainer = try? ModelContainer(for: fallbackSchema, configurations: [tempConfig]) {
                        logger.warning("[Emergency] Level 3 fallback successful (temp file)")
                        return tempContainer
                    }
                }

                // Level 4: Read-only in-memory container
                do {
                    let fallbackSchema = Schema([User.self] as [any PersistentModel.Type])
                    let memConfig = ModelConfiguration(
                        schema: fallbackSchema,
                        isStoredInMemoryOnly: true,
                        allowsSave: false
                    )
                    if let memContainer = try? ModelContainer(for: fallbackSchema, configurations: [memConfig]) {
                        logger.warning("[Emergency] Level 4 fallback successful (read-only in-memory)")
                        return memContainer
                    }
                }

                // Level 5: Default container
                do {
                    let fallbackSchema = Schema([User.self] as [any PersistentModel.Type])
                    if let defaultContainer = try? ModelContainer(for: fallbackSchema) {
                        logger.warning("[Emergency] Level 5 fallback successful (default)")
                        return defaultContainer
                    }
                }

                // Level 6: Empty schema degraded mode
                logger.critical("[Emergency] All fallback attempts failed - attempting staged recovery")
                do {
                    let emptySchema = Schema([] as [any PersistentModel.Type])
                    let emptyConfig = ModelConfiguration(
                        schema: emptySchema,
                        isStoredInMemoryOnly: true,
                        allowsSave: false
                    )
                    if let emergencyContainer = try? ModelContainer(for: emptySchema, configurations: [emptyConfig]) {
                        logger.warning("[Emergency] Level 6 fallback successful (empty schema - degraded mode)")
                        logger.critical("[Emergency] App is in severely degraded state - data operations will fail gracefully")
                        return emergencyContainer
                    }
                }

                // Absolute failure
                logger.critical("[Emergency] Critical system failure - all recovery attempts exhausted")
                fatalError("CRITICAL: Unrecoverable ModelContainer initialization failure. Please reinstall the application.")
            }
        }
    }

    // MARK: - Private Helpers

    /// Builds the full app schema. Kept as a nonisolated helper so all factory
    /// methods can call it without crossing actor boundaries.
    private nonisolated static func makeSchema() -> Schema {
        Schema([
            Plant.self,
            Garden.self,
            GardenBed.self,
            User.self,
            PlantReminder.self,
            JournalEntry.self,
            SoilLog.self,
            ShoppingItem.self,
            CompostBatch.self,
            Seed.self,
            GardenClub.self,
            ClubActivity.self,
            ClubMessage.self,
            ClubEvent.self,
        ] as [any PersistentModel.Type])
    }
}

// swiftlint:enable function_body_length line_length
