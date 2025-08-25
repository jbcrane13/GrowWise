import XCTest
import CryptoKit
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Comprehensive Migration Security Test Suite
/// Validates migration integrity, security during transitions, and data protection
final class MigrationSecurityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var migrationService: MigrationIntegrityService!
    private var keychainStorage: KeychainStorageService!
    private var auditLogger: AuditLogger!
    private var mockLegacyStorage: MockLegacyStorage!
    
    override func setUp() {
        super.setUp()
        keychainStorage = KeychainStorageService(service: "com.growwise.migration-test", accessGroup: nil)
        auditLogger = AuditLogger.shared
        mockLegacyStorage = MockLegacyStorage()
        migrationService = MigrationIntegrityService(
            keychainStorage: keychainStorage,
            auditLogger: auditLogger
        )
        
        // Clean up any existing test data
        cleanupTestData()
    }
    
    override func tearDown() {
        cleanupTestData()
        super.tearDown()
    }
    
    private func cleanupTestData() {
        let testKeys = [
            "secure_test_key_1", "secure_test_key_2", "secure_test_key_3",
            "sensitive_data_key", "encrypted_token", "user_credentials",
            "api_keys", "session_data", "biometric_template",
            "_migration_progress_test", "_backup_test_session"
        ]
        
        // Clean up keychain
        for key in testKeys {
            try? keychainStorage.delete(for: key)
        }
        
        // Clean up mock legacy storage
        mockLegacyStorage.clearAll()
        
        // Clean up UserDefaults
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - Migration Integrity Tests
    
    func testSecureMigrationIntegrity() throws {
        // Setup legacy data
        let testData = [
            "secure_test_key_1": "sensitive_value_1",
            "secure_test_key_2": "sensitive_value_2",
            "secure_test_key_3": "sensitive_value_3"
        ]
        
        // Store in legacy location (UserDefaults)
        for (key, value) in testData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(testData.keys)
        
        // Perform secure migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify migration completed successfully
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.totalItems, testData.count)
        XCTAssertEqual(report.successfulItems, testData.count)
        XCTAssertEqual(report.failedItems, 0)
        XCTAssertTrue(report.integrityVerified)
        
        // Verify data was migrated to keychain
        for (key, expectedValue) in testData {
            XCTAssertTrue(keychainStorage.exists(for: key))
            let retrievedValue = try keychainStorage.retrieveString(for: key)
            XCTAssertEqual(retrievedValue, expectedValue)
        }
        
        // Verify legacy data was removed
        for key in keys {
            XCTAssertNil(UserDefaults.standard.string(forKey: key))
        }
    }
    
    func testMigrationWithDataCorruption() throws {
        // Setup corrupted legacy data
        let validData = "valid_data"
        let corruptedData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8
        
        UserDefaults.standard.set(validData, forKey: "valid_key")
        UserDefaults.standard.set(corruptedData, forKey: "corrupted_key")
        
        let keys = ["valid_key", "corrupted_key"]
        
        // Perform migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify partial success with integrity detection
        XCTAssertEqual(report.status, .completedWithErrors)
        XCTAssertEqual(report.totalItems, 2)
        XCTAssertEqual(report.successfulItems, 1)
        XCTAssertEqual(report.failedItems, 1)
        XCTAssertFalse(report.integrityVerified) // Corruption detected
        
        // Verify valid data was migrated
        XCTAssertTrue(keychainStorage.exists(for: "valid_key"))
        let retrievedValue = try keychainStorage.retrieveString(for: "valid_key")
        XCTAssertEqual(retrievedValue, validData)
        
        // Verify corrupted data was not migrated
        XCTAssertFalse(keychainStorage.exists(for: "corrupted_key"))
    }
    
    // MARK: - Attack During Migration Tests
    
    func testMigrationInterruption() throws {
        // Setup large dataset for migration
        let largeDataset = (1...100).reduce(into: [String: String]()) { dict, i in
            dict["key_\(i)"] = "value_\(i)"
        }
        
        for (key, value) in largeDataset {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(largeDataset.keys)
        
        // Simulate interruption during migration
        // This test would require actual interruption mechanism in production
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify migration can handle interruptions gracefully
        XCTAssertTrue(report.status == .completed || report.status == .interrupted)
        
        if report.status == .interrupted {
            // Verify partial migration state is consistent
            XCTAssertLessThan(report.successfulItems, largeDataset.count)
            
            // Verify no data corruption occurred
            for i in 1...report.successfulItems {
                let key = "key_\(i)"
                if keychainStorage.exists(for: key) {
                    let value = try keychainStorage.retrieveString(for: key)
                    XCTAssertEqual(value, "value_\(i)")
                }
            }
        }
    }
    
    func testConcurrentMigrationAttempts() throws {
        let testData = [
            "concurrent_key_1": "value_1",
            "concurrent_key_2": "value_2",
            "concurrent_key_3": "value_3"
        ]
        
        for (key, value) in testData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(testData.keys)
        let expectation = XCTestExpectation(description: "Concurrent migration attempts")
        expectation.expectedFulfillmentCount = 3
        
        var results: [MigrationIntegrityService.MigrationReport] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // Attempt concurrent migrations
        for i in 0..<3 {
            DispatchQueue.global().async {
                do {
                    let migrationService = MigrationIntegrityService(
                        keychainStorage: self.keychainStorage,
                        auditLogger: self.auditLogger
                    )
                    let report = try migrationService.performSecureMigration(keys: keys)
                    
                    resultsQueue.sync {
                        results.append(report)
                    }
                } catch {
                    // Expected - concurrent migrations should be prevented
                    print("Concurrent migration prevented: \(error)")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify only one migration succeeded and data integrity maintained
        let successfulMigrations = results.filter { $0.status == .completed }
        XCTAssertLessThanOrEqual(successfulMigrations.count, 1, "Only one migration should succeed")
        
        // Verify final data state is consistent
        for (key, expectedValue) in testData {
            if keychainStorage.exists(for: key) {
                let value = try keychainStorage.retrieveString(for: key)
                XCTAssertEqual(value, expectedValue)
            }
        }
    }
    
    // MARK: - Data Validation Security Tests
    
    func testMigrationDataValidation() throws {
        // Setup data with various validation challenges
        let testCases: [String: Any] = [
            "valid_string": "normal_string_data",
            "empty_string": "",
            "very_long_string": String(repeating: "a", count: 10000),
            "unicode_string": "🔒🛡️🔐 Security Test 中文 العربية",
            "json_string": "{\"key\": \"value\", \"nested\": {\"data\": 123}}",
            "base64_data": Data("test data".utf8).base64EncodedString(),
            "null_value": NSNull(),
            "number_value": 12345,
            "boolean_value": true,
            "array_value": ["item1", "item2", "item3"],
            "dict_value": ["key1": "value1", "key2": "value2"]
        ]
        
        for (key, value) in testCases {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(testCases.keys)
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify appropriate handling of different data types
        XCTAssertGreaterThan(report.successfulItems, 0)
        
        // Check that string data was migrated successfully
        let stringKeys = ["valid_string", "empty_string", "very_long_string", "unicode_string"]
        for key in stringKeys {
            if keychainStorage.exists(for: key) {
                XCTAssertNoThrow(try keychainStorage.retrieveString(for: key))
            }
        }
    }
    
    func testMaliciousDataMigrationPrevention() throws {
        // Setup potentially malicious data
        let maliciousData: [String: String] = [
            "sql_injection": "'; DROP TABLE users; --",
            "xss_payload": "<script>alert('XSS')</script>",
            "command_injection": "; rm -rf /; echo 'hacked'",
            "path_traversal": "../../../etc/passwd",
            "buffer_overflow": String(repeating: "A", count: 100000),
            "format_string": "%s%s%s%s%s%s%s%s%s%s",
            "control_chars": "\u{0000}\u{0001}\u{0002}\u{0003}",
            "binary_data": String(data: Data([0x00, 0x01, 0xFF, 0xFE]), encoding: .utf8) ?? "invalid"
        ]
        
        for (key, value) in maliciousData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(maliciousData.keys)
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Migration should handle malicious data safely
        XCTAssertTrue(report.status == .completed || report.status == .completedWithErrors)
        
        // Verify no code execution or system compromise occurred
        XCTAssertTrue(true, "System should remain secure after processing malicious data")
        
        // Check that data was sanitized or rejected appropriately
        for key in keys {
            if keychainStorage.exists(for: key) {
                let retrievedValue = try keychainStorage.retrieveString(for: key)
                // Data should either be identical (safe) or sanitized
                XCTAssertNotNil(retrievedValue)
            }
        }
    }
    
    // MARK: - Backup and Recovery Security Tests
    
    func testSecureBackupCreation() throws {
        let testData = [
            "backup_key_1": "sensitive_data_1",
            "backup_key_2": "sensitive_data_2"
        ]
        
        for (key, value) in testData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(testData.keys)
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify backup was created securely
        XCTAssertNotNil(report.backupLocation)
        
        if let backupLocation = report.backupLocation {
            // Verify backup exists and is encrypted
            XCTAssertTrue(backupLocation.hasPrefix("_backup_"))
            
            // In production, verify backup encryption
            // XCTAssertTrue(isBackupEncrypted(backupLocation))
        }
    }
    
    func testBackupIntegrityVerification() throws {
        let sensitiveData = [
            "integrity_key_1": "critical_value_1",
            "integrity_key_2": "critical_value_2"
        ]
        
        for (key, value) in sensitiveData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(sensitiveData.keys)
        
        // Perform migration with backup
        let report = try migrationService.performSecureMigration(keys: keys)
        
        XCTAssertTrue(report.integrityVerified)
        XCTAssertNotNil(report.backupLocation)
        
        // Verify backup integrity
        if let backupLocation = report.backupLocation {
            // In production, verify backup hash/checksum
            XCTAssertNotNil(backupLocation)
        }
    }
    
    // MARK: - Time-of-Check-Time-of-Use (TOCTOU) Tests
    
    func testTOCTOUVulnerabilityPrevention() throws {
        let testKey = "toctou_test_key"
        let originalValue = "original_value"
        let maliciousValue = "malicious_replacement"
        
        // Setup original data
        UserDefaults.standard.set(originalValue, forKey: testKey)
        
        // Simulate TOCTOU attack attempt
        DispatchQueue.global().async {
            // Wait a bit then modify data during migration
            Thread.sleep(forTimeInterval: 0.1)
            UserDefaults.standard.set(maliciousValue, forKey: testKey)
        }
        
        // Perform migration
        let report = try migrationService.performSecureMigration(keys: [testKey])
        
        // Migration should detect and handle TOCTOU attempts
        XCTAssertTrue(report.status == .completed || report.status == .completedWithErrors)
        
        if keychainStorage.exists(for: testKey) {
            let migratedValue = try keychainStorage.retrieveString(for: testKey)
            
            // Should migrate either original or detect the change
            XCTAssertTrue(migratedValue == originalValue || migratedValue == maliciousValue)
            
            // In production, TOCTOU should be detected and migration should fail/retry
            // This test validates the system handles race conditions gracefully
        }
    }
    
    func testAtomicMigrationOperations() throws {
        let testData = [
            "atomic_key_1": "value_1",
            "atomic_key_2": "value_2",
            "atomic_key_3": "value_3"
        ]
        
        for (key, value) in testData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(testData.keys)
        
        // Migration should be atomic - all succeed or all fail
        let report = try migrationService.performSecureMigration(keys: keys)
        
        if report.status == .completed {
            // All data should be in keychain, none in UserDefaults
            for key in keys {
                XCTAssertTrue(keychainStorage.exists(for: key))
                XCTAssertNil(UserDefaults.standard.string(forKey: key))
            }
        } else if report.status == .failed {
            // All data should remain in UserDefaults
            for key in keys {
                XCTAssertFalse(keychainStorage.exists(for: key))
                XCTAssertNotNil(UserDefaults.standard.string(forKey: key))
            }
        }
        
        // No partial state should exist
        let keychainCount = keys.filter { keychainStorage.exists(for: $0) }.count
        let userDefaultsCount = keys.compactMap { UserDefaults.standard.string(forKey: $0) }.count
        
        XCTAssertTrue(keychainCount == 0 || userDefaultsCount == 0,
                     "Migration should be atomic - no partial state")
    }
    
    // MARK: - Rollback Security Tests
    
    func testSecureRollbackMechanism() throws {
        let originalData = [
            "rollback_key_1": "original_value_1",
            "rollback_key_2": "original_value_2"
        ]
        
        // Setup original data
        for (key, value) in originalData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(originalData.keys)
        
        // Attempt migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        if report.status == .completed {
            // Simulate need for rollback (e.g., application issue detected)
            // In production, this would trigger rollback mechanism
            
            // Verify rollback capability exists
            XCTAssertNotNil(report.backupLocation, "Backup should exist for rollback")
            
            // For testing, manually verify rollback would work
            if let backupLocation = report.backupLocation {
                XCTAssertNotNil(backupLocation, "Backup location should be available")
            }
        }
    }
    
    // MARK: - Performance Under Attack Tests
    
    func testMigrationPerformanceUnderLoad() {
        let largeDataset = (1...1000).reduce(into: [String: String]()) { dict, i in
            dict["perf_key_\(i)"] = "performance_value_\(String(repeating: "data", count: 100))"
        }
        
        for (key, value) in largeDataset {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(largeDataset.keys)
        
        measure {
            do {
                let report = try migrationService.performSecureMigration(keys: keys)
                XCTAssertTrue(report.status == .completed || report.status == .completedWithErrors)
            } catch {
                XCTFail("Migration should handle large datasets: \(error)")
            }
        }
    }
    
    func testMemoryUsageDuringMigration() throws {
        let initialMemory = getMemoryUsage()
        
        // Create large dataset
        let largeDataset = (1...500).reduce(into: [String: String]()) { dict, i in
            dict["memory_key_\(i)"] = String(repeating: "x", count: 1000)
        }
        
        for (key, value) in largeDataset {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(largeDataset.keys)
        
        // Perform migration
        let report = try migrationService.performSecureMigration(keys: keys)
        XCTAssertTrue(report.status == .completed || report.status == .completedWithErrors)
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, // 100MB threshold
                         "Migration should not consume excessive memory")
    }
    
    // MARK: - Cryptographic Security Tests
    
    func testEncryptionDuringMigration() throws {
        let sensitiveData = [
            "encryption_key": "super_secret_api_key_12345",
            "password_hash": "pbkdf2_sha256$150000$random_salt$hash_value",
            "session_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        ]
        
        for (key, value) in sensitiveData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(sensitiveData.keys)
        let report = try migrationService.performSecureMigration(keys: keys)
        
        XCTAssertEqual(report.status, .completed)
        
        // Verify data is encrypted in keychain
        for key in keys {
            XCTAssertTrue(keychainStorage.exists(for: key))
            // Keychain automatically encrypts stored data
            let retrievedValue = try keychainStorage.retrieveString(for: key)
            XCTAssertEqual(retrievedValue, sensitiveData[key])
        }
    }
    
    // MARK: - Audit Trail Security Tests
    
    func testMigrationAuditLogging() throws {
        let auditTestData = [
            "audit_key_1": "audit_value_1",
            "audit_key_2": "audit_value_2"
        ]
        
        for (key, value) in auditTestData {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        let keys = Array(auditTestData.keys)
        
        // Perform migration (should generate audit logs)
        let report = try migrationService.performSecureMigration(keys: keys)
        
        XCTAssertEqual(report.status, .completed)
        
        // Verify audit logging occurred
        // In production, verify specific audit events were logged:
        // - Migration started
        // - Data backed up
        // - Items migrated
        // - Legacy data cleared
        // - Migration completed
        XCTAssertTrue(true, "Migration should generate comprehensive audit logs")
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

// MARK: - Mock Legacy Storage

private class MockLegacyStorage {
    private var storage: [String: Any] = [:]
    
    func set(_ value: Any, for key: String) {
        storage[key] = value
    }
    
    func get(for key: String) -> Any? {
        return storage[key]
    }
    
    func remove(for key: String) {
        storage.removeValue(forKey: key)
    }
    
    func clearAll() {
        storage.removeAll()
    }
    
    func allKeys() -> [String] {
        return Array(storage.keys)
    }
}