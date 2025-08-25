import Foundation
import GrowWiseModels

/// RateLimiter provides comprehensive rate limiting for authentication attempts
/// Implements exponential backoff, persistent storage, and automatic cleanup
/// Thread-safe implementation with support for multiple rate limiting policies
public final class RateLimiter: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Rate limiting policy configuration
    public struct Policy: Codable, Sendable {
        /// Maximum number of attempts allowed
        public let maxAttempts: Int
        /// Time window in seconds for attempt counting
        public let timeWindow: TimeInterval
        /// Initial lockout duration in seconds
        public let baseLockoutDuration: TimeInterval
        /// Maximum lockout duration in seconds
        public let maxLockoutDuration: TimeInterval
        /// Multiplier for exponential backoff
        public let backoffMultiplier: Double
        /// Whether to use exponential backoff
        public let useExponentialBackoff: Bool
        
        public init(
            maxAttempts: Int,
            timeWindow: TimeInterval,
            baseLockoutDuration: TimeInterval,
            maxLockoutDuration: TimeInterval = 3600, // 1 hour max
            backoffMultiplier: Double = 2.0,
            useExponentialBackoff: Bool = true
        ) {
            self.maxAttempts = maxAttempts
            self.timeWindow = timeWindow
            self.baseLockoutDuration = baseLockoutDuration
            self.maxLockoutDuration = maxLockoutDuration
            self.backoffMultiplier = backoffMultiplier
            self.useExponentialBackoff = useExponentialBackoff
        }
        
        /// Default authentication policy (5 attempts per minute)
        public static let authentication = Policy(
            maxAttempts: 5,
            timeWindow: 60,
            baseLockoutDuration: 60
        )
        
        /// Strict policy for sensitive operations
        public static let sensitive = Policy(
            maxAttempts: 3,
            timeWindow: 60,
            baseLockoutDuration: 300,
            maxLockoutDuration: 7200 // 2 hours
        )
        
        /// Development/testing policy with bypass capability
        public static let testing = Policy(
            maxAttempts: 100,
            timeWindow: 60,
            baseLockoutDuration: 1,
            useExponentialBackoff: false
        )
    }
    
    /// Rate limit violation result
    public enum RateLimitResult: Sendable {
        case allowed
        case limited(retryAfter: TimeInterval, attemptsRemaining: Int)
        case locked(unlockAt: Date, totalFailures: Int)
        
        public var isAllowed: Bool {
            if case .allowed = self {
                return true
            }
            return false
        }
        
        public var retryAfterSeconds: TimeInterval? {
            switch self {
            case .allowed:
                return nil
            case .limited(let retryAfter, _):
                return retryAfter
            case .locked(let unlockAt, _):
                return unlockAt.timeIntervalSinceNow
            }
        }
    }
    
    /// Rate limiter error types
    public enum RateLimiterError: LocalizedError, Sendable {
        case rateLimitExceeded(retryAfter: TimeInterval)
        case accountLocked(unlockAt: Date)
        case storageError(Error)
        case invalidKey(String)
        case configurationError(String)
        
        public var errorDescription: String? {
            switch self {
            case .rateLimitExceeded(let retryAfter):
                return "Rate limit exceeded. Try again in \(Int(retryAfter)) seconds."
            case .accountLocked(let unlockAt):
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Account locked until \(formatter.string(from: unlockAt))"
            case .storageError(let error):
                return "Storage error: \(error.localizedDescription)"
            case .invalidKey(let reason):
                return "Invalid key: \(reason)"
            case .configurationError(let reason):
                return "Configuration error: \(reason)"
            }
        }
    }
    
    // MARK: - Internal Types
    
    /// Attempt record for tracking failures
    private struct AttemptRecord: Codable, Sendable {
        let timestamp: Date
        let successful: Bool
        let operation: String
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 86400 // 24 hours
        }
    }
    
    /// Rate limit state for a specific key/operation
    private struct RateLimitState: Codable, Sendable {
        var attempts: [AttemptRecord]
        var lockoutUntil: Date?
        var consecutiveFailures: Int
        var lastAttempt: Date?
        
        init() {
            self.attempts = []
            self.lockoutUntil = nil
            self.consecutiveFailures = 0
            self.lastAttempt = nil
        }
        
        /// Clean up expired attempts
        mutating func cleanupExpiredAttempts() {
            attempts.removeAll { $0.isExpired }
        }
        
        /// Reset state after successful attempt
        mutating func reset() {
            consecutiveFailures = 0
            lockoutUntil = nil
            // Keep recent attempts for monitoring but reset failure count
        }
    }
    
    // MARK: - Properties
    
    private let storage: KeychainStorageProtocol
    private let storagePrefix = "rate_limiter_"
    private let queue = DispatchQueue(label: "com.growwiser.rate-limiter", qos: .utility)
    
    /// Global bypass flag for testing
    private var bypassEnabled: Bool = false
    
    /// Default policies for different operations
    private var defaultPolicies: [String: Policy] = [
        "authentication": .authentication,
        "sensitive": .sensitive,
        "testing": .testing
    ]
    
    // MARK: - Initialization
    
    /// Initialize with storage provider
    /// - Parameter storage: Storage provider for persistent state
    public init(storage: KeychainStorageProtocol) {
        self.storage = storage
        
        // Schedule periodic cleanup
        scheduleCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Check if an operation is allowed under rate limiting
    /// - Parameters:
    ///   - key: Unique identifier (e.g., user email, IP address)
    ///   - operation: Operation name for policy lookup
    ///   - policy: Custom policy (overrides default for operation)
    /// - Returns: Rate limit result
    public func checkLimit(
        for key: String,
        operation: String,
        policy: Policy? = nil
    ) -> RateLimitResult {
        // Bypass check for testing
        if bypassEnabled && operation == "testing" {
            return .allowed
        }
        
        return queue.sync {
            do {
                let effectivePolicy = policy ?? getPolicy(for: operation)
                var state = try getState(for: key, operation: operation)
                
                // Clean up expired attempts
                state.cleanupExpiredAttempts()
                
                // Check if currently locked out
                if let lockoutUntil = state.lockoutUntil,
                   lockoutUntil > Date() {
                    return .locked(unlockAt: lockoutUntil, totalFailures: state.consecutiveFailures)
                }
                
                // Clear expired lockout
                if let lockoutUntil = state.lockoutUntil,
                   lockoutUntil <= Date() {
                    state.lockoutUntil = nil
                }
                
                // Count recent attempts within time window
                let cutoff = Date().addingTimeInterval(-effectivePolicy.timeWindow)
                let recentAttempts = state.attempts.filter { 
                    $0.timestamp >= cutoff && !$0.successful 
                }
                
                let attemptsRemaining = max(0, effectivePolicy.maxAttempts - recentAttempts.count)
                
                // Check if rate limit exceeded
                if recentAttempts.count >= effectivePolicy.maxAttempts {
                    return .limited(
                        retryAfter: effectivePolicy.timeWindow,
                        attemptsRemaining: 0
                    )
                }
                
                // Save updated state
                try saveState(state, for: key, operation: operation)
                
                return .allowed
                
            } catch {
                // On storage error, allow but log
                debugPrint("Rate limiter storage error: \(error)")
                return .allowed
            }
        }
    }
    
    /// Record an authentication attempt
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - operation: Operation name
    ///   - successful: Whether attempt was successful
    ///   - policy: Custom policy (overrides default)
    /// - Throws: RateLimiterError if rate limited or locked
    public func recordAttempt(
        for key: String,
        operation: String,
        successful: Bool,
        policy: Policy? = nil
    ) throws {
        // Bypass for testing
        if bypassEnabled && operation == "testing" {
            return
        }
        
        try queue.sync {
            let effectivePolicy = policy ?? getPolicy(for: operation)
            var state = try getState(for: key, operation: operation)
            
            // Clean up expired attempts
            state.cleanupExpiredAttempts()
            
            // Record the attempt
            let attempt = AttemptRecord(
                timestamp: Date(),
                successful: successful,
                operation: operation
            )
            state.attempts.append(attempt)
            state.lastAttempt = Date()
            
            if successful {
                // Reset on success
                state.reset()
            } else {
                // Handle failure
                state.consecutiveFailures += 1
                
                // Check if lockout is needed
                let cutoff = Date().addingTimeInterval(-effectivePolicy.timeWindow)
                let recentFailures = state.attempts.filter { 
                    $0.timestamp >= cutoff && !$0.successful 
                }.count
                
                if recentFailures >= effectivePolicy.maxAttempts {
                    // Calculate lockout duration with exponential backoff
                    let lockoutDuration = calculateLockoutDuration(
                        consecutiveFailures: state.consecutiveFailures,
                        policy: effectivePolicy
                    )
                    
                    state.lockoutUntil = Date().addingTimeInterval(lockoutDuration)
                }
            }
            
            // Save updated state
            try saveState(state, for: key, operation: operation)
            
            // Check final state and throw if necessary
            if let lockoutUntil = state.lockoutUntil,
               lockoutUntil > Date() {
                throw RateLimiterError.accountLocked(unlockAt: lockoutUntil)
            }
            
            // Check rate limit
            let cutoff = Date().addingTimeInterval(-effectivePolicy.timeWindow)
            let recentFailures = state.attempts.filter { 
                $0.timestamp >= cutoff && !$0.successful 
            }.count
            
            if recentFailures >= effectivePolicy.maxAttempts {
                throw RateLimiterError.rateLimitExceeded(retryAfter: effectivePolicy.timeWindow)
            }
        }
    }
    
    /// Reset rate limit state for a key/operation
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - operation: Operation name
    public func reset(for key: String, operation: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let stateKey = self.makeStateKey(for: key, operation: operation)
            try? self.storage.delete(for: stateKey)
        }
    }
    
    /// Get current rate limit status
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - operation: Operation name
    ///   - policy: Custom policy
    /// - Returns: Current rate limit result
    public func getStatus(
        for key: String,
        operation: String,
        policy: Policy? = nil
    ) -> RateLimitResult {
        return checkLimit(for: key, operation: operation, policy: policy)
    }
    
    /// Enable bypass mode for testing
    /// - Warning: Only use in test environments
    public func enableTestingBypass() {
        bypassEnabled = true
    }
    
    /// Disable bypass mode
    public func disableTestingBypass() {
        bypassEnabled = false
    }
    
    /// Set custom policy for an operation
    /// - Parameters:
    ///   - policy: Rate limiting policy
    ///   - operation: Operation name
    public func setPolicy(_ policy: Policy, for operation: String) {
        queue.async { [weak self] in
            self?.defaultPolicies[operation] = policy
        }
    }
    
    /// Clean up all expired rate limit data
    public func performMaintenance() {
        queue.async { [weak self] in
            self?.cleanupExpiredData()
        }
    }
    
    // MARK: - Private Methods
    
    /// Get policy for operation
    private func getPolicy(for operation: String) -> Policy {
        return defaultPolicies[operation] ?? .authentication
    }
    
    /// Get rate limit state from storage
    private func getState(for key: String, operation: String) throws -> RateLimitState {
        let stateKey = makeStateKey(for: key, operation: operation)
        
        do {
            return try storage.retrieveCodable(RateLimitState.self, for: stateKey)
        } catch {
            // Return new state if not found
            return RateLimitState()
        }
    }
    
    /// Save rate limit state to storage
    private func saveState(
        _ state: RateLimitState,
        for key: String,
        operation: String
    ) throws {
        let stateKey = makeStateKey(for: key, operation: operation)
        try storage.storeCodable(state, for: stateKey)
    }
    
    /// Create storage key for state
    private func makeStateKey(for key: String, operation: String) -> String {
        // Validate and sanitize inputs
        let sanitizedKey = key.replacingOccurrences(of: "[^a-zA-Z0-9@._-]", 
                                                   with: "_", 
                                                   options: .regularExpression)
        let sanitizedOperation = operation.replacingOccurrences(of: "[^a-zA-Z0-9_-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        return "\(storagePrefix)\(sanitizedOperation)_\(sanitizedKey)"
    }
    
    /// Calculate lockout duration with exponential backoff
    private func calculateLockoutDuration(
        consecutiveFailures: Int,
        policy: Policy
    ) -> TimeInterval {
        guard policy.useExponentialBackoff else {
            return policy.baseLockoutDuration
        }
        
        // Calculate exponential backoff
        let multiplier = pow(policy.backoffMultiplier, Double(consecutiveFailures - 1))
        let duration = policy.baseLockoutDuration * multiplier
        
        // Cap at maximum duration
        return min(duration, policy.maxLockoutDuration)
    }
    
    /// Schedule periodic cleanup
    private func scheduleCleanup() {
        // Clean up every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performMaintenance()
        }
    }
    
    /// Clean up expired rate limit data
    private func cleanupExpiredData() {
        // This is a simplified cleanup - in production you might want
        // to enumerate all rate limiter keys and clean them up
        
        // For now, cleanup happens per-key when accessed
        debugPrint("Rate limiter maintenance performed")
    }
}

// MARK: - Extensions

extension KeychainStorageProtocol {
    
    /// Store Codable object (extension for RateLimiter support)
    func storeCodable<T: Codable>(_ object: T, for key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try store(data, for: key)
    }
    
    /// Retrieve Codable object (extension for RateLimiter support)
    func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        let data = try retrieve(for: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

// MARK: - Rate Limiter Factory

/// Factory for creating rate limiters with appropriate storage
public struct RateLimiterFactory {
    
    /// Create a rate limiter with keychain storage
    /// - Parameter keychainManager: KeychainManager instance
    /// - Returns: Configured RateLimiter
    public static func create(with keychainManager: KeychainStorageProtocol) -> RateLimiter {
        return RateLimiter(storage: keychainManager)
    }
    
    /// Create a rate limiter with custom policies
    /// - Parameters:
    ///   - keychainManager: KeychainManager instance
    ///   - policies: Custom policies for operations
    /// - Returns: Configured RateLimiter
    public static func create(
        with keychainManager: KeychainStorageProtocol,
        policies: [String: RateLimiter.Policy]
    ) -> RateLimiter {
        let limiter = RateLimiter(storage: keychainManager)
        
        for (operation, policy) in policies {
            limiter.setPolicy(policy, for: operation)
        }
        
        return limiter
    }
}