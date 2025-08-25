import Foundation
import CryptoKit
import Security

/// Service for migrating from legacy keychain-based encryption to Secure Enclave
/// Handles backward compatibility and seamless migration of encrypted data
public final class LegacyEncryptionMigrationService {
    
    // MARK: - Error Types
    
    public enum MigrationError: LocalizedError {
        case legacyKeyNotFound
        case migrationFailed
        case decryptionFailed
        case reencryptionFailed
        case keyRetrievalFailed
        
        public var errorDescription: String? {
            switch self {
            case .legacyKeyNotFound:
                return "Legacy encryption key not found"
            case .migrationFailed:
                return "Failed to migrate encryption data"
            case .decryptionFailed:
                return "Failed to decrypt legacy data"
            case .reencryptionFailed:
                return "Failed to re-encrypt with new key"
            case .keyRetrievalFailed:
                return "Failed to retrieve legacy encryption key"
            }
        }
    }
    
    // MARK: - Properties
    
    private let keychainStorage: KeychainStorageService
    private let legacyKeyIdentifier = "_encryption_key_v2"
    
    // MARK: - Initialization
    
    public init(keychainStorage: KeychainStorageService) {
        self.keychainStorage = keychainStorage
    }
    
    // MARK: - Public Methods
    
    /// Check if legacy encryption key exists
    public var hasLegacyKey: Bool {
        return keychainStorage.exists(for: legacyKeyIdentifier)
    }
    
    /// Retrieve the legacy encryption key
    public func getLegacyKey() throws -> SymmetricKey {
        guard hasLegacyKey else {
            throw MigrationError.legacyKeyNotFound
        }
        
        do {
            let keyData = try keychainStorage.retrieve(for: legacyKeyIdentifier)
            return SymmetricKey(data: keyData)
        } catch {
            throw MigrationError.keyRetrievalFailed
        }
    }
    
    /// Decrypt data using legacy key
    public func decryptLegacyData(_ encryptedData: Data) throws -> Data {
        let legacyKey = try getLegacyKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: legacyKey)
        } catch {
            throw MigrationError.decryptionFailed
        }
    }
    
    /// Decrypt data with authenticated data using legacy key
    public func decryptLegacyData(_ encryptedData: Data, authenticatedData: Data) throws -> Data {
        let legacyKey = try getLegacyKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: legacyKey, authenticating: authenticatedData)
        } catch {
            throw MigrationError.decryptionFailed
        }
    }
    
    /// Migrate encrypted data from legacy key to new Secure Enclave key
    public func migrateEncryptedData(
        _ legacyEncryptedData: Data,
        using newKey: SymmetricKey,
        authenticatedData: Data? = nil
    ) throws -> Data {
        // Decrypt with legacy key
        let plaintext: Data
        if let authData = authenticatedData {
            plaintext = try decryptLegacyData(legacyEncryptedData, authenticatedData: authData)
        } else {
            plaintext = try decryptLegacyData(legacyEncryptedData)
        }
        
        // Re-encrypt with new key
        do {
            let sealedBox: AES.GCM.SealedBox
            if let authData = authenticatedData {
                sealedBox = try AES.GCM.seal(plaintext, using: newKey, authenticating: authData)
            } else {
                sealedBox = try AES.GCM.seal(plaintext, using: newKey)
            }
            
            guard let newEncryptedData = sealedBox.combined else {
                throw MigrationError.reencryptionFailed
            }
            
            return newEncryptedData
        } catch {
            throw MigrationError.reencryptionFailed
        }
    }
    
    /// Batch migrate multiple encrypted data items
    public func batchMigrateEncryptedData(
        _ dataItems: [(data: Data, authenticatedData: Data?)],
        using newKey: SymmetricKey
    ) throws -> [Data] {
        var migratedItems: [Data] = []
        
        for item in dataItems {
            let migratedData = try migrateEncryptedData(
                item.data,
                using: newKey,
                authenticatedData: item.authenticatedData
            )
            migratedItems.append(migratedData)
        }
        
        return migratedItems
    }
    
    /// Remove legacy encryption key after successful migration
    public func removeLegacyKey() throws {
        guard hasLegacyKey else {
            // Already removed, nothing to do
            return
        }
        
        try keychainStorage.delete(for: legacyKeyIdentifier)
    }
    
    /// Check if data appears to be encrypted with legacy format
    public func isLegacyEncryptedData(_ data: Data) -> Bool {
        // Try to create a SealedBox from the data
        // Legacy data will have the standard AES.GCM format
        do {
            _ = try AES.GCM.SealedBox(combined: data)
            return true
        } catch {
            return false
        }
    }
    
    /// Perform a test migration to validate the process without changing data
    public func validateMigrationCompatibility(testData: Data, newKey: SymmetricKey) throws -> Bool {
        do {
            // Try to decrypt with legacy key
            let plaintext = try decryptLegacyData(testData)
            
            // Try to encrypt with new key
            let sealedBox = try AES.GCM.seal(plaintext, using: newKey)
            guard sealedBox.combined != nil else {
                return false
            }
            
            return true
        } catch {
            return false
        }
    }
    
    /// Get migration statistics
    public func getMigrationInfo() -> MigrationInfo {
        return MigrationInfo(
            hasLegacyKey: hasLegacyKey,
            secureEnclaveAvailable: SecureEnclaveKeyManager.isSecureEnclaveAvailable,
            recommendedAction: getRecommendedMigrationAction()
        )
    }
    
    // MARK: - Private Methods
    
    private func getRecommendedMigrationAction() -> MigrationAction {
        if !hasLegacyKey {
            return .noActionNeeded
        }
        
        if SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            return .migrateToSecureEnclave
        } else {
            return .keepLegacyWithWarning
        }
    }
}

// MARK: - Supporting Types

public struct MigrationInfo {
    public let hasLegacyKey: Bool
    public let secureEnclaveAvailable: Bool
    public let recommendedAction: MigrationAction
}

public enum MigrationAction {
    case noActionNeeded
    case migrateToSecureEnclave
    case keepLegacyWithWarning
    
    public var description: String {
        switch self {
        case .noActionNeeded:
            return "No migration needed - using modern encryption"
        case .migrateToSecureEnclave:
            return "Migrate to Secure Enclave for enhanced security"
        case .keepLegacyWithWarning:
            return "Keep legacy encryption (Secure Enclave not available)"
        }
    }
}