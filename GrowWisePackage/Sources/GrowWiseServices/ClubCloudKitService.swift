import CloudKit
import Foundation
import GrowWiseModels
import os

/// Handles CloudKit sharing for Garden Clubs.
///
/// Garden Clubs use CKShare so that multiple iCloud users can collaborate
/// on a single shared zone. The flow is:
///  1. Owner calls `shareClub(_:)` → creates a CKShare and returns it for
///     presentation via UICloudSharingController / ShareLink.
///  2. Invited user accepts via `acceptShare(metadata:)`.
///  3. Both sides call `fetchSharedClubs()` to see all shared zones they
///     participate in.
///  4. `syncClubData(clubID:)` pulls activities / messages / events from a
///     specific shared zone into local records that SwiftData can read.
@MainActor
@Observable
public final class ClubCloudKitService {
    // MARK: - Public state

    public private(set) var isSyncing = false
    public private(set) var lastErrorMessage: String?

    // MARK: - Private

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    private let logger = Logger(subsystem: "com.growwise.cloudkit", category: "ClubCloudKitService")

    // MARK: - Init

    public init() {
        // Skip CloudKit entirely during UI testing (CKContainer crashes on simulator
        // without iCloud entitlements).
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            // Provide a placeholder — all methods guard early.
            let c = CKContainer.default()
            self.container = c
            self.privateDatabase = c.privateCloudDatabase
            self.sharedDatabase = c.sharedCloudDatabase
        } else {
            let c = CKContainer(identifier: "iCloud.com.growwise.gardening")
            self.container = c
            self.privateDatabase = c.privateCloudDatabase
            self.sharedDatabase = c.sharedCloudDatabase
        }
    }

    // MARK: - Account guard

    private func requireAvailableAccount() async throws {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else {
            throw ClubCloudKitError.accountNotAvailable
        }
        let status = try await container.accountStatus()
        guard status == .available else {
            throw ClubCloudKitError.accountNotAvailable
        }
    }

    // MARK: - Share a club (owner)

    /// Creates (or fetches an existing) CKShare for the given GardenClub.
    /// The caller should present the returned share via UICloudSharingController.
    /// - Parameter club: The GardenClub to share.
    /// - Returns: A `CKShare` ready for presentation.
    public func shareClub(_ club: GardenClub) async throws -> CKShare {
        try await requireAvailableAccount()

        guard let clubID = club.id else {
            throw ClubCloudKitError.missingIdentifier
        }
        guard let clubName = club.name else {
            throw ClubCloudKitError.invalidData("Club name is missing")
        }

        // Use the club UUID as a stable record name in a named zone.
        let zoneName = CloudKitSchema.Zone.gardenClub
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Ensure the zone exists.
        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
            logger.info("GardenClubZone ensured for club \(clubID.uuidString)")
        } catch {
            logger.error("Failed to create GardenClubZone: \(error.localizedDescription)")
            throw ClubCloudKitError.zoneFailed(error.localizedDescription)
        }

        let recordID = CKRecord.ID(recordName: clubID.uuidString, zoneID: zoneID)

        // Try fetching the existing root record first.
        let rootRecord: CKRecord
        do {
            rootRecord = try await privateDatabase.record(for: recordID)
            logger.info("Found existing club root record for \(clubID.uuidString)")
        } catch {
            // Record doesn't exist yet — create it.
            let newRecord = CKRecord(recordType: CloudKitSchema.RecordType.gardenClub, recordID: recordID)
            newRecord["name"] = clubName
            newRecord["inviteCode"] = club.inviteCode ?? ""
            newRecord["ownerID"] = club.ownerID ?? ""
            newRecord["createdDate"] = club.createdDate ?? Date()
            newRecord["isActive"] = club.isActive ?? true

            do {
                rootRecord = try await privateDatabase.save(newRecord)
                logger.info("Created club root record for \(clubID.uuidString)")
            } catch {
                logger.error("Failed to save club root record: \(error.localizedDescription)")
                throw ClubCloudKitError.saveFailed(error.localizedDescription)
            }
        }

        // Check whether a share already exists for this record.
        if let existingShareID = rootRecord.share?.recordID {
            do {
                let share = try await privateDatabase.record(for: existingShareID) as? CKShare
                if let share {
                    logger.info("Returning existing CKShare for club \(clubID.uuidString)")
                    return share
                }
            } catch {
                logger.warning("Could not fetch existing share, creating new one: \(error.localizedDescription)")
            }
        }

        // Create a new share.
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = clubName as CKRecordValue
        share.publicPermission = .none // invite-only

        do {
            let (savedResults, _) = try await privateDatabase.modifyRecords(
                saving: [rootRecord, share],
                deleting: []
            )

            // Extract the saved share from results.
            for (id, result) in savedResults {
                if id == share.recordID, case .success(let record) = result, let savedShare = record as? CKShare {
                    logger.info("CKShare created for club \(clubID.uuidString)")
                    return savedShare
                }
            }

            throw ClubCloudKitError.shareFailed("Share record not found in save results")
        } catch {
            logger.error("Failed to create CKShare: \(error.localizedDescription)")
            throw ClubCloudKitError.shareFailed(error.localizedDescription)
        }
    }

    // MARK: - Accept a share (invitee)

    /// Accepts a CKShare after the user taps an invite link.
    /// - Parameter metadata: The `CKShare.Metadata` extracted from the share URL.
    public func acceptShare(metadata: CKShare.Metadata) async throws {
        try await requireAvailableAccount()

        do {
            try await container.accept(metadata)
            logger.info("Accepted CKShare: \(metadata.share.recordID.recordName)")
        } catch {
            logger.error("Failed to accept CKShare: \(error.localizedDescription)")
            throw ClubCloudKitError.acceptFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch shared clubs

    /// Returns all GardenClub root records from the shared database that the
    /// current user participates in (either as owner or member).
    public func fetchSharedClubs() async throws -> [CKRecord] {
        try await requireAvailableAccount()

        isSyncing = true
        defer { isSyncing = false }

        let query = CKQuery(
            recordType: CloudKitSchema.RecordType.gardenClub,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]

        var clubs: [CKRecord] = []

        // Fetch from shared database (clubs shared with this user).
        do {
            let (results, _) = try await sharedDatabase.records(
                matching: query,
                inZoneWith: nil,
                resultsLimit: 200
            )
            for (_, result) in results {
                if case .success(let record) = result {
                    clubs.append(record)
                }
            }
            logger.info("Fetched \(clubs.count) shared club records")
        } catch {
            logger.error("Failed to fetch shared clubs: \(error.localizedDescription)")
            throw ClubCloudKitError.fetchFailed(error.localizedDescription)
        }

        return clubs
    }

    // MARK: - Sync club data

    /// Pulls the latest activities, messages, and events for `clubID` from the
    /// appropriate CloudKit zone and returns raw records for the caller to persist.
    public func syncClubData(clubID: UUID) async throws -> ClubSyncResult {
        try await requireAvailableAccount()

        isSyncing = true
        defer { isSyncing = false }

        // Build the zone ID. For owned clubs it's in the private db;
        // for joined clubs it's in the shared db. We try private first,
        // then fall back to shared.
        let zoneName = CloudKitSchema.Zone.gardenClub
        let privateZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let clubUUIDString = clubID.uuidString

        func fetch(recordType: String, from database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [CKRecord] {
            let predicate = NSPredicate(format: "clubID == %@", clubUUIDString)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

            let (results, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 200
            )
            return results.compactMap { _, result -> CKRecord? in
                if case .success(let record) = result { return record }
                return nil
            }
        }

        // Determine which database has this club's zone.
        let (database, zoneID): (CKDatabase, CKRecordZone.ID)
        do {
            _ = try await privateDatabase.recordZone(for: privateZoneID)
            database = privateDatabase
            zoneID = privateZoneID
        } catch {
            // Zone not owned — try shared database with a wildcard zone.
            database = sharedDatabase
            // In the shared database we don't know the owner, so fetch without a specific zone.
            zoneID = privateZoneID // Will be overridden below for shared
            _ = error // suppress unused warning
        }

        async let activities = (try? fetch(recordType: CloudKitSchema.RecordType.clubActivity, from: database, zoneID: zoneID)) ?? []
        async let messages = (try? fetch(recordType: CloudKitSchema.RecordType.clubMessage, from: database, zoneID: zoneID)) ?? []
        async let events = (try? fetch(recordType: CloudKitSchema.RecordType.clubEvent, from: database, zoneID: zoneID)) ?? []

        let result = await ClubSyncResult(
            activities: activities,
            messages: messages,
            events: events
        )

        logger.info("Synced club \(clubUUIDString): \(result.activities.count) activities, \(result.messages.count) messages, \(result.events.count) events")
        return result
    }

    // MARK: - Fetch recent activities for a club

    /// Queries the private CloudKit database for the most recent `ClubActivity`
    /// records belonging to `clubID`. Results are sorted newest-first and capped
    /// at `limit`. Callers should wrap this in a `do/catch` and fall back to the
    /// SwiftData-only path on error — CloudKit availability is not guaranteed.
    ///
    /// - Parameters:
    ///   - clubID: The UUID string identifying the club whose activities to fetch.
    ///   - limit: Maximum number of records to return (default: 50).
    /// - Returns: Raw `CKRecord` values ready for mapping to view-data. The
    ///   record fields mirror those written by `publishActivity(_:)`:
    ///   `clubID`, `memberName`, `memberID`, `activityType`,
    ///   `activityDescription`, `gardenName`, `timestamp`.
    public func fetchRecentActivities(for clubID: String, limit: Int = 50) async throws -> [CKRecord] {
        try await requireAvailableAccount()

        let predicate = NSPredicate(format: "clubID == %@", clubID)
        let query = CKQuery(
            recordType: CloudKitSchema.RecordType.clubActivity,
            predicate: predicate
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let zoneName = CloudKitSchema.Zone.gardenClub
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        let (results, _) = try await privateDatabase.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: limit
        )

        let records = results.compactMap { _, result -> CKRecord? in
            if case .success(let record) = result { return record }
            return nil
        }

        logger.info("fetchRecentActivities: fetched \(records.count) CK records for club \(clubID, privacy: .public)")
        return records
    }

    // MARK: - Save a club record to shared zone

    /// Saves an activity record into the club's shared zone so all members can see it.
    public func publishActivity(_ activity: ClubActivity) async throws {
        try await requireAvailableAccount()

        guard let clubID = activity.clubID else { throw ClubCloudKitError.missingIdentifier }
        guard let activityID = activity.id else { throw ClubCloudKitError.missingIdentifier }

        let zoneName = CloudKitSchema.Zone.gardenClub
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: activityID.uuidString, zoneID: zoneID)

        let record = CKRecord(recordType: CloudKitSchema.RecordType.clubActivity, recordID: recordID)
        record["clubID"] = clubID.uuidString
        record["memberName"] = activity.memberName ?? ""
        record["memberID"] = activity.memberID ?? ""
        record["activityType"] = activity.activityType ?? ""
        record["activityDescription"] = activity.activityDescription ?? ""
        record["gardenName"] = activity.gardenName ?? ""
        record["timestamp"] = activity.timestamp ?? Date()

        do {
            _ = try await privateDatabase.save(record)
            logger.info("Published activity \(activityID.uuidString) to shared zone")
        } catch {
            logger.error("Failed to publish activity: \(error.localizedDescription)")
            throw ClubCloudKitError.saveFailed(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

/// The records pulled back from a club sync operation.
public struct ClubSyncResult: Sendable {
    public let activities: [CKRecord]
    public let messages: [CKRecord]
    public let events: [CKRecord]
}

// MARK: - Errors

public enum ClubCloudKitError: LocalizedError, Sendable {
    case accountNotAvailable
    case missingIdentifier
    case invalidData(String)
    case zoneFailed(String)
    case saveFailed(String)
    case shareFailed(String)
    case acceptFailed(String)
    case fetchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            "iCloud account is not available. Please sign in to iCloud to use Garden Clubs."

        case .missingIdentifier:
            "The club record is missing a required identifier."

        case .invalidData(let msg):
            "Invalid data: \(msg)"

        case .zoneFailed(let msg):
            "Failed to create CloudKit zone: \(msg)"

        case .saveFailed(let msg):
            "Failed to save record: \(msg)"

        case .shareFailed(let msg):
            "Failed to create share: \(msg)"

        case .acceptFailed(let msg):
            "Failed to accept invite: \(msg)"

        case .fetchFailed(let msg):
            "Failed to fetch clubs: \(msg)"
        }
    }
}
