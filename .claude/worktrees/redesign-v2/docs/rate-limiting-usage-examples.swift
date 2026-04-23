import Foundation
import GrowWiseServices

// MARK: - Rate Limiting Usage Examples

/// This file demonstrates how to use the new rate limiting system 
/// integrated with KeychainManager for authentication security

// MARK: - Basic Usage

func basicRateLimitingExample() {
    let keychainManager = KeychainManager.shared
    let userEmail = "user@example.com"
    
    // Check if authentication attempts are rate limited
    let rateLimit = keychainManager.checkAuthenticationRateLimit(for: userEmail)
    
    switch rateLimit {
    case .allowed:
        print("Authentication attempt allowed")
        
        // Simulate authentication attempt
        let authenticationSuccessful = performAuthentication(email: userEmail)
        
        do {
            // Record the attempt result
            try keychainManager.recordAuthenticationAttempt(
                for: userEmail,
                successful: authenticationSuccessful
            )
            
            if authenticationSuccessful {
                print("Authentication successful - rate limit reset")
            } else {
                print("Authentication failed - attempt recorded")
            }
        } catch {
            print("Rate limiting error: \(error)")
        }
        
    case .limited(let retryAfter, let attemptsRemaining):
        print("Rate limited: retry after \(retryAfter) seconds")
        print("Attempts remaining: \(attemptsRemaining)")
        
    case .locked(let unlockAt, let totalFailures):
        print("Account locked until: \(unlockAt)")
        print("Total failures: \(totalFailures)")
    }
}

// MARK: - Advanced Configuration

func advancedRateLimitingExample() {
    let keychainManager = KeychainManager.shared
    
    // Configure custom policies for different operations
    
    // Strict policy for sensitive operations
    let sensitivePolicy = RateLimiter.Policy(
        maxAttempts: 3,
        timeWindow: 60,
        baseLockoutDuration: 300, // 5 minutes
        maxLockoutDuration: 7200, // 2 hours
        backoffMultiplier: 2.0,
        useExponentialBackoff: true
    )
    
    // Set policy for biometric authentication
    keychainManager.setRateLimitPolicy(sensitivePolicy, for: "biometric_auth")
    
    // Lenient policy for API access
    let apiPolicy = RateLimiter.Policy(
        maxAttempts: 10,
        timeWindow: 60,
        baseLockoutDuration: 60,
        useExponentialBackoff: false
    )
    
    keychainManager.setRateLimitPolicy(apiPolicy, for: "api_access")
    
    // Example of checking different operations
    let userEmail = "user@example.com"
    
    let biometricResult = keychainManager.checkAuthenticationRateLimit(
        for: userEmail, 
        operation: "biometric_auth"
    )
    
    let apiResult = keychainManager.checkAuthenticationRateLimit(
        for: userEmail, 
        operation: "api_access"
    )
    
    print("Biometric auth status: \(biometricResult)")
    print("API access status: \(apiResult)")
}

// MARK: - Biometric Authentication with Rate Limiting

func biometricAuthenticationExample() async {
    let keychainManager = KeychainManager.shared
    let userEmail = "user@example.com"
    
    do {
        // Retrieve credentials with biometric protection and rate limiting
        let credentials = try await keychainManager.retrieveSecureCredentialsWithBiometric(
            for: userEmail,
            reason: "Access your account securely"
        )
        
        print("Successfully retrieved credentials: \(credentials.accessToken)")
        
    } catch KeychainManager.KeychainError.rateLimitExceeded(let retryAfter) {
        print("Rate limit exceeded. Try again in \(retryAfter) seconds.")
        
    } catch KeychainManager.KeychainError.accountLocked(let unlockAt) {
        print("Account locked until: \(unlockAt)")
        
    } catch {
        print("Authentication error: \(error)")
    }
}

// MARK: - Development and Testing

func testingAndDevelopmentExample() {
    let keychainManager = KeychainManager.shared
    
    // Enable bypass for testing (development only)
    #if DEBUG
    keychainManager.enableRateLimitTestingBypass()
    print("Rate limiting bypass enabled for testing")
    #endif
    
    // Perform many test operations without rate limiting
    for i in 0..<100 {
        let result = keychainManager.checkAuthenticationRateLimit(
            for: "test\(i)@example.com", 
            operation: "testing"
        )
        assert(result.isAllowed)
    }
    
    // Disable bypass when done testing
    #if DEBUG
    keychainManager.disableRateLimitTestingBypass()
    #endif
    
    // Reset rate limits for specific users during development
    keychainManager.resetAuthenticationRateLimit(for: "developer@example.com")
    
    // Perform maintenance to clean up expired data
    keychainManager.performRateLimitMaintenance()
}

// MARK: - Error Handling Patterns

func errorHandlingExample() {
    let keychainManager = KeychainManager.shared
    let userEmail = "user@example.com"
    
    do {
        // Attempt to record authentication
        try keychainManager.recordAuthenticationAttempt(
            for: userEmail,
            successful: false
        )
        
    } catch KeychainManager.KeychainError.rateLimitExceeded(let retryAfter) {
        // Handle rate limit exceeded
        handleRateLimitExceeded(retryAfter: retryAfter)
        
    } catch KeychainManager.KeychainError.accountLocked(let unlockAt) {
        // Handle account lockout
        handleAccountLocked(unlockAt: unlockAt)
        
    } catch {
        // Handle other errors
        print("Unexpected error: \(error)")
    }
}

// MARK: - Integration with Credential Retrieval

func credentialRetrievalWithRateLimitingExample() {
    let keychainManager = KeychainManager.shared
    let userEmail = "user@example.com"
    
    do {
        // Retrieve credentials with rate limiting
        let credentials = try keychainManager.retrieveSecureCredentials(for: userEmail)
        
        print("Successfully retrieved credentials")
        print("Access token: \(credentials.accessToken)")
        print("Expires at: \(credentials.expiresAt)")
        
    } catch KeychainManager.KeychainError.rateLimitExceeded(let retryAfter) {
        print("Credential retrieval rate limited. Wait \(retryAfter) seconds.")
        
    } catch KeychainManager.KeychainError.accountLocked(let unlockAt) {
        print("Account locked. Try again after: \(unlockAt)")
        
    } catch KeychainManager.KeychainError.itemNotFound {
        print("No credentials found. User needs to authenticate.")
        
    } catch {
        print("Error retrieving credentials: \(error)")
    }
}

// MARK: - Helper Functions

func performAuthentication(email: String) -> Bool {
    // Simulate authentication logic
    // In real implementation, this would validate credentials
    return Bool.random() // Randomly succeed/fail for demonstration
}

func handleRateLimitExceeded(retryAfter: TimeInterval) {
    print("Rate limit exceeded. Please try again in \(Int(retryAfter)) seconds.")
    
    // Could show user a countdown timer
    // Could temporarily disable login UI
    // Could suggest alternative authentication methods
}

func handleAccountLocked(unlockAt: Date) {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    print("Account temporarily locked until \(formatter.string(from: unlockAt))")
    print("This is for your security due to repeated failed attempts.")
    
    // Could show user account recovery options
    // Could provide customer support contact
    // Could explain security policy
}

// MARK: - Security Best Practices

/*
Rate Limiting Best Practices:

1. Use different policies for different operations:
   - Authentication: 5 attempts per minute
   - Biometric auth: 3 attempts per minute (more strict)
   - API access: 10 attempts per minute (more lenient)
   - Sensitive operations: 3 attempts with longer lockouts

2. Implement exponential backoff for repeated failures:
   - First lockout: 60 seconds
   - Second lockout: 120 seconds
   - Third lockout: 240 seconds
   - Cap at maximum (e.g., 1 hour)

3. Track by appropriate identifiers:
   - Email address for user accounts
   - Device ID for device-specific limiting
   - IP address for network-level protection
   - Combination for enhanced security

4. Provide clear error messages:
   - Tell users when they can try again
   - Explain security policy
   - Offer alternative authentication methods

5. Maintenance and cleanup:
   - Regularly clean up expired attempt records
   - Monitor for suspicious patterns
   - Log security events for analysis

6. Testing and development:
   - Use bypass mode only in development
   - Test with various policies and scenarios
   - Verify error handling and user experience

7. Configuration flexibility:
   - Allow different policies per operation
   - Support configuration changes without app updates
   - Consider user feedback and adjust policies

8. Compliance considerations:
   - Document security policies
   - Ensure audit trail for security events
   - Meet regulatory requirements (SOC2, PCI, etc.)
*/