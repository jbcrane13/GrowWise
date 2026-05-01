import Foundation
import os

private let logger = Logger(subsystem: "com.growwise", category: "SwiftDataCache")

/// High-performance caching layer for SwiftData queries with TTL management
/// Supports TTL policies (short/medium/long) for different data freshness requirements
/// Provides cache warming API for preloading frequently accessed data
@MainActor
public final class SwiftDataCache {
    /// TTL policy for cache entries
    public enum TTLPolicy {
        case short // 120 seconds (2 minutes) - time-sensitive data like active reminders
        case medium // 300 seconds (5 minutes) - standard queries like plants/gardens
        case long // 900 seconds (15 minutes) - stable data like plant database
        case custom(TimeInterval) // custom TTL for special cases

        var timeInterval: TimeInterval {
            switch self {
            case .short: 120
            case .medium: 300
            case .long: 900
            case .custom(let interval): interval
            }
        }
    }

    private struct CacheEntry {
        let value: Any
        let timestamp: Date
        let ttl: TimeInterval
        let policy: TTLPolicy

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    private var cache: [String: CacheEntry] = [:]
    private let defaultTTL: TimeInterval = 300 // 5 minutes
    private let maxCacheSize = 100

    // Performance tracking
    private var hitCount = 0
    private var missCount = 0

    public init() {}

    /// Get cached value if available and not expired
    public func get<T>(_ key: String, as type: T.Type) -> T? {
        cleanExpiredEntries()

        guard let entry = cache[key], !entry.isExpired else {
            missCount += 1
            return nil
        }

        hitCount += 1
        return entry.value as? T
    }

    /// Store value with TTL
    public func set(_ key: String, value: some Any, ttl: TimeInterval? = nil) {
        let actualTTL = ttl ?? defaultTTL
        cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: actualTTL, policy: .custom(actualTTL))

        // Prevent cache from growing too large
        if cache.count > maxCacheSize {
            evictOldestEntries()
        }
    }

    /// Store value with TTL policy
    public func set(_ key: String, value: some Any, policy: TTLPolicy) {
        let ttl = policy.timeInterval
        cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: ttl, policy: policy)
        let policyDesc = String(describing: policy)
        let cacheSize = self.cache.count
        logger.debug("[Cache] Set: key=\(key, privacy: .public), policy=\(policyDesc, privacy: .public), size=\(cacheSize)")

        // Prevent cache from growing too large
        if cache.count > maxCacheSize {
            evictOldestEntries()
        }
    }

    /// Invalidate specific cache entry
    public func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }

    /// Invalidate all entries whose keys share the provided prefix
    public func invalidateAll(withPrefix prefix: String) {
        for key in cache.keys where key.hasPrefix(prefix) {
            cache.removeValue(forKey: key)
        }
    }

    /// Clear all cached data
    public func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }

    /// Get cache statistics
    public func getStats() -> (hits: Int, misses: Int, size: Int) {
        (hitCount, missCount, cache.count)
    }

    /// Get cache hit ratio for performance monitoring
    public func getHitRatio() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }

    /// Cache statistics for detailed monitoring
    public struct CacheStatistics {
        public let hits: Int
        public let misses: Int
        public let size: Int
        public let hitRatio: Double
        public let entriesByPolicy: [String: Int]
        public let oldestEntry: Date?
        public let newestEntry: Date?
    }

    /// Get detailed cache statistics
    public func getDetailedStats() -> CacheStatistics {
        var entriesByPolicy: [String: Int] = [:]
        var oldestTimestamp: Date?
        var newestTimestamp: Date?

        for entry in cache.values {
            let policyKey = switch entry.policy {
            case .short: "short"
            case .medium: "medium"
            case .long: "long"
            case .custom: "custom"
            }
            entriesByPolicy[policyKey, default: 0] += 1

            if let oldest = oldestTimestamp {
                if entry.timestamp < oldest {
                    oldestTimestamp = entry.timestamp
                }
            } else {
                oldestTimestamp = entry.timestamp
            }
            if let newest = newestTimestamp {
                if entry.timestamp > newest {
                    newestTimestamp = entry.timestamp
                }
            } else {
                newestTimestamp = entry.timestamp
            }
        }

        return CacheStatistics(
            hits: hitCount,
            misses: missCount,
            size: cache.count,
            hitRatio: getHitRatio(),
            entriesByPolicy: entriesByPolicy,
            oldestEntry: oldestTimestamp,
            newestEntry: newestTimestamp
        )
    }

    /// Check cache health and identify issues
    public func healthCheck() -> (isHealthy: Bool, issues: [String]) {
        var issues: [String] = []

        // Check cache size
        if cache.count > maxCacheSize * 9 / 10 {
            issues.append("Cache near capacity (\(cache.count)/\(maxCacheSize))")
        }

        // Check hit ratio
        let hitRatio = getHitRatio()
        if hitRatio < 0.3, (hitCount + missCount) > 10 {
            issues.append("Low cache hit ratio (\(String(format: "%.1f%%", hitRatio * 100)))")
        }

        // Check expired entries
        let expiredCount = cache.values.count(where: { $0.isExpired })
        if expiredCount > cache.count / 5 {
            issues.append("High expiration rate (\(expiredCount) expired entries)")
        }

        return (isHealthy: issues.isEmpty, issues: issues)
    }

    /// Preload value into cache if not already cached
    public func preload<T: Sendable>(_ key: String, policy: TTLPolicy = .medium, loader: @Sendable () async throws -> T) async {
        // Skip if already cached and not expired
        if let entry = cache[key], !entry.isExpired {
            return
        }

        do {
            let value = try await loader()
            set(key, value: value, policy: policy)
            let policyDesc = String(describing: policy)
            logger.debug("[Cache] Preloaded: \(key, privacy: .public) with policy \(policyDesc, privacy: .public)")
        } catch {
            logger.error("[Cache] Preload failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Warm cache with batch of items
    public func warmBatch(_ items: [(key: String, policy: TTLPolicy, loader: @Sendable () async throws -> any Sendable)]) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        var successCount = 0

        for item in items {
            // Skip if already cached
            if let entry = cache[item.key], !entry.isExpired {
                successCount += 1
                continue
            }

            do {
                let value = try await item.loader()
                let ttl = item.policy.timeInterval
                cache[item.key] = CacheEntry(value: value, timestamp: Date(), ttl: ttl, policy: item.policy)
                successCount += 1
            } catch {
                let errorDesc = error.localizedDescription
                logger.error("[Cache] Batch warming failed for \(item.key, privacy: .public): \(errorDesc, privacy: .public)")
            }

            // Keep UI responsive
            await Task.yield()
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let durationStr = String(format: "%.2fs", duration)
        logger.info("[Cache] Batch warming complete: \(successCount)/\(items.count) items in \(durationStr, privacy: .public)")
    }

    private func cleanExpiredEntries() {
        guard !cache.isEmpty else { return }

        let sizeBefore = cache.count
        cache = cache.filter { !$0.value.isExpired }
        let removedCount = sizeBefore - cache.count

        if removedCount > 0, cache.count > 10 {
            logger.debug("[Cache] Cleaned \(removedCount) expired entries")
        }
    }

    private func evictOldestEntries() {
        let sortedKeys = cache.keys.sorted { key1, key2 in
            guard let entry1 = cache[key1], let entry2 = cache[key2] else { return false }
            return entry1.timestamp < entry2.timestamp
        }

        let toRemove = sortedKeys.prefix(cache.count - maxCacheSize + 10)
        for key in toRemove {
            cache.removeValue(forKey: key)
        }
    }
}
