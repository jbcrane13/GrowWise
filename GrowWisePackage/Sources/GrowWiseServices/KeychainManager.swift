import Foundation
import Security
import LocalAuthentication
import CryptoKit
import GrowWiseModels

/// KeychainManager provides secure storage for sensitive data
/// This replaces UserDefaults for storing API keys, tokens, and user credentials
/// Now enhanced with biometric protection support
/// Refactored as a coordinator using service composition
/// 
/// Thread Safety: This class is thread-safe and can be accessed from any queue.
/// All keychain operations are inherently thread-safe as they use the system keychain APIs.
/// Internal synchronization is handled by the underlying services.
/// The @unchecked Sendable conformance is safe because:
/// 1. All keychain operations use thread-safe system APIs
/// 2. The biometricAuth property is only set during initialization
/// 3. All service dependencies are immutable after initialization
public final class KeychainManager: KeychainStorageProtocol, @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = KeychainManager()
    
    // MARK: - Services
    
    private let storageService: KeychainStorageService
    private let encryptionService: EncryptionService
    private let tokenService: TokenManagementService
    private let dataTransformationService: DataTransformationService
    private let migrationIntegrityService: MigrationIntegrityService
    
    // MARK: - Properties
    
    private let service = "com.growwiser.app"
    private let accessGroup: String? = nil // Can be set for app groups
    
    /// Biometric authentication provider (thread-safe due to property isolation)
    private var biometricAuth: BiometricAuthenticationProtocol?
    
    /// Rate limiter for authentication attempts
    private lazy var rateLimiter: RateLimiter = {
        RateLimiterFactory.create(with: self)
    }()
    
    /// Audit logger for compliance logging
    private let auditLogger: AuditLogger = AuditLogger.shared
    
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
        case serviceError(Error)
        case rateLimitExceeded(retryAfter: TimeInterval)
        case accountLocked(unlockAt: Date)
        case operationFailed
        
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
            case .serviceError(let error):
                return "Service error: \(error.localizedDescription)"
            case .rateLimitExceeded(let retryAfter):
                return "Too many authentication attempts. Try again in \(Int(retryAfter)) seconds."
            case .accountLocked(let unlockAt):
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Account locked due to repeated failed attempts. Try again after \(formatter.string(from: unlockAt))."
            case .operationFailed:
                return "Keychain operation failed"
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
        self.migrationIntegrityService = MigrationIntegrityService(keychainStorage: storageService)
        
        // Register self with dependency container synchronously
        // This is safe because we're initializing the shared singleton
        // and the dependency container is designed to handle this registration
        DispatchQueue.main.async {
            AuthenticationDependencyContainer.shared.setKeychainStorage(self)
        }
    }
    
    // MARK: - Dependency Injection
    
    /// Set the biometric authentication provider
    /// - Parameter auth: The biometric authentication provider to use
    /// - Note: This method should be called on the main queue during app initialization
    ///   to avoid potential race conditions with concurrent access
    public func setBiometricAuthentication(_ auth: BiometricAuthenticationProtocol) {
        self.biometricAuth = auth
    }
    
    // MARK: - Public Methods - KeychainStorageProtocol Implementation
    
    /// Store data securely in the keychain
    public func store(_ data: Data, for key: String) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try storageService.store(data, for: key)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log successful storage
            auditLogger.logCredentialOperation(
                type: .credentialCreation,
                userId: getCurrentUserId(),
                result: .success,
                credentialType: "keychain_data",
                operation: "store",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "data_size": "\(data.count)",
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log failed storage
            auditLogger.logCredentialOperation(
                type: .credentialCreation,
                userId: getCurrentUserId(),
                result: .failure,
                credentialType: "keychain_data",
                operation: "store",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "error_type": String(describing: type(of: error)),
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
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
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let data = try storageService.retrieve(for: key)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log successful retrieval
            auditLogger.logCredentialOperation(
                type: .credentialAccess,
                userId: getCurrentUserId(),
                result: .success,
                credentialType: "keychain_data",
                operation: "retrieve",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "data_size": "\(data.count)",
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
            
            return data
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log failed retrieval
            auditLogger.logCredentialOperation(
                type: .credentialAccess,
                userId: getCurrentUserId(),
                result: .failure,
                credentialType: "keychain_data",
                operation: "retrieve",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "error_type": String(describing: type(of: error)),
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
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
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try storageService.delete(for: key)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log successful deletion
            auditLogger.logCredentialOperation(
                type: .credentialDeletion,
                userId: getCurrentUserId(),
                result: .success,
                credentialType: "keychain_data",
                operation: "delete",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log failed deletion
            auditLogger.logCredentialOperation(
                type: .credentialDeletion,
                userId: getCurrentUserId(),
                result: .failure,
                credentialType: "keychain_data",
                operation: "delete",
                details: [
                    "key_identifier": sanitizeKeyForLogging(key),
                    "error_type": String(describing: type(of: error)),
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
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
            case .checksumMismatch(_, _):
                return .operationFailed
            case .migrationVerificationFailed(_):
                return .operationFailed
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
    
    /// Map rate limiter errors to KeychainError
    private func mapRateLimiterError(_ error: RateLimiter.RateLimiterError) -> KeychainError {
        switch error {
        case .rateLimitExceeded(let retryAfter):
            return .rateLimitExceeded(retryAfter: retryAfter)
        case .accountLocked(let unlockAt):
            return .accountLocked(unlockAt: unlockAt)
        case .storageError(let underlyingError):
            return .serviceError(underlyingError)
        case .invalidKey(let reason):
            return .invalidKey(reason)
        case .configurationError(let reason):
            return .serviceError(NSError(domain: "RateLimiterConfiguration", code: -1, userInfo: [NSLocalizedDescriptionKey: reason]))
        }
    }
    
    // MARK: - Migration from UserDefaults with Data Integrity
    
    /// Migrate sensitive data from UserDefaults to Keychain with comprehensive integrity checks
    public func migrateFromUserDefaults(dryRun: Bool = false) throws -> MigrationIntegrityService.MigrationReport {
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
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: getCurrentUserId(),
            result: .success,
            threatLevel: .low,
            description: "Starting UserDefaults to Keychain migration with integrity checks",
            details: [
                "keys_count": "\(keysToMigrate.count)",
                "dry_run": dryRun ? "true" : "false"
            ]
        )
        
        // Perform secure migration with integrity checks
        let report = try migrationIntegrityService.performSecureMigration(
            keys: keysToMigrate,
            dryRun: dryRun
        )
        
        // Only migrate legacy password data if main migration succeeded and not a dry run
        if !dryRun && report.status == .completed {
            try migrateLegacyPasswordData()
        }
        
        return report
    }
    
    /// Migrate and remove legacy password data with verification
    private func migrateLegacyPasswordData() throws {
        let legacyPasswordKeys = [
            "user_credentials",
            "user_password",
            "password", 
            "credentials",
            "user_auth",
            "login_credentials"
        ]
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: getCurrentUserId(),
            result: .success,
            threatLevel: .medium,
            description: "Starting legacy password data migration",
            details: ["keys_count": "\(legacyPasswordKeys.count)"]
        )
        
        // Use data transformation service to cleanup legacy data
        dataTransformationService.cleanupLegacyData(keys: legacyPasswordKeys)
        
        // Verify cleanup was successful
        for key in legacyPasswordKeys {
            if storageService.exists(for: key) {
                auditLogger.logSecurityEvent(
                    type: .securityViolation,
                    userId: getCurrentUserId(),
                    result: .failure,
                    threatLevel: .high,
                    description: "Legacy password data cleanup failed",
                    details: ["failed_key": key]
                )
                throw KeychainError.serviceError(NSError(
                    domain: "MigrationError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to cleanup legacy password data for key: \(key)"]
                ))
            }
        }
        
        // Mark migration as complete only after verification
        try storeBool(true, for: "_password_migration_complete_v3")
        
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: getCurrentUserId(),
            result: .success,
            threatLevel: .low,
            description: "Legacy password data migration completed successfully",
            details: ["verification": "passed"]
        )
    }
    
    /// Check if password migration has been completed
    public func isPasswordMigrationComplete() -> Bool {
        // Check for the new version marker first
        if let completed = try? retrieveBool(for: "_password_migration_complete_v3") {
            return completed
        }
        
        // Fall back to legacy marker for backward compatibility
        return (try? retrieveBool(for: "_password_migration_complete_v2")) ?? false
    }
    
    /// Perform dry run migration to test the process
    public func performDryRunMigration() throws -> MigrationIntegrityService.MigrationReport {
        return try migrateFromUserDefaults(dryRun: true)
    }
    
    /// Resume a partial migration
    public func resumeMigration(sessionId: String) throws -> MigrationIntegrityService.MigrationReport {
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: getCurrentUserId(),
            result: .success,
            threatLevel: .low,
            description: "Resuming partial migration",
            details: ["session_id": sessionId]
        )
        
        return try migrationIntegrityService.resumeMigration(sessionId: sessionId)
    }
    
    /// Rollback migration to original state
    public func rollbackMigration(sessionId: String) throws {
        auditLogger.logSecurityEvent(
            type: .configurationChange,
            userId: getCurrentUserId(),
            result: .success,
            threatLevel: .medium,
            description: "Rolling back migration",
            details: ["session_id": sessionId]
        )
        
        try migrationIntegrityService.rollbackMigration(sessionId: sessionId)
    }
    
    /// Get migration status
    public func getMigrationStatus(sessionId: String) -> MigrationIntegrityService.MigrationProgress? {
        return migrationIntegrityService.getMigrationStatus(sessionId: sessionId)
    }
    
    /// Verify data integrity for migrated keys
    public func verifyMigrationIntegrity() throws -> [MigrationIntegrityService.DataChecksum] {
        let keysToVerify = [
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
        
        return try migrationIntegrityService.verifyDataIntegrity(keys: keysToVerify)
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
    
    /// Retrieve secure JWT credentials with decryption and rate limiting
    public func retrieveSecureCredentials(for identifier: String? = nil) throws -> SecureCredentials {
        // Apply rate limiting if identifier is provided
        if let identifier = identifier {
            let result = checkAuthenticationRateLimit(for: identifier, operation: "credential_retrieval")
            switch result {
            case .allowed:
                break
            case .limited(let retryAfter, _):
                throw KeychainError.rateLimitExceeded(retryAfter: retryAfter)
            case .locked(let unlockAt, _):
                throw KeychainError.accountLocked(unlockAt: unlockAt)
            }
        }
        
        do {
            let credentials = try tokenService.retrieveSecureCredentials()
            
            // Record successful attempt if identifier provided
            if let identifier = identifier {
                try recordAuthenticationAttempt(for: identifier, successful: true, operation: "credential_retrieval")
            }
            
            return credentials
        } catch {
            // Record failed attempt if identifier provided
            if let identifier = identifier {
                try? recordAuthenticationAttempt(for: identifier, successful: false, operation: "credential_retrieval")
            }
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
    
    // MARK: - Rate Limiting Integration
    
    /// Check if authentication attempts are rate limited
    /// - Parameters:
    ///   - identifier: Unique identifier (e.g., email, device ID)
    ///   - operation: Authentication operation type
    /// - Returns: Rate limit result
    public func checkAuthenticationRateLimit(
        for identifier: String,
        operation: String = "authentication"
    ) -> RateLimiter.RateLimitResult {
        return rateLimiter.checkLimit(for: identifier, operation: operation)
    }
    
    /// Record an authentication attempt with rate limiting
    /// - Parameters:
    ///   - identifier: Unique identifier (e.g., email, device ID)
    ///   - successful: Whether the authentication attempt was successful
    ///   - operation: Authentication operation type
    /// - Throws: KeychainError if rate limited or account locked
    public func recordAuthenticationAttempt(
        for identifier: String,
        successful: Bool,
        operation: String = "authentication"
    ) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Log authentication attempt
        auditLogger.logAuthentication(
            type: successful ? .authenticationSuccess : .authenticationFailure,
            userId: identifier,
            result: successful ? .success : .failure,
            method: operation,
            details: [
                "rate_limiting_applied": "true",
                "operation_type": operation
            ]
        )
        
        do {
            try rateLimiter.recordAttempt(
                for: identifier,
                operation: operation,
                successful: successful
            )
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log rate limiting success
            auditLogger.logSecurityEvent(
                type: .configurationChange,
                userId: identifier,
                result: .success,
                threatLevel: .low,
                description: "Rate limiting applied successfully",
                details: [
                    "operation": operation,
                    "successful_auth": successful ? "true" : "false",
                    "duration_ms": String(format: "%.2f", duration * 1000)
                ]
            )
            
        } catch let error as RateLimiter.RateLimiterError {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log rate limiting events
            switch error {
            case .rateLimitExceeded(let retryAfter):
                auditLogger.logSecurityEvent(
                    type: .securityViolation,
                    userId: identifier,
                    result: .denied,
                    threatLevel: .medium,
                    description: "Authentication rate limit exceeded",
                    details: [
                        "operation": operation,
                        "retry_after": String(format: "%.0f", retryAfter),
                        "duration_ms": String(format: "%.2f", duration * 1000)
                    ]
                )
            case .accountLocked(let unlockAt):
                auditLogger.logSecurityEvent(
                    type: .accountLockout,
                    userId: identifier,
                    result: .denied,
                    threatLevel: .high,
                    description: "Account locked due to repeated failed attempts",
                    details: [
                        "operation": operation,
                        "unlock_time": unlockAt.iso8601String,
                        "duration_ms": String(format: "%.2f", duration * 1000)
                    ]
                )
            default:
                auditLogger.logSecurityEvent(
                    type: .securityViolation,
                    userId: identifier,
                    result: .failure,
                    threatLevel: .medium,
                    description: "Rate limiter error",
                    details: [
                        "operation": operation,
                        "error_type": String(describing: type(of: error)),
                        "duration_ms": String(format: "%.2f", duration * 1000)
                    ]
                )
            }
            throw mapRateLimiterError(error)
        } catch {
            // Log general error
            auditLogger.logSecurityEvent(
                type: .securityViolation,
                userId: identifier,
                result: .failure,
                threatLevel: .medium,
                description: "Authentication attempt recording failed",
                details: [
                    "operation": operation,
                    "error_type": String(describing: type(of: error))
                ]
            )
            throw KeychainError.serviceError(error)
        }
    }
    
    /// Reset rate limiting for an identifier
    /// - Parameters:
    ///   - identifier: Unique identifier
    ///   - operation: Authentication operation type
    public func resetAuthenticationRateLimit(
        for identifier: String,
        operation: String = "authentication"
    ) {
        rateLimiter.reset(for: identifier, operation: operation)
    }
    
    /// Set custom rate limiting policy for an operation
    /// - Parameters:
    ///   - policy: Rate limiting policy
    ///   - operation: Authentication operation type
    public func setRateLimitPolicy(
        _ policy: RateLimiter.Policy,
        for operation: String
    ) {
        rateLimiter.setPolicy(policy, for: operation)
    }
    
    /// Enable testing bypass for rate limiting (test environments only)
    /// - Warning: Only use in test environments
    public func enableRateLimitTestingBypass() {
        rateLimiter.enableTestingBypass()
    }
    
    /// Disable testing bypass for rate limiting
    public func disableRateLimitTestingBypass() {
        rateLimiter.disableTestingBypass()
    }
    
    /// Perform rate limiter maintenance (cleanup expired data)
    public func performRateLimitMaintenance() {
        rateLimiter.performMaintenance()
    }
    
    /// Retrieve secure credentials with biometric protection and rate limiting
    public func retrieveSecureCredentialsWithBiometric(
        for identifier: String? = nil,
        reason: String = "Authenticate to access your account"
    ) async throws -> SecureCredentials {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Log biometric authentication attempt
        auditLogger.logAuthentication(
            type: .biometricAuthentication,
            userId: identifier,
            result: .success, // Initial attempt logged as success, will update on failure
            method: "biometric_credentials",
            details: [
                "biometric_type": await getBiometricTypeString(),
                "reason": reason,
                "rate_limiting_enabled": identifier != nil ? "true" : "false"
            ]
        )
        
        // Apply rate limiting if identifier is provided
        if let identifier = identifier {
            let result = checkAuthenticationRateLimit(for: identifier, operation: "biometric_auth")
            switch result {
            case .allowed:
                break
            case .limited(let retryAfter, _):
                auditLogger.logSecurityEvent(
                    type: .securityViolation,
                    userId: identifier,
                    result: .denied,
                    threatLevel: .medium,
                    description: "Biometric authentication rate limited",
                    details: [
                        "retry_after": String(format: "%.0f", retryAfter),
                        "biometric_type": await getBiometricTypeString()
                    ]
                )
                throw KeychainError.rateLimitExceeded(retryAfter: retryAfter)
            case .locked(let unlockAt, _):
                auditLogger.logSecurityEvent(
                    type: .accountLockout,
                    userId: identifier,
                    result: .denied,
                    threatLevel: .high,
                    description: "Account locked - biometric authentication denied",
                    details: [
                        "unlock_time": unlockAt.iso8601String,
                        "biometric_type": await getBiometricTypeString()
                    ]
                )
                throw KeychainError.accountLocked(unlockAt: unlockAt)
            }
        }
        
        do {
            // Read the JSON-encoded credentials that were stored with biometric protection
            let encryptedData = try await retrieveWithBiometricProtection(
                for: "biometric_secure_jwt_credentials_v2",
                reason: reason
            )

            // Decode into SecureCredentials. We intentionally avoid any custom crypto here
            // because the Keychain item itself is protected by the device's Secure Enclave.
            let decoder = JSONDecoder()
            let credentials = try decoder.decode(SecureCredentials.self, from: encryptedData)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Record successful attempt if identifier provided
            if let identifier = identifier {
                try recordAuthenticationAttempt(for: identifier, successful: true, operation: "biometric_auth")
            }
            
            // Log successful biometric credential retrieval
            auditLogger.logCredentialOperation(
                type: .credentialAccess,
                userId: identifier,
                result: .success,
                credentialType: "jwt_credentials",
                operation: "biometric_retrieve",
                details: [
                    "biometric_type": await getBiometricTypeString(),
                    "duration_ms": String(format: "%.2f", duration * 1000),
                    "credential_type": "secure_jwt",
                    "protection_level": "biometric"
                ]
            )
            
            return credentials
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Record failed attempt if identifier provided
            if let identifier = identifier {
                try? recordAuthenticationAttempt(for: identifier, successful: false, operation: "biometric_auth")
            }
            
            // Log failed biometric authentication
            auditLogger.logAuthentication(
                type: .authenticationFailure,
                userId: identifier,
                result: .failure,
                method: "biometric_credentials",
                details: [
                    "biometric_type": await getBiometricTypeString(),
                    "error_type": String(describing: type(of: error)),
                    "duration_ms": String(format: "%.2f", duration * 1000),
                    "protection_level": "biometric"
                ]
            )
            
            throw error
        }
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
    /// - Returns: True if biometric protection is available, false otherwise
    /// - Note: This method must be called from a MainActor context
    @MainActor
    public var isBiometricProtectionAvailable: Bool {
        biometricAuth?.canUseBiometrics ?? false
    }
    
    /// Get biometric type available
    /// - Returns: The type of biometric authentication available
    /// - Note: This method must be called from a MainActor context
    @MainActor
    public var biometricType: LABiometryType {
        biometricAuth?.biometricType ?? .none
    }
    
    // MARK: - Audit Logging Utilities
    
    /// Get current user ID for audit logging
    private func getCurrentUserId() -> String? {
        // Try to get user ID from current credentials
        if let credentials = try? retrieveSecureCredentials() {
            return credentials.userId
        }
        return nil
    }
    
    /// Sanitize key names for audit logging (remove sensitive data)
    private func sanitizeKeyForLogging(_ key: String) -> String {
        // Hash sensitive keys to prevent exposure in logs
        let sensitivePatterns = [
            "password", "token", "secret", "key", "credential", 
            "jwt", "auth", "biometric", "secure"
        ]
        
        for pattern in sensitivePatterns {
            if key.lowercased().contains(pattern) {
                // Return hashed version for sensitive keys
                let hashedKey = SHA256.hash(data: Data(key.utf8))
                return "hashed_\(hashedKey.compactMap { String(format: "%02x", $0) }.joined().prefix(8))"
            }
        }
        
        return key
    }
    
    /// Get biometric type as string for audit logging
    @MainActor
    private func getBiometricTypeString() -> String {
        return biometricType.rawValue == 0 ? "none" : 
               biometricType.rawValue == 1 ? "touchid" :
               biometricType.rawValue == 2 ? "faceid" : 
               biometricType.rawValue == 4 ? "opticid" : "unknown"
    }
    
    /// Get biometric type as string (async version)
    private func getBiometricTypeString() async -> String {
        return await MainActor.run {
            getBiometricTypeString()
        }
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
