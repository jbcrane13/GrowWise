import XCTest
import CryptoKit
@testable import GrowWiseServices

final class JWTValidationIntegrationTests: XCTestCase {
    
    private var tokenService: TokenManagementService!
    private var encryptionService: EncryptionService!
    private var keychain: KeychainStorageService!
    
    override func setUp() {
        super.setUp()
        
        // Create test services
        encryptionService = EncryptionService()
        keychain = KeychainStorageService()
        
        // Configure with test parameters
        let config = TokenManagementService.Configuration(
            expectedIssuer: "test-issuer",
            expectedAudience: "test-audience",
            sharedSecret: "test-secret-key-for-hmac-256"
        )
        
        tokenService = TokenManagementService(
            encryptionService: encryptionService,
            storage: keychain,
            configuration: config
        )
    }
    
    override func tearDown() {
        tokenService.clearAllTokens()
        tokenService = nil
        encryptionService = nil
        keychain = nil
        super.tearDown()
    }
    
    func testJWTValidationWithValidToken() throws {
        // Create a valid JWT token
        let validJWT = createValidTestJWT()
        
        // Should not throw when validating
        XCTAssertNoThrow(try tokenService.validateJWT(validJWT))
    }
    
    func testJWTValidationWithInvalidFormat() {
        let invalidJWT = "invalid.jwt.format.extra"
        
        XCTAssertThrowsError(try tokenService.validateJWT(invalidJWT)) { error in
            XCTAssertTrue(error is TokenManagementService.TokenError)
        }
    }
    
    func testJWTValidationWithExpiredToken() {
        let expiredJWT = createExpiredTestJWT()
        
        XCTAssertThrowsError(try tokenService.validateJWT(expiredJWT)) { error in
            guard let tokenError = error as? TokenManagementService.TokenError else {
                XCTFail("Expected TokenError")
                return
            }
            
            XCTAssertEqual(tokenError, .tokenExpired)
        }
    }
    
    func testStoreCredentialsWithValidation() throws {
        let validJWT = createValidTestJWT()
        
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validJWT, // Using same for simplicity
            expiresIn: 3600,
            userId: "test-user",
            tokenType: "Bearer"
        )
        
        // Should store successfully with validation
        XCTAssertNoThrow(try tokenService.storeSecureCredentials(credentials))
        
        // Should retrieve successfully
        let retrieved = try tokenService.retrieveSecureCredentials()
        XCTAssertEqual(retrieved.accessToken, validJWT)
        XCTAssertEqual(retrieved.userId, credentials.userId)
    }
    
    func testStoreInvalidTokenFails() {
        let invalidJWT = "invalid.token.format"
        
        let credentials = SecureCredentials(
            accessToken: invalidJWT,
            refreshToken: "",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        
        // Should fail validation
        XCTAssertThrowsError(try tokenService.storeSecureCredentials(credentials))
    }
    
    // MARK: - Helper Methods
    
    private func createValidTestJWT() -> String {
        let header = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        let now = Date().timeIntervalSince1970
        let payload = [
            "iss": "test-issuer",
            "aud": "test-audience",
            "exp": now + 3600, // Expires in 1 hour
            "iat": now,
            "sub": "test-user"
        ] as [String: Any]
        
        return createJWTFromComponents(header: header, payload: payload)
    }
    
    private func createExpiredTestJWT() -> String {
        let header = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        let now = Date().timeIntervalSince1970
        let payload = [
            "iss": "test-issuer",
            "aud": "test-audience",
            "exp": now - 3600, // Expired 1 hour ago
            "iat": now - 7200,
            "sub": "test-user"
        ] as [String: Any]
        
        return createJWTFromComponents(header: header, payload: payload)
    }
    
    private func createJWTFromComponents(header: [String: Any], payload: [String: Any]) -> String {
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerEncoded = headerData.base64URLEncodedString()
        let payloadEncoded = payloadData.base64URLEncodedString()
        
        let signingInput = "\\(headerEncoded).\\(payloadEncoded)"
        let signature = createHMACSignature(for: signingInput)
        
        return "\\(signingInput).\\(signature)"
    }
    
    private func createHMACSignature(for input: String) -> String {
        guard let inputData = input.data(using: .utf8),
              let secretData = "test-secret-key-for-hmac-256".data(using: .utf8) else {
            return ""
        }
        
        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: inputData, using: key)
        return Data(signature).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}