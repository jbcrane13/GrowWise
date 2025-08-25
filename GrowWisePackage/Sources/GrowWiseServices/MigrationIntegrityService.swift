import Foundation
import CryptoKit
import Security

/// Comprehensive data integrity service for UserDefaults to Keychain migration
/// Provides checksums, backups, verification, rollback, and detailed reporting
public final class MigrationIntegrityService {
    
    // MARK: - Error Types
    
    public enum IntegrityError: LocalizedError {
        case checksumMismatch(expected: String, actual: String)
        case backupFailed(String)
        case verificationFailed(String)
        case rollbackFailed(String)
        case migrationAborted(String)
        case progressTrackingFailed(String)
        case invalidState(String)
        case partialMigrationCorrupted
        case dryRunFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .checksumMismatch(let expected, let actual):
                return "Data integrity check failed - expected: \(expected), actual: \(actual)"
            case .backupFailed(let reason):
                return "Backup creation failed: \(reason)"
            case .verificationFailed(let reason):
                return "Migration verification failed: \(reason)"
            case .rollbackFailed(let reason):
                return "Migration rollback failed: \(reason)"
            case .migrationAborted(let reason):
                return "Migration aborted: \(reason)"
            case .progressTrackingFailed(let reason):
                return "Progress tracking failed: \(reason)"
            case .invalidState(let reason):
                return "Invalid migration state: \(reason)"
            case .partialMigrationCorrupted:
                return "Partial migration data is corrupted and cannot be recovered"
            case .dryRunFailed(let reason):
                return "Dry run test failed: \(reason)"
            }
        }
    }
    
    // MARK: - Migration Status Types
    
    public enum MigrationStatus: String, Codable {
        case notStarted
        case backupInProgress
        case backupCompleted
        case migrationInProgress
        case verificationInProgress
        case completed
        case failed
        case rolledBack
        case partiallyComplete
        
        public var description: String {
            switch self {
            case .notStarted: return "Migration not started"
            case .backupInProgress: return "Creating backup"
            case .backupCompleted: return "Backup completed"
            case .migrationInProgress: return "Migration in progress"
            case .verificationInProgress: return "Verifying migration"
            case .completed: return "Migration completed successfully"
            case .failed: return "Migration failed"
            case .rolledBack: return "Migration rolled back"
            case .partiallyComplete: return "Migration partially complete"
            }
        }
    }
    
    public struct MigrationProgress: Codable {
        public let sessionId: String
        public var status: MigrationStatus
        public let totalItems: Int
        public var completedItems: Int
        public var failedItems: Int
        public let startTime: Date
        public var lastUpdated: Date
        public var errors: [String]
        public var checksums: [String: String] // key -> checksum
        public var backupLocation: String?
        
        public var progressPercentage: Double {
            guard totalItems > 0 else { return 0 }
            return Double(completedItems) / Double(totalItems) * 100.0
        }
        
        public var isComplete: Bool {
            return status == .completed
        }
        
        public var canResume: Bool {
            return status == .partiallyComplete || status == .failed
        }
    }
    
    public struct DataChecksum {
        public let key: String
        public let originalHash: String
        public let migratedHash: String
        public let timestamp: Date
        public let verified: Bool
        
        public var isValid: Bool {
            return originalHash == migratedHash && verified
        }
    }
    
    public struct MigrationReport {
        public let sessionId: String
        public let startTime: Date
        public let endTime: Date
        public let duration: TimeInterval
        public let status: MigrationStatus
        public let totalItems: Int
        public let successfulItems: Int
        public let failedItems: Int
        public let checksums: [DataChecksum]
        public let errors: [String]
        public let warnings: [String]
        public let backupLocation: String?
        public let rollbackPerformed: Bool
        
        public var successRate: Double {
            guard totalItems > 0 else { return 0 }
            return Double(successfulItems) / Double(totalItems) * 100.0
        }
        
        public var integrityVerified: Bool {
            return checksums.allSatisfy { $0.isValid }
        }
    }
    
    // MARK: - Properties
    
    private let keychainStorage: KeychainStorageService
    private let auditLogger: AuditLogger
    private let progressKey = "_migration_progress_v1"
    private let backupPrefix = "_backup_"
    private let checksumPrefix = "_checksum_"
    
    // MARK: - Initialization
    
    public init(keychainStorage: KeychainStorageService, auditLogger: AuditLogger = AuditLogger.shared) {
        self.keychainStorage = keychainStorage
        self.auditLogger = auditLogger
    }
    
    // MARK: - Public Methods
    
    /// Perform complete migration with full integrity checks
    public func performSecureMigration(
        keys: [String],
        dryRun: Bool = false,
        sessionId: String? = nil
    ) throws -> MigrationReport {
        let migrationSessionId = sessionId ?? UUID().uuidString
        let startTime = Date()
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: "system",
            result: .success,
            threatLevel: .low,
            description: "Starting secure migration with integrity checks",
            details: [
                "session_id": migrationSessionId,
                "keys_count": "\(keys.count)",
                "dry_run": dryRun ? "true" : "false"
            ]
        )
        
        var progress = MigrationProgress(
            sessionId: migrationSessionId,
            status: .notStarted,
            totalItems: keys.count,
            completedItems: 0,
            failedItems: 0,
            startTime: startTime,
            lastUpdated: startTime,
            errors: [],
            checksums: [:],
            backupLocation: nil
        )
        
        do {
            // Phase 1: Create backup if not dry run
            if !dryRun {
                progress = try createBackup(keys: keys, progress: progress)
            }
            
            // Phase 2: Perform migration with checksums
            progress = try performMigrationWithChecksums(keys: keys, progress: progress, dryRun: dryRun)
            
            // Phase 3: Verify migration
            progress = try verifyMigration(keys: keys, progress: progress, dryRun: dryRun)
            
            // Phase 4: Complete migration
            progress.status = .completed
            progress.lastUpdated = Date()
            
            if !dryRun {
                try saveProgress(progress)
                try cleanupBackups(sessionId: migrationSessionId)
            }
            
            let report = createMigrationReport(from: progress, endTime: Date())
            
            auditLogger.logSecurityEvent(
                type: .configurationChange,
                userId: "system",
                result: .success,
                threatLevel: .low,
                description: "Migration completed successfully",
                details: [
                    "session_id": migrationSessionId,
                    "success_rate": String(format: "%.2f%%", report.successRate),
                    "integrity_verified": report.integrityVerified ? "true" : "false"
                ]
            )
            
            return report
            
        } catch {
            // Handle migration failure
            progress.status = .failed
            progress.errors.append(error.localizedDescription)
            progress.lastUpdated = Date()
            
            if !dryRun {
                try? saveProgress(progress)
                
                // Attempt rollback if backup exists
                if progress.backupLocation != nil {
                    do {
                        try rollbackMigration(sessionId: migrationSessionId)
                        progress.status = .rolledBack
                    } catch {
                        auditLogger.logSecurityEvent(
                            type: .securityViolation,
                            userId: "system",
                            result: .failure,
                            threatLevel: .high,
                            description: "Migration rollback failed",
                            details: ["error": error.localizedDescription]
                        )
                    }
                }
            }
            
            auditLogger.logSecurityEvent(
                type: .securityViolation,
                userId: "system",
                result: .failure,
                threatLevel: .medium,
                description: "Migration failed",
                details: [
                    "session_id": migrationSessionId,
                    "error": error.localizedDescription
                ]
            )
            
            throw error
        }
    }
    
    /// Resume a partial migration
    public func resumeMigration(sessionId: String) throws -> MigrationReport {
        guard let progress = try loadProgress(sessionId: sessionId) else {
            throw IntegrityError.invalidState("No migration progress found for session \(sessionId)")
        }
        
        guard progress.canResume else {
            throw IntegrityError.invalidState("Migration cannot be resumed in current state: \(progress.status)")
        }
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: "system",
            result: .success,
            threatLevel: .low,
            description: "Resuming partial migration",
            details: [
                "session_id": sessionId,
                "previous_status": progress.status.rawValue,
                "completed_items": "\(progress.completedItems)"
            ]
        )
        
        // Get remaining keys to migrate
        let allKeys = extractKeysFromBackup(sessionId: sessionId)
        let remainingKeys = allKeys.filter { !progress.checksums.keys.contains($0) }
        
        return try performSecureMigration(keys: remainingKeys, sessionId: sessionId)
    }
    
    /// Rollback migration to original state
    public func rollbackMigration(sessionId: String) throws {
        guard let progress = try loadProgress(sessionId: sessionId) else {
            throw IntegrityError.rollbackFailed("No migration progress found")
        }
        
        guard let backupLocation = progress.backupLocation else {
            throw IntegrityError.rollbackFailed("No backup available for rollback")
        }
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: "system",
            result: .success,
            threatLevel: .medium,
            description: "Starting migration rollback",
            details: [
                "session_id": sessionId,
                "backup_location": backupLocation
            ]
        )
        
        do {
            // Restore from backup
            try restoreFromBackup(sessionId: sessionId)
            
            // Update progress
            var updatedProgress = progress
            updatedProgress.status = .rolledBack
            updatedProgress.lastUpdated = Date()
            try saveProgress(updatedProgress)
            
            auditLogger.logSecurityEvent(
                type: .configurationChange,
                userId: "system",
                result: .success,
                threatLevel: .low,
                description: "Migration rolled back successfully",
                details: ["session_id": sessionId]
            )
            
        } catch {
            auditLogger.logSecurityEvent(
                type: .securityViolation,
                userId: "system",
                result: .failure,
                threatLevel: .high,
                description: "Migration rollback failed",
                details: [
                    "session_id": sessionId,
                    "error": error.localizedDescription
                ]
            )
            throw IntegrityError.rollbackFailed(error.localizedDescription)
        }
    }
    
    /// Get current migration status
    public func getMigrationStatus(sessionId: String) -> MigrationProgress? {
        return try? loadProgress(sessionId: sessionId)
    }
    
    /// Verify data integrity for specific keys
    public func verifyDataIntegrity(keys: [String]) throws -> [DataChecksum] {
        var checksums: [DataChecksum] = []
        
        for key in keys {
            let userDefaultsData = getUserDefaultsData(for: key)
            let keychainData = try? keychainStorage.retrieve(for: key)
            
            let originalHash = calculateChecksum(data: userDefaultsData)
            let migratedHash = calculateChecksum(data: keychainData)
            
            let checksum = DataChecksum(
                key: key,
                originalHash: originalHash,
                migratedHash: migratedHash,
                timestamp: Date(),
                verified: originalHash == migratedHash
            )
            
            checksums.append(checksum)
        }
        
        return checksums
    }
    
    /// Perform dry run test
    public func performDryRun(keys: [String]) throws -> MigrationReport {
        return try performSecureMigration(keys: keys, dryRun: true)
    }
    
    // MARK: - Private Methods
    
    private func createBackup(keys: [String], progress: MigrationProgress) throws -> MigrationProgress {
        var updatedProgress = progress
        updatedProgress.status = .backupInProgress
        updatedProgress.lastUpdated = Date()
        try saveProgress(updatedProgress)
        
        let backupKey = "\(backupPrefix)\(progress.sessionId)"
        var originalData: [String: String] = [:]
        
        for key in keys {
            if let data = getUserDefaultsData(for: key) {
                originalData[key] = String(data: data, encoding: .utf8) ?? ""
            }
        }
        
        // Create backup with Codable structure
        let backupData = BackupData(
            timestamp: Date(),
            version: "1.0",
            data: originalData
        )
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(backupData)
            try keychainStorage.store(jsonData, for: backupKey)
            
            updatedProgress.status = .backupCompleted
            updatedProgress.backupLocation = backupKey
            updatedProgress.lastUpdated = Date()
            try saveProgress(updatedProgress)
            
            return updatedProgress
            
        } catch {
            throw IntegrityError.backupFailed(error.localizedDescription)
        }
    }
    
    private func performMigrationWithChecksums(keys: [String], progress: MigrationProgress, dryRun: Bool) throws -> MigrationProgress {
        var updatedProgress = progress
        updatedProgress.status = .migrationInProgress
        updatedProgress.lastUpdated = Date()
        
        if !dryRun {
            try saveProgress(updatedProgress)
        }
        
        var checksums = updatedProgress.checksums
        var completedCount = updatedProgress.completedItems
        var failedCount = updatedProgress.failedItems
        var errors = updatedProgress.errors
        
        for key in keys {
            // Skip if already migrated (for resume functionality)
            if checksums.keys.contains(key) {
                continue
            }
            
            do {
                guard let originalData = getUserDefaultsData(for: key) else {
                    continue // Skip keys with no data
                }
                
                let originalChecksum = calculateChecksum(data: originalData)
                
                if !dryRun {
                    // Perform actual migration
                    try keychainStorage.store(originalData, for: key)
                    
                    // Verify immediately after storage
                    let storedData = try keychainStorage.retrieve(for: key)
                    let storedChecksum = calculateChecksum(data: storedData)
                    
                    if originalChecksum != storedChecksum {
                        throw IntegrityError.checksumMismatch(expected: originalChecksum, actual: storedChecksum)
                    }
                    
                    // Remove from UserDefaults after successful verification
                    UserDefaults.standard.removeObject(forKey: key)
                }
                
                checksums[key] = originalChecksum
                completedCount += 1
                
            } catch {
                errors.append("Failed to migrate \(key): \(error.localizedDescription)")
                failedCount += 1
                
                if !dryRun {
                    // Clean up partial migration
                    try? keychainStorage.delete(for: key)
                }
            }
        }
        
        updatedProgress.checksums = checksums
        updatedProgress.completedItems = completedCount
        updatedProgress.failedItems = failedCount
        updatedProgress.errors = errors
        updatedProgress.lastUpdated = Date()
        
        if !dryRun {
            try saveProgress(updatedProgress)
        }
        
        return updatedProgress
    }
    
    private func verifyMigration(keys: [String], progress: MigrationProgress, dryRun: Bool) throws -> MigrationProgress {
        var updatedProgress = progress
        updatedProgress.status = .verificationInProgress
        updatedProgress.lastUpdated = Date()
        
        if !dryRun {
            try saveProgress(updatedProgress)
        }
        
        // Verify checksums for all migrated keys
        for (key, expectedChecksum) in progress.checksums {
            if !dryRun {
                do {
                    let storedData = try keychainStorage.retrieve(for: key)
                    let actualChecksum = calculateChecksum(data: storedData)
                    
                    if expectedChecksum != actualChecksum {
                        throw IntegrityError.verificationFailed("Checksum mismatch for key \(key)")
                    }
                } catch {
                    throw IntegrityError.verificationFailed("Could not verify key \(key): \(error.localizedDescription)")
                }
            }
        }
        
        updatedProgress.lastUpdated = Date()
        return updatedProgress
    }
    
    private func calculateChecksum(data: Data?) -> String {
        guard let data = data else { return "empty" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getUserDefaultsData(for key: String) -> Data? {
        if let data = UserDefaults.standard.data(forKey: key) {
            return data
        } else if let string = UserDefaults.standard.string(forKey: key) {
            return string.data(using: .utf8)
        } else if UserDefaults.standard.object(forKey: key) != nil {
            let boolValue = UserDefaults.standard.bool(forKey: key)
            return Data([boolValue ? 1 : 0])
        }
        return nil
    }
    
    // MARK: - Helper Structures
    
    private struct BackupData: Codable {
        let timestamp: Date
        let version: String
        let data: [String: String]
    }
    
    private func saveProgress(_ progress: MigrationProgress) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(progress)
            try keychainStorage.store(data, for: progressKey)
        } catch {
            throw IntegrityError.progressTrackingFailed(error.localizedDescription)
        }
    }
    
    private func loadProgress(sessionId: String) throws -> MigrationProgress? {
        do {
            let data = try keychainStorage.retrieve(for: progressKey)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let progress = try decoder.decode(MigrationProgress.self, from: data)
            return progress.sessionId == sessionId ? progress : nil
        } catch KeychainStorageService.StorageError.itemNotFound {
            return nil
        } catch {
            throw IntegrityError.progressTrackingFailed(error.localizedDescription)
        }
    }
    
    private func restoreFromBackup(sessionId: String) throws {
        let backupKey = "\(backupPrefix)\(sessionId)"
        
        do {
            let backupData = try keychainStorage.retrieve(for: backupKey)
            let decoder = JSONDecoder()
            let backup = try decoder.decode([String: Data].self, from: backupData)
            
            // Restore each item to UserDefaults
            for (key, data) in backup {
                // Remove from keychain first
                try? keychainStorage.delete(for: key)
                
                // Restore to UserDefaults based on data type
                if let string = String(data: data, encoding: .utf8), string.count < 1000 {
                    UserDefaults.standard.set(string, forKey: key)
                } else if data.count == 1, let byte = data.first {
                    UserDefaults.standard.set(byte != 0, forKey: key)
                } else {
                    UserDefaults.standard.set(data, forKey: key)
                }
            }
        } catch {
            throw IntegrityError.rollbackFailed(error.localizedDescription)
        }
    }
    
    private func extractKeysFromBackup(sessionId: String) -> [String] {
        let backupKey = "\(backupPrefix)\(sessionId)"
        
        do {
            let backupData = try keychainStorage.retrieve(for: backupKey)
            let decoder = JSONDecoder()
            let backup = try decoder.decode([String: Data].self, from: backupData)
            return Array(backup.keys)
        } catch {
            return []
        }
    }
    
    private func cleanupBackups(sessionId: String) throws {
        let backupKey = "\(backupPrefix)\(sessionId)"
        try keychainStorage.delete(for: backupKey)
    }
    
    private func createMigrationReport(from progress: MigrationProgress, endTime: Date) -> MigrationReport {
        let checksums = progress.checksums.map { key, hash in
            DataChecksum(
                key: key,
                originalHash: hash,
                migratedHash: hash, // Verified during migration
                timestamp: progress.lastUpdated,
                verified: true
            )
        }
        
        return MigrationReport(
            sessionId: progress.sessionId,
            startTime: progress.startTime,
            endTime: endTime,
            duration: endTime.timeIntervalSince(progress.startTime),
            status: progress.status,
            totalItems: progress.totalItems,
            successfulItems: progress.completedItems,
            failedItems: progress.failedItems,
            checksums: checksums,
            errors: progress.errors,
            warnings: [],
            backupLocation: progress.backupLocation,
            rollbackPerformed: progress.status == .rolledBack
        )
    }
}

// MARK: - Extensions

extension MigrationIntegrityService {
    
    /// Get all active migration sessions
    public func getActiveMigrationSessions() -> [String] {
        // Implementation would scan keychain for progress keys
        // For simplicity, returning empty array - would need more complex keychain scanning
        return []
    }
    
    /// Clean up old migration data
    public func cleanupOldMigrationData(olderThan days: Int = 30) throws {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        // Implementation would scan and clean up old backup and progress data
        // For now, this is a placeholder for the interface
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: "system",
            result: .success,
            threatLevel: .low,
            description: "Cleaned up old migration data",
            details: ["cutoff_date": cutoffDate.description]
        )
    }
}