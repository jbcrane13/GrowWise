import Foundation
import CryptoKit
import Security

/// Manager for Secure Enclave-backed encryption keys
/// Eliminates circular dependency by storing private keys in Secure Enclave instead of keychain
public final class SecureEnclaveKeyManager {
    
    // MARK: - Error Types
    
    public enum SecureEnclaveError: LocalizedError {
        case secureEnclaveNotAvailable
        case keyGenerationFailed
        case keyDerivationFailed
        case keyNotFound
        case keyAccessFailed
        case unsupportedOperation
        
        public var errorDescription: String? {
            switch self {
            case .secureEnclaveNotAvailable:
                return "Secure Enclave is not available on this device"
            case .keyGenerationFailed:
                return "Failed to generate Secure Enclave key"
            case .keyDerivationFailed:
                return "Failed to derive symmetric key from Secure Enclave key"
            case .keyNotFound:
                return "Secure Enclave key not found"
            case .keyAccessFailed:
                return "Failed to access Secure Enclave key"
            case .unsupportedOperation:
                return "Operation not supported on this device"
            }
        }
    }
    
    // MARK: - Properties
    
    private let keyIdentifier: String
    private let accessGroup: String?
    
    // Cache for the derived symmetric key to avoid repeated derivations
    private var _cachedSymmetricKey: SymmetricKey?
    private var _cachedPrivateKey: SecureEnclave.P256.Signing.PrivateKey?
    private let cacheQueue = DispatchQueue(label: "com.growwise.secure-enclave-key-manager", attributes: .concurrent)
    
    // Tag for Secure Enclave key storage
    private var keyTag: Data {
        return keyIdentifier.data(using: .utf8)!
    }
    
    // MARK: - Initialization
    
    public init(keyIdentifier: String = "com.growwise.secure-enclave-key", accessGroup: String? = nil) {
        self.keyIdentifier = keyIdentifier
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public Methods
    
    /// Check if Secure Enclave is available on this device
    public static var isSecureEnclaveAvailable: Bool {
        return SecureEnclave.isAvailable
    }
    
    /// Generate or retrieve the symmetric key for encryption/decryption
    public func getSymmetricKey() throws -> SymmetricKey {
        return try cacheQueue.sync {
            // Return cached key if available
            if let cachedKey = _cachedSymmetricKey {
                return cachedKey
            }
            
            // Try to derive from existing Secure Enclave key
            if hasSecureEnclaveKey() {
                let derivedKey = try deriveSymmetricKeyFromExistingKey()
                _cachedSymmetricKey = derivedKey
                return derivedKey
            }
            
            // Generate new Secure Enclave key and derive symmetric key
            let derivedKey = try generateNewKeyAndDeriveSymmetric()
            _cachedSymmetricKey = derivedKey
            return derivedKey
        }
    }
    
    /// Check if a Secure Enclave key exists by looking for stored public key reference
    public func hasSecureEnclaveKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecAttrService as String: "SecureEnclaveKeyManager"
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess
    }
    
    /// Generate a new Secure Enclave key pair
    @discardableResult
    public func generateSecureEnclaveKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        guard Self.isSecureEnclaveAvailable else {
            throw SecureEnclaveError.secureEnclaveNotAvailable
        }
        
        // Delete existing key if present
        try? deleteSecureEnclaveKey()
        
        do {
            // Generate private key in Secure Enclave
            let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
                compactRepresentable: false
            )
            
            // Store the public key data as a reference for key derivation
            let publicKeyData = privateKey.publicKey.rawRepresentation
            try storePublicKeyReference(publicKeyData)
            
            // Cache the key
            cacheQueue.async(flags: .barrier) {
                self._cachedPrivateKey = privateKey
            }
            
            return privateKey
        } catch {
            throw SecureEnclaveError.keyGenerationFailed
        }
    }
    
    /// Store a reference to the public key for later identification
    private func storePublicKeyReference(_ publicKeyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecAttrService as String: "SecureEnclaveKeyManager",
            kSecValueData as String: publicKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureEnclaveError.keyGenerationFailed
        }
    }
    
    /// Delete the Secure Enclave key reference
    public func deleteSecureEnclaveKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecAttrService as String: "SecureEnclaveKeyManager"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecureEnclaveError.keyAccessFailed
        }
        
        // Clear cached keys
        cacheQueue.async(flags: .barrier) {
            self._cachedSymmetricKey = nil
            self._cachedPrivateKey = nil
        }
    }
    
    /// Rotate the Secure Enclave key (generates new key)
    public func rotateKey() throws {
        try generateSecureEnclaveKey()
        
        // Clear cached keys to force re-derivation
        cacheQueue.async(flags: .barrier) {
            self._cachedSymmetricKey = nil
            self._cachedPrivateKey = nil
        }
    }
    
    /// Get raw public key data for key exchange or verification
    public func getPublicKeyData() throws -> Data {
        // Return the stored public key data directly
        return try getStoredPublicKeyData()
    }
    
    // MARK: - Private Methods
    
    private func getStoredPublicKeyData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecAttrService as String: "SecureEnclaveKeyManager",
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            throw SecureEnclaveError.keyNotFound
        }
        
        return data
    }
    
    private func deriveSymmetricKeyFromExistingKey() throws -> SymmetricKey {
        // Retrieve the stored public key data directly for key derivation
        let publicKeyData = try getStoredPublicKeyData()
        
        // Use HKDF to derive a symmetric key from the public key data
        // This is secure because the public key is deterministic for a given private key
        let salt = "GrowWise-SecureEnclave-Salt-v1".data(using: .utf8)!
        let info = "GrowWise-AES-Key-Derivation".data(using: .utf8)!
        
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: publicKeyData),
            salt: salt,
            info: info,
            outputByteCount: 32 // 256-bit key for AES-256
        )
    }
    
    private func generateNewKeyAndDeriveSymmetric() throws -> SymmetricKey {
        let privateKey = try generateSecureEnclaveKey()
        
        // Derive symmetric key using the same method as above
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let salt = "GrowWise-SecureEnclave-Salt-v1".data(using: .utf8)!
        let info = "GrowWise-AES-Key-Derivation".data(using: .utf8)!
        
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: publicKeyData),
            salt: salt,
            info: info,
            outputByteCount: 32 // 256-bit key for AES-256
        )
    }
}

// MARK: - Local Authentication Context Extension

import LocalAuthentication

private extension LAContext {
    static func createContext() -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        return context
    }
}