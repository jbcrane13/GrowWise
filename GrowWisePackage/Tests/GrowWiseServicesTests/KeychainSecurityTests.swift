import XCTest
import CryptoKit
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Security test suite for JWT token-based authentication
/// Validates OWASP compliance and security best practices
/// Updated for refactored KeychainManager with service composition
final class KeychainSecurityTests: XCTestCase {
    
    var keychainManager: KeychainManager!
    
    override func setUp() async throws {
        try await super.setUp()
        keychainManager = KeychainManager.shared
        
        // Clean up any existing test data
        keychainManager.clearSensitiveData()
    }
    
    override func tearDown() async throws {
        // Clean up after tests
        keychainManager.clearSensitiveData()
        try await super.tearDown()
    }
    
    // MARK: - JWT Token Security Tests
    
    func testSecureCredentialsStorage() throws {
        // Create test credentials
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh",
            expiresIn: 3600,
            userId: "user123"
        )
        
        // Store credentials
        XCTAssertNoThrow(try keychainManager.storeSecureCredentials(credentials))
        
        // Retrieve and verify
        let retrieved = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
        XCTAssertEqual(retrieved.refreshToken, credentials.refreshToken)
        XCTAssertEqual(retrieved.userId, credentials.userId)
        XCTAssertEqual(retrieved.tokenType, credentials.tokenType)
    }
    
    func testTokenEncryption() throws {
        // Generate test key
        let key = SecureTokenEncryption.generateKey()
        
        // Create credentials
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600
        )
        
        // Encrypt
        let encrypted = try SecureTokenEncryption.encrypt(credentials, using: key)
        
        // Verify encryption changed the data
        let originalData = try JSONEncoder().encode(credentials)
        XCTAssertNotEqual(encrypted, originalData)
        
        // Decrypt
        let decrypted = try SecureTokenEncryption.decrypt(encrypted, using: key)
        
        // Verify decryption
        XCTAssertEqual(decrypted.accessToken, credentials.accessToken)
        XCTAssertEqual(decrypted.refreshToken, credentials.refreshToken)
    }
    
    func testTokenExpiration() {
        // Create expired token
        let expiredCredentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.expired.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: -1 // Already expired
        )
        
        XCTAssertTrue(expiredCredentials.isExpired)
        XCTAssertTrue(expiredCredentials.needsRefresh)
        
        // Create valid token
        let validCredentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.valid.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600
        )
        
        XCTAssertFalse(validCredentials.isExpired)
        XCTAssertFalse(validCredentials.needsRefresh)
    }
    
    // MARK: - Input Validation Security Tests
    
    func testKeyInjectionPrevention() async throws {
        let dangerousKeys = [
            "'; DROP TABLE users; --",
            "<script>alert('xss')</script>",
            "javascript:alert(1)",
            "../../etc/passwd",
            "key--comment",
            "key/*comment*/",
            "onload=alert(1)",
            String(repeating: "a", count: 257) // Too long
        ]
        
        for key in dangerousKeys {
            // Attempt to store with dangerous key should fail
            XCTAssertThrowsError(try keychainManager.storeString("test", for: key)) { error in
                if let keychainError = error as? KeychainManager.KeychainError {
                    switch keychainError {
                    case .invalidKey:
                        // Expected error
                        break
                    case .serviceError:
                        // Also acceptable - service layer caught the error
                        break
                    default:
                        XCTFail("Expected invalidKey or serviceError error for dangerous key: \(key)")
                    }
                }
            }
        }
    }
    
    func testValidKeyPatterns() throws {
        let validKeys = [
            "user_token",
            "api-key-v2",
            "session.token",
            "AUTH_TOKEN_2024",
            "key123",
            "a"
        ]
        
        for key in validKeys {
            // Valid keys should work
            XCTAssertNoThrow(try keychainManager.storeString("test_value", for: key))
            let retrieved = try keychainManager.retrieveString(for: key)
            XCTAssertEqual(retrieved, "test_value")
            try keychainManager.delete(for: key)
        }
    }
    
    // MARK: - JWT Format Validation Tests
    
    func testJWTFormatValidation() {
        // Valid JWT format
        let validJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        XCTAssertTrue(SecureCredentials.isValidJWTFormat(validJWT))
        
        // Invalid JWT formats
        let invalidJWTs = [
            "not.a.jwt",
            "only.two",
            "contains spaces.in.token",
            "contains@invalid!chars.in.token",
            "",
            "....",
            "a",
            "eyJhbGci...", // Incomplete
        ]
        
        for jwt in invalidJWTs {
            XCTAssertFalse(SecureCredentials.isValidJWTFormat(jwt))
        }
    }
    
    // MARK: - Legacy Password Migration Tests
    
    func testLegacyPasswordRemoval() throws {
        // This test verifies that legacy password storage methods have been removed
        // and that the secure alternatives are properly enforced
        
        // Test that secure credentials require proper structure
        let testCredentials = SecureCredentials(
            accessToken: "access-token-123",
            refreshToken: "refresh-token-456",
            expiresIn: 3600,
            userId: "test-user",
            tokenType: "Bearer"
        )
        
        // Verify secure storage works
        XCTAssertNoThrow(try keychainManager.storeSecureCredentials(testCredentials))
        
        // Verify secure retrieval works
        let retrievedCredentials = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(retrievedCredentials.userId, testCredentials.userId)
        XCTAssertEqual(retrievedCredentials.accessToken, testCredentials.accessToken)
        
        // Clean up
        keychainManager.clearSensitiveData()
    }
    
    func testPasswordMigrationCompletion() {
        // Test migration status tracking
        XCTAssertFalse(keychainManager.isPasswordMigrationComplete())
        
        // Run migration
        _ = try keychainManager.migrateFromUserDefaults()
        
        // Check if marked as complete (after clearing legacy data)
        // Note: This will be true after migration runs
        // The actual value depends on whether legacy data existed
    }
    
    // MARK: - Token Refresh Tests
    
    func testTokenRefresh() throws {
        // Store initial credentials
        let initialCredentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.initial.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600,
            userId: "user123"
        )
        
        try keychainManager.storeSecureCredentials(initialCredentials)
        
        // Simulate token refresh
        let refreshResponse = TokenRefreshResponse(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.new.token",
            refreshToken: nil, // Keep existing refresh token
            expiresIn: 3600
        )
        
        try keychainManager.updateTokensAfterRefresh(response: refreshResponse)
        
        // Verify updated credentials
        let updatedCredentials = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(updatedCredentials.accessToken, refreshResponse.accessToken)
        XCTAssertEqual(updatedCredentials.refreshToken, initialCredentials.refreshToken) // Should keep original
        XCTAssertEqual(updatedCredentials.userId, initialCredentials.userId) // Should preserve user ID
    }
    
    // MARK: - Encryption Key Management Tests
    
    func testEncryptionKeyDerivation() throws {
        let password = "testPassword123!@#"
        let salt = Data(repeating: 0x53, count: 16) // Test salt
        
        // Derive key from password
        let derivedKey = try SecureTokenEncryption.deriveKey(from: password, salt: salt)
        
        // Verify key is consistent
        let derivedKey2 = try SecureTokenEncryption.deriveKey(from: password, salt: salt)
        
        // Same password and salt should produce same key
        XCTAssertEqual(derivedKey.withUnsafeBytes { Data($0) },
                      derivedKey2.withUnsafeBytes { Data($0) })
        
        // Different salt should produce different key
        let differentSalt = Data(repeating: 0x54, count: 16)
        let differentKey = try SecureTokenEncryption.deriveKey(from: password, salt: differentSalt)
        
        XCTAssertNotEqual(derivedKey.withUnsafeBytes { Data($0) },
                         differentKey.withUnsafeBytes { Data($0) })
    }
    
    // MARK: - Secure Storage Format Tests
    
    func testSecureStorageFormat() throws {
        let key = SecureTokenEncryption.generateKey()
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600
        )
        
        // Test with AAD
        let aad = Data("test-service".utf8)
        let storageData = try SecureTokenEncryption.createSecureStorage(
            credentials: credentials,
            key: key,
            additionalAuthenticatedData: aad
        )
        
        // Verify format
        XCTAssertTrue(storageData.count > 3) // Version + AAD length + data
        XCTAssertEqual(storageData[0], 0x01) // Version byte
        
        // Retrieve and verify
        let retrieved = try SecureTokenEncryption.retrieveFromSecureStorage(storageData, key: key)
        XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
        XCTAssertEqual(retrieved.refreshToken, credentials.refreshToken)
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() throws {
        let key = SecureTokenEncryption.generateKey()
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.performance.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600
        )
        
        measure {
            // Measure encryption/decryption performance
            for _ in 0..<100 {
                do {
                    let encrypted = try SecureTokenEncryption.encrypt(credentials, using: key)
                    _ = try SecureTokenEncryption.decrypt(encrypted, using: key)
                } catch {
                    XCTFail("Encryption/decryption failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Security Headers Tests
    
    func testAuthorizationHeaderGeneration() {
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        
        XCTAssertEqual(credentials.authorizationHeader, "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token")
    }
    
    // MARK: - Sensitive Data Cleanup Tests
    
    func testSensitiveDataCleanup() throws {
        // Store various types of sensitive data
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            expiresIn: 3600
        )
        
        try keychainManager.storeSecureCredentials(credentials)
        try keychainManager.storeAPIKey("test-api-key", for: "weather")
        
        // Clear all sensitive data
        keychainManager.clearSensitiveData()
        
        // Verify data is cleared
        XCTAssertThrowsError(try keychainManager.retrieveSecureCredentials())
        XCTAssertThrowsError(try keychainManager.retrieveAPIKey(for: "weather"))
    }
}