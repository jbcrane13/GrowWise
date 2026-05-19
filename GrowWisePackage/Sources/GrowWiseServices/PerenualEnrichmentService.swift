import Foundation
import GrowWiseModels
import os

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

private let logger = Logger(subsystem: "com.growwise", category: "PerenualEnrichment")

/// Result of enriching a plant with Perenual data.
public struct PerenualEnrichmentResult: Sendable {
    public let detail: PerenualSpeciesDetail
    /// Confidence score from 0.0 to 1.0 indicating match quality.
    public let confidenceScore: Double

    public init(detail: PerenualSpeciesDetail, confidenceScore: Double) {
        self.detail = detail
        self.confidenceScore = min(max(confidenceScore, 0.0), 1.0)
    }
}

/// Enriches local Plant objects with Perenual API data.
/// Caches results in memory keyed by scientific name to avoid redundant lookups.
@MainActor
@Observable
public final class PerenualEnrichmentService {
    private let api: PerenualAPIService

    /// In-memory cache: scientific name → detail (nil = looked up but not found)
    private var cache: [String: PerenualSpeciesDetail?] = [:]

    /// Currently in-flight lookups (prevents duplicate requests)
    private var inflight: Set<String> = []

    public init(api: PerenualAPIService) {
        self.api = api
    }

    /// Fetch enrichment data for a plant. Returns cached result instantly if available.
    /// Fires a background lookup if not cached yet.
    public func enrichment(for plant: Plant) -> PerenualSpeciesDetail? {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return nil }
        let key = sciName.lowercased()

        if let cached = cache[key] {
            return cached
        }

        // Trigger background fetch (only once per key)
        if !inflight.contains(key) {
            inflight.insert(key)
            Task { @MainActor in
                await fetchAndCache(scientificName: sciName, key: key)
            }
        }

        return nil
    }

    /// Synchronous check if enrichment is available (already cached)
    public func hasCachedEnrichment(for plant: Plant) -> Bool {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return false }
        return cache[sciName.lowercased()] != nil
    }

    /// Force a fresh lookup (bypasses cache)
    public func refresh(for plant: Plant) async -> PerenualSpeciesDetail? {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return nil }
        let key = sciName.lowercased()
        return await fetchAndCache(scientificName: sciName, key: key)
    }

    /// Returns cached enrichment when available, otherwise waits for a lookup.
    public func loadEnrichment(for plant: Plant) async -> PerenualSpeciesDetail? {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return nil }
        let key = sciName.lowercased()

        if let cached = cache[key] {
            return cached
        }

        if inflight.contains(key) {
            for _ in 0 ..< 30 {
                try? await Task.sleep(for: .milliseconds(200))
                if let cached = cache[key] {
                    return cached
                }
                if !inflight.contains(key) {
                    return nil
                }
            }
            return nil
        }

        inflight.insert(key)
        return await fetchAndCache(scientificName: sciName, key: key)
    }

    /// Kick off background enrichment for a plant template on first-plant-pick.
    /// Returns immediately; enrichment happens asynchronously.
    public func prefetch(for plant: Plant) {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return }
        let key = sciName.lowercased()

        // Already cached or in-flight
        if cache[key] != nil { return }
        if inflight.contains(key) { return }

        inflight.insert(key)
        Task { @MainActor in
            await fetchAndCache(scientificName: sciName, key: key)
        }
    }

    /// Returns enrichment result with confidence score.
    public func enrichmentResult(for plant: Plant) async -> PerenualEnrichmentResult? {
        guard let detail = await loadEnrichment(for: plant) else { return nil }
        let confidence = calculateConfidenceScore(for: detail, plant: plant)
        return PerenualEnrichmentResult(detail: detail, confidenceScore: confidence)
    }

    // MARK: - Private

    @discardableResult
    private func fetchAndCache(scientificName: String, key: String) async -> PerenualSpeciesDetail? {
        defer { inflight.remove(key) }

        do {
            // Search by scientific name
            let results = try await api.fetchSpeciesList(query: scientificName, page: 1)

            // Find best match — exact scientific name match preferred
            let normalizedQuery = scientificName.lowercased()
            let bestMatch = results.data.first { species in
                species.scientificName.contains { $0.lowercased() == normalizedQuery }
            } ?? results.data.first { species in
                species.scientificName.contains { $0.lowercased().contains(normalizedQuery) }
            } ?? results.data.first // Fallback to first result

            guard let match = bestMatch else {
                logger.info("[Enrich] No match for: \(scientificName, privacy: .public)")
                cache[key] = .some(nil)
                return nil
            }

            // Fetch full details
            let detail = try await api.fetchSpeciesDetail(id: match.id)
            cache[key] = detail
            logger.debug("[Enrich] Cached: \(scientificName, privacy: .public) → id=\(match.id)")
            return detail
        } catch {
            logger.error("[Enrich] Failed for \(scientificName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            cache[key] = .some(nil) // Cache the failure to avoid retrying
            return nil
        }
    }

    /// Calculates a confidence score (0.0-1.0) based on data completeness from Perenual.
    private func calculateConfidenceScore(for detail: PerenualSpeciesDetail, plant: Plant) -> Double {
        var score: Double = 0.5 // Base score

        // Higher score for complete data
        if detail.description != nil { score += 0.1 }
        if detail.watering != nil { score += 0.05 }
        if detail.sunlight != nil, !(detail.sunlight?.isEmpty ?? true) { score += 0.05 }
        if detail.careLevel != nil { score += 0.05 }
        if detail.hardiness != nil { score += 0.05 }
        if detail.dimensions != nil, !(detail.dimensions?.isEmpty ?? true) { score += 0.05 }
        if detail.defaultImage != nil { score += 0.05 }
        if detail.indoor != nil { score += 0.05 }

        return min(score, 1.0)
    }
}

// swiftlint:enable line_length

// MARK: - PerenualImageCache

/// LRU on-disk image cache for Perenual plant images.
/// Bounded to a maximum size (default 50MB) and stores in the app's cache directory.
public actor PerenualImageCache {
    // MARK: - Configuration

    /// Maximum cache size in bytes (default 50MB)
    public let maxCacheSize: Int64

    /// Cache directory URL
    private let cacheDirectory: URL

    /// In-memory index of cache entries for fast lookup
    private var index: [String: CacheEntry] = [:]

    /// Metadata file name
    private static let indexFileName = "perenual_image_cache_index.json"

    // MARK: - Types

    public struct CacheEntry: Codable, Sendable {
        let key: String
        let fileName: String
        let size: Int64
        let lastAccess: Date
    }

    // MARK: - Initialization

    public init(maxCacheSizeMB: Int = 50) {
        self.maxCacheSize = Int64(maxCacheSizeMB) * 1024 * 1024
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheDir.appendingPathComponent("PerenualImages")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Retrieve an image from cache. Returns nil if not found.
    public func image(for key: String) -> Data? {
        guard var entry = index[key] else { return nil }

        // Update last access time
        entry = CacheEntry(key: entry.key, fileName: entry.fileName, size: entry.size, lastAccess: Date())
        index[key] = entry
        saveIndex()

        let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)
        return try? Data(contentsOf: fileURL)
    }

    /// Store an image in cache. Performs LRU eviction if size limit is exceeded.
    public func storeImage(_ data: Data, for key: String) {
        // Generate unique filename
        let sanitizedKey = key.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        let fileName = "\(sanitizedKey)_\(UUID().uuidString.prefix(8)).img"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
        } catch {
            return
        }

        let entry = CacheEntry(key: key, fileName: fileName, size: Int64(data.count), lastAccess: Date())
        index[key] = entry

        // Evict if needed
        evictIfNeeded()

        // Save index
        saveIndex()
    }

    /// Check if an image is cached
    public func containsImage(for key: String) -> Bool {
        index[key] != nil
    }

    /// Clear all cached images
    public func clearAll() {
        // Remove all files
        for entry in index.values {
            let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Clear index
        index.removeAll()
        saveIndex()
    }

    /// Current cache size in bytes
    public var currentSize: Int64 {
        index.values.reduce(0) { $0 + $1.size }
    }

    // MARK: - Private

    private func saveIndex() {
        let indexURL = cacheDirectory.appendingPathComponent(Self.indexFileName)
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL)
    }

    private func evictIfNeeded() {
        while currentSize > maxCacheSize {
            // Find LRU entry
            guard let lruKey = index.values.min(by: { $0.lastAccess < $1.lastAccess })?.key else { break }

            if let entry = index[lruKey] {
                let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)
                try? FileManager.default.removeItem(at: fileURL)
            }
            index.removeValue(forKey: lruKey)
        }
    }
}