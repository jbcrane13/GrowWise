# KeychainManager Migration Guide

## Overview

The deprecated `storeUserCredentials` and `retrieveUserCredentials` methods have been completely removed from the KeychainManager public API to enhance security and prevent accidental usage of insecure authentication patterns.

## Removed Methods

### `storeUserCredentials(email:password:)` - REMOVED ❌

This method previously accepted plaintext email and password parameters, which violated security best practices by:
- Storing passwords in plaintext or with weak encryption
- Lacking proper token-based authentication
- Missing JWT validation and expiration handling
- Not supporting modern authentication flows

### `retrieveUserCredentials()` - REMOVED ❌

This method previously returned plaintext credentials as a tuple, which was insecure because:
- Passwords should never be retrieved in plaintext
- No rate limiting or biometric protection
- Vulnerable to credential theft
- Did not follow OAuth 2.0 or JWT standards

## Secure Alternatives

### For Storing Authentication Data

Replace deprecated password storage with secure JWT credential storage:

#### ❌ Old (Deprecated - Now Removed):
```swift
// This will no longer compile
try keychain.storeUserCredentials(email: "user@example.com", password: "password123")
```

#### ✅ New (Secure):
```swift
// Store JWT-based secure credentials
let credentials = SecureCredentials(
    userId: "user-12345",
    accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    refreshToken: "refresh-token-abc123",
    expiresAt: Date().addingTimeInterval(3600), // 1 hour
    tokenType: "Bearer"
)

try keychain.storeSecureCredentials(credentials)
```

### For Retrieving Authentication Data

Replace insecure credential retrieval with secure, rate-limited access:

#### ❌ Old (Deprecated - Now Removed):
```swift
// This will no longer compile
let (email, password) = try keychain.retrieveUserCredentials()
```

#### ✅ New (Secure):
```swift
// Retrieve with rate limiting protection
let credentials = try keychain.retrieveSecureCredentials(for: "user-identifier")

// Or with biometric protection
let credentials = try await keychain.retrieveSecureCredentialsWithBiometric(
    for: "user-identifier",
    reason: "Authenticate to access your account"
)

// Access the secure token
let accessToken = credentials.accessToken
```

## Migration Steps

### 1. Update Authentication Flow

Replace password-based authentication with token-based authentication:

```swift
// Instead of storing username/password
class AuthenticationService {
    private let keychain = KeychainManager.shared
    
    // ✅ New secure login flow
    func login(email: String, password: String) async throws -> SecureCredentials {
        // Authenticate with your backend service
        let authResponse = try await authenticateWithBackend(email: email, password: password)
        
        // Create secure credentials from response
        let credentials = SecureCredentials(
            userId: authResponse.userId,
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            expiresAt: authResponse.expiresAt,
            tokenType: authResponse.tokenType
        )
        
        // Store securely in keychain
        try keychain.storeSecureCredentials(credentials)
        
        return credentials
    }
    
    func getValidToken() async throws -> String {
        let credentials = try keychain.retrieveSecureCredentials()
        
        // Check if token needs refresh
        if keychain.credentialsNeedRefresh() {
            let refreshedCredentials = try await refreshTokens(credentials.refreshToken)
            try keychain.storeSecureCredentials(refreshedCredentials)
            return refreshedCredentials.accessToken
        }
        
        return credentials.accessToken
    }
}
```

### 2. Update UI Components

Replace password storage UI with secure authentication:

```swift
// ✅ Updated login view model
class LoginViewModel: ObservableObject {
    private let authService = AuthenticationService()
    
    func authenticate(email: String, password: String) async {
        do {
            let credentials = try await authService.login(email: email, password: password)
            // Use the secure credentials for subsequent API calls
            await configureAPIClient(with: credentials.accessToken)
        } catch {
            // Handle authentication errors
            handleAuthenticationError(error)
        }
    }
}
```

### 3. Update API Integration

Use secure tokens for API authentication:

```swift
class APIClient {
    private let keychain = KeychainManager.shared
    
    func makeSecureRequest() async throws {
        // Get valid token (automatically refreshes if needed)
        let token = try await getValidToken()
        
        // Use token in API request
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        // Handle response...
    }
    
    private func getValidToken() async throws -> String {
        let credentials = try keychain.retrieveSecureCredentials()
        
        if keychain.credentialsNeedRefresh() {
            // Token refresh logic here
            return try await refreshAndGetToken()
        }
        
        return credentials.accessToken
    }
}
```

## Security Benefits of Migration

### Enhanced Security Features:
- **JWT-based authentication** with proper validation
- **Automatic token expiration** handling
- **Rate limiting** to prevent brute force attacks
- **Biometric protection** for sensitive operations
- **Encrypted storage** using iOS Keychain with Secure Enclave
- **Audit logging** for compliance and security monitoring

### Removed Security Vulnerabilities:
- No more plaintext password storage
- Eliminated password retrieval in plaintext
- Removed weak credential validation
- Fixed missing rate limiting
- Addressed audit logging gaps

## Error Handling

The new secure methods provide better error handling:

```swift
do {
    let credentials = try keychain.retrieveSecureCredentials(for: userIdentifier)
    // Use credentials...
} catch KeychainManager.KeychainError.rateLimitExceeded(let retryAfter) {
    // Handle rate limiting
    showRateLimitError(retryAfter: retryAfter)
} catch KeychainManager.KeychainError.accountLocked(let unlockAt) {
    // Handle account lockout
    showAccountLockedError(unlockAt: unlockAt)
} catch KeychainManager.KeychainError.tokenExpired {
    // Handle expired tokens
    redirectToLogin()
} catch {
    // Handle other errors
    showGenericError(error)
}
```

## Testing Your Migration

### Unit Tests
```swift
func testSecureCredentialStorage() throws {
    let credentials = SecureCredentials(
        userId: "test-user",
        accessToken: "test-token",
        refreshToken: "test-refresh",
        expiresAt: Date().addingTimeInterval(3600),
        tokenType: "Bearer"
    )
    
    // Store and retrieve securely
    try keychain.storeSecureCredentials(credentials)
    let retrieved = try keychain.retrieveSecureCredentials()
    
    XCTAssertEqual(retrieved.userId, credentials.userId)
    XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
}
```

### Integration Tests
```swift
func testBiometricCredentialRetrieval() async throws {
    // Store credentials
    let credentials = SecureCredentials(/* ... */)
    try keychain.storeSecureCredentials(credentials)
    
    // Retrieve with biometric protection
    let retrieved = try await keychain.retrieveSecureCredentialsWithBiometric(
        for: "test-user",
        reason: "Test authentication"
    )
    
    XCTAssertEqual(retrieved.userId, credentials.userId)
}
```

## Rollback Plan

If you encounter issues during migration, you can temporarily use the legacy auth token methods while you fix the implementation:

```swift
// Temporary fallback (still secure, but less feature-rich)
try keychain.storeAuthToken(accessToken)
let token = try keychain.retrieveAuthToken()
```

However, these legacy methods are also deprecated and should only be used temporarily during migration.

## Support

For questions about this migration:

1. Review the [KeychainManager documentation](./KeychainManager-API-Reference.md)
2. Check the [Security Best Practices](./Security-Best-Practices.md)
3. Review example implementations in the test suite
4. For complex authentication flows, consider using the biometric protection features

## Timeline

- **Phase 1**: Deprecated methods removed from public API
- **Phase 2**: Internal cleanup of deprecated error cases
- **Phase 3**: Enhanced secure credential features
- **Phase 4**: Legacy method removal (complete)

The migration is now complete. All deprecated methods have been removed to ensure secure authentication practices across the application.