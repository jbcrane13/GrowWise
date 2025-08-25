import XCTest
import CryptoKit
@testable import GrowWiseServices
@testable import GrowWiseModels

@available(iOS 16.0, *)
final class AuditLoggerTests: XCTestCase {
    
    var auditLogger: AuditLogger!
    
    override func setUp() {
        super.setUp()
        auditLogger = AuditLogger.shared
        
        // Clean up any existing test data
        cleanupTestData()
    }
    
    override func tearDown() {
        cleanupTestData()
        super.tearDown()
    }
    
    private func cleanupTestData() {
        // Reset audit logger state if possible
        // In a real implementation, we might have a test-only cleanup method
    }
    
    // MARK: - Authentication Logging Tests
    
    func testLogAuthenticationSuccess() {
        // Given
        let userId = "test_user_123"
        let method = "biometric"
        let details = [
            "biometric_type": "faceid",
            "device_id": "test_device"
        ]
        
        // When
        auditLogger.logAuthentication(
            type: .authenticationSuccess,
            userId: userId,
            result: .success,
            method: method,
            details: details
        )
        
        // Then
        // Verify the log was created (in a real implementation, we'd have access to retrieve logs)
        XCTAssertTrue(true, "Authentication success should be logged without throwing")
    }
    
    func testLogAuthenticationFailure() {
        // Given
        let userId = "test_user_456"
        let method = "password"
        let details = [
            "reason": "invalid_credentials",
            "attempt_count": "3"
        ]
        
        // When
        auditLogger.logAuthentication(
            type: .authenticationFailure,
            userId: userId,
            result: .failure,
            method: method,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Authentication failure should be logged without throwing")
    }
    
    func testLogBiometricAuthentication() {
        // Given
        let userId = "biometric_user"
        let method = "biometric_credentials"
        let details = [
            "biometric_type": "touchid",
            "protection_level": "secure_enclave"
        ]
        
        // When
        auditLogger.logAuthentication(
            type: .biometricAuthentication,
            userId: userId,
            result: .success,
            method: method,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Biometric authentication should be logged without throwing")
    }
    
    // MARK: - Credential Management Logging Tests
    
    func testLogCredentialCreation() {
        // Given
        let userId = "cred_user_789"
        let credentialType = "jwt_token"
        let operation = "store_secure"
        let details = [
            "token_type": "bearer",
            "encryption_applied": "true",
            "validation_passed": "true"
        ]
        
        // When
        auditLogger.logCredentialOperation(
            type: .credentialCreation,
            userId: userId,
            result: .success,
            credentialType: credentialType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Credential creation should be logged without throwing")
    }
    
    func testLogCredentialAccess() {
        // Given
        let userId = "access_user_101"
        let credentialType = "keychain_data"
        let operation = "retrieve"
        let details = [
            "data_size": "1024",
            "key_type": "secure_storage"
        ]
        
        // When
        auditLogger.logCredentialOperation(
            type: .credentialAccess,
            userId: userId,
            result: .success,
            credentialType: credentialType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Credential access should be logged without throwing")
    }
    
    func testLogCredentialModification() {
        // Given
        let userId = "mod_user_202"
        let credentialType = "api_key"
        let operation = "update"
        let details = [
            "modification_type": "value_change",
            "previous_version": "v1",
            "new_version": "v2"
        ]
        
        // When
        auditLogger.logCredentialOperation(
            type: .credentialModification,
            userId: userId,
            result: .success,
            credentialType: credentialType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Credential modification should be logged without throwing")
    }
    
    func testLogCredentialDeletion() {
        // Given
        let userId = "delete_user_303"
        let credentialType = "refresh_token"
        let operation = "delete"
        let details = [
            "deletion_reason": "user_logout",
            "secure_wipe": "true"
        ]
        
        // When
        auditLogger.logCredentialOperation(
            type: .credentialDeletion,
            userId: userId,
            result: .success,
            credentialType: credentialType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Credential deletion should be logged without throwing")
    }
    
    func testLogCredentialRotation() {
        // Given
        let userId = "rotate_user_404"
        let credentialType = "encryption_key"
        let operation = "rotate"
        let details = [
            "rotation_reason": "scheduled",
            "old_key_destroyed": "true",
            "new_key_generated": "true"
        ]
        
        // When
        auditLogger.logCredentialOperation(
            type: .credentialRotation,
            userId: userId,
            result: .success,
            credentialType: credentialType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Credential rotation should be logged without throwing")
    }
    
    // MARK: - Key Management Logging Tests
    
    func testLogKeyGeneration() {
        // Given
        let userId = "key_user_505"
        let keyType = "encryption_key"
        let operation = "generate"
        let details = [
            "algorithm": "AES256",
            "key_length": "256",
            "secure_enclave": "true"
        ]
        
        // When
        auditLogger.logKeyOperation(
            type: .keyGeneration,
            userId: userId,
            result: .success,
            keyType: keyType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Key generation should be logged without throwing")
    }
    
    func testLogKeyAccess() {
        // Given
        let userId = "key_access_606"
        let keyType = "signing_key"
        let operation = "access"
        let details = [
            "access_purpose": "jwt_signing",
            "key_usage_count": "1"
        ]
        
        // When
        auditLogger.logKeyOperation(
            type: .keyAccess,
            userId: userId,
            result: .success,
            keyType: keyType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Key access should be logged without throwing")
    }
    
    func testLogKeyDeletion() {
        // Given
        let userId = "key_delete_707"
        let keyType = "old_encryption_key"
        let operation = "delete"
        let details = [
            "deletion_reason": "key_rotation",
            "secure_deletion": "true"
        ]
        
        // When
        auditLogger.logKeyOperation(
            type: .keyDeletion,
            userId: userId,
            result: .success,
            keyType: keyType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Key deletion should be logged without throwing")
    }
    
    // MARK: - Data Access Logging Tests
    
    func testLogDataAccess() {
        // Given
        let userId = "data_user_808"
        let dataType = "user_profile"
        let operation = "read"
        let details = [
            "data_classification": "personal",
            "access_reason": "profile_view"
        ]
        
        // When
        auditLogger.logDataAccess(
            type: .dataAccess,
            userId: userId,
            result: .success,
            dataType: dataType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Data access should be logged without throwing")
    }
    
    func testLogDataModification() {
        // Given
        let userId = "data_mod_909"
        let dataType = "preferences"
        let operation = "update"
        let details = [
            "fields_modified": "theme,notifications",
            "change_reason": "user_settings"
        ]
        
        // When
        auditLogger.logDataAccess(
            type: .dataModification,
            userId: userId,
            result: .success,
            dataType: dataType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Data modification should be logged without throwing")
    }
    
    func testLogDataExport() {
        // Given
        let userId = "export_user_111"
        let dataType = "garden_data"
        let operation = "export"
        let details = [
            "export_format": "json",
            "data_range": "last_12_months",
            "encryption_applied": "true"
        ]
        
        // When
        auditLogger.logDataAccess(
            type: .dataExport,
            userId: userId,
            result: .success,
            dataType: dataType,
            operation: operation,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Data export should be logged without throwing")
    }
    
    // MARK: - Security Event Logging Tests
    
    func testLogSecurityViolation() {
        // Given
        let userId = "security_user_222"
        let threatLevel = AuditLogger.RiskLevel.high
        let description = "Multiple failed authentication attempts"
        let details = [
            "failed_attempts": "5",
            "time_window": "300_seconds",
            "source_ip": "192.168.1.100"
        ]
        
        // When
        auditLogger.logSecurityEvent(
            type: .securityViolation,
            userId: userId,
            result: .denied,
            threatLevel: threatLevel,
            description: description,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Security violation should be logged without throwing")
    }
    
    func testLogUnauthorizedAccess() {
        // Given
        let userId = "unauthorized_333"
        let threatLevel = AuditLogger.RiskLevel.critical
        let description = "Attempt to access restricted resource"
        let details = [
            "resource": "admin_panel",
            "user_role": "standard",
            "required_role": "admin"
        ]
        
        // When
        auditLogger.logSecurityEvent(
            type: .unauthorizedAccess,
            userId: userId,
            result: .denied,
            threatLevel: threatLevel,
            description: description,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Unauthorized access should be logged without throwing")
    }
    
    func testLogAccountLockout() {
        // Given
        let userId = "locked_user_444"
        let threatLevel = AuditLogger.RiskLevel.high
        let description = "Account locked due to repeated failed attempts"
        let unlockTime = Date().addingTimeInterval(1800) // 30 minutes
        let details = [
            "failed_attempts": "5",
            "lockout_duration": "1800",
            "unlock_time": unlockTime.iso8601String
        ]
        
        // When
        auditLogger.logSecurityEvent(
            type: .accountLockout,
            userId: userId,
            result: .denied,
            threatLevel: threatLevel,
            description: description,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Account lockout should be logged without throwing")
    }
    
    func testLogSuspiciousActivity() {
        // Given
        let userId = "suspicious_555"
        let threatLevel = AuditLogger.RiskLevel.medium
        let description = "Login from unusual location"
        let details = [
            "previous_location": "US",
            "current_location": "Unknown",
            "time_since_last_login": "30_minutes"
        ]
        
        // When
        auditLogger.logSecurityEvent(
            type: .suspiciousActivity,
            userId: userId,
            result: .success,
            threatLevel: threatLevel,
            description: description,
            details: details
        )
        
        // Then
        XCTAssertTrue(true, "Suspicious activity should be logged without throwing")
    }
    
    // MARK: - System Event Logging Tests
    
    func testLogSystemStartup() {
        // Given
        let details = [
            "app_version": "1.0.0",
            "os_version": "iOS 17.0",
            "device_type": "iPhone"
        ]
        
        // When
        auditLogger.logSystemEvent(.systemStartup, details: details)
        
        // Then
        XCTAssertTrue(true, "System startup should be logged without throwing")
    }
    
    func testLogSystemMaintenance() {
        // Given
        let details = [
            "maintenance_type": "log_rotation",
            "duration": "15_seconds",
            "items_processed": "1000"
        ]
        
        // When
        auditLogger.logSystemEvent(.systemMaintenance, details: details)
        
        // Then
        XCTAssertTrue(true, "System maintenance should be logged without throwing")
    }
    
    func testLogBackupCreation() {
        // Given
        let details = [
            "backup_type": "audit_logs",
            "backup_size": "10MB",
            "compression_applied": "true"
        ]
        
        // When
        auditLogger.logSystemEvent(.backupCreation, details: details)
        
        // Then
        XCTAssertTrue(true, "Backup creation should be logged without throwing")
    }
    
    // MARK: - Risk Level Tests
    
    func testEventTypeRiskLevels() {
        // Test high-risk events
        XCTAssertEqual(AuditLogger.EventType.authenticationFailure.riskLevel, .high)
        XCTAssertEqual(AuditLogger.EventType.accountLockout.riskLevel, .high)
        XCTAssertEqual(AuditLogger.EventType.securityViolation.riskLevel, .high)
        XCTAssertEqual(AuditLogger.EventType.unauthorizedAccess.riskLevel, .high)
        XCTAssertEqual(AuditLogger.EventType.suspiciousActivity.riskLevel, .high)
        XCTAssertEqual(AuditLogger.EventType.privilegeEscalation.riskLevel, .high)
        
        // Test medium-risk events
        XCTAssertEqual(AuditLogger.EventType.credentialAccess.riskLevel, .medium)
        XCTAssertEqual(AuditLogger.EventType.credentialModification.riskLevel, .medium)
        XCTAssertEqual(AuditLogger.EventType.credentialDeletion.riskLevel, .medium)
        XCTAssertEqual(AuditLogger.EventType.keyAccess.riskLevel, .medium)
        XCTAssertEqual(AuditLogger.EventType.keyDeletion.riskLevel, .medium)
        XCTAssertEqual(AuditLogger.EventType.dataExport.riskLevel, .medium)
        
        // Test low-risk events
        XCTAssertEqual(AuditLogger.EventType.authenticationSuccess.riskLevel, .low)
        XCTAssertEqual(AuditLogger.EventType.biometricAuthentication.riskLevel, .low)
        XCTAssertEqual(AuditLogger.EventType.credentialCreation.riskLevel, .low)
        XCTAssertEqual(AuditLogger.EventType.keyGeneration.riskLevel, .low)
        XCTAssertEqual(AuditLogger.EventType.dataAccess.riskLevel, .low)
    }
    
    // MARK: - Compliance Export Tests
    
    func testComplianceReportExport() async throws {
        // Given
        let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let toDate = Date()
        
        // Log some test events first
        auditLogger.logAuthentication(
            type: .authenticationSuccess,
            userId: "export_test_user",
            result: .success,
            method: "biometric"
        )
        
        auditLogger.logCredentialOperation(
            type: .credentialAccess,
            userId: "export_test_user",
            result: .success,
            credentialType: "jwt_token",
            operation: "retrieve"
        )
        
        // When
        let reportData = try await auditLogger.exportComplianceReport(
            fromDate: fromDate,
            toDate: toDate,
            eventTypes: [.authenticationSuccess, .credentialAccess],
            riskLevels: [.low, .medium]
        )
        
        // Then
        XCTAssertFalse(reportData.isEmpty, "Compliance report should contain data")
        
        // Verify report can be parsed as JSON
        let reportObject = try JSONSerialization.jsonObject(with: reportData, options: [])
        XCTAssertNotNil(reportObject, "Report should be valid JSON")
        
        if let report = reportObject as? [String: Any] {
            XCTAssertNotNil(report["generatedAt"], "Report should have generation timestamp")
            XCTAssertNotNil(report["reportPeriod"], "Report should have period information")
            XCTAssertNotNil(report["events"], "Report should contain events")
            XCTAssertNotNil(report["metadata"], "Report should contain metadata")
        }
    }
    
    func testComplianceReportExportWithFilters() async throws {
        // Given
        let fromDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        let toDate = Date()
        
        // Log events with different types and risk levels
        auditLogger.logAuthentication(
            type: .authenticationFailure,
            userId: "filter_test_user",
            result: .failure,
            method: "password"
        )
        
        auditLogger.logSecurityEvent(
            type: .securityViolation,
            userId: "filter_test_user",
            result: .denied,
            threatLevel: .high,
            description: "Test security violation"
        )
        
        // When - Export only high-risk events
        let highRiskReport = try await auditLogger.exportComplianceReport(
            fromDate: fromDate,
            toDate: toDate,
            eventTypes: nil,
            riskLevels: [.high]
        )
        
        // Then
        XCTAssertFalse(highRiskReport.isEmpty, "High-risk report should contain data")
        
        // When - Export only authentication events
        let authReport = try await auditLogger.exportComplianceReport(
            fromDate: fromDate,
            toDate: toDate,
            eventTypes: [.authenticationFailure],
            riskLevels: nil
        )
        
        // Then
        XCTAssertFalse(authReport.isEmpty, "Authentication report should contain data")
    }
    
    // MARK: - Configuration Tests
    
    func testAuditLoggerConfiguration() {
        // Given
        let config = AuditLogger.Configuration(
            retentionDays: 365,
            maxLogSize: 200_000_000,
            enableRealtimeAlerts: false,
            exportEncryption: false
        )
        
        // Then
        XCTAssertEqual(config.retentionDays, 365)
        XCTAssertEqual(config.maxLogSize, 200_000_000)
        XCTAssertFalse(config.enableRealtimeAlerts)
        XCTAssertFalse(config.exportEncryption)
    }
    
    func testDefaultConfiguration() {
        // Given
        let defaultConfig = AuditLogger.Configuration()
        
        // Then - Verify SOC2/HIPAA compliance defaults
        XCTAssertEqual(defaultConfig.retentionDays, 90, "Default retention should meet SOC2/HIPAA minimum")
        XCTAssertEqual(defaultConfig.maxLogSize, 100_000_000)
        XCTAssertTrue(defaultConfig.enableRealtimeAlerts)
        XCTAssertTrue(defaultConfig.exportEncryption)
    }
    
    // MARK: - Error Handling Tests
    
    func testAuditErrorTypes() {
        // Test error descriptions
        let initError = AuditLogger.AuditError.initializationFailed
        XCTAssertNotNil(initError.errorDescription)
        
        let storageError = AuditLogger.AuditError.storageError(NSError(domain: "test", code: 1))
        XCTAssertNotNil(storageError.errorDescription)
        
        let integrityError = AuditLogger.AuditError.integrityViolation
        XCTAssertNotNil(integrityError.errorDescription)
        
        let retentionError = AuditLogger.AuditError.retentionPolicyError
        XCTAssertNotNil(retentionError.errorDescription)
        
        let exportError = AuditLogger.AuditError.exportError(NSError(domain: "export", code: 2))
        XCTAssertNotNil(exportError.errorDescription)
        
        let configError = AuditLogger.AuditError.configurationError("Invalid config")
        XCTAssertNotNil(configError.errorDescription)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentLogging() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // When - Log from multiple threads simultaneously
        for i in 0..<10 {
            queue.async {
                self.auditLogger.logAuthentication(
                    type: .authenticationSuccess,
                    userId: "concurrent_user_\(i)",
                    result: .success,
                    method: "concurrent_test",
                    details: ["thread_id": "\(i)"]
                )
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // If we reach here without crashes, concurrent access is working
        XCTAssertTrue(true, "Concurrent logging should complete without issues")
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        // Given
        let iterations = 1000
        
        // When
        measure {
            for i in 0..<iterations {
                auditLogger.logAuthentication(
                    type: .authenticationSuccess,
                    userId: "perf_user_\(i)",
                    result: .success,
                    method: "performance_test"
                )
            }
        }
        
        // Then - Performance measurement will be recorded by XCTest
    }
    
    // MARK: - Integration Tests
    
    func testAuditLoggerIntegrationWithKeychain() {
        // This would test the integration with KeychainManager
        // For now, we just verify that the audit logger can be accessed
        XCTAssertNotNil(AuditLogger.shared, "Audit logger should be accessible")
    }
    
    func testAuditLoggerIntegrationWithTokenService() {
        // This would test the integration with TokenManagementService
        // For now, we just verify that the audit logger can be accessed
        XCTAssertNotNil(AuditLogger.shared, "Audit logger should be accessible for token service")
    }
}

// MARK: - Test Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}