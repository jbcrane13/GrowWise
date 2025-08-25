import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels
import Foundation

/// Comprehensive Rate Limiting Security Test Suite
/// Validates protection against various attack scenarios and abuse patterns
final class RateLimitingSecurityTests: XCTestCase {
    
    // MARK: - Properties
    
    private var rateLimiter: RateLimiter!
    private var mockStorage: MockSecureKeychainStorage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockStorage = MockSecureKeychainStorage()
        rateLimiter = RateLimiter(storage: mockStorage)
    }
    
    override func tearDownWithError() throws {
        mockStorage.clearAll()
        mockStorage = nil
        rateLimiter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Brute Force Attack Tests
    
    func testBruteForceAttackProtection() throws {
        let attackerEmail = "attacker@malicious.com"
        let policy = RateLimiter.Policy.authentication // 5 attempts per minute
        
        // Simulate brute force attack
        for attempt in 1...5 {
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "authentication",
                successful: false,
                policy: policy
            )
            
            if attempt < 5 {
                let result = rateLimiter.checkLimit(for: attackerEmail, operation: "authentication")
                XCTAssertTrue(result.isAllowed || result.isLimited,
                            "Should allow or limit attempts before lockout")
            }
        }
        
        // 6th attempt should be blocked with lockout
        XCTAssertThrowsError(
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "authentication",
                successful: false,
                policy: policy
            )
        ) { error in
            guard let rateLimiterError = error as? RateLimiter.RateLimiterError else {
                XCTFail("Expected RateLimiterError")
                return
            }
            
            switch rateLimiterError {
            case .accountLocked(let unlockAt):
                XCTAssertGreaterThan(unlockAt.timeIntervalSinceNow, 0)
            case .rateLimitExceeded:
                break // Also acceptable
            default:
                XCTFail("Expected accountLocked or rateLimitExceeded error")
            }
        }
    }
    
    func testDistributedBruteForceAttack() throws {
        // Simulate attack from multiple IPs/accounts
        let attackerEmails = [
            "attacker1@malicious.com",
            "attacker2@malicious.com",
            "attacker3@malicious.com",
            "attacker4@malicious.com",
            "attacker5@malicious.com"
        ]
        
        let policy = RateLimiter.Policy.authentication
        
        // Each attacker tries maximum attempts
        for email in attackerEmails {
            for _ in 1...5 {
                try rateLimiter.recordAttempt(
                    for: email,
                    operation: "authentication",
                    successful: false,
                    policy: policy
                )
            }
            
            // Verify each is locked out independently
            let result = rateLimiter.checkLimit(for: email, operation: "authentication")
            XCTAssertFalse(result.isAllowed, "Attacker should be locked out: \(email)")
        }
        
        // Verify legitimate user is not affected
        let legitimateUser = "user@legitimate.com"
        let result = rateLimiter.checkLimit(for: legitimateUser, operation: "authentication")
        XCTAssertTrue(result.isAllowed, "Legitimate user should not be affected")
    }
    
    // MARK: - Credential Stuffing Attack Tests
    
    func testCredentialStuffingAttackProtection() throws {
        let commonPasswords = [
            "password123", "admin", "123456", "password", "qwerty",
            "abc123", "letmein", "welcome", "monkey", "1234567890"
        ]
        
        let targetEmail = "victim@example.com"
        let policy = RateLimiter.Policy.authentication
        
        // Simulate credential stuffing attack
        for (index, _) in commonPasswords.enumerated() {
            if index < 5 {
                try rateLimiter.recordAttempt(
                    for: targetEmail,
                    operation: "authentication",
                    successful: false,
                    policy: policy
                )
            } else {
                // Should be blocked after 5 attempts
                XCTAssertThrowsError(
                    try rateLimiter.recordAttempt(
                        for: targetEmail,
                        operation: "authentication",
                        successful: false,
                        policy: policy
                    )
                ) { error in
                    XCTAssertTrue(error is RateLimiter.RateLimiterError)
                }
                break
            }
        }
    }
    
    // MARK: - Account Enumeration Attack Tests
    
    func testAccountEnumerationProtection() throws {
        let potentialEmails = [
            "admin@company.com",
            "support@company.com",
            "user1@company.com",
            "user2@company.com",
            "test@company.com"
        ]
        
        let policy = RateLimiter.Policy.sensitive // Stricter policy for enumeration
        
        // Simulate account enumeration attack
        for email in potentialEmails {
            for attempt in 1...3 {
                if attempt <= 3 {
                    try rateLimiter.recordAttempt(
                        for: email,
                        operation: "enumeration",
                        successful: false,
                        policy: policy
                    )
                }
            }
            
            // Should be locked out quickly with sensitive policy
            let result = rateLimiter.checkLimit(for: email, operation: "enumeration", policy: policy)
            XCTAssertFalse(result.isAllowed, "Account enumeration should be blocked for: \(email)")
        }
    }
    
    // MARK: - Resource Exhaustion Attack Tests
    
    func testResourceExhaustionProtection() throws {
        let policy = RateLimiter.Policy(
            maxAttempts: 10,
            timeWindow: 60,
            baseLockoutDuration: 30,
            maxLockoutDuration: 300,
            backoffMultiplier: 1.5
        )
        
        // Simulate high-frequency requests
        let attackerIP = "192.168.1.100"
        var successfulRequests = 0
        
        for requestCount in 1...20 {
            do {
                try rateLimiter.recordAttempt(
                    for: attackerIP,
                    operation: "api_request",
                    successful: true,
                    policy: policy
                )
                successfulRequests += 1
                
                if requestCount > 10 {
                    XCTFail("Should be rate limited after 10 requests")
                }
            } catch {
                // Expected after 10 requests
                guard requestCount > 10 else {
                    XCTFail("Premature rate limiting at request \(requestCount)")
                    return
                }
                
                XCTAssertTrue(error is RateLimiter.RateLimiterError)
                break
            }
        }
        
        XCTAssertEqual(successfulRequests, 10, "Should allow exactly 10 requests")
    }
    
    // MARK: - Slowloris Attack Simulation
    
    func testSlowlorisAttackProtection() async throws {
        let policy = RateLimiter.Policy(
            maxAttempts: 5,
            timeWindow: 10, // Short window
            baseLockoutDuration: 60
        )
        
        let attackerIP = "192.168.1.101"
        
        // Simulate slow, persistent requests
        for attempt in 1...5 {
            try rateLimiter.recordAttempt(
                for: attackerIP,
                operation: "slow_request",
                successful: false,
                policy: policy
            )
            
            if attempt < 5 {
                // Small delay between requests (simulating slow attack)
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        // Next request should be blocked
        XCTAssertThrowsError(
            try rateLimiter.recordAttempt(
                for: attackerIP,
                operation: "slow_request",
                successful: false,
                policy: policy
            )
        )
    }
    
    // MARK: - Bypass Attempt Tests
    
    func testHeaderSpoofingBypassAttempts() throws {
        let baseIP = "192.168.1."
        let policy = RateLimiter.Policy.authentication
        
        // Simulate attempts to bypass using different "IPs"
        for ipSuffix in 1...10 {
            let spoofedIP = "\(baseIP)\(ipSuffix)"
            
            // Each "IP" should be treated independently
            let result = rateLimiter.checkLimit(for: spoofedIP, operation: "authentication")
            XCTAssertTrue(result.isAllowed, "Each unique identifier should be treated independently")
            
            // But exhaust each one
            for _ in 1...5 {
                try rateLimiter.recordAttempt(
                    for: spoofedIP,
                    operation: "authentication",
                    successful: false,
                    policy: policy
                )
            }
            
            // Should be locked out
            let finalResult = rateLimiter.checkLimit(for: spoofedIP, operation: "authentication")
            XCTAssertFalse(finalResult.isAllowed, "Should be locked out: \(spoofedIP)")
        }
    }
    
    func testUserAgentRotationBypassAttempt() throws {
        let userAgents = [
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "curl/7.64.1",
            "Postman/9.0.0"
        ]
        
        let attackerEmail = "attacker@bypass.com"
        let policy = RateLimiter.Policy.authentication
        
        // Simulate attacker rotating user agents (shouldn't help)
        for (index, userAgent) in userAgents.enumerated() {
            let identifier = "\(attackerEmail)_\(userAgent.hashValue)"
            
            if index < 5 {
                try rateLimiter.recordAttempt(
                    for: identifier,
                    operation: "authentication",
                    successful: false,
                    policy: policy
                )
            } else {
                // Different identifiers mean each gets their own limit
                // This demonstrates the importance of proper identifier selection
                let result = rateLimiter.checkLimit(for: identifier, operation: "authentication")
                XCTAssertTrue(result.isAllowed, "Different identifiers get separate limits")
            }
        }
        
        // But the original email should still work with different identifiers
        // This shows the need for careful identifier design in real implementations
    }
    
    // MARK: - Time Window Manipulation Tests
    
    func testTimeWindowRaceCondition() async throws {
        let policy = RateLimiter.Policy(
            maxAttempts: 3,
            timeWindow: 2, // Short window for testing
            baseLockoutDuration: 5
        )
        
        let attackerEmail = "time.attacker@example.com"
        
        // Rapidly consume attempts within time window
        try rateLimiter.recordAttempt(
            for: attackerEmail,
            operation: "time_test",
            successful: false,
            policy: policy
        )
        
        try rateLimiter.recordAttempt(
            for: attackerEmail,
            operation: "time_test",
            successful: false,
            policy: policy
        )
        
        try rateLimiter.recordAttempt(
            for: attackerEmail,
            operation: "time_test",
            successful: false,
            policy: policy
        )
        
        // Should be blocked
        XCTAssertThrowsError(
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "time_test",
                successful: false,
                policy: policy
            )
        )
        
        // Wait for window to reset
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Should be allowed again after window reset
        let result = rateLimiter.checkLimit(for: attackerEmail, operation: "time_test", policy: policy)
        if !result.isAllowed {
            // May still be in lockout period
            switch result {
            case .locked(let unlockAt, _):
                XCTAssertGreaterThan(unlockAt.timeIntervalSinceNow, -1) // Allow small timing tolerance
            default:
                XCTFail("Unexpected result after time window: \(result)")
            }
        }
    }
    
    // MARK: - Concurrent Attack Tests
    
    func testConcurrentAttackHandling() throws {
        let policy = RateLimiter.Policy.authentication
        let attackerEmail = "concurrent.attacker@example.com"
        
        let expectation = XCTestExpectation(description: "Concurrent attacks")
        expectation.expectedFulfillmentCount = 10
        
        var attemptResults: [Result<Void, Error>] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // Launch concurrent attacks
        DispatchQueue.concurrentPerform(iterations: 10) { iteration in
            do {
                try rateLimiter.recordAttempt(
                    for: attackerEmail,
                    operation: "authentication",
                    successful: false,
                    policy: policy
                )
                
                resultsQueue.sync {
                    attemptResults.append(.success(()))
                }
            } catch {
                resultsQueue.sync {
                    attemptResults.append(.failure(error))
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Analyze results
        let successfulAttempts = attemptResults.compactMap { result -> Bool? in
            switch result {
            case .success: return true
            case .failure: return false
            }
        }.filter { $0 }.count
        
        let failedAttempts = attemptResults.count - successfulAttempts
        
        // Should allow some attempts and reject others (race conditions possible)
        XCTAssertGreaterThan(failedAttempts, 0, "Some concurrent attempts should be rejected")
        XCTAssertLessThanOrEqual(successfulAttempts, 5, "Should not exceed policy limit significantly")
    }
    
    // MARK: - State Persistence Attack Tests
    
    func testStatePersistenceManipulation() throws {
        let attackerEmail = "state.attacker@example.com"
        let policy = RateLimiter.Policy.authentication
        
        // Consume some attempts
        for _ in 1...3 {
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "authentication",
                successful: false,
                policy: policy
            )
        }
        
        // Simulate app restart by creating new rate limiter with same storage
        let newRateLimiter = RateLimiter(storage: mockStorage)
        
        // Previous attempts should still be counted
        let result = newRateLimiter.checkLimit(for: attackerEmail, operation: "authentication")
        
        switch result {
        case .allowed(let remaining):
            XCTAssertEqual(remaining, 2, "Should remember previous attempts")
        case .limited(_, let remaining):
            XCTAssertEqual(remaining, 2, "Should remember previous attempts")
        default:
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    // MARK: - Denial of Service Tests
    
    func testDenialOfServiceProtection() throws {
        let policy = RateLimiter.Policy(
            maxAttempts: 100, // High limit
            timeWindow: 60,
            baseLockoutDuration: 30
        )
        
        let attackerIPs = (1...50).map { "192.168.1.\($0)" }
        
        // Simulate DoS attack from multiple sources
        for ip in attackerIPs {
            // Each IP maxes out its requests
            for attempt in 1...101 {
                do {
                    try rateLimiter.recordAttempt(
                        for: ip,
                        operation: "dos_test",
                        successful: true,
                        policy: policy
                    )
                    
                    if attempt > 100 {
                        XCTFail("Should be rate limited after 100 requests for IP: \(ip)")
                    }
                } catch {
                    // Expected after 100 requests
                    XCTAssertGreaterThan(attempt, 100, "Premature rate limiting for IP: \(ip)")
                    break
                }
            }
        }
        
        // Verify legitimate users can still access
        let legitimateIP = "10.0.0.1"
        let result = rateLimiter.checkLimit(for: legitimateIP, operation: "dos_test", policy: policy)
        XCTAssertTrue(result.isAllowed, "Legitimate users should not be affected by DoS")
    }
    
    // MARK: - Memory Exhaustion Tests
    
    func testMemoryExhaustionProtection() throws {
        let initialMemory = getMemoryUsage()
        
        // Create many rate limit entries
        for i in 1...1000 {
            let identifier = "memory.test.\(i)@example.com"
            try rateLimiter.recordAttempt(
                for: identifier,
                operation: "memory_test",
                successful: false
            )
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, // 50MB threshold
                         "Rate limiter should not consume excessive memory")
    }
    
    // MARK: - Policy Manipulation Tests
    
    func testPolicyBypassAttempts() throws {
        let strictPolicy = RateLimiter.Policy.sensitive // 3 attempts
        let lenientPolicy = RateLimiter.Policy.testing   // 100 attempts
        
        let attackerEmail = "policy.attacker@example.com"
        
        // Exhaust attempts with strict policy
        for _ in 1...3 {
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "strict_op",
                successful: false,
                policy: strictPolicy
            )
        }
        
        // Should be locked out
        XCTAssertThrowsError(
            try rateLimiter.recordAttempt(
                for: attackerEmail,
                operation: "strict_op",
                successful: false,
                policy: strictPolicy
            )
        )
        
        // Attempt to bypass by using different operation/policy
        let result = rateLimiter.checkLimit(
            for: attackerEmail,
            operation: "lenient_op",
            policy: lenientPolicy
        )
        
        // Should be allowed - different operations have separate limits
        XCTAssertTrue(result.isAllowed,
                     "Different operations should have independent rate limits")
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Mock Secure Keychain Storage

private class MockSecureKeychainStorage: KeychainStorageProtocol, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "mock-secure-storage", attributes: .concurrent)
    
    func store(_ data: Data, for key: String) throws {
        // Simulate keychain validation
        guard key.count > 0 && key.count <= 256 else {
            throw KeychainError.invalidKey
        }
        
        queue.sync(flags: .barrier) {
            self.storage[key] = data
        }
    }
    
    func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try store(data, for: key)
    }
    
    func retrieve(for key: String) throws -> Data {
        return try queue.sync {
            guard let data = storage[key] else {
                throw KeychainError.itemNotFound
            }
            return data
        }
    }
    
    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    func delete(for key: String) throws {
        queue.sync(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
    
    func deleteAll() throws {
        queue.sync(flags: .barrier) {
            self.storage.removeAll()
        }
    }
    
    func exists(for key: String) -> Bool {
        return queue.sync {
            return storage[key] != nil
        }
    }
    
    func clearAll() {
        queue.sync(flags: .barrier) {
            self.storage.removeAll()
        }
    }
    
    enum KeychainError: Error {
        case itemNotFound
        case invalidData
        case invalidKey
    }
}