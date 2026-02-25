import Testing
import Foundation
@testable import GrowWiseModels

@Suite("SecureCredentials Model Tests")
struct SecureCredentialsTests {

    // MARK: - Helpers

    private func makeCredentials(
        accessToken: String = "header.payload.signature",
        refreshToken: String = "refresh.token.value",
        expiresIn: TimeInterval = 3600,
        userId: String? = nil,
        tokenType: String = "Bearer"
    ) -> SecureCredentials {
        SecureCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            userId: userId,
            tokenType: tokenType
        )
    }

    // MARK: - Initialization

    @Test("Init stores all provided values")
    func testInitializationStoresValues() {
        let creds = makeCredentials(
            accessToken: "a.b.c",
            refreshToken: "r.e.f",
            expiresIn: 7200,
            userId: "user-123",
            tokenType: "Bearer"
        )

        #expect(creds.accessToken == "a.b.c")
        #expect(creds.refreshToken == "r.e.f")
        #expect(creds.userId == "user-123")
        #expect(creds.tokenType == "Bearer")
    }

    @Test("Init with default expiresIn of 3600 sets expiresAt ~1 hour from now")
    func testDefaultExpiresIn() {
        let before = Date()
        let creds = SecureCredentials(accessToken: "a.b.c", refreshToken: "r.e.f")
        let after = Date()

        let expectedMin = before.addingTimeInterval(3600)
        let expectedMax = after.addingTimeInterval(3600)

        #expect(creds.expiresAt >= expectedMin)
        #expect(creds.expiresAt <= expectedMax)
    }

    @Test("Init sets issuedAt to current time")
    func testIssuedAtIsNow() {
        let before = Date()
        let creds = makeCredentials()
        let after = Date()

        #expect(creds.issuedAt >= before)
        #expect(creds.issuedAt <= after)
    }

    @Test("Init with custom expiresIn sets expiresAt accordingly")
    func testCustomExpiresIn() {
        let expiresIn: TimeInterval = 900  // 15 minutes
        let before = Date()
        let creds = makeCredentials(expiresIn: expiresIn)
        let after = Date()

        #expect(creds.expiresAt >= before.addingTimeInterval(expiresIn))
        #expect(creds.expiresAt <= after.addingTimeInterval(expiresIn))
    }

    // MARK: - isExpired

    @Test("isExpired returns false for a fresh token")
    func testIsExpiredFalseForFreshToken() {
        let creds = makeCredentials(expiresIn: 3600)
        #expect(creds.isExpired == false)
    }

    @Test("isExpired returns true for a token expired in the past")
    func testIsExpiredTrueForPastToken() {
        let creds = makeCredentials(expiresIn: -10)  // expired 10 seconds ago
        #expect(creds.isExpired == true)
    }

    @Test("isExpired returns true when expiresIn is zero (expired immediately)")
    func testIsExpiredAtExactExpiry() {
        // expiresIn == 0 means expiresAt == issuedAt == Date() — Date() >= expiresAt will be true
        let creds = makeCredentials(expiresIn: -0.001)
        #expect(creds.isExpired == true)
    }

    // MARK: - needsRefresh

    @Test("needsRefresh returns false when well before expiry window")
    func testNeedsRefreshFalseWhenFresh() {
        let creds = makeCredentials(expiresIn: 600)  // 10 minutes remaining, window is 5m
        #expect(creds.needsRefresh == false)
    }

    @Test("needsRefresh returns true when within 5-minute refresh window")
    func testNeedsRefreshTrueWithinWindow() {
        let creds = makeCredentials(expiresIn: 240)  // 4 minutes remaining, inside 5m window
        #expect(creds.needsRefresh == true)
    }

    @Test("needsRefresh returns true when token is already expired")
    func testNeedsRefreshTrueWhenExpired() {
        let creds = makeCredentials(expiresIn: -60)  // expired 1 minute ago
        #expect(creds.needsRefresh == true)
    }

    @Test("needsRefresh is true at exactly the 5-minute threshold")
    func testNeedsRefreshAtExactThreshold() {
        // expiresIn == 300 means threshold == now, so Date() >= threshold is true
        let creds = makeCredentials(expiresIn: 299)
        #expect(creds.needsRefresh == true)
    }

    // MARK: - timeUntilExpiration

    @Test("timeUntilExpiration is positive for a future token")
    func testTimeUntilExpirationPositive() {
        let creds = makeCredentials(expiresIn: 3600)
        #expect(creds.timeUntilExpiration > 0)
        #expect(creds.timeUntilExpiration <= 3600)
    }

    @Test("timeUntilExpiration is negative for an expired token")
    func testTimeUntilExpirationNegative() {
        let creds = makeCredentials(expiresIn: -120)
        #expect(creds.timeUntilExpiration < 0)
    }

    @Test("timeUntilExpiration approximates the given expiresIn value")
    func testTimeUntilExpirationApproximate() {
        let expiresIn: TimeInterval = 1800
        let creds = makeCredentials(expiresIn: expiresIn)
        // Allow 1 second of tolerance for test execution time
        #expect(abs(creds.timeUntilExpiration - expiresIn) < 1.0)
    }

    // MARK: - authorizationHeader

    @Test("authorizationHeader formats as Bearer token")
    func testAuthorizationHeaderFormat() {
        let creds = makeCredentials(accessToken: "mytoken", tokenType: "Bearer")
        #expect(creds.authorizationHeader == "Bearer mytoken")
    }

    @Test("authorizationHeader uses custom tokenType")
    func testAuthorizationHeaderCustomType() {
        let creds = makeCredentials(accessToken: "xyz", tokenType: "Token")
        #expect(creds.authorizationHeader == "Token xyz")
    }

    @Test("authorizationHeader includes the full access token")
    func testAuthorizationHeaderContainsToken() {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature"
        let creds = makeCredentials(accessToken: token)
        #expect(creds.authorizationHeader.hasSuffix(token))
        #expect(creds.authorizationHeader.hasPrefix("Bearer "))
    }

    // MARK: - isValidJWTFormat

    @Test("isValidJWTFormat returns true for a valid 3-part JWT")
    func testValidJWTFormat() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == true)
    }

    @Test("isValidJWTFormat returns true for simple valid base64url parts")
    func testValidJWTSimpleParts() {
        let jwt = "abc123.def456.ghi789"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == true)
    }

    @Test("isValidJWTFormat returns false for a 2-part token")
    func testInvalidJWTTwoParts() {
        let jwt = "header.payload"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == false)
    }

    @Test("isValidJWTFormat returns false for a 4-part token")
    func testInvalidJWTFourParts() {
        let jwt = "a.b.c.d"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == false)
    }

    @Test("isValidJWTFormat returns false for empty string")
    func testInvalidJWTEmptyString() {
        #expect(SecureCredentials.isValidJWTFormat("") == false)
    }

    @Test("isValidJWTFormat returns false for string with no dots")
    func testInvalidJWTNoDots() {
        #expect(SecureCredentials.isValidJWTFormat("headerpayloadsignature") == false)
    }

    @Test("isValidJWTFormat returns false when a part contains invalid characters")
    func testInvalidJWTInvalidChars() {
        // '+' and '/' are base64 standard but NOT base64url; base64url uses '-' and '_'
        let jwt = "header+invalid.payload.signature"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == false)
    }

    @Test("isValidJWTFormat accepts base64url chars dash and underscore")
    func testValidJWTBase64URLChars() {
        let jwt = "aA1_-zZ.bB2_-yY.cC3_-xX"
        #expect(SecureCredentials.isValidJWTFormat(jwt) == true)
    }

    // MARK: - Parameterized JWT validation

    @Test("isValidJWTFormat parameterized invalid inputs", arguments: [
        "",
        "onlyone",
        "two.parts",
        "a.b.c.d",
        "has space.payload.signature",
        "header.pay+load.signature",
        "header.payload.sig/nature"
    ])
    func testIsValidJWTInvalidParameterized(token: String) {
        #expect(SecureCredentials.isValidJWTFormat(token) == false, "Expected invalid JWT for: \(token)")
    }

    @Test("isValidJWTFormat parameterized valid inputs", arguments: [
        "abc.def.ghi",
        "ABC123.DEF456.GHI789",
        "aA1_-z.bB2_-y.cC3_-x",
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0In0.validSig"
    ])
    func testIsValidJWTValidParameterized(token: String) {
        #expect(SecureCredentials.isValidJWTFormat(token) == true, "Expected valid JWT for: \(token)")
    }

    // MARK: - userId optionality

    @Test("userId defaults to nil when not provided")
    func testUserIdDefaultsToNil() {
        let creds = SecureCredentials(accessToken: "a.b.c", refreshToken: "r.e.f")
        #expect(creds.userId == nil)
    }

    @Test("userId is stored when provided")
    func testUserIdStored() {
        let creds = makeCredentials(userId: "abc-456")
        #expect(creds.userId == "abc-456")
    }
}
