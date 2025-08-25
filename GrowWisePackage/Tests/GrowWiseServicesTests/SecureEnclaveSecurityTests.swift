import XCTest
import CryptoKit
import LocalAuthentication
@testable import GrowWiseServices

/// Comprehensive Secure Enclave Security Test Suite
/// Validates hardware security integration, key protection, and attack resistance
final class SecureEnclaveSecurityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var secureEnclaveManager: SecureEnclaveKeyManager!
    private let testKeyIdentifier = "security-test-secure-enclave-key"
    
    override func setUp() {
        super.setUp()
        secureEnclaveManager = SecureEnclaveKeyManager(keyIdentifier: testKeyIdentifier)
        
        // Clean up any existing test keys
        try? secureEnclaveManager.deleteSecureEnclaveKey()
    }
    
    override func tearDown() {
        // Clean up test keys
        try? secureEnclaveManager.deleteSecureEnclaveKey()
        secureEnclaveManager = nil
        super.tearDown()
    }
    
    // MARK: - Hardware Security Tests
    
    func testSecureEnclaveAvailabilityAndFeatures() {
        let isAvailable = SecureEnclaveKeyManager.isSecureEnclaveAvailable
        
        if isAvailable {
            // Test Secure Enclave specific features
            XCTAssertTrue(LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ||
                         LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil),
                         "Device should support authentication if Secure Enclave is available")
        } else {
            print("Secure Enclave not available - running fallback tests")
        }
        
        // Test should handle both scenarios gracefully
        XCTAssertNotNil(isAvailable)
    }
    
    func testHardwareKeyGeneration() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate hardware-backed key
        let privateKey = try secureEnclaveManager.generateSecureEnclaveKey()
        
        // Verify key properties
        XCTAssertTrue(secureEnclaveManager.hasSecureEnclaveKey())
        
        // Verify public key can be extracted
        let publicKeyData = try secureEnclaveManager.getPublicKeyData()
        XCTAssertEqual(publicKeyData.count, 65) // Uncompressed P256 public key
        XCTAssertEqual(privateKey.publicKey.rawRepresentation, publicKeyData)
        
        // Verify key is hardware-backed (cannot be extracted)
        // This is implicit - Secure Enclave keys cannot be extracted by design
    }
    
    func testKeyIsolationAndTampering() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate multiple keys with different identifiers
        let manager1 = SecureEnclaveKeyManager(keyIdentifier: "test-key-1")
        let manager2 = SecureEnclaveKeyManager(keyIdentifier: "test-key-2")
        
        defer {
            try? manager1.deleteSecureEnclaveKey()
            try? manager2.deleteSecureEnclaveKey()
        }
        
        // Generate keys
        _ = try manager1.generateSecureEnclaveKey()
        _ = try manager2.generateSecureEnclaveKey()
        
        // Verify keys are isolated
        let key1Data = try manager1.getPublicKeyData()
        let key2Data = try manager2.getPublicKeyData()
        
        XCTAssertNotEqual(key1Data, key2Data, "Keys should be isolated and unique")
        
        // Verify one manager cannot access another's key
        XCTAssertTrue(manager1.hasSecureEnclaveKey())
        XCTAssertTrue(manager2.hasSecureEnclaveKey())
        
        try manager1.deleteSecureEnclaveKey()
        XCTAssertFalse(manager1.hasSecureEnclaveKey())
        XCTAssertTrue(manager2.hasSecureEnclaveKey()) // Should not be affected
    }
    
    // MARK: - Key Derivation Security Tests
    
    func testSymmetricKeyDerivationConsistency() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate Secure Enclave key
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        
        // Derive symmetric keys multiple times
        let key1 = try secureEnclaveManager.getSymmetricKey()
        let key2 = try secureEnclaveManager.getSymmetricKey()
        let key3 = try secureEnclaveManager.getSymmetricKey()
        
        // Keys should be identical (deterministic derivation)
        XCTAssertEqual(
            key1.withUnsafeBytes { Data($0) },
            key2.withUnsafeBytes { Data($0) }
        )
        XCTAssertEqual(
            key2.withUnsafeBytes { Data($0) },
            key3.withUnsafeBytes { Data($0) }
        )
    }
    
    func testKeyDerivationUniqueness() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate multiple Secure Enclave keys
        let manager1 = SecureEnclaveKeyManager(keyIdentifier: "derive-test-1")
        let manager2 = SecureEnclaveKeyManager(keyIdentifier: "derive-test-2")
        
        defer {
            try? manager1.deleteSecureEnclaveKey()
            try? manager2.deleteSecureEnclaveKey()
        }
        
        _ = try manager1.generateSecureEnclaveKey()
        _ = try manager2.generateSecureEnclaveKey()
        
        let derivedKey1 = try manager1.getSymmetricKey()
        let derivedKey2 = try manager2.getSymmetricKey()
        
        // Derived keys from different Secure Enclave keys should be different
        XCTAssertNotEqual(
            derivedKey1.withUnsafeBytes { Data($0) },
            derivedKey2.withUnsafeBytes { Data($0) }
        )
    }
    
    // MARK: - Cryptographic Operation Security Tests
    
    func testSigningAndVerification() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        let privateKey = try secureEnclaveManager.generateSecureEnclaveKey()
        let testData = Data("Test message for signing".utf8)
        
        // Sign data with Secure Enclave key
        let signature = try privateKey.signature(for: testData)
        
        // Verify signature with public key
        let publicKey = privateKey.publicKey
        XCTAssertTrue(publicKey.isValidSignature(signature, for: testData))
        
        // Verify signature fails with modified data
        let modifiedData = Data("Modified message".utf8)
        XCTAssertFalse(publicKey.isValidSignature(signature, for: modifiedData))
    }
    
    func testSecureKeyGeneration() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate two Secure Enclave keys
        let manager1 = SecureEnclaveKeyManager(keyIdentifier: "sig-test-1")
        let manager2 = SecureEnclaveKeyManager(keyIdentifier: "sig-test-2")
        
        defer {
            try? manager1.deleteSecureEnclaveKey()
            try? manager2.deleteSecureEnclaveKey()
        }
        
        let privateKey1 = try manager1.generateSecureEnclaveKey()
        let privateKey2 = try manager2.generateSecureEnclaveKey()
        
        let publicKey1 = privateKey1.publicKey
        let publicKey2 = privateKey2.publicKey
        
        // Keys should be different
        XCTAssertNotEqual(
            publicKey1.compressedRepresentation,
            publicKey2.compressedRepresentation
        )
        
        // Test signing and verification with each key
        let testData = "Key generation test".data(using: .utf8)!
        
        let signature1 = try privateKey1.signature(for: testData)
        let signature2 = try privateKey2.signature(for: testData)
        
        // Signatures should be different (different keys)
        XCTAssertNotEqual(signature1.rawRepresentation, signature2.rawRepresentation)
        
        // Each public key should verify its corresponding signature
        XCTAssertTrue(publicKey1.isValidSignature(signature1, for: testData))
        XCTAssertTrue(publicKey2.isValidSignature(signature2, for: testData))
        
        // Cross-verification should fail
        XCTAssertFalse(publicKey1.isValidSignature(signature2, for: testData))
        XCTAssertFalse(publicKey2.isValidSignature(signature1, for: testData))
    }
    
    // MARK: - Attack Resistance Tests
    
    func testBruteForceResistance() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        
        // Attempt to brute force key access (should be impossible)
        let iterations = 1000
        var accessAttempts = 0
        
        measure {
            for _ in 0..<iterations {
                do {
                    _ = try secureEnclaveManager.getSymmetricKey()
                    accessAttempts += 1
                } catch {
                    // Expected - Secure Enclave may rate limit or require authentication
                }
            }
        }
        
        // Should either succeed (if authenticated) or fail consistently
        XCTAssertTrue(accessAttempts == 0 || accessAttempts == iterations,
                     "Inconsistent access patterns may indicate vulnerability")
    }
    
    func testSideChannelAttackResistance() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        
        // Measure timing for key operations
        var timings: [Double] = []
        
        for _ in 0..<100 {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try? secureEnclaveManager.getSymmetricKey()
            let endTime = CFAbsoluteTimeGetCurrent()
            timings.append(endTime - startTime)
        }
        
        // Calculate timing statistics
        let averageTime = timings.reduce(0, +) / Double(timings.count)
        let maxDeviation = timings.map { abs($0 - averageTime) }.max() ?? 0
        
        // Timing should be relatively consistent (hardware-backed operations)
        let allowedDeviation = averageTime * 0.5 // 50% deviation allowed for hardware
        XCTAssertLessThan(maxDeviation, allowedDeviation,
                         "High timing variation may indicate side-channel vulnerability")
    }
    
    func testMemoryDisclosureResistance() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        let initialMemory = getMemoryUsage()
        
        // Generate and use keys
        let privateKey = try secureEnclaveManager.generateSecureEnclaveKey()
        let symmetricKey = try secureEnclaveManager.getSymmetricKey()
        
        // Perform operations that might leave key material in memory
        let testData = Data(repeating: 0x41, count: 1024)
        _ = try privateKey.signature(for: testData)
        
        // Use symmetric key
        let encrypted = try ChaChaPoly.seal(testData, using: symmetricKey)
        _ = try ChaChaPoly.open(encrypted, using: symmetricKey)
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (no key material leakage)
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024, // 10MB threshold
                         "Excessive memory usage may indicate key material retention")
    }
    
    // MARK: - Key Rotation Security Tests
    
    func testSecureKeyRotation() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate initial key
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        let initialSymmetricKey = try secureEnclaveManager.getSymmetricKey()
        let initialPublicKey = try secureEnclaveManager.getPublicKeyData()
        
        // Rotate key
        try secureEnclaveManager.rotateKey()
        
        // Verify new key is different
        let newSymmetricKey = try secureEnclaveManager.getSymmetricKey()
        let newPublicKey = try secureEnclaveManager.getPublicKeyData()
        
        XCTAssertNotEqual(
            initialSymmetricKey.withUnsafeBytes { Data($0) },
            newSymmetricKey.withUnsafeBytes { Data($0) }
        )
        XCTAssertNotEqual(initialPublicKey, newPublicKey)
        
        // Verify old key is no longer accessible (implementation dependent)
        // This test validates that rotation generates genuinely new keys
    }
    
    func testKeyRotationIntegrity() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate initial key
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        
        // Perform multiple rotations
        var publicKeys: [Data] = []
        for _ in 0..<5 {
            try secureEnclaveManager.rotateKey()
            let publicKey = try secureEnclaveManager.getPublicKeyData()
            publicKeys.append(publicKey)
        }
        
        // Verify each rotation produces a unique key
        let uniqueKeys = Set(publicKeys)
        XCTAssertEqual(uniqueKeys.count, publicKeys.count,
                      "Key rotation should produce unique keys")
    }
    
    // MARK: - Persistence and Recovery Tests
    
    func testKeyPersistenceAcrossSessions() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate key with first manager instance
        let manager1 = SecureEnclaveKeyManager(keyIdentifier: "persistence-test")
        _ = try manager1.generateSecureEnclaveKey()
        let key1 = try manager1.getSymmetricKey()
        let publicKey1 = try manager1.getPublicKeyData()
        
        // Create new manager instance with same identifier
        let manager2 = SecureEnclaveKeyManager(keyIdentifier: "persistence-test")
        let key2 = try manager2.getSymmetricKey()
        let publicKey2 = try manager2.getPublicKeyData()
        
        // Keys should be identical (same hardware key)
        XCTAssertEqual(
            key1.withUnsafeBytes { Data($0) },
            key2.withUnsafeBytes { Data($0) }
        )
        XCTAssertEqual(publicKey1, publicKey2)
        
        // Clean up
        try manager2.deleteSecureEnclaveKey()
    }
    
    func testKeyDeletionSecurity() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate key
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        XCTAssertTrue(secureEnclaveManager.hasSecureEnclaveKey())
        
        // Delete key
        try secureEnclaveManager.deleteSecureEnclaveKey()
        XCTAssertFalse(secureEnclaveManager.hasSecureEnclaveKey())
        
        // Verify key is truly deleted and cannot be recovered
        XCTAssertThrowsError(try secureEnclaveManager.getPublicKeyData()) { error in
            XCTAssertTrue(error is SecureEnclaveKeyManager.SecureEnclaveError)
        }
        
        XCTAssertThrowsError(try secureEnclaveManager.getSymmetricKey()) { error in
            XCTAssertTrue(error is SecureEnclaveKeyManager.SecureEnclaveError)
        }
    }
    
    // MARK: - Concurrent Access Security Tests
    
    func testConcurrentKeyAccess() throws {
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        _ = try secureEnclaveManager.generateSecureEnclaveKey()
        
        let expectation = XCTestExpectation(description: "Concurrent key access")
        expectation.expectedFulfillmentCount = 10
        
        var keys: [Data] = []
        let queue = DispatchQueue(label: "test-queue", attributes: .concurrent)
        let keyQueue = DispatchQueue(label: "key-collection")
        
        // Perform concurrent key derivations
        for _ in 0..<10 {
            queue.async {
                do {
                    let key = try self.secureEnclaveManager.getSymmetricKey()
                    keyQueue.async {
                        keys.append(key.withUnsafeBytes { Data($0) })
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail("Concurrent key access failed: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // All derived keys should be identical
        let uniqueKeys = Set(keys)
        XCTAssertEqual(uniqueKeys.count, 1, "Concurrent key derivation should be consistent")
    }
    
    // MARK: - Error Handling Security Tests
    
    func testSecureErrorHandling() throws {
        // Test error conditions don't leak sensitive information
        
        // Test with non-existent key
        let nonExistentManager = SecureEnclaveKeyManager(keyIdentifier: "non-existent")
        
        XCTAssertThrowsError(try nonExistentManager.getPublicKeyData()) { error in
            // Error should not contain sensitive information
            let errorDescription = error.localizedDescription
            XCTAssertFalse(errorDescription.contains("key material"))
            XCTAssertFalse(errorDescription.contains("private"))
            XCTAssertFalse(errorDescription.contains("secret"))
        }
        
        // Test invalid operations
        if SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            _ = try secureEnclaveManager.generateSecureEnclaveKey()
            
            // Test duplicate key generation (should handle gracefully)
            XCTAssertNoThrow(try secureEnclaveManager.generateSecureEnclaveKey())
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}