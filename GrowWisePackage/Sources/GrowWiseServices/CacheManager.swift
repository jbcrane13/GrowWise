import Foundation
import UIKit
import os.log

/// Advanced caching system for improved app performance
@MainActor
public final class CacheManager: ObservableObject {
    public static let shared = CacheManager()
    
    // Cache logger
    private let logger = Logger(subsystem: "com.growwise", category: "Cache")
    
    // Memory caches
    private let imageCache = NSCache<NSString, UIImage>()
    private let dataCache = NSCache<NSString, NSData>()
    private let queryCache = NSCache<NSString, CachedQueryResult>()
    
    // Track inserted keys for invalidation by pattern
    private var imageCacheKeys = Set<String>()
    private var dataCacheKeys = Set<String>()
    private var queryCacheKeys = Set<String>()
    
    // Disk cache paths
    private let diskCacheURL: URL
    private let imageCacheURL: URL
    private let dataCacheURL: URL
    
    // Cache configuration
    private let config = CacheConfiguration()
    
    // Statistics tracking
    @Published public private(set) var statistics = CacheStatistics()
    
    // Memory pressure handling
    private var memoryPressureObserver: NSObjectProtocol?
    
    // Background queue for disk operations
    private let diskQueue = DispatchQueue(label: "com.growwise.cache.disk", qos: .background)
    
    private init() {
        // Setup disk cache directories
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("GrowWiseCache")
        imageCacheURL = diskCacheURL.appendingPathComponent("Images")
        dataCacheURL = diskCacheURL.appendingPathComponent("Data")
        
        // Create directories
        createCacheDirectories()
        
        // Configure memory caches
        configureMemoryCaches()
        
        // Setup memory pressure observer
        setupMemoryPressureHandling()
        
        // Load cache metadata
        loadCacheMetadata()
        
        logger.info("🗄️ Cache Manager initialized")
    }
    
    nonisolated deinit {
        // Memory pressure observer cleanup is handled when the object is deallocated
        // NotificationCenter automatically removes observers when they are deallocated
    }
    
    // MARK: - Public Interface
    
    /// Store image in cache
    public func storeImage(_ image: UIImage, for key: String, toDisk: Bool = true) async {
        let cacheKey = NSString(string: key)
        
        // Store in memory cache
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory cost
        imageCache.setObject(image, forKey: cacheKey, cost: cost)
        imageCacheKeys.insert(key)
        
        statistics.recordCacheWrite()
        
        // Store to disk if requested
        if toDisk {
            await storeToDisk(image: image, key: key)
        }
    }
    
    /// Retrieve image from cache
    public func retrieveImage(for key: String) async -> UIImage? {
        let cacheKey = NSString(string: key)
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            statistics.recordCacheHit()
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = await loadFromDisk(imageKey: key) {
            // Store in memory cache for future use
            imageCache.setObject(diskImage, forKey: cacheKey)
            statistics.recordCacheHit()
            return diskImage
        }
        
        statistics.recordCacheMiss()
        return nil
    }
    
    /// Store data in cache
    public func storeData<T: Codable>(_ data: T, for key: String, ttl: TimeInterval? = nil) async {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        
        let cacheKey = NSString(string: key)
        let nsData = NSData(data: encoded)
        
        // Create cache entry with TTL
        let entry = CacheEntry(data: encoded, ttl: ttl)
        
        // Store in memory cache
        dataCache.setObject(nsData, forKey: cacheKey, cost: encoded.count)
        dataCacheKeys.insert(key)
        
        statistics.recordCacheWrite()
        
        // Store to disk
        await storeToDisk(data: entry, key: key)
    }
    
    /// Retrieve data from cache
    public func retrieveData<T: Codable>(for key: String, as type: T.Type) async -> T? {
        let cacheKey = NSString(string: key)
        
        // Check memory cache first
        if let cachedData = dataCache.object(forKey: cacheKey) {
            if let decoded = try? JSONDecoder().decode(T.self, from: cachedData as Data) {
                statistics.recordCacheHit()
                return decoded
            }
        }
        
        // Check disk cache
        if let diskEntry: CacheEntry = await loadFromDisk(dataKey: key) {
            // Check TTL
            if !diskEntry.isExpired {
                if let decoded = try? JSONDecoder().decode(T.self, from: diskEntry.data) {
                    // Store in memory cache for future use
                    let nsData = NSData(data: diskEntry.data)
                    dataCache.setObject(nsData, forKey: cacheKey)
                    statistics.recordCacheHit()
                    return decoded
                }
            } else {
                // Remove expired entry
                await removeFromDisk(key: key, isImage: false)
            }
        }
        
        statistics.recordCacheMiss()
        return nil
    }
    
    /// Cache query results
    public func cacheQueryResult<T: Codable>(_ result: [T], for query: String, ttl: TimeInterval = 300) {
        guard let encoded = try? JSONEncoder().encode(result) else { return }
        
        let cacheKey = NSString(string: query)
        let cachedResult = CachedQueryResult(
            query: query,
            data: encoded,
            resultCount: result.count,
            timestamp: Date(),
            ttl: ttl
        )
        
        queryCache.setObject(cachedResult, forKey: cacheKey)
        queryCacheKeys.insert(query)
        statistics.recordCacheWrite()
    }
    
    /// Retrieve cached query result
    public func getCachedQueryResult<T: Codable>(for query: String, as type: T.Type) -> [T]? {
        let cacheKey = NSString(string: query)
        
        guard let cachedResult = queryCache.object(forKey: cacheKey) else {
            statistics.recordCacheMiss()
            return nil
        }
        
        // Check if expired
        if cachedResult.isExpired {
            queryCache.removeObject(forKey: cacheKey)
            statistics.recordCacheMiss()
            return nil
        }
        
        // Decode and return
        if let decoded = try? JSONDecoder().decode([T].self, from: cachedResult.data) {
            statistics.recordCacheHit()
            return decoded
        }
        
        statistics.recordCacheMiss()
        return nil
    }
    
    /// Invalidate cache entries matching pattern
    public func invalidate(matching pattern: String) async {
        await MainActor.run {
            // Invalidate memory caches
            invalidateMemoryCache(pattern: pattern)
        }
        
        // Invalidate disk cache
        await invalidateDiskCache(pattern: pattern)
        
        logger.info("🗑️ Invalidated cache entries matching: \(pattern)")
    }
    
    /// Clear all caches
    public func clearAll() async {
        // Clear memory caches
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
        queryCache.removeAllObjects()
        
        // Clear disk cache
        await clearDiskCache()
        
        // Reset statistics
        statistics.reset()
        
        logger.info("🧹 All caches cleared")
    }
    
    /// Get cache size information
    public func getCacheSize() async -> CacheSizeInfo {
        let memorySizeBytes = calculateMemoryCacheSize()
        let diskSizeBytes = await calculateDiskCacheSize()
        
        return CacheSizeInfo(
            memorySizeBytes: memorySizeBytes,
            diskSizeBytes: diskSizeBytes,
            totalSizeBytes: memorySizeBytes + diskSizeBytes
        )
    }
    
    /// Preload frequently accessed data
    public func preloadFrequentData() async {
        // This would be customized based on app usage patterns
        logger.info("📦 Preloading frequently accessed data")
        
        // Example: Preload recent plants, common queries, etc.
        // Implementation would depend on actual app usage patterns
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectories() {
        do {
            try FileManager.default.createDirectory(at: imageCacheURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: dataCacheURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create cache directories: \(error)")
        }
    }
    
    private func configureMemoryCaches() {
        // Configure image cache
        imageCache.countLimit = config.maxImageCacheCount
        imageCache.totalCostLimit = config.maxImageCacheSizeBytes
        
        // Configure data cache
        dataCache.countLimit = config.maxDataCacheCount
        dataCache.totalCostLimit = config.maxDataCacheSizeBytes
        
        // Configure query cache
        queryCache.countLimit = config.maxQueryCacheCount
    }
    
    private func setupMemoryPressureHandling() {
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
    }
    
    @MainActor
    private func handleMemoryPressure() {
        logger.warning("⚠️ Memory pressure detected, clearing memory caches")
        
        // Clear memory caches but keep disk cache
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
        queryCache.removeAllObjects()
        
        statistics.recordMemoryPressureEvent()
    }
    
    private func storeToDisk(image: UIImage, key: String) async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let fileURL = self.imageCacheURL.appendingPathComponent("\(key).jpg")
                
                if let data = image.jpegData(compressionQuality: 0.8) {
                    do {
                        try data.write(to: fileURL)
                    } catch {
                        self.logger.error("Failed to cache image to disk: \(error)")
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func storeToDisk(data: CacheEntry, key: String) async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let fileURL = self.dataCacheURL.appendingPathComponent("\(key).cache")
                
                if let encoded = try? JSONEncoder().encode(data) {
                    do {
                        try encoded.write(to: fileURL)
                    } catch {
                        self.logger.error("Failed to cache data to disk: \(error)")
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func loadFromDisk(imageKey: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fileURL = self.imageCacheURL.appendingPathComponent("\(imageKey).jpg")
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadFromDisk(dataKey: String) async -> CacheEntry? {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fileURL = self.dataCacheURL.appendingPathComponent("\(dataKey).cache")
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let data = try? Data(contentsOf: fileURL),
                   let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) {
                    continuation.resume(returning: entry)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func removeFromDisk(key: String, isImage: Bool) async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let directory = isImage ? self.imageCacheURL : self.dataCacheURL
                let fileExtension = isImage ? "jpg" : "cache"
                let fileURL = directory.appendingPathComponent("\(key).\(fileExtension)")
                
                try? FileManager.default.removeItem(at: fileURL)
                continuation.resume()
            }
        }
    }
    
    private func invalidateMemoryCache(pattern: String) {
        // Remove matching image cache entries
        for key in imageCacheKeys.filter({ $0.contains(pattern) }) {
            imageCache.removeObject(forKey: NSString(string: key))
            imageCacheKeys.remove(key)
        }
        // Remove matching data cache entries
        for key in dataCacheKeys.filter({ $0.contains(pattern) }) {
            dataCache.removeObject(forKey: NSString(string: key))
            dataCacheKeys.remove(key)
        }
        // Remove matching query cache entries
        for key in queryCacheKeys.filter({ $0.contains(pattern) }) {
            queryCache.removeObject(forKey: NSString(string: key))
            queryCacheKeys.remove(key)
        }
    }
    
    private func invalidateDiskCache(pattern: String) async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Clear matching image cache files
                if let imageFiles = try? FileManager.default.contentsOfDirectory(at: self.imageCacheURL, includingPropertiesForKeys: nil) {
                    for file in imageFiles where file.lastPathComponent.contains(pattern) {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
                
                // Clear matching data cache files
                if let dataFiles = try? FileManager.default.contentsOfDirectory(at: self.dataCacheURL, includingPropertiesForKeys: nil) {
                    for file in dataFiles where file.lastPathComponent.contains(pattern) {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func clearDiskCache() async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                try? FileManager.default.removeItem(at: self.imageCacheURL)
                try? FileManager.default.removeItem(at: self.dataCacheURL)
                
                // Recreate directories directly here to avoid MainActor isolation issue
                do {
                    try FileManager.default.createDirectory(at: self.imageCacheURL, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: self.dataCacheURL, withIntermediateDirectories: true)
                } catch {
                    // Log error but continue since the directories will be created on next write
                }
                
                continuation.resume()
            }
        }
    }
    
    private func calculateMemoryCacheSize() -> Int {
        // This is an approximation
        return imageCache.totalCostLimit + dataCache.totalCostLimit
    }
    
    private func calculateDiskCacheSize() async -> Int {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var totalSize = 0
                
                if let enumerator = FileManager.default.enumerator(
                    at: self.diskCacheURL,
                    includingPropertiesForKeys: [.fileSizeKey]
                ) {
                    for case let fileURL as URL in enumerator {
                        if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            totalSize += fileSize
                        }
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    private func loadCacheMetadata() {
        // Load any persistent cache metadata
        // This could include usage patterns, frequently accessed keys, etc.
    }
}

// MARK: - Supporting Types

struct CacheConfiguration {
    let maxImageCacheCount = 100
    let maxImageCacheSizeBytes = 50 * 1024 * 1024 // 50MB
    let maxDataCacheCount = 500
    let maxDataCacheSizeBytes = 20 * 1024 * 1024 // 20MB
    let maxQueryCacheCount = 200
    let defaultTTL: TimeInterval = 300 // 5 minutes
}

struct CacheEntry: Codable {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval?
    
    init(data: Data, ttl: TimeInterval?) {
        self.data = data
        self.timestamp = Date()
        self.ttl = ttl
    }
    
    var isExpired: Bool {
        guard let ttl = ttl else { return false }
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

class CachedQueryResult: NSObject {
    let query: String
    let data: Data
    let resultCount: Int
    let timestamp: Date
    let ttl: TimeInterval
    
    init(query: String, data: Data, resultCount: Int, timestamp: Date, ttl: TimeInterval) {
        self.query = query
        self.data = data
        self.resultCount = resultCount
        self.timestamp = timestamp
        self.ttl = ttl
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

public struct CacheStatistics {
    public private(set) var hits = 0
    public private(set) var misses = 0
    public private(set) var writes = 0
    public private(set) var memoryPressureEvents = 0
    
    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
    
    mutating func recordCacheHit() {
        hits += 1
    }
    
    mutating func recordCacheMiss() {
        misses += 1
    }
    
    mutating func recordCacheWrite() {
        writes += 1
    }
    
    mutating func recordMemoryPressureEvent() {
        memoryPressureEvents += 1
    }
    
    mutating func reset() {
        hits = 0
        misses = 0
        writes = 0
        memoryPressureEvents = 0
    }
}

public struct CacheSizeInfo {
    public let memorySizeBytes: Int
    public let diskSizeBytes: Int
    public let totalSizeBytes: Int
    
    public var memorySizeMB: Double {
        Double(memorySizeBytes) / (1024 * 1024)
    }
    
    public var diskSizeMB: Double {
        Double(diskSizeBytes) / (1024 * 1024)
    }
    
    public var totalSizeMB: Double {
        Double(totalSizeBytes) / (1024 * 1024)
    }
}
