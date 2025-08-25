import Foundation
import CryptoKit
import Security

/// Service responsible for all encryption/decryption operations
public final class EncryptionService {
    
    // MARK: - Error Types
    
    public enum EncryptionError: LocalizedError {
        case encryptionFailed
        case decryptionFailed
        case keyGenerationFailed
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .keyGenerationFailed:
                return "Failed to generate encryption key"
            case .invalidData:
                return "Invalid data format"
            }
        }
    }
    
    // MARK: - Properties
    
    private let storage: KeychainStorageService
    private let keyIdentifier = "_encryption_key_v2"
    
    // Lazy encryption key - retrieved or generated on first access
    private lazy var _encryptionKey: SymmetricKey = {
        if let keyData = try? storage.retrieve(for: keyIdentifier) {
            return SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            // Store the key securely
            try? storage.store(newKey.withUnsafeBytes { Data($0) }, for: keyIdentifier)
            return newKey
        }
    }()
    
    /// Access to the encryption key (for internal use)
    public var encryptionKey: SymmetricKey {
        return _encryptionKey
    }
    
    // MARK: - Initialization
    
    public init(storage: KeychainStorageService) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// Encrypt data using AES-256-GCM
    public func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: _encryptionKey)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return encryptedData
    }
    
    /// Decrypt data using AES-256-GCM
    public func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: _encryptionKey)
    }
    
    /// Encrypt data with additional authenticated data
    public func encrypt(_ data: Data, authenticatedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: _encryptionKey, authenticating: authenticatedData)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return encryptedData
    }
    
    /// Decrypt data with additional authenticated data verification
    public func decrypt(_ encryptedData: Data, authenticatedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: _encryptionKey, authenticating: authenticatedData)
    }
    
    /// Generate a new encryption key (for key rotation)
    public func rotateKey() throws {
        let newKey = SymmetricKey(size: .bits256)
        try storage.store(newKey.withUnsafeBytes { Data($0) }, for: keyIdentifier)
        // Update the cached key
        _encryptionKey = newKey
    }
    
    /// Check if encryption key exists
    public var hasEncryptionKey: Bool {
        storage.exists(for: keyIdentifier)
    }
    
    /// Clear encryption key (use with caution - will make encrypted data inaccessible)
    public func clearEncryptionKey() throws {
        try storage.delete(for: keyIdentifier)
    }
}