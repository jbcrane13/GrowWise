// KeychainManager Security Remediation Implementation
// This file contains secure implementations to address vulnerabilities identified in the security audit

import Foundation
import Security
import LocalAuthentication
import CryptoKit
import os.log

// MARK: - Enhanced Security Logger

private extension OSLog {
    static let security = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.growwiser.app", 
                                category: "Security")
}

// MARK: - Secure KeychainManager Implementation

@MainActor
public final class SecureKeychainManager {
    
    // MARK: - Security Configuration
    
    private struct SecurityConfig {
        static let maxPasswordLength = 4096
        static let maxKeyLength = 256
        static let maxFailedAttempts = 3
        static let lockoutDuration: TimeInterval = 300 // 5 minutes
        static let sessionTimeout: TimeInterval = 1800 // 30 minutes
        static let idleTimeout: TimeInterval = 300 // 5 minutes
        static let keyRotationDays = 90
    }
    
    // MARK: - Properties
    
    public static let shared = SecureKeychainManager()
    
    private let service: String
    private let accessGroup: String?
    private var failedAttempts = 0
    private var lockoutEndTime: Date?
    private var lastActivityTime: Date?
    private var sessionStartTime: Date?
    
    // MARK: - Enhanced Error Types
    
    public enum SecureKeychainError: LocalizedError {
        case invalidInput(String)
        case validationFailed(String)
        case encryptionFailed
        case decryptionFailed
        case rateLimitExceeded
        case sessionExpired
        case lockout(TimeInterval)
        case operationFailed // Generic error for production
        
        public var errorDescription: String? {
            #if DEBUG
            switch self {
            case .invalidInput(let detail):
                return "Invalid input: \(detail)"
            case .validationFailed(let detail):
                return "Validation failed: \(detail)"
            case .encryptionFailed:
                return "Encryption operation failed"
            case .decryptionFailed:
                return "Decryption operation failed"
            case .rateLimitExceeded:
                return "Too many attempts. Please try again later"
            case .sessionExpired:
                return "Session expired. Please authenticate again"
            case .lockout(let remaining):
                return "Account locked for \(Int(remaining)) seconds"
            case .operationFailed:
                return "Operation failed"
            }
            #else
            // Generic message in production
            return "Security operation failed. Please try again."
            #endif
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        self.service = Bundle.main.bundleIdentifier ?? "com.growwiser.app"
        self.accessGroup = nil // Set for app groups if needed
        setupSecurityMonitoring()
    }
    
    // MARK: - Input Validation
    
    private func validateInput(_ input: String, maxLength: Int, pattern: String? = nil) throws {
        // Length validation
        guard !input.isEmpty, input.count <= maxLength else {
            throw SecureKeychainError.invalidInput("Invalid length")
        }
        
        // Pattern validation if provided
        if let pattern = pattern {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: input.utf16.count)
            guard regex.firstMatch(in: input, options: [], range: range) != nil else {
                throw SecureKeychainError.validationFailed("Format validation failed")
            }
        }
        
        // SQL injection prevention
        let dangerousPatterns = [
            "';", "--", "/*", "*/", "xp_", "sp_", "exec", "execute",
            "drop", "alter", "union", "select", "insert", "update", "delete"
        ]
        
        let lowercased = input.lowercased()
        for pattern in dangerousPatterns {
            if lowercased.contains(pattern) {
                throw SecureKeychainError.invalidInput("Potentially dangerous input detected")
            }
        }
    }
    
    private func sanitizeKey(_ key: String) throws -> String {
        try validateInput(key, maxLength: SecurityConfig.maxKeyLength, 
                         pattern: "^[a-zA-Z0-9_-]+$")
        return key
    }
    
    // MARK: - Encryption Layer
    
    private func encryptData(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            var encryptedData = Data()
            encryptedData.append(sealedBox.nonce.withUnsafeBytes { Data($0) })
            encryptedData.append(sealedBox.ciphertext)
            encryptedData.append(sealedBox.tag)
            
            return encryptedData
        } catch {
            logSecurityEvent(.encryptionFailed)
            throw SecureKeychainError.encryptionFailed
        }
    }
    
    private func decryptData(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        guard encryptedData.count > 28 else { // 12 (nonce) + 16 (tag) minimum
            throw SecureKeychainError.decryptionFailed
        }
        
        do {
            let nonceData = encryptedData.prefix(12)
            let tagData = encryptedData.suffix(16)
            let ciphertext = encryptedData.dropFirst(12).dropLast(16)
            
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, 
                                                  ciphertext: ciphertext, 
                                                  tag: tagData)
            
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            logSecurityEvent(.decryptionFailed)
            throw SecureKeychainError.decryptionFailed
        }
    }
    
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        let keyIdentifier = "com.growwiser.encryption.key"
        
        // Try to retrieve existing key
        if let keyData = try? retrieveRawData(for: keyIdentifier) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Store with highest protection
        try storeRawDataWithMaxProtection(keyData, for: keyIdentifier)
        
        return key
    }
    
    // MARK: - Enhanced Access Control
    
    private func createStrongAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        let flags: SecAccessControlCreateFlags = [
            .biometryCurrentSet,
            .devicePasscode,
            .or // Allow either biometry or passcode
        ]
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            flags,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                secureLog("Access control creation failed: \(error)", level: .error)
            }
            throw SecureKeychainError.operationFailed
        }
        
        return accessControl
    }
    
    // MARK: - Rate Limiting & Session Management
    
    private func checkRateLimit() throws {
        if let lockoutEnd = lockoutEndTime {
            let now = Date()
            if now < lockoutEnd {
                let remaining = lockoutEnd.timeIntervalSince(now)
                throw SecureKeychainError.lockout(remaining)
            } else {
                // Lockout expired
                lockoutEndTime = nil
                failedAttempts = 0
            }
        }
        
        if failedAttempts >= SecurityConfig.maxFailedAttempts {
            lockoutEndTime = Date().addingTimeInterval(SecurityConfig.lockoutDuration)
            logSecurityEvent(.rateLimitTriggered)
            throw SecureKeychainError.rateLimitExceeded
        }
    }
    
    private func recordFailedAttempt() {
        failedAttempts += 1
        logSecurityEvent(.authenticationFailed)
        
        if failedAttempts >= SecurityConfig.maxFailedAttempts {
            lockoutEndTime = Date().addingTimeInterval(SecurityConfig.lockoutDuration)
        }
    }
    
    private func recordSuccessfulAccess() {
        failedAttempts = 0
        lockoutEndTime = nil
        lastActivityTime = Date()
        
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        
        logSecurityEvent(.authenticationSucceeded)
    }
    
    public func checkSessionValidity() -> Bool {
        let now = Date()
        
        // Check session timeout
        if let sessionStart = sessionStartTime,
           now.timeIntervalSince(sessionStart) > SecurityConfig.sessionTimeout {
            endSession()
            return false
        }
        
        // Check idle timeout
        if let lastActivity = lastActivityTime,
           now.timeIntervalSince(lastActivity) > SecurityConfig.idleTimeout {
            endSession()
            return false
        }
        
        // Update activity time
        lastActivityTime = now
        return true
    }
    
    private func endSession() {
        sessionStartTime = nil
        lastActivityTime = nil
        logSecurityEvent(.sessionEnded)
    }
    
    // MARK: - Secure Storage Methods
    
    public func storeSecureData(_ data: Data, for key: String, requireBiometric: Bool = true) throws {
        // Validate inputs
        let sanitizedKey = try sanitizeKey(key)
        guard data.count <= SecurityConfig.maxPasswordLength else {
            throw SecureKeychainError.invalidInput("Data too large")
        }
        
        // Check rate limiting
        try checkRateLimit()
        
        // Encrypt data
        let encryptedData = try encryptData(data)
        
        if requireBiometric {
            try storeWithBiometricProtection(encryptedData, for: sanitizedKey)
        } else {
            try storeWithStandardProtection(encryptedData, for: sanitizedKey)
        }
        
        // Record successful operation
        recordSuccessfulAccess()
        
        // Store metadata
        try storeMetadata(for: sanitizedKey)
    }
    
    public func retrieveSecureData(for key: String) async throws -> Data {
        // Validate session
        guard checkSessionValidity() else {
            throw SecureKeychainError.sessionExpired
        }
        
        // Validate input
        let sanitizedKey = try sanitizeKey(key)
        
        // Check rate limiting
        try checkRateLimit()
        
        do {
            // Check if key rotation is needed
            try await checkAndRotateKeyIfNeeded(for: sanitizedKey)
            
            // Retrieve encrypted data
            let encryptedData = try await retrieveWithAuthentication(for: sanitizedKey)
            
            // Decrypt data
            let decryptedData = try decryptData(encryptedData)
            
            recordSuccessfulAccess()
            return decryptedData
            
        } catch {
            recordFailedAttempt()
            throw error
        }
    }
    
    // MARK: - Token Management (Instead of Password Storage)
    
    public struct AuthToken: Codable {
        let token: String
        let userId: String
        let createdAt: Date
        let expiresAt: Date
        let deviceId: String
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    public func storeAuthToken(_ token: String, userId: String, expiresIn: TimeInterval = 3600) throws {
        let authToken = AuthToken(
            token: token,
            userId: userId,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expiresIn),
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
        
        let encoder = JSONEncoder()
        let tokenData = try encoder.encode(authToken)
        
        try storeSecureData(tokenData, for: "auth_token_\(userId)", requireBiometric: true)
        
        logSecurityEvent(.tokenStored)
    }
    
    public func retrieveAuthToken(for userId: String) async throws -> AuthToken {
        let tokenData = try await retrieveSecureData(for: "auth_token_\(userId)")
        
        let decoder = JSONDecoder()
        let authToken = try decoder.decode(AuthToken.self, from: tokenData)
        
        // Check expiration
        guard !authToken.isExpired else {
            try deleteSecureData(for: "auth_token_\(userId)")
            throw SecureKeychainError.sessionExpired
        }
        
        return authToken
    }
    
    // MARK: - API Key Management
    
    public struct APIKeyData: Codable {
        let key: String
        let service: String
        let createdAt: Date
        let lastUsed: Date
        let version: Int
    }
    
    public func storeAPIKey(_ apiKey: String, for service: String) throws {
        // Validate API key format (example: base64 encoded, minimum length)
        let apiKeyPattern = "^[A-Za-z0-9+/]{32,}={0,2}$"
        try validateInput(apiKey, maxLength: 256, pattern: apiKeyPattern)
        
        // Validate service name
        try validateInput(service, maxLength: 64, pattern: "^[a-zA-Z0-9_-]+$")
        
        let keyData = APIKeyData(
            key: apiKey,
            service: service,
            createdAt: Date(),
            lastUsed: Date(),
            version: 1
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(keyData)
        
        try storeSecureData(data, for: "api_key_\(service)", requireBiometric: false)
        
        logSecurityEvent(.apiKeyStored)
    }
    
    // MARK: - Key Rotation
    
    private struct KeyMetadata: Codable {
        let createdAt: Date
        let version: Int
        let lastRotated: Date?
    }
    
    private func storeMetadata(for key: String) throws {
        let metadata = KeyMetadata(
            createdAt: Date(),
            version: 1,
            lastRotated: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        
        try storeRawData(data, for: "\(key)_metadata")
    }
    
    private func checkAndRotateKeyIfNeeded(for key: String) async throws {
        guard let metadataData = try? retrieveRawData(for: "\(key)_metadata") else {
            return // No metadata, possibly new key
        }
        
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(KeyMetadata.self, from: metadataData)
        
        let daysSinceCreation = Date().timeIntervalSince(metadata.createdAt) / 86400
        
        if daysSinceCreation > Double(SecurityConfig.keyRotationDays) {
            logSecurityEvent(.keyRotationRequired)
            // Implement key rotation logic here
        }
    }
    
    // MARK: - Security Logging
    
    private enum SecurityEventType {
        case authenticationSucceeded
        case authenticationFailed
        case rateLimitTriggered
        case sessionEnded
        case tokenStored
        case apiKeyStored
        case keyRotationRequired
        case encryptionFailed
        case decryptionFailed
        case suspiciousActivity
    }
    
    private func logSecurityEvent(_ event: SecurityEventType) {
        #if DEBUG
        let eventDescription: String
        switch event {
        case .authenticationSucceeded:
            eventDescription = "Authentication succeeded"
        case .authenticationFailed:
            eventDescription = "Authentication failed"
        case .rateLimitTriggered:
            eventDescription = "Rate limit triggered"
        case .sessionEnded:
            eventDescription = "Session ended"
        case .tokenStored:
            eventDescription = "Auth token stored"
        case .apiKeyStored:
            eventDescription = "API key stored"
        case .keyRotationRequired:
            eventDescription = "Key rotation required"
        case .encryptionFailed:
            eventDescription = "Encryption failed"
        case .decryptionFailed:
            eventDescription = "Decryption failed"
        case .suspiciousActivity:
            eventDescription = "Suspicious activity detected"
        }
        
        os_log("%{public}@", log: .security, type: .info, eventDescription)
        #endif
        
        // In production, send to secure logging service
        // Analytics.logSecurityEvent(event)
    }
    
    private func secureLog(_ message: String, level: OSLogType = .info) {
        #if DEBUG
        os_log("%{public}@", log: .security, type: level, message)
        #endif
    }
    
    // MARK: - Low-Level Keychain Operations
    
    private func storeRawData(_ data: Data, for key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeychainError.operationFailed
        }
    }
    
    private func storeRawDataWithMaxProtection(_ data: Data, for key: String) throws {
        let accessControl = try createStrongAccessControl()
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeychainError.operationFailed
        }
    }
    
    private func retrieveRawData(for key: String) throws -> Data {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data else {
            throw SecureKeychainError.operationFailed
        }
        
        return data
    }
    
    private func storeWithBiometricProtection(_ data: Data, for key: String) throws {
        let accessControl = try createStrongAccessControl()
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometric_\(key)",
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeychainError.operationFailed
        }
    }
    
    private func storeWithStandardProtection(_ data: Data, for key: String) throws {
        try storeRawData(data, for: key)
    }
    
    private func retrieveWithAuthentication(for key: String) async throws -> Data {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.touchIDAuthenticationAllowableReuseDuration = 10
        
        let reason = "Authenticate to access secure data"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            guard success else {
                throw SecureKeychainError.operationFailed
            }
            
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
            
            guard status == errSecSuccess,
                  let data = item as? Data else {
                // Try standard protection fallback
                return try retrieveRawData(for: key)
            }
            
            return data
            
        } catch {
            throw SecureKeychainError.operationFailed
        }
    }
    
    public func deleteSecureData(for key: String) throws {
        let sanitizedKey = try sanitizeKey(key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sanitizedKey
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureKeychainError.operationFailed
        }
        
        // Also delete biometric version
        query[kSecAttrAccount as String] = "biometric_\(sanitizedKey)"
        SecItemDelete(query as CFDictionary)
        
        // Delete metadata
        query[kSecAttrAccount as String] = "\(sanitizedKey)_metadata"
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Security Monitoring
    
    private func setupSecurityMonitoring() {
        // Monitor for jailbreak
        checkForJailbreak()
        
        // Monitor for debugging
        checkForDebugger()
        
        // Setup app lifecycle monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func checkForJailbreak() {
        #if !targetEnvironment(simulator)
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                logSecurityEvent(.suspiciousActivity)
                // Take appropriate action
                break
            }
        }
        #endif
    }
    
    private func checkForDebugger() {
        #if !DEBUG
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        if result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0 {
            logSecurityEvent(.suspiciousActivity)
            // App is being debugged in production
        }
        #endif
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Clear sensitive data from memory
        endSession()
        
        // Optionally logout for high security
        // clearAllSensitiveData()
    }
    
    // MARK: - Emergency Controls
    
    public func emergencyWipe() {
        do {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            
            SecItemDelete(query as CFDictionary)
            
            logSecurityEvent(.suspiciousActivity)
            
            // Notify server of wipe if possible
            // notifyServerOfEmergencyWipe()
            
        } catch {
            // Even if error, attempt to clear what we can
        }
    }
}

// MARK: - Usage Examples

/*
// Store auth token (never store passwords!)
let tokenManager = SecureKeychainManager.shared
try tokenManager.storeAuthToken("jwt_token_here", userId: "user123", expiresIn: 3600)

// Retrieve auth token
let token = try await tokenManager.retrieveAuthToken(for: "user123")

// Store API key
try tokenManager.storeAPIKey("sk-1234567890abcdef", for: "openai")

// Store secure data
let sensitiveData = "sensitive".data(using: .utf8)!
try tokenManager.storeSecureData(sensitiveData, for: "my_secure_key")

// Retrieve secure data
let retrievedData = try await tokenManager.retrieveSecureData(for: "my_secure_key")
*/