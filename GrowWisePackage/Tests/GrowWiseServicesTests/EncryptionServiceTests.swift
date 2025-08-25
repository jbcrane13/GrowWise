import XCTest
import CryptoKit
@testable import GrowWiseServices

/// Unit tests for EncryptionService - AES-256-GCM encryption operations
final class EncryptionServiceTests: XCTestCase {
    
    var storage: KeychainStorageService!
    var encryptionService: EncryptionService!
    private let testService = "com.growwiser.encryption.test"
    
    override func setUp() {
        super.setUp()
        storage = KeychainStorageService(service: testService)
        encryptionService = EncryptionService(storage: storage)
        
        // Clean up any existing test data
        try? storage.deleteAll()
    }
    
    override func tearDown() {
        // Clean up after tests
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
        
        // Should still return true because key is lazily regenerated
        XCTAssertTrue(encryptionService.hasEncryptionKey)
    }
    
    func testKeyRotation() throws {
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
        
        // Cannot decrypt old data with new key
        XCTAssertThrowsError(try encryptionService.decrypt(encryptedWithOriginalKey))
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
    
    func testDeterministicKeyGeneration() {
        // Keys should be generated consistently but not predictably
        let service1 = EncryptionService(storage: storage)
        let service2 = EncryptionService(storage: storage)
        
        // Both services should use the same key (from storage)
        let key1 = service1.encryptionKey.withUnsafeBytes { Data($0) }
        let key2 = service2.encryptionKey.withUnsafeBytes { Data($0) }
        
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.count, 32) // 256 bits
    }
    
    func testKeyUniqueness() {
        // Different storage services should generate different keys
        let storage1 = KeychainStorageService(service: "test.service1")
        let storage2 = KeychainStorageService(service: "test.service2")
        
        let encryption1 = EncryptionService(storage: storage1)
        let encryption2 = EncryptionService(storage: storage2)
        
        let key1 = encryption1.encryptionKey.withUnsafeBytes { Data($0) }
        let key2 = encryption2.encryptionKey.withUnsafeBytes { Data($0) }
        
        XCTAssertNotEqual(key1, key2)
        
        // Cleanup
        try? storage1.deleteAll()
        try? storage2.deleteAll()
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let errors: [EncryptionService.EncryptionError] = [
            .encryptionFailed,
            .decryptionFailed,
            .keyGenerationFailed,
            .invalidData
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}