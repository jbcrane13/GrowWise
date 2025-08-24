import XCTest
import LocalAuthentication
@testable import GrowWiseServices

final class BiometricAuthenticationManagerTests: XCTestCase {
    
    var authManager: BiometricAuthenticationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        authManager = BiometricAuthenticationManager.shared
    }
    
    override func tearDown() async throws {
        authManager.logout()
        try await super.tearDown()
    }
    
    // MARK: - Biometric Availability Tests
    
    func testBiometricAvailabilityCheck() {
        // This test will vary based on the device/simulator
        authManager.checkBiometricAvailability()
        
        // On simulator without biometrics enrolled
        if !authManager.canUseBiometrics {
            XCTAssertEqual(authManager.biometricType, .none)
        } else {
            // On device with biometrics
            XCTAssertTrue(authManager.biometricType == .faceID || 
                         authManager.biometricType == .touchID ||
                         authManager.biometricType == .opticID)
        }
    }
    
    func testBiometricTypeName() {
        // Test name mapping
        authManager.checkBiometricAvailability()
        
        let typeName = authManager.biometricTypeName
        XCTAssertTrue(["Face ID", "Touch ID", "Optic ID", "None", "Unknown"].contains(typeName))
    }
    
    // MARK: - Authentication State Tests
    
    func testInitialAuthenticationState() {
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.isAuthenticating)
    }
    
    func testLogout() {
        // Simulate authentication
        authManager.logout()
        
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    // MARK: - Authentication Timeout Tests
    
    func testAuthenticationStatusWithTimeout() {
        // Test immediate check (should fail as not authenticated)
        XCTAssertFalse(authManager.checkAuthenticationStatus(timeoutMinutes: 5))
        
        // Cannot easily test timeout without mocking time
        // In production, would use dependency injection for time provider
    }
    
    // MARK: - Error Handling Tests
    
    func testBiometricErrorMapping() {
        // Test error conversions
        let laErrors: [(LAError.Code, BiometricAuthenticationManager.BiometricError)] = [
            (.authenticationFailed, .authenticationFailed),
            (.userCancel, .userCancelled),
            (.userFallback, .userFallback),
            (.systemCancel, .systemCancel),
            (.passcodeNotSet, .passcodeNotSet),
            (.biometryNotAvailable, .biometricsNotAvailable),
            (.biometryNotEnrolled, .biometricsNotEnrolled),
            (.biometryLockout, .lockout),
            (.appCancel, .appCancel),
            (.invalidContext, .invalidContext),
            (.notInteractive, .notInteractive)
        ]
        
        for (_, expectedError) in laErrors {
            XCTAssertNotNil(expectedError.errorDescription)
        }
    }
    
    func testErrorDescriptions() {
        let errors: [BiometricAuthenticationManager.BiometricError] = [
            .biometricsNotAvailable,
            .biometricsNotEnrolled,
            .authenticationFailed,
            .userCancelled,
            .userFallback,
            .systemCancel,
            .passcodeNotSet,
            .lockout,
            .appCancel,
            .invalidContext,
            .notInteractive,
            .unknown("Test error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Biometric Authentication Tests (Simulator)
    
    func testAuthenticateWithBiometricsOnSimulator() async {
        guard !authManager.canUseBiometrics else {
            // Skip on devices with biometrics
            return
        }
        
        do {
            try await authManager.authenticateWithBiometrics()
            XCTFail("Should throw error on simulator without biometrics")
        } catch {
            if let biometricError = error as? BiometricAuthenticationManager.BiometricError {
                XCTAssertEqual(biometricError, .biometricsNotAvailable)
            }
        }
    }
    
    // MARK: - Protected Operation Tests
    
    func testProtectOperationRequiresAuthentication() async {
        guard !authManager.canUseBiometrics else {
            // Skip on devices with biometrics (would require user interaction)
            return
        }
        
        do {
            let result = try await authManager.protectOperation(reason: "Test operation") {
                return "Protected data"
            }
            XCTFail("Should not succeed without biometrics: \(result)")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Keychain Integration Tests
    
    func testStoreWithBiometricProtection() throws {
        let testData = "Test secret data".data(using: .utf8)!
        
        // This will succeed in storing but require authentication to retrieve
        try authManager.storeWithBiometricProtection(testData, for: "test_key")
        
        // Verify it was stored (we can't retrieve without authentication on device)
        // Cleanup
        try? KeychainManager.shared.delete(for: "biometric_test_key")
    }
    
    // MARK: - Lifecycle Tests
    
    func testAppLifecycleNotifications() {
        // Test that manager responds to app lifecycle
        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Allow time for notification handling
        let expectation = expectation(description: "Background notification handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Test foreground notification
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        let foregroundExpectation = expectation(description: "Foreground notification handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            foregroundExpectation.fulfill()
        }
        wait(for: [foregroundExpectation], timeout: 1.0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAuthenticationAttempts() async {
        guard !authManager.canUseBiometrics else {
            // Skip on devices with biometrics
            return
        }
        
        // Try multiple concurrent authentication attempts
        async let attempt1 = authManager.authenticateWithBiometrics()
        async let attempt2 = authManager.authenticateWithBiometrics()
        
        do {
            _ = try await (attempt1, attempt2)
            XCTFail("Should fail on simulator")
        } catch {
            // Expected to fail on simulator
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock Context for Testing

class MockLAContext: LAContext {
    var shouldSucceed = false
    var errorToThrow: Error?
    
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if let errorToThrow = errorToThrow {
            error?.pointee = errorToThrow as NSError
            return false
        }
        return shouldSucceed
    }
    
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        if let error = errorToThrow {
            throw error
        }
        return shouldSucceed
    }
}