import Foundation
import Security
import LocalAuthentication
import CryptoKit

/// KeychainManager provides secure storage for sensitive data
/// This replaces UserDefaults for storing API keys, tokens, and user credentials
/// Now enhanced with biometric protection support
@MainActor
public final class KeychainManager: KeychainStorageProtocol {
    
    // MARK: - Singleton
    
    public static let shared = KeychainManager()
    
    // MARK: - Properties
    
    private let service = "com.growwiser.app"
    private let accessGroup: String? = nil // Can be set for app groups
    private var biometricAuth: BiometricAuthenticationProtocol?
    
    // Encryption key for secure token storage
    private lazy var encryptionKey: SymmetricKey = {
        // Try to retrieve existing key or generate new one
        if let keyData = try? retrieve(for: "_encryption_key_v2") {
            return SymmetricKey(data: keyData)
        } else {
            let newKey = SecureTokenEncryption.generateKey()
            // Store the key securely (this is metadata, not sensitive data)
            try? store(newKey.withUnsafeBytes { Data($0) }, for: "_encryption_key_v2")
            return newKey
        }
    }()
    
    // Key validation regex patterns
    private let keyValidationPattern = "^[a-zA-Z0-9_.-]+$"
    private let maxKeyLength = 256
    
    // MARK: - Error Types
    
    public enum KeychainError: LocalizedError {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
        case invalidData
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        case invalidKey(String)
        case tokenExpired
        case encryptionFailed
        case decryptionFailed
        case insecureOperation
        
        public var errorDescription: String? {
            switch self {
            case .duplicateEntry:
                return "Item already exists in keychain"
            case .unknown(let status):
                return "Unknown keychain error: \(status)"
            case .itemNotFound:
                return "Item not found in keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedPasswordData:
                return "Unexpected password data format"
            case .unhandledError(let status):
                return "Unhandled keychain error: \(status)"
            case .invalidKey(let reason):
                return "Invalid key: \(reason)"
            case .tokenExpired:
                return "Authentication token has expired"
            case .encryptionFailed:
                return "Failed to encrypt sensitive data"
            case .decryptionFailed:
                return "Failed to decrypt sensitive data"
            case .insecureOperation:
                return "Operation not allowed: insecure method deprecated"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Register self with dependency container after initialization
        Task { @MainActor in
            AuthenticationDependencyContainer.shared.setKeychainStorage(self)
        }
    }
    
    // MARK: - Dependency Injection
    
    /// Set the biometric authentication provider
    public func setBiometricAuthentication(_ auth: BiometricAuthenticationProtocol) {
        self.biometricAuth = auth
    }
    
    // MARK: - Public Methods
    
    /// Store data securely in the keychain
    public func store(_ data: Data, for key: String) throws {
        // Validate key to prevent injection
        try validateKey(key)
        
        let query = createQuery(for: key)
        
        // Check if item exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status == errSecItemNotFound {
            // Add new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            guard addStatus == errSecSuccess else {
                if addStatus == errSecDuplicateItem {
                    throw KeychainError.duplicateEntry
                }
                throw KeychainError.unknown(addStatus)
            }
        } else {
            throw KeychainError.unknown(status)
        }
    }
    
    /// Store a string securely in the keychain
    public func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try store(data, for: key)
    }
    
    /// Store a boolean securely in the keychain
    public func storeBool(_ value: Bool, for key: String) throws {
        let data = Data([value ? 1 : 0])
        try store(data, for: key)
    }
    
    /// Retrieve data from the keychain
    public func retrieve(for key: String) throws -> Data {
        // Validate key to prevent injection
        try validateKey(key)
        
        var query = createQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = item as? Data else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return data
    }
    
    /// Retrieve a string from the keychain
    public func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    /// Retrieve a boolean from the keychain
    public func retrieveBool(for key: String) throws -> Bool {
        let data = try retrieve(for: key)
        guard let byte = data.first else {
            throw KeychainError.invalidData
        }
        return byte != 0
    }
    
    /// Delete an item from the keychain
    public func delete(for key: String) throws {
        // Validate key to prevent injection
        try validateKey(key)
        
        let query = createQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    /// Delete all items for this app from the keychain
    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    /// Check if a key exists in the keychain
    public func exists(for key: String) -> Bool {
        // Validate key - return false if invalid
        guard (try? validateKey(key)) != nil else { return false }
        
        let query = createQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Methods
    
    /// Validate key to prevent injection attacks
    private func validateKey(_ key: String) throws {
        // Check key length
        guard key.count > 0 && key.count <= maxKeyLength else {
            throw KeychainError.invalidKey("Key length must be between 1 and \(maxKeyLength) characters")
        }
        
        // Check for valid characters only
        let regex = try NSRegularExpression(pattern: keyValidationPattern, options: [])
        let range = NSRange(location: 0, length: key.count)
        
        guard regex.firstMatch(in: key, options: [], range: range) != nil else {
            throw KeychainError.invalidKey("Key contains invalid characters. Only alphanumeric, underscore, hyphen, and period allowed.")
        }
        
        // Check for common injection patterns
        let dangerousPatterns = ["--", "/*", "*/", "<script", "javascript:", "data:", "vbscript:", "onload=", "onerror="]
        for pattern in dangerousPatterns {
            if key.lowercased().contains(pattern) {
                throw KeychainError.invalidKey("Key contains potentially dangerous pattern")
            }
        }
    }
    
    private func createQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    // MARK: - Migration from UserDefaults
    
    /// Migrate sensitive data from UserDefaults to Keychain
    public func migrateFromUserDefaults() {
        let keysToMigrate = [
            "userGardeningGoals",
            "userPlantInterests",
            "userPreferredNotificationTime",
            "hasCompletedOnboarding",
            "default_notification_time",
            "enable_watering_reminders",
            "enable_fertilizing_reminders",
            "enable_pest_control_reminders",
            "enable_weather_adjustments",
            "quiet_hours_start",
            "quiet_hours_end"
        ]
        
        for key in keysToMigrate {
            // Check if already migrated
            if exists(for: key) {
                continue
            }
            
            // Get value from UserDefaults
            if let data = UserDefaults.standard.data(forKey: key) {
                do {
                    try store(data, for: key)
                    // Remove from UserDefaults after successful migration
                    UserDefaults.standard.removeObject(forKey: key)
                    #if DEBUG
                    print("Migrated \(key) to Keychain")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to migrate \(key) to Keychain: \(error)")
                    #endif
                }
            } else if let string = UserDefaults.standard.string(forKey: key) {
                do {
                    try storeString(string, for: key)
                    UserDefaults.standard.removeObject(forKey: key)
                    #if DEBUG
                    print("Migrated \(key) to Keychain")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to migrate \(key) to Keychain: \(error)")
                    #endif
                }
            } else if UserDefaults.standard.object(forKey: key) != nil {
                // Handle boolean and other types
                let value = UserDefaults.standard.bool(forKey: key)
                do {
                    try storeBool(value, for: key)
                    UserDefaults.standard.removeObject(forKey: key)
                    #if DEBUG
                    print("Migrated \(key) to Keychain")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to migrate \(key) to Keychain: \(error)")
                    #endif
                }
            }
        }
        
        // Clean up any legacy password data
        migrateLegacyPasswordData()
    }
    
    /// Migrate and remove legacy password data
    private func migrateLegacyPasswordData() {
        // SECURITY: Remove any legacy password storage
        // This method ensures no passwords remain in the keychain
        
        let legacyPasswordKeys = [
            "user_credentials",
            "user_password",
            "password",
            "credentials",
            "user_auth",
            "login_credentials"
        ]
        
        for key in legacyPasswordKeys {
            if exists(for: key) {
                // Log that we're removing legacy data (no sensitive info in logs)
                #if DEBUG
                print("[Security Migration] Removing legacy credential storage for key: \(key)")
                #endif
                
                // Delete the insecure data
                try? delete(for: key)
            }
        }
        
        // Mark migration as complete
        try? storeBool(true, for: "_password_migration_complete_v2")
    }
    
    /// Check if password migration has been completed
    public func isPasswordMigrationComplete() -> Bool {
        return (try? retrieveBool(for: "_password_migration_complete_v2")) ?? false
    }
    
    // MARK: - Convenience Methods for Common Keys
    
    /// Store API key securely
    public func storeAPIKey(_ apiKey: String, for service: String) throws {
        try storeString(apiKey, for: "api_key_\(service)")
    }
    
    /// Retrieve API key
    public func retrieveAPIKey(for service: String) throws -> String {
        try retrieveString(for: "api_key_\(service)")
    }
    
    // MARK: - Secure JWT Token Management
    
    /// Store secure JWT credentials with encryption
    public func storeSecureCredentials(_ credentials: SecureCredentials) throws {
        // Validate token format
        guard SecureCredentials.isValidJWTFormat(credentials.accessToken) else {
            throw KeychainError.invalidData
        }
        
        if !credentials.refreshToken.isEmpty {
            guard SecureCredentials.isValidJWTFormat(credentials.refreshToken) else {
                throw KeychainError.invalidData
            }
        }
        
        // Encrypt credentials using AES-256-GCM
        let encryptedData = try SecureTokenEncryption.createSecureStorage(
            credentials: credentials,
            key: encryptionKey,
            additionalAuthenticatedData: Data(service.utf8)
        )
        
        // Store encrypted data
        try store(encryptedData, for: "secure_jwt_credentials_v2")
        
        // Store token metadata separately (non-sensitive)
        let metadata = [
            "issuedAt": credentials.issuedAt.timeIntervalSince1970,
            "expiresAt": credentials.expiresAt.timeIntervalSince1970,
            "tokenType": credentials.tokenType
        ]
        
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            try? store(metadataData, for: "jwt_metadata_v2")
        }
    }
    
    /// Retrieve secure JWT credentials with decryption
    public func retrieveSecureCredentials() throws -> SecureCredentials {
        let encryptedData = try retrieve(for: "secure_jwt_credentials_v2")
        
        // Decrypt credentials
        let credentials = try SecureTokenEncryption.retrieveFromSecureStorage(
            encryptedData,
            key: encryptionKey
        )
        
        // Check if token is expired
        if credentials.isExpired {
            throw KeychainError.tokenExpired
        }
        
        return credentials
    }
    
    /// Store only the access token (for quick access without full credentials)
    public func storeAccessToken(_ token: String) throws {
        // Validate JWT format
        guard SecureCredentials.isValidJWTFormat(token) else {
            throw KeychainError.invalidData
        }
        
        // Encrypt the token
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let encryptedToken = try AES.GCM.seal(tokenData, using: encryptionKey)
        guard let encryptedData = encryptedToken.combined else {
            throw KeychainError.encryptionFailed
        }
        
        try store(encryptedData, for: "encrypted_access_token_v2")
    }
    
    /// Retrieve the access token
    public func retrieveAccessToken() throws -> String {
        let encryptedData = try retrieve(for: "encrypted_access_token_v2")
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        
        guard let token = String(data: decryptedData, encoding: .utf8) else {
            throw KeychainError.decryptionFailed
        }
        
        return token
    }
    
    /// Update tokens after refresh
    public func updateTokensAfterRefresh(response: TokenRefreshResponse) throws {
        // Retrieve existing credentials to preserve metadata
        if let existingCredentials = try? retrieveSecureCredentials() {
            let updatedCredentials = SecureCredentials(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? existingCredentials.refreshToken,
                expiresIn: response.expiresIn,
                userId: existingCredentials.userId,
                tokenType: response.tokenType
            )
            
            try storeSecureCredentials(updatedCredentials)
        } else {
            // Create new credentials if none exist
            let newCredentials = SecureCredentials(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? "",
                expiresIn: response.expiresIn,
                tokenType: response.tokenType
            )
            
            try storeSecureCredentials(newCredentials)
        }
    }
    
    /// Check if credentials need refresh
    public func credentialsNeedRefresh() -> Bool {
        guard let credentials = try? retrieveSecureCredentials() else {
            return true
        }
        return credentials.needsRefresh
    }
    
    /// DEPRECATED: These methods are no longer supported for security reasons
    @available(*, deprecated, message: "Use storeSecureCredentials instead. Direct password storage is insecure.")
    public func storeUserCredentials(email: String, password: String) throws {
        throw KeychainError.insecureOperation
    }
    
    @available(*, deprecated, message: "Use retrieveSecureCredentials instead. Direct password retrieval is insecure.")
    public func retrieveUserCredentials() throws -> (email: String, password: String) {
        throw KeychainError.insecureOperation
    }
    
    /// Store authentication token (legacy support - internally uses secure storage)
    public func storeAuthToken(_ token: String) throws {
        // Validate and store as access token
        try storeAccessToken(token)
    }
    
    /// Retrieve authentication token (legacy support)
    public func retrieveAuthToken() throws -> String {
        // Try to get from secure credentials first
        if let credentials = try? retrieveSecureCredentials() {
            return credentials.accessToken
        }
        // Fall back to encrypted access token
        return try retrieveAccessToken()
    }
    
    /// Clear all sensitive data (useful for logout)
    public func clearSensitiveData() {
        let sensitiveKeys = [
            "secure_jwt_credentials_v2",
            "encrypted_access_token_v2",
            "jwt_metadata_v2",
            "auth_token", // Legacy
            "user_credentials", // Legacy - should be removed
            "api_key_weather",
            "api_key_plant_database",
            // Biometric protected keys
            "biometric_secure_jwt_credentials_v2",
            "biometric_encrypted_access_token_v2"
        ]
        
        for key in sensitiveKeys {
            try? delete(for: key)
        }
        
        // Clear any legacy password data if it exists
        clearLegacyPasswordData()
    }
    
    /// Clear legacy password data (for migration)
    private func clearLegacyPasswordData() {
        // Remove any legacy credential storage
        try? delete(for: "user_credentials")
        try? delete(for: "user_password")
        try? delete(for: "credentials")
        
        // Log security event (without sensitive data)
        #if DEBUG
        print("[Security] Legacy password data cleared")
        #endif
    }
    
    // MARK: - Biometric Protection Methods
    
    /// Store data with biometric protection
    public func storeWithBiometricProtection(_ data: Data, for key: String) throws {
        // Validate key to prevent injection
        try validateKey(key)
        
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometric_\(key)",
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl as Any
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new item with biometric protection
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateEntry
            }
            throw KeychainError.unknown(status)
        }
    }
    
    /// Store string with biometric protection
    public func storeStringWithBiometricProtection(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try storeWithBiometricProtection(data, for: key)
    }
    
    /// Store secure credentials with biometric protection
    public func storeSecureCredentialsWithBiometric(_ credentials: SecureCredentials) throws {
        // Validate tokens
        guard SecureCredentials.isValidJWTFormat(credentials.accessToken) else {
            throw KeychainError.invalidData
        }
        
        if !credentials.refreshToken.isEmpty {
            guard SecureCredentials.isValidJWTFormat(credentials.refreshToken) else {
                throw KeychainError.invalidData
            }
        }
        
        // Encrypt credentials
        let encryptedData = try SecureTokenEncryption.createSecureStorage(
            credentials: credentials,
            key: encryptionKey,
            additionalAuthenticatedData: Data(service.utf8)
        )
        
        // Store with biometric protection
        try storeWithBiometricProtection(encryptedData, for: "secure_jwt_credentials_v2")
    }
    
    /// Retrieve secure credentials with biometric protection
    public func retrieveSecureCredentialsWithBiometric(reason: String = "Authenticate to access your account") async throws -> SecureCredentials {
        let encryptedData = try await retrieveWithBiometricProtection(
            for: "secure_jwt_credentials_v2",
            reason: reason
        )
        
        // Decrypt credentials
        let credentials = try SecureTokenEncryption.retrieveFromSecureStorage(
            encryptedData,
            key: encryptionKey
        )
        
        // Check if token is expired
        if credentials.isExpired {
            throw KeychainError.tokenExpired
        }
        
        return credentials
    }
    
    /// Retrieve data with biometric protection
    public func retrieveWithBiometricProtection(for key: String, reason: String = "Authenticate to access secure data") async throws -> Data {
        // Validate key to prevent injection
        try validateKey(key)
        
        // Create authentication context
        let context = LAContext()
        
        // Authenticate first
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        
        guard success else {
            throw KeychainError.unknown(-1)
        }
        
        // Retrieve data
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometric_\(key)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = item as? Data else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return data
    }
    
    /// Retrieve string with biometric protection
    public func retrieveStringWithBiometricProtection(for key: String, reason: String = "Authenticate to access secure data") async throws -> String {
        let data = try await retrieveWithBiometricProtection(for: key, reason: reason)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    /// Check if biometric protection is available
    public var isBiometricProtectionAvailable: Bool {
        biometricAuth?.canUseBiometrics ?? false
    }
    
    /// Get biometric type available
    public var biometricType: LABiometryType {
        biometricAuth?.biometricType ?? .none
    }
}

// MARK: - Extensions

extension KeychainManager {
    
    /// Store Codable object in Keychain
    public func storeCodable<T: Codable>(_ object: T, for key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try store(data, for: key)
    }
    
    /// Retrieve Codable object from Keychain
    public func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        let data = try retrieve(for: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    /// Store Codable object with biometric protection
    public func storeCodableWithBiometricProtection<T: Codable>(_ object: T, for key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try storeWithBiometricProtection(data, for: key)
    }
    
    /// Retrieve Codable object with biometric protection
    public func retrieveCodableWithBiometricProtection<T: Codable>(_ type: T.Type, for key: String, reason: String = "Authenticate to access secure data") async throws -> T {
        let data = try await retrieveWithBiometricProtection(for: key, reason: reason)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}