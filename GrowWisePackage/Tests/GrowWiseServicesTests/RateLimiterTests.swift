import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels
import Foundation

final class RateLimiterTests: XCTestCase {
    
    private var mockStorage: MockKeychainStorage!
    private var rateLimiter: RateLimiter!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockStorage = MockKeychainStorage()
        rateLimiter = RateLimiter(storage: mockStorage)
    }
    
    override func tearDownWithError() throws {
        mockStorage = nil
        rateLimiter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Rate Limiting Tests
    
    func testAllowsInitialAttempts() throws {
        let result = rateLimiter.checkLimit(for: "test@example.com", operation: "authentication")
        XCTAssertTrue(result.isAllowed)
    }
    
    func testBlocksAfterMaxAttempts() throws {
        let email = "test@example.com"
        let policy = RateLimiter.Policy.authentication // 5 attempts per minute
        
        // Record 5 failed attempts
        for _ in 0..<5 {
            try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)
        }
        
        // 6th attempt should be blocked
        let result = rateLimiter.checkLimit(for: email, operation: "authentication")
        
        switch result {
        case .limited(let retryAfter, let attemptsRemaining):
            XCTAssertGreaterThan(retryAfter, 0)
            XCTAssertEqual(attemptsRemaining, 0)
        default:
            XCTFail("Expected limited result")
        }
    }
    
    func testResetsAfterSuccessfulAttempt() throws {
        let email = "test@example.com"
        
        // Record 4 failed attempts
        for _ in 0..<4 {
            try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)
        }
        
        // Record successful attempt
        try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: true)
        
        // Should be allowed again
        let result = rateLimiter.checkLimit(for: email, operation: "authentication")
        XCTAssertTrue(result.isAllowed)
    }
    
    // MARK: - Exponential Backoff Tests
    
    func testExponentialBackoff() throws {
        let email = "test@example.com"
        let policy = RateLimiter.Policy(
            maxAttempts: 3,
            timeWindow: 60,
            baseLockoutDuration: 60,
            maxLockoutDuration: 3600,
            backoffMultiplier: 2.0,
            useExponentialBackoff: true
        )
        
        rateLimiter.setPolicy(policy, for: "test_operation")
        
        // First lockout after 3 failed attempts
        for _ in 0..<3 {
            try rateLimiter.recordAttempt(for: email, operation: "test_operation", successful: false)
        }
        
        let result1 = rateLimiter.checkLimit(for: email, operation: "test_operation", policy: policy)
        
        switch result1 {
        case .locked(let unlockAt1, _):
            // Reset and try again after more failures
            rateLimiter.reset(for: email, operation: "test_operation")
            
            // Second round of failures - should have longer lockout
            for _ in 0..<6 { // More consecutive failures
                try? rateLimiter.recordAttempt(for: email, operation: "test_operation", successful: false)
            }
            
            let result2 = rateLimiter.checkLimit(for: email, operation: "test_operation", policy: policy)
            
            switch result2 {
            case .locked(let unlockAt2, _):
                // Second lockout should be longer than first (exponential backoff)
                let firstLockoutDuration = unlockAt1.timeIntervalSinceNow
                let secondLockoutDuration = unlockAt2.timeIntervalSinceNow
                XCTAssertGreaterThan(abs(secondLockoutDuration), abs(firstLockoutDuration))
            default:
                XCTFail("Expected locked result for second round")
            }
        default:
            XCTFail("Expected locked result for first round")
        }
    }
    
    // MARK: - Policy Tests
    
    func testCustomPolicy() throws {
        let email = "test@example.com"
        let strictPolicy = RateLimiter.Policy(
            maxAttempts: 2,
            timeWindow: 60,
            baseLockoutDuration: 300
        )
        
        // Should be blocked after 2 attempts
        try rateLimiter.recordAttempt(for: email, operation: "strict", successful: false, policy: strictPolicy)
        try rateLimiter.recordAttempt(for: email, operation: "strict", successful: false, policy: strictPolicy)
        
        let result = rateLimiter.checkLimit(for: email, operation: "strict", policy: strictPolicy)
        
        switch result {
        case .limited(_, _):
            break // Expected
        case .locked(_, _):
            break // Also acceptable depending on policy
        default:
            XCTFail("Expected limited or locked result")
        }
    }
    
    func testPredefinedPolicies() throws {
        // Test authentication policy
        let authPolicy = RateLimiter.Policy.authentication
        XCTAssertEqual(authPolicy.maxAttempts, 5)
        XCTAssertEqual(authPolicy.timeWindow, 60)
        XCTAssertEqual(authPolicy.baseLockoutDuration, 60)
        
        // Test sensitive policy
        let sensitivePolicy = RateLimiter.Policy.sensitive
        XCTAssertEqual(sensitivePolicy.maxAttempts, 3)
        XCTAssertEqual(sensitivePolicy.timeWindow, 60)
        XCTAssertEqual(sensitivePolicy.baseLockoutDuration, 300)
        
        // Test testing policy
        let testingPolicy = RateLimiter.Policy.testing
        XCTAssertEqual(testingPolicy.maxAttempts, 100)
        XCTAssertFalse(testingPolicy.useExponentialBackoff)
    }
    
    // MARK: - Testing Bypass Tests
    
    func testTestingBypass() throws {
        rateLimiter.enableTestingBypass()
        
        let email = "test@example.com"
        
        // Record many failed attempts
        for _ in 0..<100 {
            try rateLimiter.recordAttempt(for: email, operation: "testing", successful: false)
        }
        
        // Should still be allowed with bypass enabled
        let result = rateLimiter.checkLimit(for: email, operation: "testing")
        XCTAssertTrue(result.isAllowed)
        
        // Disable bypass
        rateLimiter.disableTestingBypass()
        
        // Regular operations should still be rate limited
        for _ in 0..<5 {
            try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)
        }
        
        let nonBypassResult = rateLimiter.checkLimit(for: email, operation: "authentication")
        XCTAssertFalse(nonBypassResult.isAllowed)
    }
    
    // MARK: - State Management Tests
    
    func testStateReset() throws {
        let email = "test@example.com"
        
        // Record failed attempts
        for _ in 0..<4 {
            try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)
        }
        
        // Reset state
        rateLimiter.reset(for: email, operation: "authentication")
        
        // Should be allowed again
        let result = rateLimiter.checkLimit(for: email, operation: "authentication")
        XCTAssertTrue(result.isAllowed)
    }
    
    func testDifferentOperationsIndependent() throws {
        let email = "test@example.com"
        
        // Exhaust attempts for one operation
        for _ in 0..<5 {
            try rateLimiter.recordAttempt(for: email, operation: "operation1", successful: false)
        }
        
        // Different operation should still be allowed
        let result = rateLimiter.checkLimit(for: email, operation: "operation2")
        XCTAssertTrue(result.isAllowed)
    }
    
    func testDifferentKeysIndependent() throws {
        let email1 = "test1@example.com"
        let email2 = "test2@example.com"
        
        // Exhaust attempts for first email
        for _ in 0..<5 {
            try rateLimiter.recordAttempt(for: email1, operation: "authentication", successful: false)
        }
        
        // Different email should still be allowed
        let result = rateLimiter.checkLimit(for: email2, operation: "authentication")
        XCTAssertTrue(result.isAllowed)
    }
    
    // MARK: - Error Handling Tests
    
    func testRateLimitExceededError() throws {
        let email = "test@example.com"
        
        // Record maximum attempts
        for _ in 0..<5 {
            try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)
        }
        
        // Next attempt should throw
        XCTAssertThrowsError(try rateLimiter.recordAttempt(for: email, operation: "authentication", successful: false)) { error in
            if let rateLimiterError = error as? RateLimiter.RateLimiterError {
                switch rateLimiterError {
                case .rateLimitExceeded(let retryAfter):
                    XCTAssertGreaterThan(retryAfter, 0)
                default:
                    XCTFail("Expected rateLimitExceeded error")
                }
            } else {
                XCTFail("Expected RateLimiter.RateLimiterError")
            }
        }
    }
    
    func testAccountLockedError() throws {
        let email = "test@example.com"
        let policy = RateLimiter.Policy(
            maxAttempts: 2,
            timeWindow: 60,
            baseLockoutDuration: 300
        )
        
        // Trigger lockout
        for _ in 0..<2 {
            try rateLimiter.recordAttempt(for: email, operation: "test", successful: false, policy: policy)
        }
        
        // Next attempt should throw account locked error
        XCTAssertThrowsError(try rateLimiter.recordAttempt(for: email, operation: "test", successful: false, policy: policy)) { error in
            if let rateLimiterError = error as? RateLimiter.RateLimiterError {
                switch rateLimiterError {
                case .accountLocked(let unlockAt):
                    XCTAssertGreaterThan(unlockAt.timeIntervalSinceNow, 0)
                default:
                    XCTFail("Expected accountLocked error")
                }
            } else {
                XCTFail("Expected RateLimiter.RateLimiterError")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyOperations() throws {
        let email = "test@example.com"
        
        measure {
            for i in 0..<1000 {
                let result = rateLimiter.checkLimit(for: "\(email)_\(i)", operation: "authentication")
                XCTAssertTrue(result.isAllowed)
            }
        }
    }
    
    func testConcurrentAccess() throws {
        let email = "test@example.com"
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { i in
            let result = rateLimiter.checkLimit(for: "\(email)_\(i)", operation: "authentication")
            XCTAssertTrue(result.isAllowed)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock Storage

private class MockKeychainStorage: KeychainStorageProtocol, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "mock-storage", attributes: .concurrent)
    
    func store(_ data: Data, for key: String) throws {
        queue.sync(flags: .barrier) {
            self.storage[key] = data
        }
    }
    
    func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw TestError.invalidData
        }
        try store(data, for: key)
    }
    
    func retrieve(for key: String) throws -> Data {
        return try queue.sync {
            guard let data = storage[key] else {
                throw TestError.itemNotFound
            }
            return data
        }
    }
    
    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TestError.invalidData
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
    
    enum TestError: Error {
        case itemNotFound
        case invalidData
    }
}