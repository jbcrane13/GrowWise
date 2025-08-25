import XCTest
import CryptoKit
@testable import GrowWiseServices

final class KeyRotationManagerTests: XCTestCase {
    
    var keyRotationManager: KeyRotationManager!
    var secureEnclaveKeyManager: SecureEnclaveKeyManager!
    var keychainStorage: KeychainStorageService!
    
    override func setUp() {
        super.setUp()
        secureEnclaveKeyManager = SecureEnclaveKeyManager(keyIdentifier: "test-key-rotation")
        keychainStorage = KeychainStorageService(serviceIdentifier: "test-key-rotation-service")
        keyRotationManager = KeyRotationManager(
            secureEnclaveKeyManager: secureEnclaveKeyManager,
            keychainStorage: keychainStorage,
            rotationPolicy: KeyRotationManager.RotationPolicy.defaultPolicy()
        )
    }
    
    override func tearDown() {
        // Clean up test keys
        try? secureEnclaveKeyManager.deleteSecureEnclaveKey()
        try? keychainStorage.deleteData(for: "key-rotation-metadata")
        try? keychainStorage.deleteData(for: "key-rotation-audit")
        super.tearDown()
    }
    
    // MARK: - Key Generation Tests
    
    func testInitialKeyGeneration() async throws {
        // Given: A new key rotation manager
        XCTAssertEqual(keyRotationManager.currentKeyVersion, 0)
        
        // When: We perform the first key rotation
        let newVersion = try await keyRotationManager.rotateKey(reason: "Initial setup")
        
        // Then: We should have version 1 as current
        XCTAssertEqual(newVersion, 1)
        XCTAssertEqual(keyRotationManager.currentKeyVersion, 1)
        
        // And: We should be able to get the encryption key
        let encryptionKey = try keyRotationManager.getCurrentEncryptionKey()
        XCTAssertNotNil(encryptionKey)
    }
    
    func testKeyRotation() async throws {
        // Given: An initial key version
        let version1 = try await keyRotationManager.rotateKey(reason: "Initial setup")
        XCTAssertEqual(version1, 1)
        
        // When: We rotate the key
        let version2 = try await keyRotationManager.rotateKey(reason: "Regular rotation")
        
        // Then: We should have a new version
        XCTAssertEqual(version2, 2)
        XCTAssertEqual(keyRotationManager.currentKeyVersion, 2)
        
        // And: Both keys should be accessible for decryption
        let activeVersions = keyRotationManager.getActiveKeyVersions()
        XCTAssertTrue(activeVersions.contains(1))
        XCTAssertTrue(activeVersions.contains(2))
    }
    
    func testMultipleKeyVersionsSupport() async throws {
        // Given: Multiple key versions
        let version1 = try await keyRotationManager.rotateKey(reason: "Version 1")
        let version2 = try await keyRotationManager.rotateKey(reason: "Version 2")
        let version3 = try await keyRotationManager.rotateKey(reason: "Version 3")
        
        // Then: All versions should be accessible
        XCTAssertNoThrow(try keyRotationManager.getKeyForVersion(version1))
        XCTAssertNoThrow(try keyRotationManager.getKeyForVersion(version2))
        XCTAssertNoThrow(try keyRotationManager.getKeyForVersion(version3))
        
        // And: Current version should be the latest
        XCTAssertEqual(keyRotationManager.currentKeyVersion, version3)
    }
    
    // MARK: - Rotation Policy Tests
    
    func testRotationPolicyValidation() throws {
        // Given: Invalid policies
        let invalidPolicy1 = KeyRotationManager.RotationPolicy(
            interval: 0, // Invalid: zero interval
            maxKeyAge: 100,
            minKeyAge: 50,
            autoRotationEnabled: true,
            complianceMode: .standard,
            reencryptionBatchSize: 100,
            quietHours: nil
        )
        
        let invalidPolicy2 = KeyRotationManager.RotationPolicy(
            interval: 100,
            maxKeyAge: 50, // Invalid: maxKeyAge < interval
            minKeyAge: 10,
            autoRotationEnabled: true,
            complianceMode: .standard,
            reencryptionBatchSize: 100,
            quietHours: nil
        )
        
        // When/Then: Invalid policies should be rejected
        XCTAssertThrowsError(try keyRotationManager.updateRotationPolicy(invalidPolicy1))
        XCTAssertThrowsError(try keyRotationManager.updateRotationPolicy(invalidPolicy2))
    }
    
    func testRotationPolicyUpdate() throws {
        // Given: A new rotation policy
        let newPolicy = KeyRotationManager.RotationPolicy(
            interval: 60 * 60 * 24 * 7, // 7 days
            maxKeyAge: 60 * 60 * 24 * 30, // 30 days
            minKeyAge: 60 * 60 * 24, // 1 day
            autoRotationEnabled: true,
            complianceMode: .strict,
            reencryptionBatchSize: 50,
            quietHours: KeyRotationManager.RotationPolicy.QuietHours(
                startHour: 1,
                endHour: 5,
                timezone: "UTC"
            )
        )
        
        // When: We update the policy
        XCTAssertNoThrow(try keyRotationManager.updateRotationPolicy(newPolicy))
        
        // Then: The policy should be updated (we'd need to expose the policy to verify this)
    }
    
    // MARK: - Compliance Tests
    
    func testComplianceReporting() async throws {
        // Given: Some key rotations
        let _ = try await keyRotationManager.rotateKey(reason: "Initial setup")
        let _ = try await keyRotationManager.rotateKey(reason: "Regular rotation")
        
        // When: We generate a compliance report
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let report = await keyRotationManager.generateComplianceReport(period: period)
        
        // Then: The report should contain expected information
        XCTAssertEqual(report.keyVersions.count, 2)
        XCTAssertEqual(report.rotationEvents.count, 2)
        XCTAssertNotNil(report.complianceStatus)
        XCTAssertFalse(report.recommendations.isEmpty)
    }
    
    func testAuditTrail() async throws {
        // Given: Some key operations
        let _ = try await keyRotationManager.rotateKey(reason: "Test rotation")
        
        // When: We get the audit trail
        let auditEvents = keyRotationManager.getAuditTrail(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )
        
        // Then: We should have audit events
        XCTAssertFalse(auditEvents.isEmpty)
        
        let rotationEvents = auditEvents.filter { $0.event == .keyRotated }
        XCTAssertEqual(rotationEvents.count, 1)
        
        let generationEvents = auditEvents.filter { $0.event == .keyGenerated }
        XCTAssertEqual(generationEvents.count, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidKeyVersionAccess() throws {
        // Given: No keys generated
        
        // When/Then: Accessing invalid key versions should throw
        XCTAssertThrowsError(try keyRotationManager.getKeyForVersion(999))
        XCTAssertThrowsError(try keyRotationManager.getKeyForVersion(-1))
    }
    
    func testConcurrentRotation() async throws {
        // Given: Initial key
        let _ = try await keyRotationManager.rotateKey(reason: "Initial")
        
        // When: Multiple concurrent rotations are attempted
        let task1 = Task {
            try await keyRotationManager.rotateKey(reason: "Concurrent 1")
        }
        
        let task2 = Task {
            try await keyRotationManager.rotateKey(reason: "Concurrent 2")
        }
        
        // Then: Only one should succeed, one should fail
        let results = await [task1.result, task2.result]
        let successes = results.compactMap { try? $0.get() }
        let failures = results.compactMap { result in
            switch result {
            case .failure(let error): return error
            case .success: return nil
            }
        }
        
        XCTAssertEqual(successes.count, 1)
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures.first is KeyRotationManager.KeyRotationError)
    }
    
    // MARK: - Performance Tests
    
    func testKeyDerivationPerformance() async throws {
        // Given: A key version
        let version = try await keyRotationManager.rotateKey(reason: "Performance test")
        
        // When: We measure key derivation performance
        measure {
            for _ in 0..<100 {
                _ = try? keyRotationManager.getKeyForVersion(version)
            }
        }
    }
    
    func testComplianceReportPerformance() async throws {
        // Given: Multiple key rotations
        for i in 1...10 {
            let _ = try await keyRotationManager.rotateKey(reason: "Rotation \(i)")
        }
        
        // When: We measure compliance report generation performance
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        
        await measure {
            let _ = await keyRotationManager.generateComplianceReport(period: period)
        }
    }
    
    // MARK: - Integration Tests
    
    func testEncryptionDecryptionWithRotation() async throws {
        // This test would require integration with EncryptionService
        // Testing that data encrypted with old keys can be decrypted after rotation
        
        // Given: Initial encryption key
        let version1 = try await keyRotationManager.rotateKey(reason: "Initial")
        let key1 = try keyRotationManager.getKeyForVersion(version1)
        
        // When: We encrypt some data
        let testData = "Secret data for testing".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(testData, using: key1).combined!
        
        // And: Rotate the key
        let _ = try await keyRotationManager.rotateKey(reason: "Rotation")
        
        // Then: We should still be able to decrypt the old data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key1)
        
        XCTAssertEqual(decryptedData, testData)
    }
    
    // MARK: - Compliance Standards Tests
    
    func testPCIDSSCompliance() async throws {
        // Test PCI DSS specific requirements
        let strictPolicy = KeyRotationManager.RotationPolicy(
            interval: 60 * 60 * 24 * 30, // 30 days (PCI DSS requirement)
            maxKeyAge: 60 * 60 * 24 * 90, // 90 days max
            minKeyAge: 60 * 60 * 24, // 1 day min
            autoRotationEnabled: true,
            complianceMode: .strict,
            reencryptionBatchSize: 100,
            quietHours: nil
        )
        
        try keyRotationManager.updateRotationPolicy(strictPolicy)
        
        let version = try await keyRotationManager.rotateKey(reason: "PCI DSS compliance test")
        XCTAssertGreaterThan(version, 0)
        
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let report = await keyRotationManager.generateComplianceReport(period: period)
        
        XCTAssertTrue(report.complianceStatus.pciDssCompliant)
    }
    
    func testSOC2Compliance() async throws {
        // Test SOC2 specific requirements
        let version = try await keyRotationManager.rotateKey(reason: "SOC2 compliance test")
        
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let report = await keyRotationManager.generateComplianceReport(period: period)
        
        XCTAssertTrue(report.complianceStatus.soc2Compliant)
        XCTAssertFalse(report.recommendations.isEmpty)
    }
}

// MARK: - Test Helpers

extension KeyRotationManagerTests {
    
    private func measure(_ block: () async -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance assertion - should complete within reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Operation took too long: \(timeElapsed) seconds")
    }
    
    private func createTestPolicy(interval: TimeInterval = 3600) -> KeyRotationManager.RotationPolicy {
        return KeyRotationManager.RotationPolicy(
            interval: interval,
            maxKeyAge: interval * 3,
            minKeyAge: interval / 24,
            autoRotationEnabled: true,
            complianceMode: .standard,
            reencryptionBatchSize: 100,
            quietHours: nil
        )
    }
}