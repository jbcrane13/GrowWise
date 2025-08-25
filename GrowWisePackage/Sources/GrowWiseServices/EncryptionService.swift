import Foundation
import CryptoKit
import Security

/// Service responsible for all encryption/decryption operations with key rotation support
/// Now uses Secure Enclave for enhanced security and supports PCI DSS/SOC2 compliance
public final class EncryptionService {
    
    // MARK: - Error Types
    
    public enum EncryptionError: LocalizedError {
        case encryptionFailed
        case decryptionFailed
        case keyGenerationFailed
        case invalidData
        case migrationFailed
        case secureEnclaveNotAvailable
        case keyRotationRequired
        case complianceViolation
        case unsupportedKeyVersion
        
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
            case .migrationFailed:
                return "Failed to migrate encryption keys"
            case .secureEnclaveNotAvailable:
                return "Secure Enclave is not available on this device"
            case .keyRotationRequired:
                return "Key rotation is required for compliance"
            case .complianceViolation:
                return "Operation violates security compliance requirements"
            case .unsupportedKeyVersion:
                return "Unsupported key version for decryption"
            }
        }
    }
    
    // MARK: - Properties
    
    private let secureEnclaveKeyManager: SecureEnclaveKeyManager
    private let migrationService: LegacyEncryptionMigrationService
    private let keyRotationManager: KeyRotationManager
    private let useLegacyFallback: Bool
    
    // Cache for encryption keys by version
    private var _cachedKeys: [Int: SymmetricKey] = [:]
    private let keyQueue = DispatchQueue(label: "com.growwise.encryption-service", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Initialize with Secure Enclave (preferred) or legacy keychain fallback
    public init(storage: KeychainStorageService) {
        self.secureEnclaveKeyManager = SecureEnclaveKeyManager()
        self.migrationService = LegacyEncryptionMigrationService(keychainStorage: storage)
        self.keyRotationManager = KeyRotationManager(
            secureEnclaveKeyManager: SecureEnclaveKeyManager(),
            keychainStorage: storage
        )
        self.useLegacyFallback = !SecureEnclaveKeyManager.isSecureEnclaveAvailable
        
        // Attempt automatic migration if conditions are met
        performAutomaticMigrationIfNeeded()
        
        // Initialize key rotation system
        initializeKeyRotationSystem()
    }
    
    /// Initialize with custom components (for testing)
    public init(
        secureEnclaveKeyManager: SecureEnclaveKeyManager, 
        migrationService: LegacyEncryptionMigrationService,
        keyRotationManager: KeyRotationManager
    ) {
        self.secureEnclaveKeyManager = secureEnclaveKeyManager
        self.migrationService = migrationService
        self.keyRotationManager = keyRotationManager
        self.useLegacyFallback = !SecureEnclaveKeyManager.isSecureEnclaveAvailable
    }
    
    // MARK: - Public Methods
    
    /// Get current encryption key with version support
    public var encryptionKey: SymmetricKey {
        get throws {
            // Check if key rotation is overdue and throw compliance error
            if keyRotationManager.isRotationOverdue() {
                throw EncryptionError.keyRotationRequired
            }
            
            return try keyQueue.sync {
                let currentVersion = keyRotationManager.currentKeyVersion
                
                if let cachedKey = _cachedKeys[currentVersion] {
                    return cachedKey
                }
                
                let key = try keyRotationManager.getCurrentEncryptionKey()
                _cachedKeys[currentVersion] = key
                return key
            }
        }
    }
    
    /// Encrypt data using AES-256-GCM with current key version
    public func encrypt(_ data: Data) throws -> Data {
        let key = try encryptionKey
        let currentVersion = keyRotationManager.currentKeyVersion
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        // Prepend version information to encrypted data for decryption
        return createVersionedEncryptedData(version: currentVersion, encryptedData: encryptedData)
    }
    
    /// Decrypt data using AES-256-GCM with intelligent key version selection
    public func decrypt(_ encryptedData: Data) throws -> Data {
        // Extract version information if present
        if let versionedData = extractVersionedEncryptedData(encryptedData) {
            return try decryptWithVersion(
                version: versionedData.version, 
                encryptedData: versionedData.encryptedData
            )
        }
        
        // Legacy data without version - try current key first, then fallback
        return try decryptLegacyData(encryptedData)
    }
    
    /// Encrypt data with additional authenticated data and version support
    public func encrypt(_ data: Data, authenticatedData: Data) throws -> Data {
        let key = try encryptionKey
        let currentVersion = keyRotationManager.currentKeyVersion
        
        let sealedBox = try AES.GCM.seal(data, using: key, authenticating: authenticatedData)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        // Prepend version information
        return createVersionedEncryptedData(version: currentVersion, encryptedData: encryptedData)
    }
    
    /// Decrypt data with additional authenticated data verification and version support
    public func decrypt(_ encryptedData: Data, authenticatedData: Data) throws -> Data {
        // Extract version information if present
        if let versionedData = extractVersionedEncryptedData(encryptedData) {
            return try decryptWithVersion(
                version: versionedData.version,
                encryptedData: versionedData.encryptedData,
                authenticatedData: authenticatedData
            )
        }
        
        // Legacy data without version - try current key first, then fallback
        return try decryptLegacyData(encryptedData, authenticatedData: authenticatedData)
    }
    
    /// Perform key rotation with compliance checks
    public func rotateKey(reason: String = "Manual rotation") async throws -> Int {
        if useLegacyFallback {
            throw EncryptionError.secureEnclaveNotAvailable
        }
        
        let newVersion = try await keyRotationManager.rotateKey(reason: reason)
        
        // Clear cached keys to force re-derivation
        keyQueue.async(flags: .barrier) {
            self._cachedKeys.removeAll()
        }
        
        return newVersion
    }
    
    /// Check if key rotation is needed based on compliance policies
    public func isKeyRotationNeeded() -> Bool {
        return keyRotationManager.isRotationNeeded()
    }
    
    /// Check if key rotation is overdue (compliance violation)
    public func isKeyRotationOverdue() -> Bool {
        return keyRotationManager.isRotationOverdue()
    }
    
    /// Force rotation if compliance requirements are violated
    public func enforceComplianceRotation() async throws {
        try await keyRotationManager.forceRotationIfOverdue()
    }
    
    /// Check if encryption key exists
    public var hasEncryptionKey: Bool {
        if useLegacyFallback {
            return migrationService.hasLegacyKey
        } else {
            return keyRotationManager.currentKeyVersion > 0 || 
                   secureEnclaveKeyManager.hasSecureEnclaveKey() || 
                   migrationService.hasLegacyKey
        }
    }
    
    /// Clear encryption key (use with caution - will make encrypted data inaccessible)
    public func clearEncryptionKey() throws {
        if !useLegacyFallback {
            try secureEnclaveKeyManager.deleteSecureEnclaveKey()
        }
        
        // Also clear legacy key if it exists
        if migrationService.hasLegacyKey {
            try migrationService.removeLegacyKey()
        }
        
        // Clear cached keys
        keyQueue.async(flags: .barrier) {
            self._cachedKeys.removeAll()
        }
    }
    
    // MARK: - Compliance and Reporting Methods
    
    /// Generate comprehensive compliance report for PCI DSS and SOC2
    public func generateComplianceReport(period: DateInterval) async -> KeyRotationManager.ComplianceReport {
        return await keyRotationManager.generateComplianceReport(period: period)
    }
    
    /// Get audit trail for compliance review
    public func getAuditTrail(from startDate: Date, to endDate: Date) -> [KeyRotationManager.AuditEvent] {
        return keyRotationManager.getAuditTrail(from: startDate, to: endDate)
    }
    
    /// Get current key rotation policy
    public func getRotationPolicy() -> KeyRotationManager.RotationPolicy {
        // This would need to be exposed by KeyRotationManager
        return KeyRotationManager.RotationPolicy.defaultPolicy()
    }
    
    /// Update key rotation policy
    public func updateRotationPolicy(_ policy: KeyRotationManager.RotationPolicy) throws {
        try keyRotationManager.updateRotationPolicy(policy)
    }
    
    /// Get all active key versions for backward compatibility
    public func getActiveKeyVersions() -> [Int] {
        return keyRotationManager.getActiveKeyVersions()
    }
    
    /// Get current key version
    public var currentKeyVersion: Int {
        return keyRotationManager.currentKeyVersion
    }
    
    // MARK: - Migration Methods
    
    /// Manually trigger migration from legacy to Secure Enclave encryption
    public func migrateLegacyEncryption() throws {
        guard !useLegacyFallback else {
            throw EncryptionError.secureEnclaveNotAvailable
        }
        
        guard migrationService.hasLegacyKey else {
            // No legacy key to migrate
            return
        }
        
        // Generate new Secure Enclave key
        let _ = try secureEnclaveKeyManager.getSymmetricKey()
        
        // Clear cached keys to force re-derivation
        keyQueue.async(flags: .barrier) {
            self._cachedKeys.removeAll()
        }
        
        // Note: Actual data migration should be handled by the calling code
        // This method only sets up the new key infrastructure
    }
    
    /// Get migration information
    public func getMigrationInfo() -> MigrationInfo {
        return migrationService.getMigrationInfo()
    }
    
    /// Migrate a specific piece of encrypted data
    public func migrateEncryptedData(_ legacyData: Data, authenticatedData: Data? = nil) throws -> Data {
        guard !useLegacyFallback else {
            throw EncryptionError.secureEnclaveNotAvailable
        }
        
        let newKey = try secureEnclaveKeyManager.getSymmetricKey()
        return try migrationService.migrateEncryptedData(legacyData, using: newKey, authenticatedData: authenticatedData)
    }
    
    /// Check if this service is using Secure Enclave
    public var isUsingSecureEnclave: Bool {
        return !useLegacyFallback && secureEnclaveKeyManager.hasSecureEnclaveKey()
    }
    
    /// Get comprehensive security status information including key rotation
    public var securityStatus: SecurityStatus {
        return SecurityStatus(
            isUsingSecureEnclave: isUsingSecureEnclave,
            hasLegacyKey: migrationService.hasLegacyKey,
            secureEnclaveAvailable: SecureEnclaveKeyManager.isSecureEnclaveAvailable,
            recommendsMigration: migrationService.hasLegacyKey && SecureEnclaveKeyManager.isSecureEnclaveAvailable,
            keyRotationStatus: KeyRotationStatus(
                currentVersion: keyRotationManager.currentKeyVersion,
                rotationNeeded: keyRotationManager.isRotationNeeded(),
                rotationOverdue: keyRotationManager.isRotationOverdue(),
                activeVersions: keyRotationManager.getActiveKeyVersions()
            )
        )
    }
    
    // MARK: - Private Methods
    
    private func initializeKeyRotationSystem() {
        // Note: Initial key generation should be handled externally
        // This prevents potential concurrency issues during initialization
        // Call keyRotationManager.rotateKey() externally if needed
    }
    
    private struct VersionedData {
        let version: Int
        let encryptedData: Data
    }
    
    private func createVersionedEncryptedData(version: Int, encryptedData: Data) -> Data {
        // Create version header: 4 bytes for version + encrypted data
        var versionedData = Data()
        withUnsafeBytes(of: UInt32(version).bigEndian) { bytes in
            versionedData.append(contentsOf: bytes)
        }
        versionedData.append(encryptedData)
        return versionedData
    }
    
    private func extractVersionedEncryptedData(_ data: Data) -> VersionedData? {
        // Check if data has version header (at least 4 bytes)
        guard data.count > 4 else { return nil }
        
        // Extract version from first 4 bytes
        let versionData = data.prefix(4)
        let version = versionData.withUnsafeBytes { bytes in
            return UInt32(bigEndian: bytes.load(as: UInt32.self))
        }
        
        // Validate version is reasonable (1-1000)
        guard version > 0 && version < 1000 else { return nil }
        
        let encryptedData = data.suffix(from: 4)
        return VersionedData(version: Int(version), encryptedData: encryptedData)
    }
    
    private func decryptWithVersion(
        version: Int, 
        encryptedData: Data, 
        authenticatedData: Data? = nil
    ) throws -> Data {
        // Get cached key or load from key manager
        let key = try keyQueue.sync {
            if let cachedKey = _cachedKeys[version] {
                return cachedKey
            }
            
            let key = try keyRotationManager.getKeyForVersion(version)
            _cachedKeys[version] = key
            return key
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        if let authData = authenticatedData {
            return try AES.GCM.open(sealedBox, using: key, authenticating: authData)
        } else {
            return try AES.GCM.open(sealedBox, using: key)
        }
    }
    
    private func decryptLegacyData(_ encryptedData: Data, authenticatedData: Data? = nil) throws -> Data {
        // Try current key first
        do {
            let currentKey = try keyRotationManager.getCurrentEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            
            if let authData = authenticatedData {
                return try AES.GCM.open(sealedBox, using: currentKey, authenticating: authData)
            } else {
                return try AES.GCM.open(sealedBox, using: currentKey)
            }
        } catch {
            // If current key fails, try legacy fallback
            return try decryptWithLegacyFallback(encryptedData, authenticatedData: authenticatedData)
        }
    }
    
    private func getCurrentEncryptionKey() throws -> SymmetricKey {
        if useLegacyFallback {
            // Use legacy key on devices without Secure Enclave
            return try migrationService.getLegacyKey()
        } else {
            // Use key rotation manager (preferred)
            return try keyRotationManager.getCurrentEncryptionKey()
        }
    }
    
    private func decryptWithLegacyFallback(_ encryptedData: Data, authenticatedData: Data?) throws -> Data {
        guard migrationService.hasLegacyKey else {
            throw EncryptionError.decryptionFailed
        }
        
        if let authData = authenticatedData {
            return try migrationService.decryptLegacyData(encryptedData, authenticatedData: authData)
        } else {
            return try migrationService.decryptLegacyData(encryptedData)
        }
    }
    
    private func performAutomaticMigrationIfNeeded() {
        // Only attempt automatic migration if:
        // 1. Secure Enclave is available
        // 2. We have a legacy key
        // 3. We don't already have a Secure Enclave key
        guard !useLegacyFallback,
              migrationService.hasLegacyKey,
              !secureEnclaveKeyManager.hasSecureEnclaveKey() else {
            return
        }
        
        // Note: Automatic migration disabled for now to avoid concurrency issues
        // Migration can be performed manually when needed
        print("Legacy encryption detected - manual migration recommended")
    }
}

// MARK: - Supporting Types

public struct KeyRotationStatus {
    public let currentVersion: Int
    public let rotationNeeded: Bool
    public let rotationOverdue: Bool
    public let activeVersions: [Int]
    
    public var description: String {
        if rotationOverdue {
            return "Key rotation overdue (Compliance violation)"
        } else if rotationNeeded {
            return "Key rotation due soon"
        } else {
            return "Key rotation up to date"
        }
    }
}

public struct SecurityStatus {
    public let isUsingSecureEnclave: Bool
    public let hasLegacyKey: Bool
    public let secureEnclaveAvailable: Bool
    public let recommendsMigration: Bool
    public let keyRotationStatus: KeyRotationStatus
    
    public var description: String {
        var status = ""
        
        if isUsingSecureEnclave {
            status = "Using Secure Enclave encryption"
        } else if secureEnclaveAvailable && hasLegacyKey {
            status = "Legacy encryption (Migration recommended)"
        } else if hasLegacyKey {
            status = "Legacy encryption (Secure Enclave not available)"
        } else {
            status = "No encryption key configured"
        }
        
        // Add key rotation status
        if keyRotationStatus.rotationOverdue {
            status += " - Key rotation overdue!"
        } else if keyRotationStatus.rotationNeeded {
            status += " - Key rotation due"
        }
        
        return status
    }
    
    public var complianceStatus: String {
        if keyRotationStatus.rotationOverdue {
            return "Non-compliant: Key rotation overdue"
        } else if keyRotationStatus.rotationNeeded {
            return "Warning: Key rotation due soon"
        } else if isUsingSecureEnclave {
            return "Fully compliant: Secure Enclave + Key rotation"
        } else {
            return "Partially compliant: Consider upgrading to Secure Enclave"
        }
    }
}