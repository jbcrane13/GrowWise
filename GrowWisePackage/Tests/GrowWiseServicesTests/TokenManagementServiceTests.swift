import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels

/// Unit tests for TokenManagementService - JWT token operations
final class TokenManagementServiceTests: XCTestCase {
    
    var storage: KeychainStorageService!
    var encryptionService: EncryptionService!
    var tokenService: TokenManagementService!
    private let testService = "com.growwiser.token.test"
    
    // Test JWT tokens
    private let validJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    private let validRefreshToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.refresh_token_signature"
    
    override func setUp() {
        super.setUp()
        storage = KeychainStorageService(service: testService)
        encryptionService = EncryptionService(storage: storage)
        tokenService = TokenManagementService(encryptionService: encryptionService, storage: storage)
        
        // Clean up any existing test data
        try? storage.deleteAll()
    }
    
    override func tearDown() {
        // Clean up after tests
        try? storage.deleteAll()
        tokenService = nil
        encryptionService = nil
        storage = nil
        super.tearDown()
    }
    
    // MARK: - Secure Credentials Tests
    
    func testStoreAndRetrieveSecureCredentials() throws {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600,
            userId: "user123",
            tokenType: "Bearer"
        )
        
        // Store credentials
        XCTAssertNoThrow(try tokenService.storeSecureCredentials(credentials))
        
        // Retrieve credentials
        let retrieved = try tokenService.retrieveSecureCredentials()
        
        XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
        XCTAssertEqual(retrieved.refreshToken, credentials.refreshToken)
        XCTAssertEqual(retrieved.userId, credentials.userId)
        XCTAssertEqual(retrieved.tokenType, credentials.tokenType)
        XCTAssertEqual(retrieved.expiresIn, credentials.expiresIn)
    }
    
    func testStoreCredentialsWithoutRefreshToken() throws {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: "",
            expiresIn: 3600,
            userId: "user456"
        )
        
        // Store credentials without refresh token
        XCTAssertNoThrow(try tokenService.storeSecureCredentials(credentials))
        
        // Retrieve credentials
        let retrieved = try tokenService.retrieveSecureCredentials()
        
        XCTAssertEqual(retrieved.accessToken, credentials.accessToken)
        XCTAssertEqual(retrieved.refreshToken, "")
        XCTAssertEqual(retrieved.userId, credentials.userId)
    }
    
    func testRetrieveNonExistentCredentials() {
        // Should throw error when no credentials exist
        XCTAssertThrowsError(try tokenService.retrieveSecureCredentials()) { error in
            if let tokenError = error as? TokenManagementService.TokenError {
                switch tokenError {
                case .storageError:
                    break // Expected
                default:
                    XCTFail("Expected storage error")
                }
            }
        }
    }
    
    // MARK: - Access Token Tests
    
    func testStoreAndRetrieveAccessToken() throws {
        // Store access token
        XCTAssertNoThrow(try tokenService.storeAccessToken(validJWT))
        
        // Retrieve access token
        let retrieved = try tokenService.retrieveAccessToken()
        XCTAssertEqual(retrieved, validJWT)
    }
    
    func testAccessTokenEncryption() throws {
        // Store access token
        try tokenService.storeAccessToken(validJWT)
        
        // Verify it's encrypted in storage
        let encryptedData = try storage.retrieve(for: "encrypted_access_token_v2")
        
        // Raw encrypted data should not contain the token
        let encryptedString = String(data: encryptedData, encoding: .utf8) ?? ""
        XCTAssertFalse(encryptedString.contains(validJWT))
        
        // But decryption should work
        let retrieved = try tokenService.retrieveAccessToken()
        XCTAssertEqual(retrieved, validJWT)
    }
    
    func testRetrieveNonExistentAccessToken() {
        XCTAssertThrowsError(try tokenService.retrieveAccessToken()) { error in
            if let tokenError = error as? TokenManagementService.TokenError {
                switch tokenError {
                case .storageError:
                    break // Expected
                default:
                    XCTFail("Expected storage error")
                }
            }
        }
    }
    
    // MARK: - JWT Format Validation Tests
    
    func testValidJWTFormats() throws {
        let validTokens = [
            validJWT,
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.ET_x5_Tu8ZgWUyJaG3nFlq-jFzgNHaB5nJ0c2fKxvbE",
            "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9.signature_part_here"
        ]
        
        for token in validTokens {
            let credentials = SecureCredentials(
                accessToken: token,
                refreshToken: validRefreshToken,
                expiresIn: 3600
            )
            XCTAssertNoThrow(try tokenService.storeSecureCredentials(credentials))
            XCTAssertNoThrow(try tokenService.storeAccessToken(token))
            tokenService.clearAllTokens()
        }
    }
    
    func testInvalidJWTFormats() {
        let invalidTokens = [
            "not.a.jwt",
            "only.two",
            "contains spaces.in.token",
            "",
            "....",
            "a",
            "incomplete.",
            ".incomplete",
            "incomplete.."
        ]
        
        for token in invalidTokens {
            // Should throw invalid format error
            XCTAssertThrowsError(try tokenService.storeAccessToken(token)) { error in
                if let tokenError = error as? TokenManagementService.TokenError {
                    switch tokenError {
                    case .invalidTokenFormat:
                        break // Expected
                    default:
                        XCTFail("Expected invalidTokenFormat error for token: \(token)")
                    }
                }
            }
            
            let credentials = SecureCredentials(
                accessToken: token,
                refreshToken: validRefreshToken,
                expiresIn: 3600
            )
            XCTAssertThrowsError(try tokenService.storeSecureCredentials(credentials)) { error in
                if let tokenError = error as? TokenManagementService.TokenError {
                    switch tokenError {
                    case .invalidTokenFormat:
                        break // Expected
                    default:
                        XCTFail("Expected invalidTokenFormat error for credentials with token: \(token)")
                    }
                }
            }
        }
    }
    
    func testInvalidRefreshTokenFormat() {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: "invalid.refresh",
            expiresIn: 3600
        )
        
        XCTAssertThrowsError(try tokenService.storeSecureCredentials(credentials)) { error in
            if let tokenError = error as? TokenManagementService.TokenError {
                switch tokenError {
                case .invalidTokenFormat:
                    break // Expected
                default:
                    XCTFail("Expected invalidTokenFormat error for invalid refresh token")
                }
            }
        }
    }
    
    // MARK: - Token Expiration Tests
    
    func testExpiredTokenDetection() throws {
        let expiredCredentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: -1 // Already expired
        )
        
        // Store expired credentials
        try tokenService.storeSecureCredentials(expiredCredentials)
        
        // Should throw expired error when retrieving
        XCTAssertThrowsError(try tokenService.retrieveSecureCredentials()) { error in
            if let tokenError = error as? TokenManagementService.TokenError {
                switch tokenError {
                case .tokenExpired:
                    break // Expected
                default:
                    XCTFail("Expected tokenExpired error")
                }
            }
        }
    }
    
    func testCredentialsNeedRefresh() throws {
        // Store credentials that need refresh (expires in 1 second, buffer is 5 minutes)
        let needsRefreshCredentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 1
        )
        
        try tokenService.storeSecureCredentials(needsRefreshCredentials)
        
        // Should indicate refresh is needed
        XCTAssertTrue(tokenService.credentialsNeedRefresh())
        
        // Store fresh credentials
        let freshCredentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600
        )
        
        try tokenService.storeSecureCredentials(freshCredentials)
        
        // Should not need refresh
        XCTAssertFalse(tokenService.credentialsNeedRefresh())
    }
    
    func testCredentialsNeedRefreshNoCredentials() {
        // Should return true when no credentials exist
        XCTAssertTrue(tokenService.credentialsNeedRefresh())
    }
    
    // MARK: - Token Refresh Tests
    
    func testUpdateTokensAfterRefresh() throws {
        // Store initial credentials
        let initialCredentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600,
            userId: "user123"
        )
        
        try tokenService.storeSecureCredentials(initialCredentials)
        
        // Create refresh response with new tokens
        let newAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.new_access_token"
        let newRefreshToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.new_refresh_token"
        
        let refreshResponse = TokenRefreshResponse(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresIn: 7200,
            tokenType: "Bearer"
        )
        
        // Update tokens
        XCTAssertNoThrow(try tokenService.updateTokensAfterRefresh(response: refreshResponse))
        
        // Verify updated credentials
        let updatedCredentials = try tokenService.retrieveSecureCredentials()
        XCTAssertEqual(updatedCredentials.accessToken, newAccessToken)
        XCTAssertEqual(updatedCredentials.refreshToken, newRefreshToken)
        XCTAssertEqual(updatedCredentials.userId, initialCredentials.userId) // Should preserve
        XCTAssertEqual(updatedCredentials.tokenType, "Bearer")
    }
    
    func testUpdateTokensKeepRefreshToken() throws {
        // Store initial credentials
        let initialCredentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600,
            userId: "user456"
        )
        
        try tokenService.storeSecureCredentials(initialCredentials)
        
        // Refresh response without new refresh token
        let newAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.updated_token"
        
        let refreshResponse = TokenRefreshResponse(
            accessToken: newAccessToken,
            refreshToken: nil, // Keep existing refresh token
            expiresIn: 3600
        )
        
        // Update tokens
        try tokenService.updateTokensAfterRefresh(response: refreshResponse)
        
        // Verify credentials
        let updatedCredentials = try tokenService.retrieveSecureCredentials()
        XCTAssertEqual(updatedCredentials.accessToken, newAccessToken)
        XCTAssertEqual(updatedCredentials.refreshToken, validRefreshToken) // Should keep original
        XCTAssertEqual(updatedCredentials.userId, initialCredentials.userId)
    }
    
    func testUpdateTokensNoExistingCredentials() throws {
        // Update tokens without existing credentials
        let newAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.fresh_token"
        let newRefreshToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.fresh_refresh"
        
        let refreshResponse = TokenRefreshResponse(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresIn: 3600
        )
        
        // Should create new credentials
        XCTAssertNoThrow(try tokenService.updateTokensAfterRefresh(response: refreshResponse))
        
        // Verify new credentials
        let newCredentials = try tokenService.retrieveSecureCredentials()
        XCTAssertEqual(newCredentials.accessToken, newAccessToken)
        XCTAssertEqual(newCredentials.refreshToken, newRefreshToken)
    }
    
    // MARK: - Clear Tokens Tests
    
    func testClearAllTokens() throws {
        // Store various tokens
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600
        )
        
        try tokenService.storeSecureCredentials(credentials)
        try tokenService.storeAccessToken(validJWT)
        
        // Verify tokens exist
        XCTAssertNoThrow(try tokenService.retrieveSecureCredentials())
        XCTAssertNoThrow(try tokenService.retrieveAccessToken())
        
        // Clear all tokens
        tokenService.clearAllTokens()
        
        // Verify tokens are cleared
        XCTAssertThrowsError(try tokenService.retrieveSecureCredentials())
        XCTAssertThrowsError(try tokenService.retrieveAccessToken())
    }
    
    // MARK: - Security Tests
    
    func testTokenEncryptionWithAuthentication() throws {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600
        )
        
        // Store credentials
        try tokenService.storeSecureCredentials(credentials)
        
        // Verify raw storage is encrypted and authenticated
        let encryptedData = try storage.retrieve(for: "secure_jwt_credentials_v2")
        
        // Should not contain plain text tokens
        let dataString = String(data: encryptedData, encoding: .utf8) ?? ""
        XCTAssertFalse(dataString.contains(validJWT))
        XCTAssertFalse(dataString.contains(validRefreshToken))
        
        // Should be able to retrieve properly
        let retrieved = try tokenService.retrieveSecureCredentials()
        XCTAssertEqual(retrieved.accessToken, validJWT)
        XCTAssertEqual(retrieved.refreshToken, validRefreshToken)
    }
    
    func testTokenMetadataStorage() throws {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        
        // Store credentials
        try tokenService.storeSecureCredentials(credentials)
        
        // Check if metadata is stored (non-sensitive)
        XCTAssertTrue(storage.exists(for: "jwt_metadata_v2"))
        
        // Metadata should exist but be non-sensitive
        let metadataData = try storage.retrieve(for: "jwt_metadata_v2")
        let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata?["issuedAt"])
        XCTAssertNotNil(metadata?["expiresAt"])
        XCTAssertEqual(metadata?["tokenType"] as? String, "Bearer")
    }
    
    // MARK: - Performance Tests
    
    func testTokenOperationsPerformance() {
        let credentials = SecureCredentials(
            accessToken: validJWT,
            refreshToken: validRefreshToken,
            expiresIn: 3600
        )
        
        measure {
            for _ in 0..<50 {
                do {
                    try tokenService.storeSecureCredentials(credentials)
                    _ = try tokenService.retrieveSecureCredentials()
                    try tokenService.storeAccessToken(validJWT)
                    _ = try tokenService.retrieveAccessToken()
                    tokenService.clearAllTokens()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentTokenOperations() {
        let expectation = XCTestExpectation(description: "Concurrent token operations")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let credentials = SecureCredentials(
                    accessToken: validJWT,
                    refreshToken: validRefreshToken,
                    expiresIn: 3600,
                    userId: "user_\(index)"
                )
                
                try tokenService.storeSecureCredentials(credentials)
                let retrieved = try tokenService.retrieveSecureCredentials()
                XCTAssertEqual(retrieved.accessToken, validJWT)
                
                tokenService.clearAllTokens()
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent test failed for iteration \(index): \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let mockError = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let errors: [TokenManagementService.TokenError] = [
            .tokenExpired,
            .invalidTokenFormat,
            .encryptionFailed,
            .decryptionFailed,
            .storageError(mockError)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}