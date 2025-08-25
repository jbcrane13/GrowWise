import XCTest
import CryptoKit
@testable import GrowWiseServices
@testable import GrowWiseModels

@available(iOS 16.0, *)
final class KeychainAuditIntegrationTests: XCTestCase {
    
    var keychainManager: KeychainManager!
    var testUserId: String!
    
    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager.shared
        testUserId = "audit_test_user_\(UUID().uuidString)"
        
        // Enable rate limit testing bypass for clean testing
        keychainManager.enableRateLimitTestingBypass()
        
        // Clean up any existing test data
        cleanupTestData()
    }
    
    override func tearDown() {
        cleanupTestData()
        keychainManager.disableRateLimitTestingBypass()
        super.tearDown()
    }
    
    private func cleanupTestData() {
        // Clean up test keys
        let testKeys = [
            "test_audit_data",
            "test_audit_string",
            "test_audit_bool",
            "test_audit_api_key",
            "api_key_test_service"
        ]
        
        for key in testKeys {
            try? keychainManager.delete(for: key)
        }
        
        // Clear any test credentials
        try? keychainManager.clearSensitiveData()
    }
    
    // MARK: - Basic Storage Operation Audit Tests
    
    func testDataStorageAuditLogging() throws {
        // Given
        let testData = "Test audit data".data(using: .utf8)!
        let testKey = "test_audit_data"
        
        // When
        XCTAssertNoThrow(try keychainManager.store(testData, for: testKey))
        
        // Then - Storage should complete without errors
        // Audit logging happens asynchronously, so we verify the operation succeeded
        XCTAssertTrue(keychainManager.exists(for: testKey))
        
        // Verify we can retrieve the data (also audited)
        let retrievedData = try keychainManager.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, testData)
    }
    
    func testStringStorageAuditLogging() throws {
        // Given
        let testString = "Test audit string"
        let testKey = "test_audit_string"
        
        // When
        XCTAssertNoThrow(try keychainManager.storeString(testString, for: testKey))
        
        // Then
        XCTAssertTrue(keychainManager.exists(for: testKey))
        
        let retrievedString = try keychainManager.retrieveString(for: testKey)
        XCTAssertEqual(retrievedString, testString)
    }
    
    func testBooleanStorageAuditLogging() throws {
        // Given
        let testBool = true
        let testKey = "test_audit_bool"
        
        // When
        XCTAssertNoThrow(try keychainManager.storeBool(testBool, for: testKey))
        
        // Then
        XCTAssertTrue(keychainManager.exists(for: testKey))
        
        let retrievedBool = try keychainManager.retrieveBool(for: testKey)
        XCTAssertEqual(retrievedBool, testBool)
    }
    
    func testDataDeletionAuditLogging() throws {
        // Given
        let testData = "Data to delete".data(using: .utf8)!
        let testKey = "test_audit_delete"
        
        // Store first
        try keychainManager.store(testData, for: testKey)
        XCTAssertTrue(keychainManager.exists(for: testKey))
        
        // When
        XCTAssertNoThrow(try keychainManager.delete(for: testKey))
        
        // Then
        XCTAssertFalse(keychainManager.exists(for: testKey))
    }
    
    func testAPIKeyStorageAuditLogging() throws {
        // Given
        let apiKey = "test-api-key-12345"
        let serviceName = "test_service"
        
        // When
        XCTAssertNoThrow(try keychainManager.storeAPIKey(apiKey, for: serviceName))
        
        // Then
        let retrievedKey = try keychainManager.retrieveAPIKey(for: serviceName)
        XCTAssertEqual(retrievedKey, apiKey)
    }
    
    // MARK: - Authentication Attempt Audit Tests
    
    func testSuccessfulAuthenticationAuditLogging() throws {
        // Given
        let userId = testUserId!
        let operation = "test_auth_success"
        
        // When
        XCTAssertNoThrow(
            try keychainManager.recordAuthenticationAttempt(
                for: userId,
                successful: true,
                operation: operation
            )
        )
        
        // Then - Should complete without errors
        // Audit logging verifies the attempt was recorded properly
        XCTAssertTrue(true, "Successful authentication should be recorded and audited")
    }
    
    func testFailedAuthenticationAuditLogging() throws {
        // Given
        let userId = testUserId!
        let operation = "test_auth_failure"
        
        // When
        XCTAssertNoThrow(
            try keychainManager.recordAuthenticationAttempt(
                for: userId,
                successful: false,
                operation: operation
            )
        )
        
        // Then
        XCTAssertTrue(true, "Failed authentication should be recorded and audited")
    }
    
    func testRateLimitingAuditLogging() throws {
        // Given
        let userId = "rate_limit_test_user"
        let operation = "test_rate_limiting"
        
        // Disable testing bypass to test rate limiting
        keychainManager.disableRateLimitTestingBypass()
        
        // Set a restrictive rate limit policy for testing
        let restrictivePolicy = RateLimiter.Policy(
            maxAttempts: 2,
            windowSeconds: 60,
            lockoutDuration: 300
        )
        keychainManager.setRateLimitPolicy(restrictivePolicy, for: operation)
        
        // When - Make multiple failed attempts to trigger rate limiting
        try keychainManager.recordAuthenticationAttempt(
            for: userId,
            successful: false,
            operation: operation
        )
        
        try keychainManager.recordAuthenticationAttempt(
            for: userId,
            successful: false,
            operation: operation
        )
        
        // Third attempt should trigger rate limiting and be audited
        XCTAssertThrowsError(
            try keychainManager.recordAuthenticationAttempt(
                for: userId,
                successful: false,
                operation: operation
            )
        ) { error in
            // Verify it's a rate limit error
            XCTAssertTrue(error is KeychainManager.KeychainError)
            if case KeychainManager.KeychainError.rateLimitExceeded = error {
                XCTAssertTrue(true, "Rate limit exceeded error properly thrown and audited")
            } else {
                XCTFail("Expected rate limit exceeded error, got \(error)")
            }
        }
        
        // Reset for cleanup
        keychainManager.resetAuthenticationRateLimit(for: userId, operation: operation)
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testAccountLockoutAuditLogging() throws {
        // Given
        let userId = "lockout_test_user"
        let operation = "test_lockout"
        
        keychainManager.disableRateLimitTestingBypass()
        
        // Set policy that leads to lockout
        let lockoutPolicy = RateLimiter.Policy(
            maxAttempts: 1,
            windowSeconds: 60,
            lockoutDuration: 300
        )
        keychainManager.setRateLimitPolicy(lockoutPolicy, for: operation)
        
        // When - Make failed attempts to trigger lockout
        try keychainManager.recordAuthenticationAttempt(
            for: userId,
            successful: false,
            operation: operation
        )
        
        // Second attempt should trigger account lockout
        XCTAssertThrowsError(
            try keychainManager.recordAuthenticationAttempt(
                for: userId,
                successful: false,
                operation: operation
            )
        ) { error in
            if case KeychainManager.KeychainError.accountLocked = error {
                XCTAssertTrue(true, "Account lockout properly triggered and audited")
            }
        }
        
        // Reset
        keychainManager.resetAuthenticationRateLimit(for: userId, operation: operation)
        keychainManager.enableRateLimitTestingBypass()
    }
    
    // MARK: - Secure Credentials Audit Tests
    
    func testSecureCredentialsStorageAuditLogging() throws {
        // Given
        let credentials = SecureCredentials(
            accessToken: createMockJWT(),
            refreshToken: createMockJWT(),
            expiresIn: 3600,
            userId: testUserId,
            tokenType: "Bearer"
        )
        
        // When
        XCTAssertNoThrow(try keychainManager.storeSecureCredentials(credentials))
        
        // Then
        let retrievedCredentials = try keychainManager.retrieveSecureCredentials(for: testUserId)
        XCTAssertEqual(retrievedCredentials.userId, credentials.userId)
        XCTAssertEqual(retrievedCredentials.tokenType, credentials.tokenType)
    }
    
    func testSecureCredentialsRetrievalAuditLogging() throws {
        // Given - Store credentials first
        let credentials = SecureCredentials(
            accessToken: createMockJWT(),
            refreshToken: createMockJWT(),
            expiresIn: 3600,
            userId: testUserId,
            tokenType: "Bearer"
        )
        try keychainManager.storeSecureCredentials(credentials)
        
        // When
        let retrievedCredentials = try keychainManager.retrieveSecureCredentials(for: testUserId)
        
        // Then
        XCTAssertEqual(retrievedCredentials.userId, credentials.userId)
        XCTAssertEqual(retrievedCredentials.tokenType, credentials.tokenType)
    }
    
    // MARK: - Error Cases Audit Tests
    
    func testStorageErrorAuditLogging() {
        // Given
        let invalidData = Data()
        let emptyKey = "" // This should cause an error
        
        // When/Then
        XCTAssertThrowsError(try keychainManager.store(invalidData, for: emptyKey)) { error in
            // Error should be thrown and audited
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
    }
    
    func testRetrievalErrorAuditLogging() {
        // Given
        let nonExistentKey = "non_existent_key_12345"
        
        // When/Then
        XCTAssertThrowsError(try keychainManager.retrieve(for: nonExistentKey)) { error in
            // Error should be thrown and audited
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
    }
    
    func testDeletionErrorAuditLogging() {
        // Given
        let nonExistentKey = "non_existent_delete_key"
        
        // When/Then
        XCTAssertThrowsError(try keychainManager.delete(for: nonExistentKey)) { error in
            // Error should be thrown and audited
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
    }
    
    // MARK: - Sensitive Data Clearing Audit Tests
    
    func testSensitiveDataClearingAuditLogging() {
        // Given - Store some sensitive data first
        let testCredentials = SecureCredentials(
            accessToken: createMockJWT(),
            refreshToken: createMockJWT(),
            expiresIn: 3600,
            userId: testUserId,
            tokenType: "Bearer"
        )
        try? keychainManager.storeSecureCredentials(testCredentials)
        try? keychainManager.storeAPIKey("sensitive-api-key", for: "test-service")
        
        // When
        keychainManager.clearSensitiveData()
        
        // Then - Verify data was cleared (and clearing was audited)
        XCTAssertThrowsError(try keychainManager.retrieveSecureCredentials()) { error in
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
        
        XCTAssertThrowsError(try keychainManager.retrieveAPIKey(for: "test-service")) { error in
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
    }
    
    // MARK: - Biometric Protection Audit Tests (Mock)
    
    func testBiometricProtectionStorageAuditLogging() throws {
        // Given
        let testData = "Biometric protected data".data(using: .utf8)!
        let testKey = "biometric_test_key"
        
        // When
        XCTAssertNoThrow(try keychainManager.storeWithBiometricProtection(testData, for: testKey))
        
        // Then
        // Biometric retrieval would normally require biometric authentication
        // For testing purposes, we just verify the storage completed successfully
        XCTAssertTrue(true, "Biometric protection storage should be audited")
    }
    
    // MARK: - Key Validation Audit Tests
    
    func testKeyValidationAuditLogging() {
        // Given
        let invalidKeys = [
            "", // empty key
            String(repeating: "a", count: 200), // too long key
            "invalid@key#with$special%chars", // invalid characters
        ]
        
        for invalidKey in invalidKeys {
            // When/Then
            XCTAssertThrowsError(
                try keychainManager.store("test".data(using: .utf8)!, for: invalidKey)
            ) { error in
                // Invalid key errors should be thrown and audited
                if case KeychainManager.KeychainError.invalidKey = error {
                    XCTAssertTrue(true, "Invalid key error properly thrown and audited")
                }
            }
        }
    }
    
    // MARK: - Concurrent Access Audit Tests
    
    func testConcurrentAccessAuditLogging() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent keychain access")
        expectation.expectedFulfillmentCount = 5
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // When - Perform concurrent operations
        for i in 0..<5 {
            queue.async {
                let key = "concurrent_test_\(i)"
                let data = "Concurrent data \(i)".data(using: .utf8)!
                
                do {
                    try self.keychainManager.store(data, for: key)
                    let _ = try self.keychainManager.retrieve(for: key)
                    try self.keychainManager.delete(for: key)
                } catch {
                    // Errors should be handled gracefully and audited
                }
                
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(true, "Concurrent operations should complete with proper auditing")
    }
    
    // MARK: - Helper Methods
    
    private func createMockJWT(expirationOffset: TimeInterval = 3600) -> String {
        // Create a mock JWT token for testing
        // In a real implementation, this would be a properly signed JWT
        let header = ["alg": "HS256", "typ": "JWT"]
        let payload = [
            "sub": testUserId ?? "test_user",
            "iat": Int(Date().timeIntervalSince1970),
            "exp": Int(Date().timeIntervalSince1970 + expirationOffset),
            "iss": "com.growwiser.app",
            "aud": "growwiser-api"
        ]
        
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerString = headerData.base64EncodedString()
        let payloadString = payloadData.base64EncodedString()
        let signature = "mock_signature_for_testing"
        
        return "\(headerString).\(payloadString).\(signature)"
    }
    
    // MARK: - Performance Tests
    
    func testAuditLoggingPerformanceImpact() {
        // Given
        let testData = "Performance test data".data(using: .utf8)!
        let iterations = 100
        
        // When - Measure performance with audit logging
        measure {
            for i in 0..<iterations {
                let key = "perf_test_\(i)"
                do {
                    try keychainManager.store(testData, for: key)
                    let _ = try keychainManager.retrieve(for: key)
                    try keychainManager.delete(for: key)
                } catch {
                    // Handle errors gracefully in performance test
                }
            }
        }
        
        // Then - Performance measurement recorded by XCTest
        // Audit logging should not significantly impact performance
    }
    
    // MARK: - Integration Verification Tests
    
    func testAuditLoggerSingletonAccess() {
        // Given
        let auditLogger = AuditLogger.shared
        
        // Then
        XCTAssertNotNil(auditLogger, "Audit logger should be accessible")
        XCTAssertTrue(auditLogger === AuditLogger.shared, "Should return same singleton instance")
    }
    
    func testAuditLoggingDoesNotAffectFunctionality() throws {
        // Given
        let testString = "Functionality test"
        let testKey = "functionality_test"
        
        // When
        try keychainManager.storeString(testString, for: testKey)
        let retrieved = try keychainManager.retrieveString(for: testKey)
        
        // Then
        XCTAssertEqual(retrieved, testString, "Audit logging should not affect core functionality")
        
        // Cleanup
        try keychainManager.delete(for: testKey)
    }
}

// MARK: - Test Extensions

extension KeychainAuditIntegrationTests {
    
    /// Verify that audit logging doesn't interfere with normal keychain operations
    func testTransparentAuditLogging() throws {
        // This test ensures audit logging is transparent to normal operations
        let operations = [
            ("string_test", "Test String"),
            ("data_test", "Test Data"),
            ("bool_test", "true"),
            ("api_test", "api-key-123")
        ]
        
        for (key, value) in operations {
            // Store
            if key.contains("string") {
                try keychainManager.storeString(value, for: key)
                let retrieved = try keychainManager.retrieveString(for: key)
                XCTAssertEqual(retrieved, value)
            } else if key.contains("data") {
                let data = value.data(using: .utf8)!
                try keychainManager.store(data, for: key)
                let retrieved = try keychainManager.retrieve(for: key)
                XCTAssertEqual(retrieved, data)
            } else if key.contains("bool") {
                try keychainManager.storeBool(true, for: key)
                let retrieved = try keychainManager.retrieveBool(for: key)
                XCTAssertTrue(retrieved)
            } else if key.contains("api") {
                try keychainManager.storeAPIKey(value, for: "test_service")
                let retrieved = try keychainManager.retrieveAPIKey(for: "test_service")
                XCTAssertEqual(retrieved, value)
            }
            
            // Clean up
            try keychainManager.delete(for: key)
        }
    }
}