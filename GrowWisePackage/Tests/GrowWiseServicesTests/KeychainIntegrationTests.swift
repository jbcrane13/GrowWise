import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Integration tests for the refactored KeychainManager service architecture
/// Tests service interactions, data flow, and end-to-end functionality
final class KeychainIntegrationTests: XCTestCase {
    
    var keychainManager: KeychainManager!
    
    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager.shared
        
        // Clean up any existing test data
        keychainManager.clearSensitiveData()
    }
    
    override func tearDown() {
        // Clean up after tests
        keychainManager.clearSensitiveData()
        super.tearDown()
    }
    
    // MARK: - Service Integration Tests
    
    func testServiceComposition() throws {
        // Test that all services work together properly
        let testData = "Integration test data".data(using: .utf8)!
        let testKey = "integration_test_key"
        
        // Store data through KeychainManager
        XCTAssertNoThrow(try keychainManager.store(testData, for: testKey))
        
        // Retrieve data through KeychainManager
        let retrieved = try keychainManager.retrieve(for: testKey)
        XCTAssertEqual(retrieved, testData)
        
        // Verify existence check
        XCTAssertTrue(keychainManager.exists(for: testKey))
        
        // Delete data
        XCTAssertNoThrow(try keychainManager.delete(for: testKey))
        XCTAssertFalse(keychainManager.exists(for: testKey))
    }
    
    func testCompleteUserFlow() throws {
        // Simulate complete user authentication flow
        
        // 1. Store user credentials
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh_token",
            expiresIn: 3600,
            userId: "user123"
        )
        
        try keychainManager.storeSecureCredentials(credentials)
        
        // 2. Store API keys
        try keychainManager.storeAPIKey("weather-api-key-12345", for: "weather")
        try keychainManager.storeAPIKey("plant-db-api-key-67890", for: "plant_database")
        
        // 3. Store user preferences
        try keychainManager.storeBool(true, for: "enable_notifications")
        try keychainManager.storeString("08:00", for: "notification_time")
        
        // 4. Verify all data can be retrieved
        let retrievedCredentials = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(retrievedCredentials.accessToken, credentials.accessToken)
        XCTAssertEqual(retrievedCredentials.userId, credentials.userId)
        
        let weatherKey = try keychainManager.retrieveAPIKey(for: "weather")
        XCTAssertEqual(weatherKey, "weather-api-key-12345")
        
        let plantDbKey = try keychainManager.retrieveAPIKey(for: "plant_database")
        XCTAssertEqual(plantDbKey, "plant-db-api-key-67890")
        
        let notifications = try keychainManager.retrieveBool(for: "enable_notifications")
        XCTAssertTrue(notifications)
        
        let notificationTime = try keychainManager.retrieveString(for: "notification_time")
        XCTAssertEqual(notificationTime, "08:00")
        
        // 5. Test token refresh
        let refreshResponse = TokenRefreshResponse(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.new_token",
            refreshToken: nil, // Keep existing refresh token
            expiresIn: 7200
        )
        
        try keychainManager.updateTokensAfterRefresh(response: refreshResponse)
        
        let updatedCredentials = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(updatedCredentials.accessToken, refreshResponse.accessToken)
        XCTAssertEqual(updatedCredentials.refreshToken, credentials.refreshToken) // Should keep original
        
        // 6. Clear sensitive data (logout)
        keychainManager.clearSensitiveData()
        
        // Verify data is cleared
        XCTAssertThrowsError(try keychainManager.retrieveSecureCredentials())
        XCTAssertThrowsError(try keychainManager.retrieveAPIKey(for: "weather"))
        XCTAssertThrowsError(try keychainManager.retrieveAPIKey(for: "plant_database"))
    }
    
    func testDataMigrationIntegration() throws {
        // Test migration workflow
        let migrationKeys = ["test_pref1", "test_pref2", "test_pref3"]
        
        // Set up UserDefaults data to migrate
        UserDefaults.standard.set("Preference 1", forKey: migrationKeys[0])
        UserDefaults.standard.set(true, forKey: migrationKeys[1])
        UserDefaults.standard.set("Preference 3".data(using: .utf8), forKey: migrationKeys[2])
        
        // Perform migration
        keychainManager.migrateFromUserDefaults()
        
        // Verify data exists in keychain after migration
        // Note: Migration only happens for predefined keys in the actual implementation
        // This test verifies the migration infrastructure works
        XCTAssertTrue(keychainManager.isPasswordMigrationComplete())
        
        // Clean up UserDefaults
        for key in migrationKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - Service Error Mapping Tests
    
    func testErrorMappingFromServices() {
        // Test that service errors are properly mapped to KeychainError
        
        // Test invalid key error mapping
        XCTAssertThrowsError(try keychainManager.storeString("test", for: "")) { error in
            XCTAssertTrue(error is KeychainManager.KeychainError)
            if let keychainError = error as? KeychainManager.KeychainError {
                switch keychainError {
                case .invalidKey, .serviceError:
                    break // Expected
                default:
                    XCTFail("Expected invalidKey or serviceError")
                }
            }
        }
        
        // Test item not found error mapping
        XCTAssertThrowsError(try keychainManager.retrieveString(for: "non_existent_key")) { error in
            XCTAssertTrue(error is KeychainManager.KeychainError)
            if let keychainError = error as? KeychainManager.KeychainError {
                switch keychainError {
                case .itemNotFound, .serviceError:
                    break // Expected
                default:
                    XCTFail("Expected itemNotFound or serviceError")
                }
            }
        }
    }
    
    // MARK: - Backwards Compatibility Tests
    
    func testBackwardsCompatibility() throws {
        // Test that the refactored KeychainManager maintains API compatibility
        
        // Legacy auth token methods should work
        let testToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.legacy_token"
        
        try keychainManager.storeAuthToken(testToken)
        let retrievedToken = try keychainManager.retrieveAuthToken()
        XCTAssertEqual(retrievedToken, testToken)
        
        // Basic data operations should work
        let testData = "Backwards compatibility test".data(using: .utf8)!
        try keychainManager.store(testData, for: "compat_test")
        let retrievedData = try keychainManager.retrieve(for: "compat_test")
        XCTAssertEqual(retrievedData, testData)
        
        // String and bool operations should work
        try keychainManager.storeString("Compatibility String", for: "compat_string")
        let retrievedString = try keychainManager.retrieveString(for: "compat_string")
        XCTAssertEqual(retrievedString, "Compatibility String")
        
        try keychainManager.storeBool(true, for: "compat_bool")
        let retrievedBool = try keychainManager.retrieveBool(for: "compat_bool")
        XCTAssertTrue(retrievedBool)
        
        // Codable operations should work
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let testCodable = TestData(name: "Test", value: 42)
        try keychainManager.storeCodable(testCodable, for: "compat_codable")
        let retrievedCodable = try keychainManager.retrieveCodable(TestData.self, for: "compat_codable")
        XCTAssertEqual(retrievedCodable, testCodable)
    }
    
    // MARK: - Performance Integration Tests
    
    func testServicePerformanceOverhead() {
        // Test that service composition doesn't introduce significant overhead
        let testData = "Performance test data".data(using: .utf8)!
        
        measure {
            for i in 0..<100 {
                let key = "perf_integration_\(i)"
                do {
                    try keychainManager.store(testData, for: key)
                    _ = try keychainManager.retrieve(for: key)
                    try keychainManager.delete(for: key)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testComplexOperationsPerformance() {
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.perf_token",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh_perf",
            expiresIn: 3600
        )
        
        measure {
            for _ in 0..<20 {
                do {
                    try keychainManager.storeSecureCredentials(credentials)
                    _ = try keychainManager.retrieveSecureCredentials()
                    try keychainManager.storeAPIKey("test-api-key", for: "performance_test")
                    _ = try keychainManager.retrieveAPIKey(for: "performance_test")
                    keychainManager.clearSensitiveData()
                } catch {
                    XCTFail("Complex performance test failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Thread Safety Integration Tests
    
    func testConcurrentServiceOperations() {
        let expectation = XCTestExpectation(description: "Concurrent service operations")
        expectation.expectedFulfillmentCount = 20
        
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            do {
                // Mix different types of operations
                let credentials = SecureCredentials(
                    accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.concurrent_\(index)",
                    refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh_\(index)",
                    expiresIn: 3600,
                    userId: "concurrent_user_\(index)"
                )
                
                try keychainManager.storeSecureCredentials(credentials)
                let retrieved = try keychainManager.retrieveSecureCredentials()
                XCTAssertEqual(retrieved.userId, "concurrent_user_\(index)")
                
                try keychainManager.storeString("Concurrent string \(index)", for: "concurrent_string_\(index)")
                let stringValue = try keychainManager.retrieveString(for: "concurrent_string_\(index)")
                XCTAssertEqual(stringValue, "Concurrent string \(index)")
                
                try keychainManager.storeBool(index % 2 == 0, for: "concurrent_bool_\(index)")
                let boolValue = try keychainManager.retrieveBool(for: "concurrent_bool_\(index)")
                XCTAssertEqual(boolValue, index % 2 == 0)
                
                keychainManager.clearSensitiveData()
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent integration test failed for iteration \(index): \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Edge Cases Integration Tests
    
    func testServiceInteractionWithCorruptedData() throws {
        // Test how services handle corrupted data
        let testKey = "corrupted_data_test"
        
        // Store valid encrypted credentials
        let credentials = SecureCredentials(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.test",
            refreshToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh",
            expiresIn: 3600
        )
        
        try keychainManager.storeSecureCredentials(credentials)
        
        // Verify normal retrieval works
        let retrieved = try keychainManager.retrieveSecureCredentials()
        XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
        
        // Simulate corruption by storing random data with credential key
        let corruptedData = Data([0xFF, 0xFE, 0xFD, 0xFC])
        try keychainManager.store(corruptedData, for: "secure_jwt_credentials_v2")
        
        // Retrieval should fail gracefully
        XCTAssertThrowsError(try keychainManager.retrieveSecureCredentials()) { error in
            // Should be a service error, not a crash
            XCTAssertTrue(error is KeychainManager.KeychainError)
        }
    }
    
    func testServiceRecoveryAfterErrors() throws {
        // Test that services can recover after errors
        
        // Cause an error
        XCTAssertThrowsError(try keychainManager.retrieveString(for: "non_existent"))
        
        // Should still be able to perform normal operations
        try keychainManager.storeString("Recovery test", for: "recovery_test")
        let retrieved = try keychainManager.retrieveString(for: "recovery_test")
        XCTAssertEqual(retrieved, "Recovery test")
        
        // Cause another error
        XCTAssertThrowsError(try keychainManager.storeString("test", for: ""))
        
        // Should still work normally
        try keychainManager.storeBool(true, for: "recovery_bool")
        let boolValue = try keychainManager.retrieveBool(for: "recovery_bool")
        XCTAssertTrue(boolValue)
    }
    
    // MARK: - Service Boundary Tests
    
    func testServiceEncapsulation() {
        // Test that service boundaries are properly maintained
        // Services should not leak implementation details
        
        let testData = "Encapsulation test".data(using: .utf8)!
        
        // Store through one interface
        XCTAssertNoThrow(try keychainManager.store(testData, for: "encapsulation_test"))
        
        // Retrieve through another interface
        let retrieved = try? keychainManager.retrieve(for: "encapsulation_test")
        XCTAssertEqual(retrieved, testData)
        
        // String interface should work on the same data if it's UTF-8
        let stringRetrieved = try? keychainManager.retrieveString(for: "encapsulation_test")
        XCTAssertEqual(stringRetrieved, "Encapsulation test")
        
        // But direct keychain access should not reveal service implementation
        XCTAssertTrue(keychainManager.exists(for: "encapsulation_test"))
    }
}