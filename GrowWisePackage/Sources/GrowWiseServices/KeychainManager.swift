import Foundation
import Security
import LocalAuthentication
import CryptoKit
import GrowWiseModels

/// KeychainManager provides secure storage for sensitive data
/// This replaces UserDefaults for storing API keys, tokens, and user credentials
/// Now enhanced with biometric protection support
/// Refactored as a coordinator using service composition
public final class KeychainManager: KeychainStorageProtocol {
    
    // MARK: - Singleton
    
    public static let shared = KeychainManager()
    
    // MARK: - Services
    
    private let storageService: KeychainStorageService
    private let encryptionService: EncryptionService
    private let tokenService: TokenManagementService
    private let dataTransformationService: DataTransformationService
    
    // MARK: - Properties
    
    private let service = "com.growwiser.app"
    private let accessGroup: String? = nil // Can be set for app groups
    private var biometricAuth: BiometricAuthenticationProtocol?
    
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
        case serviceError(Error)
        
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
            case .serviceError(let error):
                return "Service error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Initialize services
        self.storageService = KeychainStorageService(service: service, accessGroup: accessGroup)
        self.encryptionService = EncryptionService(storage: storageService)
        self.tokenService = TokenManagementService(encryptionService: encryptionService, storage: storageService)
        self.dataTransformationService = DataTransformationService(storage: storageService, encryptionService: encryptionService)
        
        // Register self with dependency container after initialization
        Task {
            await MainActor.run {
                AuthenticationDependencyContainer.shared.setKeychainStorage(self)
            }
        }
    }
    
    // MARK: - Dependency Injection
    
    /// Set the biometric authentication provider
    public func setBiometricAuthentication(_ auth: BiometricAuthenticationProtocol) {
        self.biometricAuth = auth
    }
    
    // MARK: - Public Methods - KeychainStorageProtocol Implementation
    
    /// Store data securely in the keychain
    public func store(_ data: Data, for key: String) throws {
        do {
            try storageService.store(data, for: key)
        } catch {
            throw mapStorageError(error)
        }
    }
    
    /// Store a string securely in the keychain
    public func storeString(_ string: String, for key: String) throws {
        do {
            try dataTransformationService.storeString(string, for: key)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Store a boolean securely in the keychain
    public func storeBool(_ value: Bool, for key: String) throws {
        do {
            try dataTransformationService.storeBool(value, for: key)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Retrieve data from the keychain
    public func retrieve(for key: String) throws -> Data {
        do {
            return try storageService.retrieve(for: key)
        } catch {
            throw mapStorageError(error)
        }
    }
    
    /// Retrieve a string from the keychain
    public func retrieveString(for key: String) throws -> String {
        do {
            return try dataTransformationService.retrieveString(for: key)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Retrieve a boolean from the keychain
    public func retrieveBool(for key: String) throws -> Bool {
        do {
            return try dataTransformationService.retrieveBool(for: key)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Delete an item from the keychain
    public func delete(for key: String) throws {
        do {
            try storageService.delete(for: key)
        } catch {
            throw mapStorageError(error)
        }
    }
    
    /// Delete all items for this app from the keychain
    public func deleteAll() throws {
        do {
            try storageService.deleteAll()
        } catch {
            throw mapStorageError(error)
        }
    }
    
    /// Check if a key exists in the keychain
    public func exists(for key: String) -> Bool {
        return storageService.exists(for: key)
    }
    
    // MARK: - Private Methods - Error Mapping
    
    /// Map storage service errors to KeychainError
    private func mapStorageError(_ error: Error) -> KeychainError {
        if let storageError = error as? KeychainStorageService.StorageError {
            switch storageError {
            case .duplicateEntry:
                return .duplicateEntry
            case .itemNotFound:
                return .itemNotFound
            case .invalidData:
                return .invalidData
            case .unexpectedPasswordData:
                return .unexpectedPasswordData
            case .invalidKey(let reason):
                return .invalidKey(reason)
            case .unknown(let status):
                return .unknown(status)
            case .unhandledError(let status):
                return .unhandledError(status: status)
            }
        }
        return .serviceError(error)
    }
    
    /// Map general service errors to KeychainError
    private func mapServiceError(_ error: Error) -> KeychainError {
        if let transformationError = error as? DataTransformationService.TransformationError {
            switch transformationError {
            case .invalidData:
                return .invalidData
            case .encodingFailed, .decodingFailed, .serializationFailed:
                return .serviceError(transformationError)
            }
        } else if let tokenError = error as? TokenManagementService.TokenError {
            switch tokenError {
            case .tokenExpired:
                return .tokenExpired
            case .invalidTokenFormat:
                return .invalidData
            case .invalidSignature:
                return .invalidData
            case .invalidIssuer:
                return .invalidData
            case .invalidAudience:
                return .invalidData
            case .notYetValid:
                return .invalidData
            case .unsupportedAlgorithm:
                return .invalidData
            case .encryptionFailed:
                return .encryptionFailed
            case .decryptionFailed:
                return .decryptionFailed
            case .storageError(let underlyingError):
                return mapServiceError(underlyingError)
            }
        }
        return .serviceError(error)
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
        
        // Use data transformation service for migration
        dataTransformationService.migrateFromUserDefaults(keys: keysToMigrate)
        
        // Clean up any legacy password data
        migrateLegacyPasswordData()
    }
    
    /// Migrate and remove legacy password data
    private func migrateLegacyPasswordData() {
        let legacyPasswordKeys = [
            "user_credentials",
            "user_password",
            "password",
            "credentials",
            "user_auth",
            "login_credentials"
        ]
        
        // Use data transformation service to cleanup legacy data
        dataTransformationService.cleanupLegacyData(keys: legacyPasswordKeys)
        
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
        do {
            try tokenService.storeSecureCredentials(credentials)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Retrieve secure JWT credentials with decryption
    public func retrieveSecureCredentials() throws -> SecureCredentials {
        do {
            return try tokenService.retrieveSecureCredentials()
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Store only the access token (for quick access without full credentials)
    public func storeAccessToken(_ token: String) throws {
        do {
            try tokenService.storeAccessToken(token)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Retrieve the access token
    public func retrieveAccessToken() throws -> String {
        do {
            return try tokenService.retrieveAccessToken()
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Update tokens after refresh
    public func updateTokensAfterRefresh(response: TokenRefreshResponse) throws {
        do {
            try tokenService.updateTokensAfterRefresh(response: response)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Check if credentials need refresh
    public func credentialsNeedRefresh() -> Bool {
        return tokenService.credentialsNeedRefresh()
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
        // Use token service to clear tokens
        tokenService.clearAllTokens()

        // Clear additional sensitive keys
        let additionalSensitiveKeys = [
            "api_key_weather",
            "api_key_plant_database",
            // Biometric protected keys
            "biometric_secure_jwt_credentials_v2",
            "biometric_encrypted_access_token_v2"
        ]

        for key in additionalSensitiveKeys {
            try? delete(for: key)
        }
    }
    
    /// Retrieve secure credentials with biometric protection
    public func retrieveSecureCredentialsWithBiometric(reason: String = "Authenticate to access your account") async throws -> SecureCredentials {
        // Read the JSON-encoded credentials that were stored with biometric protection
        let encryptedData = try await retrieveWithBiometricProtection(
            for: "biometric_secure_jwt_credentials_v2",
            reason: reason
        )

        // Decode into SecureCredentials. We intentionally avoid any custom crypto here
        // because the Keychain item itself is protected by the device's Secure Enclave.
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(SecureCredentials.self, from: encryptedData)
        return credentials
    }
    /// Store data with biometric protection (Face ID / Touch ID)
    public func storeWithBiometricProtection(_ data: Data, for key: String) throws {
        // Validate key to prevent injection
        try validateKey(key)

        let account = "biometric_\(key)"

        // Create access control requiring the current biometric set on this device
        var acError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &acError
        ) else {
            let err = (acError?.takeRetainedValue()) as Error?
            throw err.map { KeychainError.serviceError($0) } ?? KeychainError.unknown(errSecParam)
        }

        // Try to add (create if missing)
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        if let accessGroup = accessGroup {
            addQuery[kSecAttrAccessGroup as String] = accessGroup
        }

        var status = SecItemAdd(addQuery as CFDictionary, nil)

        // If the item already exists, update its value
        if status == errSecDuplicateItem {
            var matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            if let accessGroup = accessGroup {
                matchQuery[kSecAttrAccessGroup as String] = accessGroup
            }
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            status = SecItemUpdate(matchQuery as CFDictionary, attributesToUpdate as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    /// Validate keys used to address Keychain records
    private func validateKey(_ key: String) throws {
        guard !key.isEmpty else { throw KeychainError.invalidKey("empty") }
        guard key.count <= 128 else { throw KeychainError.invalidKey("too long") }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")
        if key.rangeOfCharacter(from: allowed.inverted) != nil {
            throw KeychainError.invalidKey("contains illegal characters")
        }
    }
    
    /// Retrieve data with biometric protection
    public func retrieveWithBiometricProtection(for key: String, reason: String = "Authenticate to access secure data") async throws -> Data {
        // Validate key to prevent injection
        try validateKey(key)
        
        // Create authentication context with localized reason
        let context = LAContext()
        context.localizedReason = reason
        
        // Build query with authentication context - keychain will handle biometric auth atomically
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
            switch status {
            case errSecItemNotFound:
                throw KeychainError.itemNotFound
            case errSecAuthFailed:
                // Authentication failed
                throw KeychainError.unknown(status)
            default:
                throw KeychainError.unknown(status)
            }
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
        do {
            try dataTransformationService.storeCodable(object, for: key)
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Retrieve Codable object from Keychain
    public func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        do {
            return try dataTransformationService.retrieveCodable(type, for: key)
        } catch {
            throw mapServiceError(error)
        }
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
