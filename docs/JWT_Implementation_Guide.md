# JWT Cryptographic Validation Implementation

## Overview

The GrowWise Token Management Service now includes comprehensive JWT (JSON Web Token) cryptographic validation with signature verification and claims validation. This implementation follows security best practices and supports both RS256 (RSA with SHA-256) and HS256 (HMAC with SHA-256) algorithms.

## Features

### ✅ Cryptographic Signature Verification
- **RS256**: RSA with SHA-256 using public/private key pairs
- **HS256**: HMAC with SHA-256 using shared secrets
- **Constant-time signature comparison** to prevent timing attacks

### ✅ Standard Claims Validation
- **iss** (Issuer): Verifies the token issuer
- **aud** (Audience): Validates intended audience
- **exp** (Expiration): Checks token expiration
- **nbf** (Not Before): Validates token activation time
- **iat** (Issued At): Token issuance timestamp
- **sub** (Subject): Token subject identifier

### ✅ Security Features
- **Format validation**: Proper JWT structure (header.payload.signature)
- **Base64URL decoding**: RFC 7515 compliant encoding
- **Algorithm verification**: Prevents algorithm substitution attacks
- **Key validation**: Ensures proper cryptographic material

## Implementation Details

### JWTValidator Class

```swift
public final class JWTValidator {
    
    // Initialize with configuration
    let config = TokenManagementService.Configuration(
        expectedIssuer: "com.growwiser.app",
        expectedAudience: "growwiser-api",
        publicKey: rsaPublicKey,      // For RS256
        sharedSecret: hmacSecret      // For HS256
    )
    
    let validator = JWTValidator(configuration: config)
    
    // Validate JWT with full verification
    try validator.validate(jwtToken)
    
    // Decode JWT for inspection (without validation)
    let decoded = try validator.decode(jwtToken)
}
```

### TokenManagementService Integration

```swift
// Configure the service with JWT validation
let config = TokenManagementService.Configuration(
    expectedIssuer: "your-issuer",
    expectedAudience: "your-audience",
    publicKey: "-----BEGIN PUBLIC KEY-----\\n...", // For RS256
    sharedSecret: "your-secret-key"                  // For HS256
)

let tokenService = TokenManagementService(
    encryptionService: encryptionService,
    storage: keychainStorage,
    configuration: config
)

// Store credentials - automatically validates JWT
try tokenService.storeSecureCredentials(credentials)

// Validate existing JWT
try tokenService.validateJWT(accessToken)
```

## Supported Algorithms

### RS256 (RSA with SHA-256)
- Uses RSA public/private key pairs
- Public key verification on client
- Suitable for distributed systems
- Requires valid PEM-formatted public key

```swift
let publicKey = """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----
"""

let config = TokenManagementService.Configuration(
    expectedIssuer: "your-issuer",
    expectedAudience: "your-audience",
    publicKey: publicKey
)
```

### HS256 (HMAC with SHA-256)
- Uses shared secret
- Symmetric key cryptography
- Suitable for internal systems
- Requires secure secret distribution

```swift
let config = TokenManagementService.Configuration(
    expectedIssuer: "your-issuer",
    expectedAudience: "your-audience",
    sharedSecret: "your-256-bit-secret-key"
)
```

## Error Handling

The JWT validator provides comprehensive error handling:

```swift
do {
    try validator.validate(jwt)
} catch let error as JWTValidator.JWTValidationError {
    switch error {
    case .invalidFormat:
        // JWT format is invalid
    case .invalidSignature:
        // Signature verification failed
    case .tokenExpired:
        // Token has expired
    case .invalidIssuer(let expected, let actual):
        // Wrong issuer
    case .invalidAudience(let expected, let actual):
        // Wrong audience
    case .unsupportedAlgorithm(let alg):
        // Algorithm not supported
    // ... other cases
    }
}
```

## Security Considerations

### 1. Key Management
- **RS256**: Store public keys securely, rotate regularly
- **HS256**: Use strong secrets (256+ bits), never expose
- **Key Rotation**: Implement proper key rotation procedures

### 2. Claims Validation
- Always validate `iss` (issuer) and `aud` (audience)
- Check `exp` (expiration) for every request
- Consider `nbf` (not before) for time-sensitive operations
- Implement reasonable clock skew tolerance

### 3. Algorithm Security
- Never allow `"alg": "none"` tokens
- Prevent algorithm substitution attacks
- Use constant-time comparisons for HMAC

### 4. Transport Security
- Always use HTTPS in production
- Implement proper CORS policies
- Store tokens securely (encrypted in Keychain)

## Example JWT Structure

```json
// Header
{
  "alg": "HS256",
  "typ": "JWT"
}

// Payload
{
  "iss": "com.growwiser.app",
  "aud": "growwiser-api",
  "sub": "user-123",
  "exp": 1640995200,
  "iat": 1640991600,
  "nbf": 1640991600,
  "jti": "unique-token-id"
}

// Signature (Base64URL encoded)
// HMAC-SHA256(base64urlEncode(header) + "." + base64urlEncode(payload), secret)
```

## Testing

Comprehensive test suite included:

```swift
func testJWTValidation() throws {
    let validator = JWTValidator(configuration: config)
    
    // Test valid token
    XCTAssertNoThrow(try validator.validate(validJWT))
    
    // Test expired token
    XCTAssertThrowsError(try validator.validate(expiredJWT))
    
    // Test invalid signature
    XCTAssertThrowsError(try validator.validate(tamperedJWT))
}
```

## Production Checklist

- [ ] Configure appropriate issuer and audience values
- [ ] Set up secure key storage and rotation
- [ ] Implement proper error handling
- [ ] Add logging for security events
- [ ] Test with various JWT scenarios
- [ ] Monitor for invalid token attempts
- [ ] Set up token refresh mechanisms
- [ ] Implement rate limiting for validation endpoints

## Migration Guide

### From Basic Format Validation

**Before:**
```swift
// Only checked format
private func isValidJWTFormat(_ token: String) -> Bool {
    let parts = token.components(separatedBy: ".")
    return parts.count == 3
}
```

**After:**
```swift
// Full cryptographic validation
try tokenService.validateJWT(token) // Validates signature + claims
```

### Configuration Required

Update your service initialization:

```swift
// Add configuration with your security parameters
let config = TokenManagementService.Configuration(
    expectedIssuer: "your-issuer",
    expectedAudience: "your-audience",
    sharedSecret: "your-secret" // or publicKey for RS256
)

let tokenService = TokenManagementService(
    encryptionService: encryptionService,
    storage: storage,
    configuration: config  // Add this parameter
)
```

## References

- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)
- [RFC 7515 - JSON Web Signature (JWS)](https://tools.ietf.org/html/rfc7515)
- [OWASP JWT Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)