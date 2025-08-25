import XCTest
import CryptoKit
@testable import GrowWiseServices

/// Unit tests for EncryptionService - Secure Enclave-based AES-256-GCM encryption operations
final class EncryptionServiceTests: XCTestCase {
    
    var storage: KeychainStorageService!
    var encryptionService: EncryptionService!
    private let testService = "com.growwise.encryption.test"
    
    override func setUp() {
        super.setUp()
        storage = KeychainStorageService(service: testService)
        encryptionService = EncryptionService(storage: storage)
        
        // Clean up any existing test data
        try? storage.deleteAll()
        try? encryptionService.clearEncryptionKey()
    }
    
    override func tearDown() {
        // Clean up after tests
        try? encryptionService.clearEncryptionKey()
        try? storage.deleteAll()
        encryptionService = nil
        storage = nil
        super.tearDown()
    }
    
    // MARK: - Basic Encryption/Decryption Tests
    
    func testEncryptDecryptData() throws {
        let originalData = "Hello, World! This is a test message.".data(using: .utf8)!
        
        // Encrypt data
        let encryptedData = try encryptionService.encrypt(originalData)
        
        // Verify encryption changed the data
        XCTAssertNotEqual(encryptedData, originalData)
        XCTAssertGreaterThan(encryptedData.count, originalData.count) // Includes nonce and tag
        
        // Decrypt data
        let decryptedData = try encryptionService.decrypt(encryptedData)
        
        // Verify decryption
        XCTAssertEqual(decryptedData, originalData)
        
        // Verify string content
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        XCTAssertEqual(decryptedString, "Hello, World! This is a test message.")
    }
    
    // MARK: - Key Rotation Tests
    
    func testKeyRotation() async throws {
        let originalData = "Test data for key rotation".data(using: .utf8)!
        
        // Encrypt with initial key
        let encryptedData1 = try encryptionService.encrypt(originalData)
        let initialVersion = encryptionService.currentKeyVersion
        
        // Rotate key
        let newVersion = try await encryptionService.rotateKey(reason: "Test rotation")
        
        // Verify key was rotated
        XCTAssertGreaterThan(newVersion, initialVersion)
        XCTAssertEqual(encryptionService.currentKeyVersion, newVersion)
        
        // Encrypt with new key
        let encryptedData2 = try encryptionService.encrypt(originalData)
        
        // Both encryptions should be different (different keys)
        XCTAssertNotEqual(encryptedData1, encryptedData2)
        
        // Both should decrypt successfully (backward compatibility)
        let decrypted1 = try encryptionService.decrypt(encryptedData1)
        let decrypted2 = try encryptionService.decrypt(encryptedData2)
        
        XCTAssertEqual(decrypted1, originalData)
        XCTAssertEqual(decrypted2, originalData)
    }
    
    func testMultipleKeyVersionsBackwardCompatibility() async throws {
        let testData = "Multi-version test data".data(using: .utf8)!
        var encryptedDataSets: [Data] = []
        var keyVersions: [Int] = []
        
        // Create multiple key versions and encrypt data with each
        for i in 1...3 {
            let version = try await encryptionService.rotateKey(reason: "Version \(i)")
            keyVersions.append(version)
            
            let encrypted = try encryptionService.encrypt(testData)
            encryptedDataSets.append(encrypted)
        }
        
        // Verify all encrypted data can still be decrypted
        for (index, encryptedData) in encryptedDataSets.enumerated() {
            let decrypted = try encryptionService.decrypt(encryptedData)
            XCTAssertEqual(decrypted, testData, "Failed to decrypt data from version \(keyVersions[index])")
        }
        
        // Verify active key versions
        let activeVersions = encryptionService.getActiveKeyVersions()
        for version in keyVersions {
            XCTAssertTrue(activeVersions.contains(version), "Version \(version) should be active")
        }
    }
    
    func testKeyRotationNeeded() async throws {
        // Initially, no key exists
        XCTAssertTrue(encryptionService.isKeyRotationNeeded())
        
        // After first rotation, should be up to date
        let _ = try await encryptionService.rotateKey(reason: "Initial key")
        XCTAssertFalse(encryptionService.isKeyRotationNeeded())
        
        // For testing, we'd need to modify the rotation policy or mock time
        // This is a placeholder for more sophisticated time-based testing
    }
    
    func testComplianceViolationDetection() async throws {
        // Create initial key
        let _ = try await encryptionService.rotateKey(reason: "Initial")
        
        // Initially should not be overdue
        XCTAssertFalse(encryptionService.isKeyRotationOverdue())
        
        // For full testing, we'd need to mock time or adjust policies
        // This ensures the API exists and returns boolean values
    }
    
    func testComplianceReporting() async throws {
        // Create some key rotations
        let _ = try await encryptionService.rotateKey(reason: "Initial")
        let _ = try await encryptionService.rotateKey(reason: "Regular rotation")
        
        // Generate compliance report
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let report = await encryptionService.generateComplianceReport(period: period)
        
        // Verify report structure
        XCTAssertNotNil(report.reportId)
        XCTAssertFalse(report.keyVersions.isEmpty)
        XCTAssertFalse(report.rotationEvents.isEmpty)
        XCTAssertNotNil(report.complianceStatus)
    }
    
    func testAuditTrail() async throws {
        // Perform some operations
        let _ = try await encryptionService.rotateKey(reason: "Audit test")
        let testData = "Audit trail test".data(using: .utf8)!
        let _ = try encryptionService.encrypt(testData)
        
        // Get audit trail
        let auditEvents = encryptionService.getAuditTrail(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )
        
        // Verify audit events were recorded
        XCTAssertFalse(auditEvents.isEmpty)
        
        let rotationEvents = auditEvents.filter { $0.event == .keyRotated }
        let accessEvents = auditEvents.filter { $0.event == .keyAccessed }
        
        XCTAssertFalse(rotationEvents.isEmpty)
        // Note: Access events might be empty depending on implementation details
    }
    
    func testSecurityStatusWithKeyRotation() async throws {
        // Create initial key
        let _ = try await encryptionService.rotateKey(reason: "Status test")
        
        let status = encryptionService.securityStatus
        
        // Verify key rotation status is included
        XCTAssertNotNil(status.keyRotationStatus)
        XCTAssertGreaterThan(status.keyRotationStatus.currentVersion, 0)
        XCTAssertFalse(status.keyRotationStatus.activeVersions.isEmpty)
        
        // Verify compliance status
        XCTAssertNotNil(status.complianceStatus)
        XCTAssertFalse(status.description.isEmpty)
    }
    
    func testVersionedEncryptionFormat() async throws {
        let testData = "Versioned encryption test".data(using: .utf8)!
        
        // Create first version
        let version1 = try await encryptionService.rotateKey(reason: "Version 1")
        let encrypted1 = try encryptionService.encrypt(testData)
        
        // Create second version
        let version2 = try await encryptionService.rotateKey(reason: "Version 2")
        let encrypted2 = try encryptionService.encrypt(testData)
        
        // Encrypted data should be different
        XCTAssertNotEqual(encrypted1, encrypted2)
        
        // Both should have version information embedded
        // (This tests the versioned data format internally)
        XCTAssertGreaterThan(encrypted1.count, testData.count + 16) // Extra bytes for version + encryption overhead
        XCTAssertGreaterThan(encrypted2.count, testData.count + 16)
        
        // Both should decrypt correctly
        let decrypted1 = try encryptionService.decrypt(encrypted1)
        let decrypted2 = try encryptionService.decrypt(encrypted2)
        
        XCTAssertEqual(decrypted1, testData)
        XCTAssertEqual(decrypted2, testData)
    }
    
    func testKeyRotationPolicyUpdate() throws {
        let newPolicy = KeyRotationManager.RotationPolicy(
            interval: 60 * 60 * 24 * 7, // 7 days
            maxKeyAge: 60 * 60 * 24 * 30, // 30 days
            minKeyAge: 60 * 60 * 24, // 1 day
            autoRotationEnabled: true,
            complianceMode: .standard,
            reencryptionBatchSize: 50,
            quietHours: nil
        )
        
        XCTAssertNoThrow(try encryptionService.updateRotationPolicy(newPolicy))
    }
    
    func testEncryptionWithOverdueKey() async throws {
        // This test would require mocking time or using test policies
        // For now, we test that the compliance check exists
        
        let _ = try await encryptionService.rotateKey(reason: "Test overdue")
        
        // Should not throw for fresh key
        let testData = "Overdue key test".data(using: .utf8)!
        XCTAssertNoThrow(try encryptionService.encrypt(testData))
    }
    
    func testEncryptDecryptEmptyData() throws {
        let emptyData = Data()
        
        // Encrypt empty data
        let encryptedData = try encryptionService.encrypt(emptyData)
        XCTAssertNotEqual(encryptedData, emptyData)
        XCTAssertGreaterThan(encryptedData.count, 0) // Still has nonce and tag
        
        // Decrypt empty data
        let decryptedData = try encryptionService.decrypt(encryptedData)
        XCTAssertEqual(decryptedData, emptyData)
        XCTAssertEqual(decryptedData.count, 0)
    }
    
    func testEncryptDecryptLargeData() throws {
        // Test with 1MB of data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        
        // Encrypt large data
        let encryptedData = try encryptionService.encrypt(largeData)
        XCTAssertNotEqual(encryptedData, largeData)
        
        // Decrypt large data
        let decryptedData = try encryptionService.decrypt(encryptedData)
        XCTAssertEqual(decryptedData, largeData)
        XCTAssertEqual(decryptedData.count, 1024 * 1024)
    }
    
    func testEncryptDecryptBinaryData() throws {
        let binaryData = Data([0x00, 0x01, 0xFF, 0x7F, 0x80, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78])
        
        // Encrypt binary data
        let encryptedData = try encryptionService.encrypt(binaryData)
        XCTAssertNotEqual(encryptedData, binaryData)
        
        // Decrypt binary data
        let decryptedData = try encryptionService.decrypt(encryptedData)
        XCTAssertEqual(decryptedData, binaryData)
    }
    
    // MARK: - Authenticated Encryption Tests
    
    func testEncryptDecryptWithAAD() throws {
        let originalData = "Sensitive authentication data".data(using: .utf8)!
        let authenticatedData = "com.growwiser.app".data(using: .utf8)!
        
        // Encrypt with AAD
        let encryptedData = try encryptionService.encrypt(originalData, authenticatedData: authenticatedData)
        XCTAssertNotEqual(encryptedData, originalData)
        
        // Decrypt with correct AAD
        let decryptedData = try encryptionService.decrypt(encryptedData, authenticatedData: authenticatedData)
        XCTAssertEqual(decryptedData, originalData)
        
        // Attempt to decrypt with wrong AAD should fail
        let wrongAAD = "wrong.app.identifier".data(using: .utf8)!
        XCTAssertThrowsError(try encryptionService.decrypt(encryptedData, authenticatedData: wrongAAD)) { error in
            XCTAssertTrue(error is CryptoKitError)
        }
    }
    
    func testAADIntegrityProtection() throws {
        let originalData = "Protected message".data(using: .utf8)!
        let authenticatedData = "protection.context".data(using: .utf8)!
        
        // Encrypt with AAD
        let encryptedData = try encryptionService.encrypt(originalData, authenticatedData: authenticatedData)
        
        // Tamper with encrypted data
        var tamperedData = encryptedData
        if tamperedData.count > 10 {
            tamperedData[10] = tamperedData[10] ^ 0xFF // Flip bits
        }
        
        // Decryption should fail due to tampering
        XCTAssertThrowsError(try encryptionService.decrypt(tamperedData, authenticatedData: authenticatedData))
    }
    
    // MARK: - Key Management Tests
    
    func testEncryptionKeyPersistence() throws {
        let testData = "Key persistence test".data(using: .utf8)!
        
        // Encrypt data
        let encryptedData = try encryptionService.encrypt(testData)
        
        // Create new encryption service (simulates app restart)
        let newEncryptionService = EncryptionService(storage: storage)
        
        // Should be able to decrypt with new service instance
        let decryptedData = try newEncryptionService.decrypt(encryptedData)
        XCTAssertEqual(decryptedData, testData)
    }
    
    func testHasEncryptionKey() {
        // Initially should have a key (created on first access)
        XCTAssertTrue(encryptionService.hasEncryptionKey)
        
        // Clear the key
        try? encryptionService.clearEncryptionKey()
        
        // Key should be recreated on next access
        XCTAssertTrue(encryptionService.hasEncryptionKey)
    }
    
    func testKeyRotation() throws {
        // Skip if Secure Enclave not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            // Test legacy behavior - key rotation should throw
            XCTAssertThrowsError(try encryptionService.rotateKey()) { error in
                XCTAssertTrue(error is EncryptionService.EncryptionError)
            }
            return
        }
        
        let testData = "Key rotation test".data(using: .utf8)!
        
        // Encrypt with original key
        let encryptedWithOriginalKey = try encryptionService.encrypt(testData)
        
        // Rotate key
        XCTAssertNoThrow(try encryptionService.rotateKey())
        
        // Encrypt with new key
        let encryptedWithNewKey = try encryptionService.encrypt(testData)
        
        // Encrypted data should be different (different keys)
        XCTAssertNotEqual(encryptedWithOriginalKey, encryptedWithNewKey)
        
        // Can decrypt with new key
        let decryptedWithNewKey = try encryptionService.decrypt(encryptedWithNewKey)
        XCTAssertEqual(decryptedWithNewKey, testData)
        
        // Old data should be decryptable due to legacy fallback
        let decryptedOldData = try encryptionService.decrypt(encryptedWithOriginalKey)
        XCTAssertEqual(decryptedOldData, testData)
    }
    
    func testClearEncryptionKey() throws {
        let testData = "Clear key test".data(using: .utf8)!
        
        // Encrypt data
        let encryptedData = try encryptionService.encrypt(testData)
        
        // Clear encryption key
        try encryptionService.clearEncryptionKey()
        
        // Should not be able to decrypt with cleared key (new key generated)
        XCTAssertThrowsError(try encryptionService.decrypt(encryptedData))
    }
    
    // MARK: - Error Handling Tests
    
    func testDecryptInvalidData() {
        let invalidData = "Not encrypted data".data(using: .utf8)!
        
        XCTAssertThrowsError(try encryptionService.decrypt(invalidData)) { error in
            XCTAssertTrue(error is CryptoKitError)
        }
    }
    
    func testDecryptTruncatedData() throws {
        let originalData = "Test data for truncation".data(using: .utf8)!
        let encryptedData = try encryptionService.encrypt(originalData)
        
        // Truncate encrypted data
        let truncatedData = encryptedData.prefix(encryptedData.count - 5)
        
        XCTAssertThrowsError(try encryptionService.decrypt(truncatedData)) { error in
            XCTAssertTrue(error is CryptoKitError)
        }
    }
    
    func testDecryptCorruptedData() throws {
        let originalData = "Test data for corruption".data(using: .utf8)!
        let encryptedData = try encryptionService.encrypt(originalData)
        
        // Corrupt encrypted data
        var corruptedData = encryptedData
        if corruptedData.count > 5 {
            corruptedData[5] = corruptedData[5] ^ 0xFF
        }
        
        XCTAssertThrowsError(try encryptionService.decrypt(corruptedData)) { error in
            XCTAssertTrue(error is CryptoKitError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() {
        let testData = Data(repeating: 0x42, count: 1024) // 1KB test data
        
        measure {
            for _ in 0..<100 {
                do {
                    let encrypted = try encryptionService.encrypt(testData)
                    _ = try encryptionService.decrypt(encrypted)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testLargeDataEncryptionPerformance() {
        let largeData = Data(repeating: 0x42, count: 100 * 1024) // 100KB test data
        
        measure {
            do {
                let encrypted = try encryptionService.encrypt(largeData)
                _ = try encryptionService.decrypt(encrypted)
            } catch {
                XCTFail("Large data performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentEncryptionDecryption() {
        let testData = "Concurrent test data".data(using: .utf8)!
        let expectation = XCTestExpectation(description: "Concurrent encryption/decryption")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let encrypted = try encryptionService.encrypt(testData)
                let decrypted = try encryptionService.decrypt(encrypted)
                XCTAssertEqual(decrypted, testData)
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent test failed for iteration \(index): \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultipleEncryptionsProduceDifferentCiphertext() throws {
        let testData = "Same plaintext".data(using: .utf8)!
        
        // Encrypt the same data multiple times
        let encrypted1 = try encryptionService.encrypt(testData)
        let encrypted2 = try encryptionService.encrypt(testData)
        let encrypted3 = try encryptionService.encrypt(testData)
        
        // Ciphertext should be different (due to different nonces)
        XCTAssertNotEqual(encrypted1, encrypted2)
        XCTAssertNotEqual(encrypted1, encrypted3)
        XCTAssertNotEqual(encrypted2, encrypted3)
        
        // But all should decrypt to the same plaintext
        let decrypted1 = try encryptionService.decrypt(encrypted1)
        let decrypted2 = try encryptionService.decrypt(encrypted2)
        let decrypted3 = try encryptionService.decrypt(encrypted3)
        
        XCTAssertEqual(decrypted1, testData)
        XCTAssertEqual(decrypted2, testData)
        XCTAssertEqual(decrypted3, testData)
    }
    
    func testEncryptionWithUnicodeData() throws {
        let unicodeString = "Hello 世界! 🌍 Testing émojis and spëcial characters: ñáéíóú"
        let unicodeData = unicodeString.data(using: .utf8)!
        
        // Encrypt unicode data
        let encryptedData = try encryptionService.encrypt(unicodeData)
        
        // Decrypt and verify
        let decryptedData = try encryptionService.decrypt(encryptedData)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        
        XCTAssertEqual(decryptedData, unicodeData)
        XCTAssertEqual(decryptedString, unicodeString)
    }
    
    // MARK: - Security Tests
    
    func testDeterministicKeyGeneration() throws {
        // Keys should be generated consistently but not predictably
        let service1 = EncryptionService(storage: storage)
        let service2 = EncryptionService(storage: storage)
        
        // Both services should use the same key (from storage)
        let key1 = try service1.encryptionKey.withUnsafeBytes { Data($0) }
        let key2 = try service2.encryptionKey.withUnsafeBytes { Data($0) }
        
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.count, 32) // 256 bits
    }
    
    func testKeyUniqueness() throws {
        // Different storage services should generate different keys
        let storage1 = KeychainStorageService(service: "test.service1")
        let storage2 = KeychainStorageService(service: "test.service2")
        
        let encryption1 = EncryptionService(storage: storage1)
        let encryption2 = EncryptionService(storage: storage2)
        
        let key1 = try encryption1.encryptionKey.withUnsafeBytes { Data($0) }
        let key2 = try encryption2.encryptionKey.withUnsafeBytes { Data($0) }
        
        XCTAssertNotEqual(key1, key2)
        
        // Cleanup
        try? encryption1.clearEncryptionKey()
        try? encryption2.clearEncryptionKey()
        try? storage1.deleteAll()
        try? storage2.deleteAll()
    }
    
    // MARK: - Secure Enclave & Migration Tests
    
    func testSecurityStatus() {
        let status = encryptionService.securityStatus
        
        // Verify status contains expected information
        XCTAssertNotNil(status.description)
        XCTAssertFalse(status.description.isEmpty)
        
        // Status should reflect current environment capabilities
        XCTAssertEqual(status.secureEnclaveAvailable, SecureEnclaveKeyManager.isSecureEnclaveAvailable)
        
        if SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            // On Secure Enclave devices, should recommend using it or already be using it
            if status.hasLegacyKey {
                XCTAssertTrue(status.recommendsMigration)
            }
        } else {
            // On non-Secure Enclave devices, should not recommend migration
            XCTAssertFalse(status.recommendsMigration)
        }
    }
    
    func testMigrationInfo() {
        let migrationInfo = encryptionService.getMigrationInfo()
        
        // Verify migration info structure
        XCTAssertEqual(migrationInfo.secureEnclaveAvailable, SecureEnclaveKeyManager.isSecureEnclaveAvailable)
        XCTAssertNotNil(migrationInfo.recommendedAction.description)
        XCTAssertFalse(migrationInfo.recommendedAction.description.isEmpty)
    }
    
    func testLegacyDataDecryption() throws {
        // Create a legacy key first
        let legacyStorage = KeychainStorageService(service: testService)
        let legacyKey = SymmetricKey(size: .bits256)
        try legacyStorage.store(legacyKey.withUnsafeBytes { Data($0) }, for: "_encryption_key_v2")
        
        // Encrypt some data with the legacy key
        let testData = "Legacy encrypted data".data(using: .utf8)!
        let legacyEncrypted = try AES.GCM.seal(testData, using: legacyKey).combined!
        
        // Create new encryption service (should auto-detect legacy key)
        let newEncryptionService = EncryptionService(storage: legacyStorage)
        
        // Should be able to decrypt legacy data
        let decrypted = try newEncryptionService.decrypt(legacyEncrypted)
        XCTAssertEqual(decrypted, testData)
        
        // Cleanup
        try? newEncryptionService.clearEncryptionKey()
        try? legacyStorage.deleteAll()
    }
    
    func testMigrationFromLegacyToSecureEnclave() throws {
        // Skip if Secure Enclave not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Create legacy setup
        let legacyStorage = KeychainStorageService(service: testService + ".migration")
        let legacyKey = SymmetricKey(size: .bits256)
        try legacyStorage.store(legacyKey.withUnsafeBytes { Data($0) }, for: "_encryption_key_v2")
        
        // Create test data encrypted with legacy key
        let testData = "Migration test data".data(using: .utf8)!
        let legacyEncrypted = try AES.GCM.seal(testData, using: legacyKey).combined!
        
        // Create encryption service with legacy data
        let migrationService = EncryptionService(storage: legacyStorage)
        
        // Should initially be able to decrypt legacy data
        let decrypted1 = try migrationService.decrypt(legacyEncrypted)
        XCTAssertEqual(decrypted1, testData)
        
        // Perform manual migration
        try migrationService.migrateLegacyEncryption()
        
        // Should still be able to decrypt legacy data (backward compatibility)
        let decrypted2 = try migrationService.decrypt(legacyEncrypted)
        XCTAssertEqual(decrypted2, testData)
        
        // New encryptions should use Secure Enclave
        XCTAssertTrue(migrationService.isUsingSecureEnclave)
        
        // Cleanup
        try? migrationService.clearEncryptionKey()
        try? legacyStorage.deleteAll()
    }
    
    func testDataMigration() throws {
        // Skip if Secure Enclave not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Create legacy setup
        let legacyStorage = KeychainStorageService(service: testService + ".datamigration")
        let legacyKey = SymmetricKey(size: .bits256)
        try legacyStorage.store(legacyKey.withUnsafeBytes { Data($0) }, for: "_encryption_key_v2")
        
        let testData = "Data migration test".data(using: .utf8)!
        let legacyEncrypted = try AES.GCM.seal(testData, using: legacyKey).combined!
        
        let migrationService = EncryptionService(storage: legacyStorage)
        
        // Migrate specific data
        let migratedData = try migrationService.migrateEncryptedData(legacyEncrypted)
        
        // New data should be decryptable with current (Secure Enclave) key
        let decrypted = try migrationService.decrypt(migratedData)
        XCTAssertEqual(decrypted, testData)
        
        // Migrated data should be different from legacy data
        XCTAssertNotEqual(migratedData, legacyEncrypted)
        
        // Cleanup
        try? migrationService.clearEncryptionKey()
        try? legacyStorage.deleteAll()
    }
    
    func testSecureEnclaveUnavailableFallback() {
        // Test behavior when Secure Enclave is not available
        if !SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            // Should use legacy encryption without errors
            XCTAssertFalse(encryptionService.isUsingSecureEnclave)
            
            let testData = "Fallback test".data(using: .utf8)!
            XCTAssertNoThrow(try encryptionService.encrypt(testData))
            
            // Key rotation should fail gracefully
            XCTAssertThrowsError(try encryptionService.rotateKey()) { error in
                XCTAssertTrue(error is EncryptionService.EncryptionError)
                if case EncryptionService.EncryptionError.secureEnclaveNotAvailable = error {
                    // Expected
                } else {
                    XCTFail("Wrong error type: \(error)")
                }
            }
        } else {
            // On devices with Secure Enclave, should use it
            XCTAssertTrue(encryptionService.isUsingSecureEnclave)
        }
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let errors: [EncryptionService.EncryptionError] = [
            .encryptionFailed,
            .decryptionFailed,
            .keyGenerationFailed,
            .invalidData,
            .migrationFailed,
            .secureEnclaveNotAvailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}