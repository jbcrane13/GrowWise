import Foundation

/// High-performance caching layer for SwiftData queries with TTL management
@MainActor
public final class SwiftDataCache {
    private struct CacheEntry {
        let value: Any
        let timestamp: Date
        let ttl: TimeInterval
        
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
    public func set<T>(_ key: String, value: T, ttl: TimeInterval? = nil) {
        let actualTTL = ttl ?? defaultTTL
        cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: actualTTL)
        
        // Prevent cache from growing too large
        if cache.count > maxCacheSize {
            evictOldestEntries()
        }
    }
    
    /// Invalidate specific cache entry
    public func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    /// Clear all cached data
    public func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    /// Get cache statistics
    public func getStats() -> (hits: Int, misses: Int, size: Int) {
        return (hitCount, missCount, cache.count)
    }
    
    /// Get cache hit ratio for performance monitoring
    public func getHitRatio() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    private func cleanExpiredEntries() {
        cache = cache.filter { !$0.value.isExpired }
    }
    
    private func evictOldestEntries() {
        let sortedKeys = cache.keys.sorted { key1, key2 in
            cache[key1]!.timestamp < cache[key2]!.timestamp
        }
        
        let toRemove = sortedKeys.prefix(cache.count - maxCacheSize + 10)
        for key in toRemove {
            cache.removeValue(forKey: key)
        }
    }
}