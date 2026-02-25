import Foundation
import CloudKit
import CoreData
import GrowWiseModels
import os

/// Extended CloudKit service supporting both private (user data) and public (community) databases
@MainActor
@Observable public final class CloudSyncService {
    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastErrorMessage: String?
    public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // Public database state
    public private(set) var isLoadingPublicGardens = false
    public private(set) var publicGardens: [PublicGarden] = []
    public private(set) var publicDatabaseError: String?

    private weak var dataService: DataService?
    private var cloudEventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?
    
    // CloudKit containers — nil during UI testing to avoid CKContainer crash on simulator
    private var privateContainer: CKContainer?
    private var publicDatabase: CKDatabase?
    private var privateDatabase: CKDatabase?

    // Logger
    private let logger = Logger(subsystem: "com.growwise.cloudkit", category: "CloudSyncService")

    public init() {
        // CKContainer crashes on simulators without iCloud entitlements.
        // Skip CloudKit entirely during UI testing.
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }

        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        self.privateContainer = container
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        startObserving()
    }

    public func attach(dataService: DataService) {
        self.dataService = dataService
        Task {
            await refreshStatus()
        }
    }

    public func refreshStatus() async {
        guard let dataService else { return }
        let status = await dataService.getCloudSyncStatus()
        accountStatus = status.accountStatus
        lastSyncDate = status.lastSync
        lastErrorMessage = status.error
    }
    
    // MARK: - Account Status
    
    public func checkAccountStatus() async -> CKAccountStatus {
        guard let privateContainer else { return .couldNotDetermine }
        do {
            let status = try await privateContainer.accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
            return status
        } catch {
            logger.error("Failed to check account status: \(error.localizedDescription)")
            return .couldNotDetermine
        }
    }

    // MARK: - Public Database Operations (Garden Showcase)
    
    /// Publish a garden to the public database (Garden Showcase)
    public func publishGarden(_ garden: Garden, authorName: String, description: String? = nil) async throws -> PublicGarden {
        // Check account status first
        let status = await checkAccountStatus()
        guard status == .available else {
            throw CloudKitError.accountNotAvailable
        }
        
        await MainActor.run {
            isLoadingPublicGardens = true
        }
        defer {
            Task { @MainActor in
                isLoadingPublicGardens = false
            }
        }
        
        // Create a CKRecord for the public garden
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = garden.name
        record["authorName"] = authorName
        record["gardenType"] = garden.gardenType?.rawValue
        record["description"] = description
        record["publishedDate"] = Date()
        record["likeCount"] = 0
        record["viewCount"] = 0
        
        // Save to public database
        guard let publicDatabase else { throw CloudKitError.publishFailed("CloudKit unavailable") }
        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let publicGarden = PublicGarden(from: savedRecord) else {
                throw CloudKitError.invalidRecord
            }
            logger.info("Successfully published garden: \(garden.name ?? "Unnamed")")
            return publicGarden
        } catch {
            logger.error("Failed to publish garden: \(error.localizedDescription)")
            throw CloudKitError.publishFailed(error.localizedDescription)
        }
    }
    
    /// Fetch public gardens from the Garden Showcase
    public func fetchPublicGardens(
        sortBy: PublicGardenSort = .newest,
        limit: Int = 50,
        cursor: CKQueryOperation.Cursor? = nil
    ) async throws -> ([PublicGarden], CKQueryOperation.Cursor?) {
        await MainActor.run {
            isLoadingPublicGardens = true
            publicDatabaseError = nil
        }
        defer {
            Task { @MainActor in
                isLoadingPublicGardens = false
            }
        }
        
        let query = CKQuery(recordType: "PublicGarden", predicate: NSPredicate(value: true))
        
        // Apply sorting
        switch sortBy {
        case .newest:
            query.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: false)]
        case .oldest:
            query.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: true)]
        case .mostLiked:
            query.sortDescriptors = [NSSortDescriptor(key: "likeCount", ascending: false)]
        case .mostViewed:
            query.sortDescriptors = [NSSortDescriptor(key: "viewCount", ascending: false)]
        }
        
        guard let publicDatabase else { throw CloudKitError.fetchFailed("CloudKit unavailable") }
        do {
            let (results, newCursor) = try await publicDatabase.records(
                matching: query,
                inZoneWith: nil,
                resultsLimit: limit
            )
            
            let gardens = results.compactMap { (_, result) -> PublicGarden? in
                switch result {
                case .success(let record):
                    return PublicGarden(from: record)
                case .failure(let error):
                    logger.error("Failed to decode garden record: \(error.localizedDescription)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.publicGardens = gardens
            }
            
            logger.info("Fetched \(gardens.count) public gardens")
            return (gardens, newCursor)
        } catch {
            let errorMessage = error.localizedDescription
            await MainActor.run {
                self.publicDatabaseError = errorMessage
            }
            logger.error("Failed to fetch public gardens: \(errorMessage)")
            throw CloudKitError.fetchFailed(errorMessage)
        }
    }
    
    /// Like a public garden
    public func likeGarden(_ garden: PublicGarden) async throws {
        guard let recordID = garden.recordID else {
            throw CloudKitError.invalidRecord
        }
        
        guard let publicDatabase else { throw CloudKitError.operationFailed("CloudKit unavailable") }
        do {
            let record = try await publicDatabase.record(for: recordID)
            let currentLikes = record["likeCount"] as? Int ?? 0
            record["likeCount"] = currentLikes + 1

            try await publicDatabase.save(record)
            logger.info("Liked garden: \(garden.name)")
        } catch {
            logger.error("Failed to like garden: \(error.localizedDescription)")
            throw CloudKitError.operationFailed(error.localizedDescription)
        }
    }
    
    /// Increment view count for a public garden
    public func incrementViewCount(for garden: PublicGarden) async {
        guard let recordID = garden.recordID, let publicDatabase else { return }

        do {
            let record = try await publicDatabase.record(for: recordID)
            let currentViews = record["viewCount"] as? Int ?? 0
            record["viewCount"] = currentViews + 1

            try await publicDatabase.save(record)
        } catch {
            logger.error("Failed to increment view count: \(error.localizedDescription)")
        }
    }
    
    /// Delete a published garden (only by owner)
    public func unpublishGarden(_ garden: PublicGarden) async throws {
        guard let recordID = garden.recordID else {
            throw CloudKitError.invalidRecord
        }
        
        guard let publicDatabase else { throw CloudKitError.operationFailed("CloudKit unavailable") }
        do {
            try await publicDatabase.deleteRecord(withID: recordID)
            logger.info("Unpublished garden: \(garden.name)")
        } catch {
            logger.error("Failed to unpublish garden: \(error.localizedDescription)")
            throw CloudKitError.operationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Database Operations

    public func getCloudSyncStatus() async -> CloudSyncStatus {
        let status = await checkAccountStatus()
        
        return CloudSyncStatus(
            isAvailable: status == .available,
            accountStatus: status,
            lastSync: lastSyncDate,
            error: lastErrorMessage
        )
    }
    private func startObserving() {
        cloudEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else {
                return
            }

            let endDate = event.endDate
            let errorDescription = event.error?.localizedDescription

            Task { @MainActor in
                if endDate == nil {
                    self.isSyncing = true
                } else {
                    self.isSyncing = false
                    self.lastSyncDate = endDate
                    UserDefaults.standard.set(endDate, forKey: "lastCloudSync")
                }

                if let errorDescription {
                    self.lastErrorMessage = errorDescription
                }
            }
        }

        accountObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshStatus()
            }
        }
    }
}

// MARK: - Supporting Types

/// Represents a garden published in the public database (Garden Showcase)
public struct PublicGarden: Identifiable, Sendable {
    public let id: UUID
    public let recordID: CKRecord.ID?
    public let name: String
    public let authorName: String
    public let gardenType: String?
    public let description: String?
    public let publishedDate: Date
    public let likeCount: Int
    public let viewCount: Int
    public let imageAsset: CKAsset?
    
    public init(
        id: UUID = UUID(),
        recordID: CKRecord.ID? = nil,
        name: String,
        authorName: String,
        gardenType: String? = nil,
        description: String? = nil,
        publishedDate: Date = Date(),
        likeCount: Int = 0,
        viewCount: Int = 0,
        imageAsset: CKAsset? = nil
    ) {
        self.id = id
        self.recordID = recordID
        self.name = name
        self.authorName = authorName
        self.gardenType = gardenType
        self.description = description
        self.publishedDate = publishedDate
        self.likeCount = likeCount
        self.viewCount = viewCount
        self.imageAsset = imageAsset
    }
    
    init?(from record: CKRecord) {
        guard let name = record["name"] as? String,
              let authorName = record["authorName"] as? String else {
            return nil
        }
        
        self.id = UUID()
        self.recordID = record.recordID
        self.name = name
        self.authorName = authorName
        self.gardenType = record["gardenType"] as? String
        self.description = record["description"] as? String
        self.publishedDate = record["publishedDate"] as? Date ?? Date()
        self.likeCount = record["likeCount"] as? Int ?? 0
        self.viewCount = record["viewCount"] as? Int ?? 0
        self.imageAsset = record["image"] as? CKAsset
    }
}

public enum PublicGardenSort: String, CaseIterable, Sendable {
    case newest = "newest"
    case oldest = "oldest"
    case mostLiked = "mostLiked"
    case mostViewed = "mostViewed"
    
    public var displayName: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .mostLiked: return "Most Liked"
        case .mostViewed: return "Most Viewed"
        }
    }
}

// CloudSyncStatus is defined in DataService.swift to avoid duplication

public enum CloudKitError: LocalizedError, Sendable {
    case accountNotAvailable
    case publishFailed(String)
    case fetchFailed(String)
    case operationFailed(String)
    case invalidRecord
    
    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud to use this feature."
        case .publishFailed(let message):
            return "Failed to publish garden: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch gardens: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .invalidRecord:
            return "Invalid record data"
        }
    }
}
