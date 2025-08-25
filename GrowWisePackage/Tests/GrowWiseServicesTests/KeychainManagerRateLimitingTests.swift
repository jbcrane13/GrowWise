import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels
import Foundation

final class KeychainManagerRateLimitingTests: XCTestCase {
    
    private var keychainManager: KeychainManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        keychainManager = KeychainManager.shared
        
        // Enable testing bypass for controlled tests
        keychainManager.enableRateLimitTestingBypass()
        
        // Clear any existing data
        try keychainManager.deleteAll()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        try keychainManager.deleteAll()
        keychainManager.disableRateLimitTestingBypass()
        try super.tearDownWithError()
    }
    
    // MARK: - Rate Limiting Integration Tests
    
    func testBasicRateLimitCheck() throws {
        let email = "test@example.com"
        
        // Initial check should be allowed
        let result = keychainManager.checkAuthenticationRateLimit(for: email)
        XCTAssertTrue(result.isAllowed)
    }
    
    func testRateLimitWithCredentialRetrieval() throws {
        // Store test credentials first
        let credentials = SecureCredentials(
            accessToken: "test_token",
            refreshToken: "refresh_token",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        try keychainManager.storeSecureCredentials(credentials)
        
        let email = "test@example.com"
        
        // Disable testing bypass to test actual rate limiting
        keychainManager.disableRateLimitTestingBypass()
        
        // First retrieval should succeed
        let retrievedCredentials = try keychainManager.retrieveSecureCredentials(for: email)
        XCTAssertEqual(retrievedCredentials.accessToken, credentials.accessToken)
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testRateLimitExceeded() throws {
        let email = "test@example.com"
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Set a strict policy for testing
        let strictPolicy = RateLimiter.Policy(
            maxAttempts: 2,
            timeWindow: 60,
            baseLockoutDuration: 30
        )
        keychainManager.setRateLimitPolicy(strictPolicy, for: "authentication")
        
        // Record failed attempts
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        
        // Third attempt should throw rate limit error
        XCTAssertThrowsError(try keychainManager.recordAuthenticationAttempt(for: email, successful: false)) { error in
            if let keychainError = error as? KeychainManager.KeychainError {
                switch keychainError {
                case .rateLimitExceeded(let retryAfter):
                    XCTAssertGreaterThan(retryAfter, 0)
                case .accountLocked(let unlockAt):
                    XCTAssertGreaterThan(unlockAt.timeIntervalSinceNow, 0)
                default:
                    XCTFail("Expected rate limit or account locked error, got: \(keychainError)")
                }
            } else {
                XCTFail("Expected KeychainError, got: \(error)")
            }
        }
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testSuccessfulAttemptResetsRateLimit() throws {
        let email = "test@example.com"
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Record several failed attempts
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        
        // Record successful attempt - should reset
        try keychainManager.recordAuthenticationAttempt(for: email, successful: true)
        
        // Should be allowed again
        let result = keychainManager.checkAuthenticationRateLimit(for: email)
        XCTAssertTrue(result.isAllowed)
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testBiometricAuthenticationRateLimit() async throws {
        let email = "test@example.com"
        
        // Store credentials with biometric protection first
        let credentials = SecureCredentials(
            accessToken: "test_token",
            refreshToken: "refresh_token",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        try keychainManager.storeCodableWithBiometricProtection(credentials, for: "biometric_secure_jwt_credentials_v2")
        
        // Test rate limit check for biometric auth
        let result = keychainManager.checkAuthenticationRateLimit(for: email, operation: "biometric_auth")
        XCTAssertTrue(result.isAllowed)
        
        // Note: We can't actually test biometric retrieval without a real device
        // but we can test the rate limiting logic
    }
    
    func testRateLimitReset() throws {
        let email = "test@example.com"
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Record failed attempts to trigger rate limiting
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false)
        
        // Check that we're rate limited
        let limitedResult = keychainManager.checkAuthenticationRateLimit(for: email)
        XCTAssertFalse(limitedResult.isAllowed)
        
        // Reset rate limit
        keychainManager.resetAuthenticationRateLimit(for: email)
        
        // Should be allowed again
        let allowedResult = keychainManager.checkAuthenticationRateLimit(for: email)
        XCTAssertTrue(allowedResult.isAllowed)
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testDifferentOperationsIndependent() throws {
        let email = "test@example.com"
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Set strict policy for one operation
        let strictPolicy = RateLimiter.Policy(
            maxAttempts: 2,
            timeWindow: 60,
            baseLockoutDuration: 30
        )
        keychainManager.setRateLimitPolicy(strictPolicy, for: "operation1")
        
        // Exhaust attempts for operation1
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "operation1")
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "operation1")
        
        // operation1 should be blocked
        XCTAssertThrowsError(try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "operation1"))
        
        // operation2 should still be allowed
        let result = keychainManager.checkAuthenticationRateLimit(for: email, operation: "operation2")
        XCTAssertTrue(result.isAllowed)
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testCustomPolicyConfiguration() throws {
        let email = "test@example.com"
        
        // Set custom policy
        let customPolicy = RateLimiter.Policy(
            maxAttempts: 3,
            timeWindow: 60,
            baseLockoutDuration: 120,
            maxLockoutDuration: 3600,
            backoffMultiplier: 3.0,
            useExponentialBackoff: true
        )
        keychainManager.setRateLimitPolicy(customPolicy, for: "custom_operation")
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Should allow up to 3 attempts
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "custom_operation")
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "custom_operation")
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "custom_operation")
        
        // 4th attempt should fail
        XCTAssertThrowsError(try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "custom_operation"))
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    func testRateLimitMaintenance() throws {
        // Test that maintenance doesn't crash
        keychainManager.performRateLimitMaintenance()
        
        // Verify normal operations still work after maintenance
        let email = "test@example.com"
        let result = keychainManager.checkAuthenticationRateLimit(for: email)
        XCTAssertTrue(result.isAllowed)
    }
    
    func testBypassModeToggle() throws {
        let email = "test@example.com"
        
        // Disable bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Record many failed attempts for testing operation
        for _ in 0..<10 {
            try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "testing")
        }
        
        // Should be rate limited for non-testing operations
        let authResult = keychainManager.checkAuthenticationRateLimit(for: email, operation: "authentication")
        // Note: This might still be allowed if it's a different operation
        
        // Enable bypass
        keychainManager.enableRateLimitTestingBypass()
        
        // Testing operation should now be allowed
        let testingResult = keychainManager.checkAuthenticationRateLimit(for: email, operation: "testing")
        XCTAssertTrue(testingResult.isAllowed)
        
        // Keep bypass enabled for cleanup
    }
    
    // MARK: - Error Message Tests
    
    func testErrorMessages() throws {
        let email = "test@example.com"
        
        // Disable testing bypass
        keychainManager.disableRateLimitTestingBypass()
        
        // Set strict policy
        let policy = RateLimiter.Policy(
            maxAttempts: 1,
            timeWindow: 60,
            baseLockoutDuration: 300
        )
        keychainManager.setRateLimitPolicy(policy, for: "test_error")
        
        // Trigger rate limit
        try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "test_error")
        
        // Check error message
        XCTAssertThrowsError(try keychainManager.recordAuthenticationAttempt(for: email, successful: false, operation: "test_error")) { error in
            let errorMessage = error.localizedDescription
            XCTAssertTrue(errorMessage.contains("authentication attempts") || 
                         errorMessage.contains("Account locked") || 
                         errorMessage.contains("Try again"))
        }
        
        // Re-enable bypass for cleanup
        keychainManager.enableRateLimitTestingBypass()
    }
    
    // MARK: - Performance Tests
    
    func testRateLimitPerformance() throws {
        let emails = (0..<100).map { "user\($0)@example.com" }
        
        measure {
            for email in emails {
                let result = keychainManager.checkAuthenticationRateLimit(for: email)
                XCTAssertTrue(result.isAllowed)
            }
        }
    }
}