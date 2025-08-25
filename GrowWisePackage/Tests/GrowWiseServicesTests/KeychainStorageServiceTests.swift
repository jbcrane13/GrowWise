import XCTest
import Security
@testable import GrowWiseServices

/// Unit tests for KeychainStorageService - Core keychain operations
final class KeychainStorageServiceTests: XCTestCase {
    
    var service: KeychainStorageService!
    private let testService = "com.growwiser.test"
    
    override func setUp() {
        super.setUp()
        service = KeychainStorageService(service: testService)
        
        // Clean up any existing test data
        try? service.deleteAll()
    }
    
    override func tearDown() {
        // Clean up after tests
        try? service.deleteAll()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStoreAndRetrieveData() throws {
        let testKey = "test_key"
        let testData = "Hello, World!".data(using: .utf8)!
        
        // Store data
        XCTAssertNoThrow(try service.store(testData, for: testKey))
        
        // Retrieve data
        let retrievedData = try service.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, testData)
        
        // Verify string conversion
        let retrievedString = String(data: retrievedData, encoding: .utf8)
        XCTAssertEqual(retrievedString, "Hello, World!")
    }
    
    func testStoreAndUpdateData() throws {
        let testKey = "update_test"
        let initialData = "Initial data".data(using: .utf8)!
        let updatedData = "Updated data".data(using: .utf8)!
        
        // Store initial data
        try service.store(initialData, for: testKey)
        
        // Update with new data
        XCTAssertNoThrow(try service.store(updatedData, for: testKey))
        
        // Verify updated data
        let retrievedData = try service.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, updatedData)
        XCTAssertNotEqual(retrievedData, initialData)
    }
    
    func testDeleteData() throws {
        let testKey = "delete_test"
        let testData = "Data to delete".data(using: .utf8)!
        
        // Store data
        try service.store(testData, for: testKey)
        XCTAssertTrue(service.exists(for: testKey))
        
        // Delete data
        XCTAssertNoThrow(try service.delete(for: testKey))
        XCTAssertFalse(service.exists(for: testKey))
        
        // Verify deletion
        XCTAssertThrowsError(try service.retrieve(for: testKey)) { error in
            XCTAssertTrue(error is KeychainStorageService.StorageError)
            if let storageError = error as? KeychainStorageService.StorageError {
                switch storageError {
                case .itemNotFound:
                    break // Expected
                default:
                    XCTFail("Expected itemNotFound error")
                }
            }
        }
    }
    
    func testExistsMethod() throws {
        let testKey = "exists_test"
        let testData = "Test existence".data(using: .utf8)!
        
        // Initially should not exist
        XCTAssertFalse(service.exists(for: testKey))
        
        // Store data
        try service.store(testData, for: testKey)
        XCTAssertTrue(service.exists(for: testKey))
        
        // Delete and verify
        try service.delete(for: testKey)
        XCTAssertFalse(service.exists(for: testKey))
    }
    
    func testDeleteAll() throws {
        let keys = ["key1", "key2", "key3"]
        let testData = "Test data".data(using: .utf8)!
        
        // Store multiple items
        for key in keys {
            try service.store(testData, for: key)
            XCTAssertTrue(service.exists(for: key))
        }
        
        // Delete all
        XCTAssertNoThrow(try service.deleteAll())
        
        // Verify all deleted
        for key in keys {
            XCTAssertFalse(service.exists(for: key))
        }
    }
    
    // MARK: - Key Validation Tests
    
    func testValidKeys() throws {
        let validKeys = [
            "valid_key",
            "api-key-v2",
            "session.token",
            "AUTH_TOKEN_2024",
            "key123",
            "a",
            "user-id_123.test"
        ]
        let testData = "test".data(using: .utf8)!
        
        for key in validKeys {
            XCTAssertNoThrow(try service.store(testData, for: key), "Key '\(key)' should be valid")
            XCTAssertTrue(service.exists(for: key))
            try service.delete(for: key)
        }
    }
    
    func testInvalidKeys() {
        let testData = "test".data(using: .utf8)!
        
        // Test dangerous patterns
        let dangerousKeys = [
            "'; DROP TABLE users; --",
            "<script>alert('xss')</script>",
            "javascript:alert(1)",
            "onload=alert(1)",
            "key--comment",
            "key/*comment*/"
        ]
        
        for key in dangerousKeys {
            XCTAssertThrowsError(try service.store(testData, for: key)) { error in
                XCTAssertTrue(error is KeychainStorageService.StorageError)
                if let storageError = error as? KeychainStorageService.StorageError {
                    switch storageError {
                    case .invalidKey:
                        break // Expected
                    default:
                        XCTFail("Expected invalidKey error for: \(key)")
                    }
                }
            }
        }
    }
    
    func testKeyLengthValidation() {
        let testData = "test".data(using: .utf8)!
        
        // Empty key
        XCTAssertThrowsError(try service.store(testData, for: ""))
        
        // Too long key (over 256 characters)
        let tooLongKey = String(repeating: "a", count: 257)
        XCTAssertThrowsError(try service.store(testData, for: tooLongKey))
        
        // Maximum length key (256 characters)
        let maxLengthKey = String(repeating: "a", count: 256)
        XCTAssertNoThrow(try service.store(testData, for: maxLengthKey))
    }
    
    func testInvalidCharacters() {
        let testData = "test".data(using: .utf8)!
        let invalidCharacters = ["key with spaces", "key@invalid", "key#hash", "key%percent"]
        
        for key in invalidCharacters {
            XCTAssertThrowsError(try service.store(testData, for: key)) { error in
                if let storageError = error as? KeychainStorageService.StorageError {
                    switch storageError {
                    case .invalidKey:
                        break // Expected
                    default:
                        XCTFail("Expected invalidKey error for: \(key)")
                    }
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testRetrieveNonExistentItem() {
        XCTAssertThrowsError(try service.retrieve(for: "non_existent_key")) { error in
            XCTAssertTrue(error is KeychainStorageService.StorageError)
            if let storageError = error as? KeychainStorageService.StorageError {
                switch storageError {
                case .itemNotFound:
                    break // Expected
                default:
                    XCTFail("Expected itemNotFound error")
                }
            }
        }
    }
    
    func testDeleteNonExistentItem() {
        // Deleting non-existent item should not throw (idempotent)
        XCTAssertNoThrow(try service.delete(for: "non_existent_key"))
    }
    
    func testExistsWithInvalidKey() {
        // exists() should return false for invalid keys instead of throwing
        XCTAssertFalse(service.exists(for: "key with spaces"))
        XCTAssertFalse(service.exists(for: ""))
        XCTAssertFalse(service.exists(for: String(repeating: "a", count: 257)))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyData() throws {
        let testKey = "empty_data_key"
        let emptyData = Data()
        
        // Store empty data
        XCTAssertNoThrow(try service.store(emptyData, for: testKey))
        
        // Retrieve empty data
        let retrievedData = try service.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, emptyData)
        XCTAssertEqual(retrievedData.count, 0)
    }
    
    func testLargeData() throws {
        let testKey = "large_data_key"
        // Create 1MB of test data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        
        // Store large data
        XCTAssertNoThrow(try service.store(largeData, for: testKey))
        
        // Retrieve and verify
        let retrievedData = try service.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, largeData)
        XCTAssertEqual(retrievedData.count, 1024 * 1024)
    }
    
    func testBinaryData() throws {
        let testKey = "binary_data_key"
        // Create binary data with various byte values
        let binaryData = Data([0x00, 0x01, 0xFF, 0x7F, 0x80, 0xAB, 0xCD, 0xEF])
        
        // Store binary data
        try service.store(binaryData, for: testKey)
        
        // Retrieve and verify
        let retrievedData = try service.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, binaryData)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceStoreRetrieve() {
        let testData = "Performance test data".data(using: .utf8)!
        
        measure {
            for i in 0..<100 {
                let key = "perf_key_\(i)"
                do {
                    try service.store(testData, for: key)
                    _ = try service.retrieve(for: key)
                    try service.delete(for: key)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testConcurrentAccess() {
        let testData = "Concurrent test data".data(using: .utf8)!
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let key = "concurrent_key_\(index)"
            do {
                try service.store(testData, for: key)
                _ = try service.retrieve(for: key)
                XCTAssertTrue(service.exists(for: key))
                try service.delete(for: key)
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent test failed for index \(index): \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Access Group Tests
    
    func testWithAccessGroup() {
        let serviceWithGroup = KeychainStorageService(service: testService, accessGroup: "group.com.growwiser.test")
        let testData = "Access group test".data(using: .utf8)!
        let testKey = "access_group_key"
        
        // Store data with access group
        XCTAssertNoThrow(try serviceWithGroup.store(testData, for: testKey))
        
        // Retrieve data
        let retrievedData = try? serviceWithGroup.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, testData)
        
        // Clean up
        try? serviceWithGroup.delete(for: testKey)
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let errors: [KeychainStorageService.StorageError] = [
            .duplicateEntry,
            .unknown(errSecItemNotFound),
            .itemNotFound,
            .invalidData,
            .unexpectedPasswordData,
            .unhandledError(status: errSecAuthFailed),
            .invalidKey("Test reason")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}