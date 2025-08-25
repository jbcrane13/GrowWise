import XCTest
import CryptoKit
@testable import GrowWiseServices

final class MigrationIntegrityServiceTests: XCTestCase {
    
    var migrationService: MigrationIntegrityService!
    var keychainStorage: KeychainStorageService!
    var auditLogger: AuditLogger!
    
    override func setUp() {
        super.setUp()
        keychainStorage = KeychainStorageService(service: "com.growwise.test", accessGroup: nil)
        auditLogger = AuditLogger.shared
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
    
    // MARK: - Helper Methods
    
    private func cleanupTestData() {
        let testKeys = [
            "test_string_key",
            "test_data_key",
            "test_bool_key",
            "test_empty_key",
            "_migration_progress_v1",
            "_backup_test-session-1",
            "_backup_test-session-2"
        ]
        
        // Clean up keychain
        for key in testKeys {
            try? keychainStorage.delete(for: key)
        }
        
        // Clean up UserDefaults
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private func setupUserDefaultsData() {
        UserDefaults.standard.set("test string value", forKey: "test_string_key")
        UserDefaults.standard.set(Data("test data".utf8), forKey: "test_data_key")
        UserDefaults.standard.set(true, forKey: "test_bool_key")
    }
    
    // MARK: - Dry Run Tests
    
    func testDryRunMigration() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute dry run
        let report = try migrationService.performDryRun(keys: keys)
        
        // Verify dry run results
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.totalItems, 3)
        XCTAssertEqual(report.successfulItems, 3)
        XCTAssertEqual(report.failedItems, 0)
        XCTAssertTrue(report.integrityVerified)
        XCTAssertNil(report.backupLocation)
        
        // Verify no actual migration occurred
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "test_string_key"))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "test_data_key"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "test_bool_key"))
        XCTAssertFalse(keychainStorage.exists(for: "test_string_key"))
        XCTAssertFalse(keychainStorage.exists(for: "test_data_key"))
        XCTAssertFalse(keychainStorage.exists(for: "test_bool_key"))
    }
    
    // MARK: - Full Migration Tests
    
    func testSuccessfulMigration() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify migration results
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.totalItems, 3)
        XCTAssertEqual(report.successfulItems, 3)
        XCTAssertEqual(report.failedItems, 0)
        XCTAssertTrue(report.integrityVerified)
        XCTAssertNotNil(report.backupLocation)
        XCTAssertGreaterThan(report.duration, 0)
        
        // Verify data was migrated
        XCTAssertTrue(keychainStorage.exists(for: "test_string_key"))
        XCTAssertTrue(keychainStorage.exists(for: "test_data_key"))
        XCTAssertTrue(keychainStorage.exists(for: "test_bool_key"))
        
        // Verify data integrity
        let stringData = try keychainStorage.retrieve(for: "test_string_key")
        XCTAssertEqual(String(data: stringData, encoding: .utf8), "test string value")
        
        let retrievedData = try keychainStorage.retrieve(for: "test_data_key")
        XCTAssertEqual(String(data: retrievedData, encoding: .utf8), "test data")
        
        let boolData = try keychainStorage.retrieve(for: "test_bool_key")
        XCTAssertEqual(boolData.first, 1)
        
        // Verify UserDefaults was cleaned up
        XCTAssertNil(UserDefaults.standard.string(forKey: "test_string_key"))
        XCTAssertNil(UserDefaults.standard.data(forKey: "test_data_key"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "test_bool_key"))
        
        // Verify checksums
        XCTAssertEqual(report.checksums.count, 3)
        XCTAssertTrue(report.checksums.allSatisfy { $0.isValid })
    }
    
    func testMigrationWithEmptyKeys() throws {
        // Setup - no data in UserDefaults
        let keys = ["test_empty_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify results - should complete but with 0 items processed
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.totalItems, 1)
        XCTAssertEqual(report.successfulItems, 0)
        XCTAssertEqual(report.failedItems, 0)
        XCTAssertEqual(report.checksums.count, 0)
    }
    
    // MARK: - Backup and Rollback Tests
    
    func testBackupCreation() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify backup was created
        XCTAssertNotNil(report.backupLocation)
        XCTAssertTrue(keychainStorage.exists(for: report.backupLocation!))
    }
    
    func testRollback() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        let sessionId = report.sessionId
        
        // Verify migration succeeded
        XCTAssertEqual(report.status, .completed)
        XCTAssertTrue(keychainStorage.exists(for: "test_string_key"))
        
        // Perform rollback
        try migrationService.rollbackMigration(sessionId: sessionId)
        
        // Verify rollback
        let progress = migrationService.getMigrationStatus(sessionId: sessionId)
        XCTAssertEqual(progress?.status, .rolledBack)
        
        // Verify data was restored to UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "test_string_key"), "test string value")
        XCTAssertEqual(String(data: UserDefaults.standard.data(forKey: "test_data_key")!, encoding: .utf8), "test data")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "test_bool_key"))
    }
    
    // MARK: - Progress Tracking Tests
    
    func testMigrationProgress() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify progress tracking
        let progress = migrationService.getMigrationStatus(sessionId: report.sessionId)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.status, .completed)
        XCTAssertEqual(progress?.totalItems, 3)
        XCTAssertEqual(progress?.completedItems, 3)
        XCTAssertEqual(progress?.failedItems, 0)
        XCTAssertEqual(progress?.progressPercentage, 100.0)
        XCTAssertTrue(progress?.isComplete ?? false)
        XCTAssertFalse(progress?.canResume ?? true)
    }
    
    // MARK: - Data Integrity Tests
    
    func testChecksumValidation() throws {
        // Setup
        let testData = Data("test checksum data".utf8)
        let key = "test_checksum_key"
        UserDefaults.standard.set(testData, forKey: key)
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: [key])
        
        // Verify checksums
        XCTAssertEqual(report.checksums.count, 1)
        let checksum = report.checksums.first!
        XCTAssertEqual(checksum.key, key)
        XCTAssertTrue(checksum.isValid)
        
        // Calculate expected checksum
        let hash = SHA256.hash(data: testData)
        let expectedChecksum = hash.compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(checksum.originalHash, expectedChecksum)
        XCTAssertEqual(checksum.migratedHash, expectedChecksum)
    }
    
    func testDataIntegrityVerification() throws {
        // Setup - migrate some data first
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        _ = try migrationService.performSecureMigration(keys: keys)
        
        // Verify data integrity
        let checksums = try migrationService.verifyDataIntegrity(keys: keys)
        
        XCTAssertEqual(checksums.count, 3)
        XCTAssertTrue(checksums.allSatisfy { $0.verified })
    }
    
    // MARK: - Error Handling Tests
    
    func testChecksumMismatch() throws {
        // This test would require mocking the keychain storage to simulate corruption
        // For now, we'll test the basic error types are defined
        let error = MigrationIntegrityService.IntegrityError.checksumMismatch(expected: "abc123", actual: "def456")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("integrity check failed"))
    }
    
    func testInvalidMigrationState() {
        let error = MigrationIntegrityService.IntegrityError.invalidState("test reason")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid migration state"))
    }
    
    // MARK: - Session Management Tests
    
    func testSessionIdGeneration() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key"]
        
        // Execute multiple migrations
        let report1 = try migrationService.performSecureMigration(keys: keys)
        
        // Clean up and setup again
        cleanupTestData()
        setupUserDefaultsData()
        
        let report2 = try migrationService.performSecureMigration(keys: keys)
        
        // Verify unique session IDs
        XCTAssertNotEqual(report1.sessionId, report2.sessionId)
    }
    
    func testMigrationStatusRetrieval() throws {
        // Test with non-existent session
        let nonExistentProgress = migrationService.getMigrationStatus(sessionId: "non-existent")
        XCTAssertNil(nonExistentProgress)
    }
    
    // MARK: - Performance Tests
    
    func testMigrationPerformance() throws {
        // Setup multiple keys
        let keys = (1...100).map { "test_key_\($0)" }
        for key in keys {
            UserDefaults.standard.set("value_\(key)", forKey: key)
        }
        
        // Measure migration time
        let startTime = CFAbsoluteTimeGetCurrent()
        let report = try migrationService.performSecureMigration(keys: keys)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Verify results
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.successfulItems, keys.count)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        
        print("Migration of \(keys.count) keys completed in \(String(format: "%.3f", duration)) seconds")
    }
    
    // MARK: - Edge Cases
    
    func testMigrationWithSpecialCharacters() throws {
        // Setup data with special characters
        let specialValue = "Test data with émojis 🔐 and spëciål çharactërs"
        UserDefaults.standard.set(specialValue, forKey: "special_char_key")
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: ["special_char_key"])
        
        // Verify migration
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.successfulItems, 1)
        
        // Verify data integrity
        let retrievedData = try keychainStorage.retrieve(for: "special_char_key")
        let retrievedString = String(data: retrievedData, encoding: .utf8)
        XCTAssertEqual(retrievedString, specialValue)
    }
    
    func testMigrationWithLargeData() throws {
        // Setup large data
        let largeString = String(repeating: "This is a test of large data migration. ", count: 1000)
        UserDefaults.standard.set(largeString, forKey: "large_data_key")
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: ["large_data_key"])
        
        // Verify migration
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.successfulItems, 1)
        
        // Verify data integrity
        let retrievedData = try keychainStorage.retrieve(for: "large_data_key")
        let retrievedString = String(data: retrievedData, encoding: .utf8)
        XCTAssertEqual(retrievedString, largeString)
    }
}

// MARK: - Migration Report Tests

extension MigrationIntegrityServiceTests {
    
    func testMigrationReportStructure() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify report structure
        XCTAssertNotNil(report.sessionId)
        XCTAssertFalse(report.sessionId.isEmpty)
        XCTAssertGreaterThan(report.endTime, report.startTime)
        XCTAssertGreaterThan(report.duration, 0)
        XCTAssertEqual(report.totalItems, keys.count)
        XCTAssertEqual(report.successRate, 100.0)
        XCTAssertTrue(report.integrityVerified)
        XCTAssertFalse(report.rollbackPerformed)
        XCTAssertNotNil(report.backupLocation)
        XCTAssertTrue(report.errors.isEmpty)
        XCTAssertTrue(report.warnings.isEmpty)
    }
    
    func testMigrationReportWithFailures() throws {
        // Setup - this test simulates a scenario where some keys fail
        // In a real scenario, this might happen due to keychain capacity limits or other issues
        let keys = ["test_string_key", "nonexistent_key", "test_bool_key"]
        UserDefaults.standard.set("test value", forKey: "test_string_key")
        UserDefaults.standard.set(true, forKey: "test_bool_key")
        // Note: "nonexistent_key" is not set, so it should be skipped (not fail)
        
        // Execute migration
        let report = try migrationService.performSecureMigration(keys: keys)
        
        // Verify partial success
        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(report.totalItems, 3)
        XCTAssertEqual(report.successfulItems, 2) // Only 2 keys have data
        XCTAssertEqual(report.failedItems, 0) // No actual failures, just missing data
        XCTAssertLessThan(report.successRate, 100.0)
    }
}

// MARK: - Concurrency Tests

extension MigrationIntegrityServiceTests {
    
    func testConcurrentMigrationAttempts() throws {
        // Setup
        setupUserDefaultsData()
        let keys = ["test_string_key", "test_data_key", "test_bool_key"]
        
        // Attempt concurrent migrations (this should be handled gracefully)
        let expectation1 = expectation(description: "Migration 1")
        let expectation2 = expectation(description: "Migration 2")
        
        var report1: MigrationIntegrityService.MigrationReport?
        var report2: MigrationIntegrityService.MigrationReport?
        var error1: Error?
        var error2: Error?
        
        DispatchQueue.global().async {
            do {
                report1 = try self.migrationService.performSecureMigration(keys: keys, sessionId: "session-1")
            } catch {
                error1 = error
            }
            expectation1.fulfill()
        }
        
        DispatchQueue.global().async {
            do {
                report2 = try self.migrationService.performSecureMigration(keys: keys, sessionId: "session-2")
            } catch {
                error2 = error
            }
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 10.0)
        
        // At least one migration should succeed
        let successCount = [report1, report2].compactMap { $0 }.count
        XCTAssertGreaterThanOrEqual(successCount, 1)
        
        // If both succeeded, they should have different session IDs
        if let r1 = report1, let r2 = report2 {
            XCTAssertNotEqual(r1.sessionId, r2.sessionId)
        }
    }
}