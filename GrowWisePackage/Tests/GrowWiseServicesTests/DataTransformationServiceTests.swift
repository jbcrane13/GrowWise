import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Unit tests for DataTransformationService - Data transformation and serialization
final class DataTransformationServiceTests: XCTestCase {
    
    var storage: KeychainStorageService!
    var encryptionService: EncryptionService!
    var dataTransformationService: DataTransformationService!
    var encryptedDataTransformationService: DataTransformationService!
    private let testService = "com.growwiser.transformation.test"
    
    override func setUp() {
        super.setUp()
        storage = KeychainStorageService(service: testService)
        encryptionService = EncryptionService(storage: storage)
        
        // Create both encrypted and non-encrypted services for testing
        dataTransformationService = DataTransformationService(storage: storage, encryptionService: nil)
        encryptedDataTransformationService = DataTransformationService(storage: storage, encryptionService: encryptionService)
        
        // Clean up any existing test data
        try? storage.deleteAll()
    }
    
    override func tearDown() {
        // Clean up after tests
        try? storage.deleteAll()
        encryptedDataTransformationService = nil
        dataTransformationService = nil
        encryptionService = nil
        storage = nil
        super.tearDown()
    }
    
    // MARK: - String Operations Tests
    
    func testStoreAndRetrieveString() throws {
        let testString = "Hello, World! This is a test string with émojis 🌍 and spëcial characters."
        let testKey = "string_test"
        
        // Store string
        XCTAssertNoThrow(try dataTransformationService.storeString(testString, for: testKey))
        
        // Retrieve string
        let retrieved = try dataTransformationService.retrieveString(for: testKey)
        XCTAssertEqual(retrieved, testString)
    }
    
    func testStoreEmptyString() throws {
        let emptyString = ""
        let testKey = "empty_string_test"
        
        // Store empty string
        try dataTransformationService.storeString(emptyString, for: testKey)
        
        // Retrieve empty string
        let retrieved = try dataTransformationService.retrieveString(for: testKey)
        XCTAssertEqual(retrieved, emptyString)
    }
    
    func testStoreUnicodeString() throws {
        let unicodeString = "Testing Unicode: 中文, العربية, русский, 🚀🌟💫"
        let testKey = "unicode_string_test"
        
        // Store unicode string
        try dataTransformationService.storeString(unicodeString, for: testKey)
        
        // Retrieve unicode string
        let retrieved = try dataTransformationService.retrieveString(for: testKey)
        XCTAssertEqual(retrieved, unicodeString)
    }
    
    func testRetrieveNonExistentString() {
        XCTAssertThrowsError(try dataTransformationService.retrieveString(for: "non_existent")) { error in
            // Should throw storage error (item not found)
            XCTAssertTrue(error is KeychainStorageService.StorageError || error is DataTransformationService.TransformationError)
        }
    }
    
    // MARK: - Boolean Operations Tests
    
    func testStoreAndRetrieveBoolTrue() throws {
        let testKey = "bool_true_test"
        
        // Store true
        try dataTransformationService.storeBool(true, for: testKey)
        
        // Retrieve true
        let retrieved = try dataTransformationService.retrieveBool(for: testKey)
        XCTAssertTrue(retrieved)
    }
    
    func testStoreAndRetrieveBoolFalse() throws {
        let testKey = "bool_false_test"
        
        // Store false
        try dataTransformationService.storeBool(false, for: testKey)
        
        // Retrieve false
        let retrieved = try dataTransformationService.retrieveBool(for: testKey)
        XCTAssertFalse(retrieved)
    }
    
    func testBooleanToggle() throws {
        let testKey = "bool_toggle_test"
        
        // Store true
        try dataTransformationService.storeBool(true, for: testKey)
        XCTAssertTrue(try dataTransformationService.retrieveBool(for: testKey))
        
        // Update to false
        try dataTransformationService.storeBool(false, for: testKey)
        XCTAssertFalse(try dataTransformationService.retrieveBool(for: testKey))
    }
    
    func testRetrieveNonExistentBool() {
        XCTAssertThrowsError(try dataTransformationService.retrieveBool(for: "non_existent_bool"))
    }
    
    // MARK: - Codable Operations Tests
    
    // Test model for Codable operations
    struct TestUser: Codable, Equatable {
        let id: String
        let name: String
        let email: String
        let age: Int
        let isActive: Bool
        let tags: [String]
        
        static func == (lhs: TestUser, rhs: TestUser) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.name == rhs.name &&
                   lhs.email == rhs.email &&
                   lhs.age == rhs.age &&
                   lhs.isActive == rhs.isActive &&
                   lhs.tags == rhs.tags
        }
    }
    
    func testStoreAndRetrieveCodable() throws {
        let testUser = TestUser(
            id: "user123",
            name: "John Doe",
            email: "john@example.com",
            age: 30,
            isActive: true,
            tags: ["developer", "swift", "ios"]
        )
        let testKey = "codable_user_test"
        
        // Store codable object
        XCTAssertNoThrow(try dataTransformationService.storeCodable(testUser, for: testKey))
        
        // Retrieve codable object
        let retrieved = try dataTransformationService.retrieveCodable(TestUser.self, for: testKey)
        XCTAssertEqual(retrieved, testUser)
    }
    
    func testStoreAndRetrieveCodableWithEncryption() throws {
        let testUser = TestUser(
            id: "encrypted_user123",
            name: "Jane Smith",
            email: "jane@example.com",
            age: 25,
            isActive: false,
            tags: ["manager", "team-lead"]
        )
        let testKey = "encrypted_codable_test"
        
        // Store with encryption
        try encryptedDataTransformationService.storeCodable(testUser, for: testKey)
        
        // Retrieve with encryption
        let retrieved = try encryptedDataTransformationService.retrieveCodable(TestUser.self, for: testKey)
        XCTAssertEqual(retrieved, testUser)
        
        // Verify it's encrypted in storage
        let encryptedData = try storage.retrieve(for: testKey)
        let dataString = String(data: encryptedData, encoding: .utf8) ?? ""
        XCTAssertFalse(dataString.contains(testUser.name))
        XCTAssertFalse(dataString.contains(testUser.email))
    }
    
    func testCodableWithComplexTypes() throws {
        struct ComplexData: Codable, Equatable {
            let timestamp: Date
            let metadata: [String: String]
            let numbers: [Double]
            let nestedObject: NestedData
            
            struct NestedData: Codable, Equatable {
                let value: String
                let count: Int
            }
            
            static func == (lhs: ComplexData, rhs: ComplexData) -> Bool {
                return abs(lhs.timestamp.timeIntervalSince1970 - rhs.timestamp.timeIntervalSince1970) < 1.0 &&
                       lhs.metadata == rhs.metadata &&
                       lhs.numbers == rhs.numbers &&
                       lhs.nestedObject == rhs.nestedObject
            }
        }
        
        let complexData = ComplexData(
            timestamp: Date(),
            metadata: ["version": "1.0", "environment": "test"],
            numbers: [1.5, 2.7, 3.14159, -42.0],
            nestedObject: ComplexData.NestedData(value: "nested", count: 42)
        )
        let testKey = "complex_codable_test"
        
        // Store complex codable
        try dataTransformationService.storeCodable(complexData, for: testKey)
        
        // Retrieve complex codable
        let retrieved = try dataTransformationService.retrieveCodable(ComplexData.self, for: testKey)
        XCTAssertEqual(retrieved, complexData)
    }
    
    func testRetrieveNonExistentCodable() {
        XCTAssertThrowsError(try dataTransformationService.retrieveCodable(TestUser.self, for: "non_existent"))
    }
    
    // MARK: - JSON Operations Tests
    
    func testStoreAndRetrieveJSONSerializable() throws {
        let jsonObject: [String: Any] = [
            "name": "Test User",
            "age": 30,
            "isActive": true,
            "scores": [85, 92, 78],
            "metadata": [
                "department": "Engineering",
                "role": "Developer"
            ]
        ]
        let testKey = "json_serializable_test"
        
        // Store JSON serializable object
        XCTAssertNoThrow(try dataTransformationService.storeJSONSerializable(jsonObject, for: testKey))
        
        // Retrieve JSON serializable object
        let retrieved = try dataTransformationService.retrieveJSONSerializable(for: testKey)
        
        // Cast to dictionary for comparison
        guard let retrievedDict = retrieved as? [String: Any] else {
            XCTFail("Retrieved object is not a dictionary")
            return
        }
        
        XCTAssertEqual(retrievedDict["name"] as? String, "Test User")
        XCTAssertEqual(retrievedDict["age"] as? Int, 30)
        XCTAssertEqual(retrievedDict["isActive"] as? Bool, true)
        
        let scores = retrievedDict["scores"] as? [Int]
        XCTAssertEqual(scores, [85, 92, 78])
        
        let metadata = retrievedDict["metadata"] as? [String: String]
        XCTAssertEqual(metadata?["department"], "Engineering")
        XCTAssertEqual(metadata?["role"], "Developer")
    }
    
    func testStoreInvalidJSONObject() {
        // Objects that can't be serialized to JSON
        let invalidObjects: [Any] = [
            Date(), // Date is not JSON serializable without custom encoding
            UIView(), // UIKit objects are not JSON serializable
        ]
        
        for (index, invalidObject) in invalidObjects.enumerated() {
            XCTAssertThrowsError(try dataTransformationService.storeJSONSerializable(invalidObject, for: "invalid_\(index)")) { error in
                if let transformationError = error as? DataTransformationService.TransformationError {
                    switch transformationError {
                    case .serializationFailed:
                        break // Expected
                    default:
                        XCTFail("Expected serializationFailed error")
                    }
                }
            }
        }
    }
    
    func testRetrieveNonExistentJSON() {
        XCTAssertThrowsError(try dataTransformationService.retrieveJSONSerializable(for: "non_existent_json"))
    }
    
    // MARK: - Migration Tests
    
    func testMigrateFromUserDefaults() {
        let testKeys = ["migrate_key1", "migrate_key2", "migrate_key3"]
        
        // Set up UserDefaults with test data
        UserDefaults.standard.set("Test String", forKey: testKeys[0])
        UserDefaults.standard.set(true, forKey: testKeys[1])
        UserDefaults.standard.set("Another String".data(using: .utf8), forKey: testKeys[2])
        
        // Verify UserDefaults has the data
        XCTAssertNotNil(UserDefaults.standard.string(forKey: testKeys[0]))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testKeys[1]))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: testKeys[2]))
        
        // Migrate from UserDefaults
        dataTransformationService.migrateFromUserDefaults(keys: testKeys)
        
        // Verify data was migrated to keychain
        XCTAssertTrue(storage.exists(for: testKeys[0]))
        XCTAssertTrue(storage.exists(for: testKeys[1]))
        XCTAssertTrue(storage.exists(for: testKeys[2]))
        
        // Verify UserDefaults was cleaned up
        XCTAssertNil(UserDefaults.standard.string(forKey: testKeys[0]))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: testKeys[1])) // Returns false when not set
        XCTAssertNil(UserDefaults.standard.data(forKey: testKeys[2]))
        
        // Verify migrated data is accessible
        let migratedString = try? dataTransformationService.retrieveString(for: testKeys[0])
        XCTAssertEqual(migratedString, "Test String")
        
        let migratedBool = try? dataTransformationService.retrieveBool(for: testKeys[1])
        XCTAssertEqual(migratedBool, true)
    }
    
    func testMigrationSkipsExistingKeys() {
        let testKey = "existing_key_test"
        
        // Store data in keychain first
        try? dataTransformationService.storeString("Keychain Value", for: testKey)
        
        // Set different data in UserDefaults
        UserDefaults.standard.set("UserDefaults Value", forKey: testKey)
        
        // Migrate (should skip existing key)
        dataTransformationService.migrateFromUserDefaults(keys: [testKey])
        
        // Verify keychain data is unchanged
        let value = try? dataTransformationService.retrieveString(for: testKey)
        XCTAssertEqual(value, "Keychain Value")
        
        // UserDefaults should still have the data (not removed because key existed in keychain)
        XCTAssertEqual(UserDefaults.standard.string(forKey: testKey), "UserDefaults Value")
        
        // Cleanup UserDefaults
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    func testCleanupLegacyData() {
        let legacyKeys = ["legacy_key1", "legacy_key2", "legacy_key3"]
        
        // Store legacy data in keychain
        for key in legacyKeys {
            try? dataTransformationService.storeString("Legacy data for \(key)", for: key)
            XCTAssertTrue(storage.exists(for: key))
        }
        
        // Cleanup legacy data
        dataTransformationService.cleanupLegacyData(keys: legacyKeys)
        
        // Verify legacy data is removed
        for key in legacyKeys {
            XCTAssertFalse(storage.exists(for: key))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDataRetrieval() throws {
        let testKey = "invalid_data_test"
        
        // Store invalid data directly
        let invalidStringData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8 sequence
        try storage.store(invalidStringData, for: testKey)
        
        // Should throw invalid data error when retrieving as string
        XCTAssertThrowsError(try dataTransformationService.retrieveString(for: testKey)) { error in
            if let transformationError = error as? DataTransformationService.TransformationError {
                switch transformationError {
                case .invalidData:
                    break // Expected
                default:
                    XCTFail("Expected invalidData error")
                }
            }
        }
    }
    
    func testInvalidBooleanData() throws {
        let testKey = "invalid_bool_test"
        
        // Store data that's not a single byte
        let invalidBoolData = Data([0x01, 0x02]) // More than one byte
        try storage.store(invalidBoolData, for: testKey)
        
        // Should handle gracefully (use first byte)
        let retrievedBool = try dataTransformationService.retrieveBool(for: testKey)
        XCTAssertTrue(retrievedBool) // First byte is 0x01 (true)
    }
    
    func testEmptyBooleanData() throws {
        let testKey = "empty_bool_test"
        
        // Store empty data
        try storage.store(Data(), for: testKey)
        
        // Should throw invalid data error
        XCTAssertThrowsError(try dataTransformationService.retrieveBool(for: testKey)) { error in
            if let transformationError = error as? DataTransformationService.TransformationError {
                switch transformationError {
                case .invalidData:
                    break // Expected
                default:
                    XCTFail("Expected invalidData error")
                }
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testStringOperationsPerformance() {
        let testString = "Performance test string with some content to make it realistic"
        
        measure {
            for i in 0..<100 {
                let key = "perf_string_\(i)"
                do {
                    try dataTransformationService.storeString(testString, for: key)
                    _ = try dataTransformationService.retrieveString(for: key)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testCodableOperationsPerformance() {
        let testUser = TestUser(
            id: "perf_user",
            name: "Performance Test User",
            email: "perf@example.com",
            age: 25,
            isActive: true,
            tags: ["performance", "test", "swift"]
        )
        
        measure {
            for i in 0..<50 {
                let key = "perf_codable_\(i)"
                do {
                    try dataTransformationService.storeCodable(testUser, for: key)
                    _ = try dataTransformationService.retrieveCodable(TestUser.self, for: key)
                } catch {
                    XCTFail("Codable performance test failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent data transformation operations")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let testString = "Concurrent test string \(index)"
                let testBool = index % 2 == 0
                let testUser = TestUser(
                    id: "concurrent_user_\(index)",
                    name: "User \(index)",
                    email: "user\(index)@example.com",
                    age: 20 + index,
                    isActive: testBool,
                    tags: ["concurrent", "test"]
                )
                
                // Test string operations
                try dataTransformationService.storeString(testString, for: "concurrent_string_\(index)")
                let retrievedString = try dataTransformationService.retrieveString(for: "concurrent_string_\(index)")
                XCTAssertEqual(retrievedString, testString)
                
                // Test boolean operations
                try dataTransformationService.storeBool(testBool, for: "concurrent_bool_\(index)")
                let retrievedBool = try dataTransformationService.retrieveBool(for: "concurrent_bool_\(index)")
                XCTAssertEqual(retrievedBool, testBool)
                
                // Test codable operations
                try dataTransformationService.storeCodable(testUser, for: "concurrent_codable_\(index)")
                let retrievedUser = try dataTransformationService.retrieveCodable(TestUser.self, for: "concurrent_codable_\(index)")
                XCTAssertEqual(retrievedUser, testUser)
                
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent test failed for iteration \(index): \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let mockError = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        
        let errors: [DataTransformationService.TransformationError] = [
            .encodingFailed(mockError),
            .decodingFailed(mockError),
            .invalidData,
            .serializationFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}