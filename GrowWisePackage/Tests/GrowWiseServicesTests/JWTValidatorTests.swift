import XCTest
import CryptoKit
@testable import GrowWiseServices

final class JWTValidatorTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var validator: JWTValidator!
    private let testIssuer = "com.growwiser.app"
    private let testAudience = "growwiser-api"
    private let testSharedSecret = "test-secret-key-for-hmac-256"
    
    // Test RSA key pair (for testing only - DO NOT use in production)
    private let testPublicKey = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4f5wg5l2hKsTeNem/V41
    fGnJm6gOdrj8ym3rFkEjWT2btf07HST5vszz5h7zEX8yIhkPFyDl7cgzCnkjN9gU
    TETl4LlWRhSHwNWa7gvXXDM5LwK3o1Th5PEr1Q1kVOm1k4w1mTZ5sL8B2fvwjqjb
    k1PNgOKY1T3h5w8hwG7G8mX3tQ1q2+GxF0xCvqLx9OGmGXzOGU9eVJR2YKCzKhMM
    CVFN7bUz5xCz8yYJCe8DglL6EQ0UHPLs+7ULnR0FkOYy8t1Rg6QIR1bGZyNhJr7Y
    zLU3mZYHJQiUy4U8DKjXi8KXEXwgpJ8N7v8nLQ2XvA5Q4q5yVY3XN2F2H5Q1w8Q7
    wIDAQAB
    -----END PUBLIC KEY-----
    """
    
    private let testPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDh/nCDmXaEqxN4
    16b9XjV8acmbqA52uPzKbesWQSNZPZu1/TsdJPm+zPPmHvMRfzIiGQ8XIOXtyDMK
    eSM32BRMROXguVZGFIfA1ZruC9dcMzkvArejVOHk8SvVDWRU6bWTjDWZNnmwvwHZ
    +/COqNuTU82A4pjVPeHnDyHAbsbyZfe1DWrb4bEXTEK+ovH04aYZfM4ZT15UlHZg
    oLMqEwwJUU3ttTPnELPzJgkJ7wOCUvoRDRQc8uz7tQudHQWQ5jLy3VGDpAhHVsZn
    I2EmvtjMtTeZlgclCJTLhTwMqNeLwpcRfCCknw3u/yctDZe8DlDirnJVjdc3YXYf
    lDXDxDvAgMBAAECggEBALiKfDjD2wJM/G8KnCnxnDYg7nfOjL6rL3UMDwGzLXQV
    XzHhw9b1p8z9mBhQjL6KOj6h9L8WXjK4t5oFp3tIuA2XsXkM9X7q/HwQ3bZvs1wG
    lFpkGgRRN7OIX9CJL2F4J5c6O6L1A3xL8xQv8KYE7N3vf4h3z8p7cXFhB2F4hDjH
    KCQlZfYAJYhpQPF1vxCJNQlE2lK9GtZ1qBCHNF4OB1K8H2fzLKZD9e9+mLfW2XM8
    v2xJoEYWIrW3t7iC2z5tS9Z4KM3p5hQrKJ1C3v9EJJ5J+4Z4Yj3Y5Y8U5J8t1gL
    2YV3yH7f+pG3Q2cYzQ1qP8F2RrG9v7Y3eY7F6Q6d3QJBANmZv5I2I3OPqN6Z7u1k
    mCz2X9bZ6T8L2qL7OEn5B5Z0qM9Z9Y1F2K4f5qA2pL8xE6g5wF9E8qY7XM8t9kJQ
    f3UCQQCTw3t9p2PfQ4HlB2+V9w3XvZ7c9O8f2K8L3hT7t8G2q5zKQRbT2H5E8Cv1
    3k9M6b8Y3f7p9L4s1x2T6x8E6y7xAkEAjOJnZP8OQk4X2V3G8Q9J5K2F4E8f9g7H
    1q5Y7Z3R2w4T6V8E9f7L4s2x3J5k1g8M7h9T3e4Y5Z1q2C6F9H8x1wJBAI5Y7Z3R
    2w4T6V8E9f7L4s2x3J5k1g8M7h9T3e4Y5Z1q2C6F9H8x1wJBANmZv5I2I3OPqN6Z
    7u1kmCz2X9bZ6T8L2qL7OEn5B5Z0qM9Z9Y1F2K4f5qA2pL8xE6g5wF9E8qY7XM8t
    9kJQf3U=
    -----END PRIVATE KEY-----
    """
    
    override func setUp() {
        super.setUp()
        
        let configuration = TokenManagementService.Configuration(
            expectedIssuer: testIssuer,
            expectedAudience: testAudience,
            publicKey: testPublicKey,
            sharedSecret: testSharedSecret
        )
        
        validator = JWTValidator(configuration: configuration)
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
    
    // MARK: - Format Validation Tests
    
    func testValidJWTFormat() throws {
        let validJWT = createTestJWT(algorithm: "HS256")
        
        // Should not throw
        XCTAssertNoThrow(try validator.decode(validJWT))
    }
    
    func testInvalidJWTFormat() {
        let invalidJWTs = [
            "invalid",
            "invalid.jwt",
            "invalid.jwt.format.extra",
            "",
            "...",
            "invalid..signature"
        ]
        
        for invalidJWT in invalidJWTs {
            XCTAssertThrowsError(try validator.decode(invalidJWT)) { error in
                guard let validationError = error as? JWTValidator.JWTValidationError else {
                    XCTFail("Expected JWTValidationError")
                    return
                }
                
                switch validationError {
                case .invalidFormat, .invalidHeader, .invalidPayload:
                    break // Expected
                default:
                    XCTFail("Unexpected error type: \\(validationError)")
                }
            }
        }
    }
    
    // MARK: - Header Validation Tests
    
    func testValidHeader() throws {
        let jwt = createTestJWT(algorithm: "HS256")
        let decoded = try validator.decode(jwt)
        
        XCTAssertEqual(decoded.header.alg, "HS256")
        XCTAssertEqual(decoded.header.typ, "JWT")
    }
    
    func testInvalidHeader() {
        let invalidHeader = "invalid-base64"
        let validPayload = createTestPayload()
        let validSignature = "signature"
        
        let invalidJWT = "\\(invalidHeader).\\(validPayload).\\(validSignature)"
        
        XCTAssertThrowsError(try validator.decode(invalidJWT)) { error in
            XCTAssertTrue(error is JWTValidator.JWTValidationError)
        }
    }
    
    // MARK: - Payload Validation Tests
    
    func testValidPayload() throws {
        let jwt = createTestJWT(algorithm: "HS256")
        let decoded = try validator.decode(jwt)
        
        XCTAssertEqual(decoded.payload.iss, testIssuer)
        XCTAssertEqual(decoded.payload.aud, testAudience)
        XCTAssertNotNil(decoded.payload.exp)
        XCTAssertNotNil(decoded.payload.iat)
    }
    
    func testTokenExpiration() {
        let expiredJWT = createTestJWT(
            algorithm: "HS256",
            expirationOffset: -3600 // Expired 1 hour ago
        )
        
        XCTAssertThrowsError(try validator.validate(expiredJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .tokenExpired = validationError {
                // Expected
            } else {
                XCTFail("Expected tokenExpired error, got \\(validationError)")
            }
        }
    }
    
    func testTokenNotYetValid() {
        let futureJWT = createTestJWT(
            algorithm: "HS256",
            notBeforeOffset: 3600 // Valid in 1 hour
        )
        
        XCTAssertThrowsError(try validator.validate(futureJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .tokenNotYetValid = validationError {
                // Expected
            } else {
                XCTFail("Expected tokenNotYetValid error, got \\(validationError)")
            }
        }
    }
    
    func testInvalidIssuer() {
        let invalidIssuerJWT = createTestJWT(
            algorithm: "HS256",
            issuer: "invalid.issuer.com"
        )
        
        XCTAssertThrowsError(try validator.validate(invalidIssuerJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .invalidIssuer(let expected, let actual) = validationError {
                XCTAssertEqual(expected, testIssuer)
                XCTAssertEqual(actual, "invalid.issuer.com")
            } else {
                XCTFail("Expected invalidIssuer error, got \\(validationError)")
            }
        }
    }
    
    func testInvalidAudience() {
        let invalidAudienceJWT = createTestJWT(
            algorithm: "HS256",
            audience: "invalid-audience"
        )
        
        XCTAssertThrowsError(try validator.validate(invalidAudienceJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .invalidAudience(let expected, let actual) = validationError {
                XCTAssertEqual(expected, testAudience)
                XCTAssertEqual(actual, "invalid-audience")
            } else {
                XCTFail("Expected invalidAudience error, got \\(validationError)")
            }
        }
    }
    
    // MARK: - Signature Validation Tests
    
    func testValidHS256Signature() {
        let validJWT = createTestJWT(algorithm: "HS256")
        
        // Should validate successfully
        XCTAssertNoThrow(try validator.validate(validJWT))
    }
    
    func testInvalidHS256Signature() {
        let validJWT = createTestJWT(algorithm: "HS256")
        let parts = validJWT.components(separatedBy: ".")
        let invalidJWT = "\\(parts[0]).\\(parts[1]).invalid-signature"
        
        XCTAssertThrowsError(try validator.validate(invalidJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            // Should fail during signature verification or format validation
            switch validationError {
            case .invalidSignature, .invalidFormat:
                break // Expected
            default:
                XCTFail("Expected invalidSignature or invalidFormat error, got \\(validationError)")
            }
        }
    }
    
    func testUnsupportedAlgorithm() {
        let unsupportedJWT = createTestJWT(algorithm: "HS512") // Not supported
        
        XCTAssertThrowsError(try validator.validate(unsupportedJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .unsupportedAlgorithm(let alg) = validationError {
                XCTAssertEqual(alg, "HS512")
            } else {
                XCTFail("Expected unsupportedAlgorithm error, got \\(validationError)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteValidation() {
        let validJWT = createTestJWT(algorithm: "HS256")
        
        // Complete validation should succeed
        XCTAssertNoThrow(try validator.validate(validJWT))
    }
    
    func testDecodeWithoutValidation() throws {
        let jwt = createTestJWT(algorithm: "HS256")
        let decoded = try validator.decode(jwt)
        
        XCTAssertEqual(decoded.header.alg, "HS256")
        XCTAssertEqual(decoded.payload.iss, testIssuer)
        XCTAssertEqual(decoded.payload.aud, testAudience)
        XCTAssertFalse(decoded.isExpired)
        XCTAssertFalse(decoded.isNotYetValid)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStringValidation() {
        XCTAssertThrowsError(try validator.validate(""))
    }
    
    func testNilClaimsHandling() throws {
        let jwt = createTestJWT(
            algorithm: "HS256",
            includeOptionalClaims: false
        )
        
        let decoded = try validator.decode(jwt)
        XCTAssertNil(decoded.payload.sub)
        XCTAssertNil(decoded.payload.jti)
    }
    
    // MARK: - Helper Methods
    
    private func createTestJWT(
        algorithm: String = "HS256",
        issuer: String? = nil,
        audience: String? = nil,
        expirationOffset: TimeInterval = 3600,
        notBeforeOffset: TimeInterval? = nil,
        includeOptionalClaims: Bool = true
    ) -> String {
        
        let header = [
            "alg": algorithm,
            "typ": "JWT"
        ]
        
        let now = Date().timeIntervalSince1970
        var payload: [String: Any] = [
            "iss": issuer ?? testIssuer,
            "aud": audience ?? testAudience,
            "exp": now + expirationOffset,
            "iat": now
        ]
        
        if let nbf = notBeforeOffset {
            payload["nbf"] = now + nbf
        }
        
        if includeOptionalClaims {
            payload["sub"] = "test-user-123"
            payload["jti"] = UUID().uuidString
        }
        
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerEncoded = headerData.base64URLEncodedString()
        let payloadEncoded = payloadData.base64URLEncodedString()
        
        let signingInput = "\\(headerEncoded).\\(payloadEncoded)"
        
        if algorithm == "HS256" {
            let signature = createHMACSignature(for: signingInput)
            return "\\(signingInput).\\(signature)"
        } else {
            // For unsupported algorithms, just return with empty signature
            return "\\(signingInput)."
        }
    }
    
    private func createTestPayload() -> String {
        let payload = [
            "iss": testIssuer,
            "aud": testAudience,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "iat": Date().timeIntervalSince1970
        ] as [String: Any]
        
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        return payloadData.base64URLEncodedString()
    }
    
    private func createHMACSignature(for input: String) -> String {
        guard let inputData = input.data(using: .utf8),
              let secretData = testSharedSecret.data(using: .utf8) else {
            return ""
        }
        
        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: inputData, using: key)
        return Data(signature).base64URLEncodedString()
    }
}

// MARK: - Data Extension for Base64URL

private extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}