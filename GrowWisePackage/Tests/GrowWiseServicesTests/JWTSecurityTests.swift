import XCTest
import CryptoKit
@testable import GrowWiseServices

/// Comprehensive JWT Security Test Suite
/// Validates cryptographic verification, timing attacks, and security best practices
final class JWTSecurityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var validator: JWTValidator!
    private let testIssuer = "com.growwise.security"
    private let testAudience = "growwise-secure-api"
    private let testSharedSecret = "test-security-secret-key-for-hmac-validation-long-enough"
    
    // Test RSA key pair for cryptographic tests
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
    
    // MARK: - Cryptographic Security Tests
    
    func testCryptographicSignatureVerification() throws {
        // Test valid signature
        let validJWT = createSecureTestJWT(algorithm: "HS256")
        XCTAssertNoThrow(try validator.validate(validJWT))
        
        // Test signature tampering
        let parts = validJWT.components(separatedBy: ".")
        let tamperedSignature = Data(repeating: 0x41, count: 32).base64URLEncodedString()
        let tamperedJWT = "\(parts[0]).\(parts[1]).\(tamperedSignature)"
        
        XCTAssertThrowsError(try validator.validate(tamperedJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            switch validationError {
            case .invalidSignature, .invalidFormat:
                break // Expected
            default:
                XCTFail("Expected signature validation error, got \(validationError)")
            }
        }
    }
    
    func testWeakSignatureAlgorithms() {
        let weakAlgorithms = ["none", "HS1", "RS1", "ES1"]
        
        for algorithm in weakAlgorithms {
            let weakJWT = createTestJWT(algorithm: algorithm)
            
            XCTAssertThrowsError(try validator.validate(weakJWT)) { error in
                guard let validationError = error as? JWTValidator.JWTValidationError else {
                    XCTFail("Expected JWTValidationError for algorithm \(algorithm)")
                    return
                }
                
                switch validationError {
                case .unsupportedAlgorithm(let alg):
                    XCTAssertEqual(alg, algorithm)
                case .invalidSignature, .invalidFormat:
                    break // Also acceptable
                default:
                    XCTFail("Expected unsupportedAlgorithm error for \(algorithm), got \(validationError)")
                }
            }
        }
    }
    
    func testAlgorithmConfusion() {
        // Test algorithm confusion attack (changing RS256 to HS256)
        let confusedJWT = createTestJWT(algorithm: "RS256") // Server expects HS256
        
        XCTAssertThrowsError(try validator.validate(confusedJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            // Should fail due to unsupported algorithm or signature mismatch
            switch validationError {
            case .unsupportedAlgorithm, .invalidSignature, .invalidFormat:
                break // Expected
            default:
                XCTFail("Expected algorithm confusion protection, got \(validationError)")
            }
        }
    }
    
    // MARK: - Timing Attack Tests
    
    func testTimingAttackResistance() {
        let validJWT = createSecureTestJWT(algorithm: "HS256")
        let invalidJWTs = [
            createTestJWT(algorithm: "HS256", issuer: "invalid.issuer"),
            createTestJWT(algorithm: "HS256", audience: "invalid.audience"),
            createTestJWT(algorithm: "HS256", expirationOffset: -3600),
            "invalid.jwt.format"
        ]
        
        // Measure timing for valid JWT
        let validStartTime = CFAbsoluteTimeGetCurrent()
        _ = try? validator.validate(validJWT)
        let validEndTime = CFAbsoluteTimeGetCurrent()
        let validDuration = validEndTime - validStartTime
        
        // Measure timing for invalid JWTs
        var invalidDurations: [Double] = []
        
        for invalidJWT in invalidJWTs {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try? validator.validate(invalidJWT)
            let endTime = CFAbsoluteTimeGetCurrent()
            invalidDurations.append(endTime - startTime)
        }
        
        // Calculate timing statistics
        let averageInvalidDuration = invalidDurations.reduce(0, +) / Double(invalidDurations.count)
        let timingDifference = abs(validDuration - averageInvalidDuration)
        
        // Timing difference should be minimal to prevent timing attacks
        XCTAssertLessThan(timingDifference, 0.001, "Significant timing difference detected")
        
        // All invalid JWTs should have similar timing
        let maxTiming = invalidDurations.max() ?? 0
        let minTiming = invalidDurations.min() ?? 0
        let timingVariance = maxTiming - minTiming
        
        XCTAssertLessThan(timingVariance, 0.001, "High timing variance in invalid JWT processing")
    }
    
    // MARK: - Token Manipulation Tests
    
    func testPayloadManipulation() {
        let originalJWT = createSecureTestJWT(algorithm: "HS256")
        let parts = originalJWT.components(separatedBy: ".")
        
        // Manipulate payload
        var payload: [String: Any] = [
            "iss": testIssuer,
            "aud": testAudience,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "iat": Date().timeIntervalSince1970,
            "admin": true, // Added privilege escalation
            "roles": ["admin", "superuser"] // Added unauthorized roles
        ]
        
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        let manipulatedPayload = payloadData.base64URLEncodedString()
        let manipulatedJWT = "\(parts[0]).\(manipulatedPayload).\(parts[2])"
        
        // Should fail signature verification
        XCTAssertThrowsError(try validator.validate(manipulatedJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            switch validationError {
            case .invalidSignature:
                break // Expected - signature doesn't match modified payload
            default:
                XCTFail("Expected invalidSignature error, got \(validationError)")
            }
        }
    }
    
    func testHeaderManipulation() {
        let originalJWT = createSecureTestJWT(algorithm: "HS256")
        let parts = originalJWT.components(separatedBy: ".")
        
        // Manipulate header to change algorithm
        let maliciousHeader = [
            "alg": "none", // Attempt to bypass signature verification
            "typ": "JWT"
        ]
        
        let headerData = try! JSONSerialization.data(withJSONObject: maliciousHeader)
        let manipulatedHeader = headerData.base64URLEncodedString()
        let manipulatedJWT = "\(manipulatedHeader).\(parts[1]).\(parts[2])"
        
        XCTAssertThrowsError(try validator.validate(manipulatedJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            switch validationError {
            case .unsupportedAlgorithm(let alg):
                XCTAssertEqual(alg, "none")
            case .invalidSignature, .invalidFormat:
                break // Also acceptable
            default:
                XCTFail("Expected protection against algorithm manipulation, got \(validationError)")
            }
        }
    }
    
    // MARK: - Replay Attack Tests
    
    func testReplayAttackPrevention() {
        let jwt = createSecureTestJWT(algorithm: "HS256", includeJTI: true)
        
        // First validation should succeed
        XCTAssertNoThrow(try validator.validate(jwt))
        
        // Subsequent validations should also succeed (JWT itself doesn't prevent replay)
        // Replay attack prevention should be handled at application level
        XCTAssertNoThrow(try validator.validate(jwt))
        
        // However, expired tokens should not be replayable
        let expiredJWT = createSecureTestJWT(
            algorithm: "HS256",
            expirationOffset: -3600, // Expired 1 hour ago
            includeJTI: true
        )
        
        XCTAssertThrowsError(try validator.validate(expiredJWT)) { error in
            guard let validationError = error as? JWTValidator.JWTValidationError else {
                XCTFail("Expected JWTValidationError")
                return
            }
            
            if case .tokenExpired = validationError {
                // Expected - expired tokens cannot be replayed
            } else {
                XCTFail("Expected tokenExpired error, got \(validationError)")
            }
        }
    }
    
    // MARK: - Side Channel Attack Tests
    
    func testSideChannelResistance() {
        // Test with various JWT lengths to ensure constant-time processing
        let jwtLengths = [100, 200, 500, 1000, 2000]
        var processingTimes: [Double] = []
        
        for length in jwtLengths {
            let longClaims = String(repeating: "a", count: length)
            let jwt = createSecureTestJWT(
                algorithm: "HS256",
                additionalClaims: ["longClaim": longClaims]
            )
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try? validator.validate(jwt)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            processingTimes.append(endTime - startTime)
        }
        
        // Processing time should not vary significantly with JWT size
        let maxTime = processingTimes.max() ?? 0
        let minTime = processingTimes.min() ?? 0
        let timingRatio = maxTime / max(minTime, 0.001) // Avoid division by zero
        
        XCTAssertLessThan(timingRatio, 5.0, "Processing time varies too much with JWT size")
    }
    
    // MARK: - Boundary Condition Tests
    
    func testExtremeExpirationTimes() {
        // Test far future expiration
        let farFutureJWT = createSecureTestJWT(
            algorithm: "HS256",
            expirationOffset: 365 * 24 * 60 * 60 // 1 year
        )
        XCTAssertNoThrow(try validator.validate(farFutureJWT))
        
        // Test very recent expiration (within grace period)
        let recentExpirationJWT = createSecureTestJWT(
            algorithm: "HS256",
            expirationOffset: 1 // 1 second
        )
        XCTAssertNoThrow(try validator.validate(recentExpirationJWT))
        
        // Test maximum timestamp value
        let maxTimestampJWT = createTestJWT(
            algorithm: "HS256",
            customClaims: [
                "exp": Double(Int.max),
                "iat": Date().timeIntervalSince1970
            ]
        )
        // Should handle gracefully without overflow
        _ = try? validator.validate(maxTimestampJWT)
    }
    
    func testMalformedTokenHandling() {
        let malformedTokens = [
            "", // Empty
            ".", // Single dot
            "..", // Two dots
            "...", // Three empty parts
            "a.b.c.d", // Too many parts
            "invalid-base64!@#.payload.signature",
            "header.invalid-base64!@#.signature",
            "header.payload.invalid-base64!@#",
            String(repeating: "a", count: 10000), // Extremely long
            "header\n.payload\n.signature\n", // With newlines
            "header .payload .signature" // With spaces
        ]
        
        for token in malformedTokens {
            XCTAssertThrowsError(try validator.validate(token)) { error in
                XCTAssertTrue(error is JWTValidator.JWTValidationError,
                            "Expected JWTValidationError for malformed token: \(token)")
            }
        }
    }
    
    // MARK: - Security Header Tests
    
    func testCriticalHeaderParameters() {
        // Test with critical header parameter
        let criticalHeader = [
            "alg": "HS256",
            "typ": "JWT",
            "crit": ["custom"] // Critical parameter that must be understood
        ]
        
        let headerData = try! JSONSerialization.data(withJSONObject: criticalHeader)
        let headerBase64 = headerData.base64URLEncodedString()
        let payload = createTestPayload()
        let signingInput = "\(headerBase64).\(payload)"
        let signature = createHMACSignature(for: signingInput)
        let jwtWithCrit = "\(signingInput).\(signature)"
        
        // Should reject tokens with unrecognized critical parameters
        XCTAssertThrowsError(try validator.validate(jwtWithCrit)) { error in
            // Implementation should reject unrecognized critical parameters
            XCTAssertTrue(error is JWTValidator.JWTValidationError)
        }
    }
    
    // MARK: - Performance Security Tests
    
    func testPerformanceUnderAttack() {
        measure {
            // Simulate high-frequency validation attempts
            for _ in 0..<1000 {
                let jwt = createSecureTestJWT(algorithm: "HS256")
                _ = try? validator.validate(jwt)
            }
        }
    }
    
    func testMemoryExhaustionResistance() {
        // Test with very large JWTs
        let largePayload = String(repeating: "x", count: 100000)
        let largeJWT = createSecureTestJWT(
            algorithm: "HS256",
            additionalClaims: ["largeData": largePayload]
        )
        
        // Should handle large JWTs without memory exhaustion
        let initialMemory = getMemoryUsage()
        _ = try? validator.validate(largeJWT)
        let finalMemory = getMemoryUsage()
        
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Excessive memory usage during JWT validation")
    }
    
    // MARK: - Helper Methods
    
    private func createSecureTestJWT(
        algorithm: String = "HS256",
        issuer: String? = nil,
        audience: String? = nil,
        expirationOffset: TimeInterval = 3600,
        notBeforeOffset: TimeInterval? = nil,
        includeJTI: Bool = false,
        additionalClaims: [String: Any] = [:]
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
        
        if includeJTI {
            payload["jti"] = UUID().uuidString
        }
        
        // Add additional claims
        for (key, value) in additionalClaims {
            payload[key] = value
        }
        
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerEncoded = headerData.base64URLEncodedString()
        let payloadEncoded = payloadData.base64URLEncodedString()
        
        let signingInput = "\(headerEncoded).\(payloadEncoded)"
        
        if algorithm == "HS256" {
            let signature = createHMACSignature(for: signingInput)
            return "\(signingInput).\(signature)"
        } else {
            // For unsupported algorithms, return with empty signature
            return "\(signingInput)."
        }
    }
    
    private func createTestJWT(
        algorithm: String = "HS256",
        customClaims: [String: Any]? = nil
    ) -> String {
        let header = [
            "alg": algorithm,
            "typ": "JWT"
        ]
        
        let payload = customClaims ?? [
            "iss": testIssuer,
            "aud": testAudience,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "iat": Date().timeIntervalSince1970
        ]
        
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerEncoded = headerData.base64URLEncodedString()
        let payloadEncoded = payloadData.base64URLEncodedString()
        
        return "\(headerEncoded).\(payloadEncoded)."
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

// MARK: - Data Extension for Base64URL

private extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}