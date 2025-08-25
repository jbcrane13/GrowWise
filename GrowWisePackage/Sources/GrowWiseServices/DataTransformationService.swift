import Foundation
import CryptoKit

/// Service responsible for data transformation (Codable operations, serialization)
public final class DataTransformationService {
    
    // MARK: - Error Types
    
    public enum TransformationError: LocalizedError {
        case encodingFailed(Error)
        case decodingFailed(Error)
        case invalidData
        case serializationFailed
        case checksumMismatch(expected: String, actual: String)
        case migrationVerificationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .encodingFailed(let error):
                return "Failed to encode data: \(error.localizedDescription)"
            case .decodingFailed(let error):
                return "Failed to decode data: \(error.localizedDescription)"
            case .invalidData:
                return "Invalid data format"
            case .serializationFailed:
                return "JSON serialization failed"
            case .checksumMismatch(let expected, let actual):
                return "Data integrity check failed - expected: \(expected), actual: \(actual)"
            case .migrationVerificationFailed(let reason):
                return "Migration verification failed: \(reason)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let storage: KeychainStorageService
    private let encryptionService: EncryptionService?
    
    // MARK: - Initialization
    
    public init(storage: KeychainStorageService, encryptionService: EncryptionService? = nil) {
        self.storage = storage
        self.encryptionService = encryptionService
    }
    
    // MARK: - String Operations
    
    /// Store string data
    public func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw TransformationError.invalidData
        }
        try storage.store(data, for: key)
    }
    
    /// Retrieve string data
    public func retrieveString(for key: String) throws -> String {
        let data = try storage.retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TransformationError.invalidData
        }
        return string
    }
    
    // MARK: - Boolean Operations
    
    /// Store boolean data
    public func storeBool(_ value: Bool, for key: String) throws {
        let data = Data([value ? 1 : 0])
        try storage.store(data, for: key)
    }
    
    /// Retrieve boolean data
    public func retrieveBool(for key: String) throws -> Bool {
        let data = try storage.retrieve(for: key)
        guard let byte = data.first else {
            throw TransformationError.invalidData
        }
        return byte != 0
    }
    
    // MARK: - Codable Operations
    
    /// Store Codable object
    public func storeCodable<T: Codable>(_ object: T, for key: String) throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(object)
            
            if let encryptionService = encryptionService {
                let encryptedData = try encryptionService.encrypt(data)
                try storage.store(encryptedData, for: key)
            } else {
                try storage.store(data, for: key)
            }
        } catch {
            throw TransformationError.encodingFailed(error)
        }
    }
    
    /// Retrieve Codable object
    public func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        do {
            let storedData = try storage.retrieve(for: key)
            
            let data: Data
            if let encryptionService = encryptionService {
                data = try encryptionService.decrypt(storedData)
            } else {
                data = storedData
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch let error as EncryptionService.EncryptionError {
            throw TransformationError.decodingFailed(error)
        } catch {
            throw TransformationError.decodingFailed(error)
        }
    }
    
    // MARK: - JSON Operations
    
    /// Store JSON serializable data
    public func storeJSONSerializable(_ object: Any, for key: String) throws {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw TransformationError.serializationFailed
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object)
            try storage.store(jsonData, for: key)
        } catch {
            throw TransformationError.serializationFailed
        }
    }
    
    /// Retrieve JSON serializable data
    public func retrieveJSONSerializable(for key: String) throws -> Any {
        let data = try storage.retrieve(for: key)
        
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TransformationError.decodingFailed(error)
        }
    }
    
    // MARK: - Migration Helpers with Checksum Validation
    
    /// Data structure for migration with checksum
    public struct MigratedData {
        public let key: String
        public let originalChecksum: String
        public let migratedChecksum: String
        public let timestamp: Date
        public let verified: Bool
        
        public var isValid: Bool {
            return originalChecksum == migratedChecksum && verified
        }
    }
    
    /// Migrate data from UserDefaults with checksum validation
    public func migrateFromUserDefaults(keys: [String]) -> [MigratedData] {
        var migrationResults: [MigratedData] = []
        
        for key in keys {
            // Skip if already migrated
            if storage.exists(for: key) {
                continue
            }
            
            var originalData: Data?
            var migrated = false
            
            // Try different UserDefaults data types
            if let data = UserDefaults.standard.data(forKey: key) {
                originalData = data
                try? storage.store(data, for: key)
                migrated = true
                UserDefaults.standard.removeObject(forKey: key)
            } else if let string = UserDefaults.standard.string(forKey: key) {
                originalData = string.data(using: .utf8)
                try? storeString(string, for: key)
                migrated = true
                UserDefaults.standard.removeObject(forKey: key)
            } else if UserDefaults.standard.object(forKey: key) != nil {
                let boolValue = UserDefaults.standard.bool(forKey: key)
                originalData = Data([boolValue ? 1 : 0])
                try? storeBool(boolValue, for: key)
                migrated = true
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            if migrated, let originalData = originalData {
                // Calculate checksums for verification
                let originalChecksum = calculateChecksum(data: originalData)
                let migratedChecksum: String
                let verified: Bool
                
                do {
                    let storedData = try storage.retrieve(for: key)
                    migratedChecksum = calculateChecksum(data: storedData)
                    verified = originalChecksum == migratedChecksum
                } catch {
                    migratedChecksum = "error"
                    verified = false
                }
                
                let migrationResult = MigratedData(
                    key: key,
                    originalChecksum: originalChecksum,
                    migratedChecksum: migratedChecksum,
                    timestamp: Date(),
                    verified: verified
                )
                
                migrationResults.append(migrationResult)
                
                #if DEBUG
                print("Migrated \(key) to Keychain - Verified: \(verified)")
                #endif
            }
        }
        
        return migrationResults
    }
    
    /// Migrate single key with checksum validation
    public func migrateFromUserDefaults(key: String) throws -> MigratedData {
        // Skip if already migrated
        if storage.exists(for: key) {
            throw TransformationError.migrationVerificationFailed("Key already exists in keychain")
        }
        
        var originalData: Data?
        var migrated = false
        
        // Try different UserDefaults data types
        if let data = UserDefaults.standard.data(forKey: key) {
            originalData = data
            try storage.store(data, for: key)
            migrated = true
        } else if let string = UserDefaults.standard.string(forKey: key) {
            originalData = string.data(using: .utf8)
            try storeString(string, for: key)
            migrated = true
        } else if UserDefaults.standard.object(forKey: key) != nil {
            let boolValue = UserDefaults.standard.bool(forKey: key)
            originalData = Data([boolValue ? 1 : 0])
            try storeBool(boolValue, for: key)
            migrated = true
        } else {
            throw TransformationError.invalidData
        }
        
        guard migrated, let originalData = originalData else {
            throw TransformationError.migrationVerificationFailed("Failed to migrate data")
        }
        
        // Calculate checksums for verification
        let originalChecksum = calculateChecksum(data: originalData)
        let storedData = try storage.retrieve(for: key)
        let migratedChecksum = calculateChecksum(data: storedData)
        let verified = originalChecksum == migratedChecksum
        
        if !verified {
            // Rollback on checksum mismatch
            try? storage.delete(for: key)
            throw TransformationError.checksumMismatch(expected: originalChecksum, actual: migratedChecksum)
        }
        
        // Only remove from UserDefaults after successful verification
        UserDefaults.standard.removeObject(forKey: key)
        
        return MigratedData(
            key: key,
            originalChecksum: originalChecksum,
            migratedChecksum: migratedChecksum,
            timestamp: Date(),
            verified: verified
        )
    }
    
    /// Verify data integrity for a specific key
    public func verifyDataIntegrity(key: String, originalChecksum: String) throws -> Bool {
        guard storage.exists(for: key) else {
            throw TransformationError.migrationVerificationFailed("Key not found in keychain")
        }
        
        let storedData = try storage.retrieve(for: key)
        let currentChecksum = calculateChecksum(data: storedData)
        
        return currentChecksum == originalChecksum
    }
    
    /// Cleanup legacy data with verification
    public func cleanupLegacyData(keys: [String]) {
        for key in keys {
            if storage.exists(for: key) {
                #if DEBUG
                print("[Security Migration] Removing legacy data for key: \(key)")
                #endif
                try? storage.delete(for: key)
                
                // Verify deletion
                if storage.exists(for: key) {
                    #if DEBUG
                    print("[Security Migration] WARNING: Failed to delete key: \(key)")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Checksum Utilities
    
    /// Calculate SHA-256 checksum for data
    private func calculateChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Validate checksum against stored data
    public func validateChecksum(key: String, expectedChecksum: String) throws -> Bool {
        guard storage.exists(for: key) else {
            throw TransformationError.migrationVerificationFailed("Key not found in keychain")
        }
        
        let storedData = try storage.retrieve(for: key)
        let actualChecksum = calculateChecksum(data: storedData)
        
        if actualChecksum != expectedChecksum {
            throw TransformationError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
        }
        
        return true
    }
}