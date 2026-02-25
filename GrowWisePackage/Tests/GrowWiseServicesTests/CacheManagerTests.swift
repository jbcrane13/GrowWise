import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - Helpers

/// Simple Codable type for roundtrip tests.
private struct CachedPlant: Codable, Equatable {
    let id: UUID
    let name: String
    let wateringIntervalDays: Int
}

private struct CachedGardenNote: Codable, Equatable {
    let text: String
    let rating: Double
}

// MARK: - CacheManager Tests
//
// CacheManager is a @MainActor singleton backed by NSCache (in-memory) and FileManager
// (disk). Tests that write and immediately read are race-free as long as no other test
// calls clearAll() concurrently. We place all tests that touch the shared cache inside a
// single top-level suite marked .serialized so they execute one-at-a-time, eliminating
// all races. Value-type model tests (CacheEntry, CacheStatistics, CacheSizeInfo) run
// independently and are grouped in separate suites outside this serialized parent.

@Suite("CacheManager Shared Cache Tests", .serialized)
struct CacheManagerSharedCacheTests {

    // MARK: Data Roundtrip

    @Test("storeData and retrieveData roundtrip returns stored value")
    @MainActor
    func testDataRoundtrip() async throws {
        let cache = CacheManager.shared
        let key   = "roundtrip-\(UUID().uuidString)"
        let plant = CachedPlant(id: UUID(), name: "Basil", wateringIntervalDays: 3)

        await cache.storeData(plant, for: key)
        let retrieved = await cache.retrieveData(for: key, as: CachedPlant.self)

        #expect(retrieved == plant)
    }

    @Test("retrieveData for non-existent key returns nil")
    @MainActor
    func testMissingKeyReturnsNil() async throws {
        let cache   = CacheManager.shared
        let missing = await cache.retrieveData(
            for: "definitely-not-stored-\(UUID().uuidString)",
            as: CachedPlant.self
        )
        #expect(missing == nil)
    }

    @Test("storeData with TTL — value is accessible immediately after store")
    @MainActor
    func testDataWithTTLAccessibleImmediately() async throws {
        let cache = CacheManager.shared
        let key   = "ttl-\(UUID().uuidString)"
        let plant = CachedPlant(id: UUID(), name: "Mint", wateringIntervalDays: 2)

        await cache.storeData(plant, for: key, ttl: 300)
        let retrieved = await cache.retrieveData(for: key, as: CachedPlant.self)

        #expect(retrieved == plant)
    }

    @Test("Multiple items stored under distinct keys are each retrievable")
    @MainActor
    func testMultipleItemsStoredAndRetrieved() async throws {
        let cache = CacheManager.shared
        let base  = UUID().uuidString
        let plants = [
            CachedPlant(id: UUID(), name: "Rosemary", wateringIntervalDays: 7),
            CachedPlant(id: UUID(), name: "Thyme",    wateringIntervalDays: 5),
            CachedPlant(id: UUID(), name: "Oregano",  wateringIntervalDays: 4),
        ]

        for (i, plant) in plants.enumerated() {
            await cache.storeData(plant, for: "\(base)-\(i)")
        }
        for (i, expected) in plants.enumerated() {
            let result = await cache.retrieveData(for: "\(base)-\(i)", as: CachedPlant.self)
            #expect(result == expected)
        }
    }

    @Test("Overwriting a key stores the newest value")
    @MainActor
    func testOverwriteKey() async throws {
        let cache  = CacheManager.shared
        let key    = "overwrite-\(UUID().uuidString)"
        let first  = CachedPlant(id: UUID(), name: "First",  wateringIntervalDays: 1)
        let second = CachedPlant(id: UUID(), name: "Second", wateringIntervalDays: 9)

        await cache.storeData(first, for: key)
        let afterFirst = await cache.retrieveData(for: key, as: CachedPlant.self)
        #expect(afterFirst == first)

        await cache.storeData(second, for: key)
        let afterSecond = await cache.retrieveData(for: key, as: CachedPlant.self)
        #expect(afterSecond == second)
    }

    @Test("Store and retrieve a different Codable type")
    @MainActor
    func testDifferentCodableType() async throws {
        let cache = CacheManager.shared
        let key   = "note-\(UUID().uuidString)"
        let note  = CachedGardenNote(text: "Leaves look healthy", rating: 4.5)

        await cache.storeData(note, for: key)
        let retrieved = await cache.retrieveData(for: key, as: CachedGardenNote.self)

        #expect(retrieved == note)
    }

    // MARK: Statistics (increment-based — do not rely on absolute values)

    @Test("storeData increments statistics.writes by at least one per call")
    @MainActor
    func testWritesStatisticIncrements() async throws {
        let cache = CacheManager.shared
        let plant = CachedPlant(id: UUID(), name: "Chervil", wateringIntervalDays: 4)

        let writesBefore = cache.statistics.writes
        await cache.storeData(plant, for: "w1-\(UUID().uuidString)")
        await cache.storeData(plant, for: "w2-\(UUID().uuidString)")

        #expect(cache.statistics.writes >= writesBefore + 2)
    }

    @Test("retrieveData hit increments statistics.hits")
    @MainActor
    func testHitsStatisticIncrements() async throws {
        let cache = CacheManager.shared
        let key   = "hit-stat-\(UUID().uuidString)"
        let plant = CachedPlant(id: UUID(), name: "Tarragon", wateringIntervalDays: 8)

        await cache.storeData(plant, for: key)

        let hitsBefore = cache.statistics.hits
        _ = await cache.retrieveData(for: key, as: CachedPlant.self)

        #expect(cache.statistics.hits >= hitsBefore + 1)
    }

    @Test("retrieveData miss increments statistics.misses")
    @MainActor
    func testMissesStatisticIncrements() async throws {
        let cache = CacheManager.shared

        let missesBefore = cache.statistics.misses
        _ = await cache.retrieveData(
            for: "absent-\(UUID().uuidString)",
            as: CachedPlant.self
        )

        #expect(cache.statistics.misses >= missesBefore + 1)
    }

    // MARK: clearAll (placed at the end so prior tests are unaffected)

    @Test("clearAll removes previously stored data entries")
    @MainActor
    func testClearAllRemovesData() async throws {
        let cache = CacheManager.shared
        let base  = UUID().uuidString
        let plant = CachedPlant(id: UUID(), name: "Lavender", wateringIntervalDays: 10)

        for i in 0..<3 {
            await cache.storeData(plant, for: "\(base)-\(i)")
        }
        for i in 0..<3 {
            let before = await cache.retrieveData(for: "\(base)-\(i)", as: CachedPlant.self)
            #expect(before == plant, "Data should be present before clearAll")
        }

        await cache.clearAll()

        for i in 0..<3 {
            let result = await cache.retrieveData(for: "\(base)-\(i)", as: CachedPlant.self)
            #expect(result == nil)
        }
    }

    @Test("clearAll resets statistics to zero")
    @MainActor
    func testClearAllResetsStatistics() async throws {
        let cache = CacheManager.shared

        let key   = "stats-pre-\(UUID().uuidString)"
        let plant = CachedPlant(id: UUID(), name: "Sage", wateringIntervalDays: 6)
        await cache.storeData(plant, for: key)
        _ = await cache.retrieveData(for: key, as: CachedPlant.self)

        await cache.clearAll()

        #expect(cache.statistics.hits   == 0)
        #expect(cache.statistics.misses == 0)
        #expect(cache.statistics.writes == 0)
    }

    @Test("hitRate is 1.0 after clearAll followed by cache-hit retrievals only")
    @MainActor
    func testHitRateIsOneWhenAllHit() async throws {
        let cache = CacheManager.shared

        await cache.clearAll()

        let key   = "hitrate-\(UUID().uuidString)"
        let plant = CachedPlant(id: UUID(), name: "Lemongrass", wateringIntervalDays: 3)
        await cache.storeData(plant, for: key)

        // Retrieve twice — both must be cache hits (data is in memory after storeData).
        _ = await cache.retrieveData(for: key, as: CachedPlant.self)
        _ = await cache.retrieveData(for: key, as: CachedPlant.self)

        #expect(cache.statistics.hitRate == 1.0)
    }

    @Test("hitRate is 0.0 after clearAll followed by cache-miss retrievals only")
    @MainActor
    func testHitRateIsZeroWhenAllMiss() async throws {
        let cache = CacheManager.shared

        await cache.clearAll()

        _ = await cache.retrieveData(for: "miss1-\(UUID().uuidString)", as: CachedPlant.self)
        _ = await cache.retrieveData(for: "miss2-\(UUID().uuidString)", as: CachedPlant.self)

        #expect(cache.statistics.hitRate == 0.0)
    }

    // MARK: invalidate(matching:)

    @Test("invalidate(matching:) removes entries whose keys contain the pattern")
    @MainActor
    func testInvalidateMatchingRemovesEntries() async throws {
        let cache     = CacheManager.shared
        let runId     = UUID().uuidString
        let targetKey = "inv-target-\(runId)"
        let otherKey  = "inv-other-\(runId)"
        let plant     = CachedPlant(id: UUID(), name: "Parsley", wateringIntervalDays: 3)

        await cache.storeData(plant, for: targetKey)
        await cache.storeData(plant, for: otherKey)

        let priorTarget = await cache.retrieveData(for: targetKey, as: CachedPlant.self)
        let priorOther  = await cache.retrieveData(for: otherKey,  as: CachedPlant.self)
        #expect(priorTarget == plant)
        #expect(priorOther  == plant)

        // Invalidate only the target key.
        await cache.invalidate(matching: "inv-target-\(runId)")

        let gone = await cache.retrieveData(for: targetKey, as: CachedPlant.self)
        let kept = await cache.retrieveData(for: otherKey,  as: CachedPlant.self)

        #expect(gone == nil)
        #expect(kept == plant)
    }

    @Test("invalidate(matching:) with no matching keys does not crash")
    @MainActor
    func testInvalidateNoMatchIsNoop() async throws {
        let cache = CacheManager.shared
        await cache.invalidate(matching: "no-match-\(UUID().uuidString)")
    }

    @Test("invalidate(matching:) removes multiple entries sharing a pattern")
    @MainActor
    func testInvalidateMatchesMultipleEntries() async throws {
        let cache   = CacheManager.shared
        let pattern = "bulk-\(UUID().uuidString)"
        let plant   = CachedPlant(id: UUID(), name: "Dill", wateringIntervalDays: 4)

        for i in 0..<4 {
            await cache.storeData(plant, for: "\(pattern)-item-\(i)")
        }
        for i in 0..<4 {
            let before = await cache.retrieveData(for: "\(pattern)-item-\(i)", as: CachedPlant.self)
            #expect(before == plant)
        }

        await cache.invalidate(matching: pattern)

        for i in 0..<4 {
            let result = await cache.retrieveData(for: "\(pattern)-item-\(i)", as: CachedPlant.self)
            #expect(result == nil)
        }
    }

    // MARK: Query cache

    @Test("cacheQueryResult and getCachedQueryResult roundtrip")
    @MainActor
    func testQueryRoundtrip() async throws {
        let cache  = CacheManager.shared
        let query  = "SELECT herbs \(UUID().uuidString)"
        let plants = [
            CachedPlant(id: UUID(), name: "Basil",    wateringIntervalDays: 3),
            CachedPlant(id: UUID(), name: "Cilantro", wateringIntervalDays: 2),
        ]

        cache.cacheQueryResult(plants, for: query, ttl: 300)
        let retrieved = cache.getCachedQueryResult(for: query, as: CachedPlant.self)

        #expect(retrieved?.count == 2)
        #expect(retrieved == plants)
    }

    @Test("getCachedQueryResult returns nil for unknown query")
    @MainActor
    func testQueryMissReturnsNil() async throws {
        let cache  = CacheManager.shared
        let result = cache.getCachedQueryResult(
            for: "unknown-query-\(UUID().uuidString)",
            as: CachedPlant.self
        )
        #expect(result == nil)
    }

    @Test("cacheQueryResult with empty array stores and retrieves successfully")
    @MainActor
    func testQueryWithEmptyArrayRoundtrip() async throws {
        let cache  = CacheManager.shared
        let query  = "empty-result-\(UUID().uuidString)"
        let plants: [CachedPlant] = []

        cache.cacheQueryResult(plants, for: query, ttl: 300)
        let retrieved = cache.getCachedQueryResult(for: query, as: CachedPlant.self)

        #expect(retrieved != nil)
        #expect(retrieved?.isEmpty == true)
    }

    @Test("getCachedQueryResult returns nil for immediately-expired TTL")
    @MainActor
    func testExpiredQueryResultReturnsNil() async throws {
        let cache  = CacheManager.shared
        let query  = "expiring-query-\(UUID().uuidString)"
        let plants = [CachedPlant(id: UUID(), name: "Fennel", wateringIntervalDays: 5)]

        // Negative TTL: isExpired returns true because Date().timeIntervalSince(now) >= 0 > -1.
        cache.cacheQueryResult(plants, for: query, ttl: -1)
        let result = cache.getCachedQueryResult(for: query, as: CachedPlant.self)

        #expect(result == nil)
    }

    @Test("Multiple distinct queries are cached independently")
    @MainActor
    func testMultipleQueriesCachedIndependently() async throws {
        let cache        = CacheManager.shared
        let base         = UUID().uuidString
        let herbPlants   = [CachedPlant(id: UUID(), name: "Basil", wateringIntervalDays: 3)]
        let flowerPlants = [CachedPlant(id: UUID(), name: "Rose",  wateringIntervalDays: 5)]

        cache.cacheQueryResult(herbPlants,   for: "herbs-\(base)",   ttl: 300)
        cache.cacheQueryResult(flowerPlants, for: "flowers-\(base)", ttl: 300)

        let herbs   = cache.getCachedQueryResult(for: "herbs-\(base)",   as: CachedPlant.self)
        let flowers = cache.getCachedQueryResult(for: "flowers-\(base)", as: CachedPlant.self)

        #expect(herbs   == herbPlants)
        #expect(flowers == flowerPlants)
    }

    // MARK: getCacheSize

    @Test("getCacheSize returns without crashing and yields non-negative values")
    @MainActor
    func testGetCacheSizeDoesNotCrash() async throws {
        let cache    = CacheManager.shared
        let sizeInfo = await cache.getCacheSize()

        #expect(sizeInfo.memorySizeBytes >= 0)
        #expect(sizeInfo.diskSizeBytes   >= 0)
        #expect(sizeInfo.totalSizeBytes  >= 0)
        #expect(sizeInfo.totalSizeBytes  == sizeInfo.memorySizeBytes + sizeInfo.diskSizeBytes)
    }

    @Test("getCacheSize convenience MB properties are consistent with raw bytes")
    @MainActor
    func testCacheSizeConvenienceProperties() async throws {
        let cache = CacheManager.shared
        let info  = await cache.getCacheSize()

        let expectedMemoryMB = Double(info.memorySizeBytes) / (1024 * 1024)
        let expectedDiskMB   = Double(info.diskSizeBytes)   / (1024 * 1024)
        let expectedTotalMB  = Double(info.totalSizeBytes)  / (1024 * 1024)

        #expect(abs(info.memorySizeMB - expectedMemoryMB) < 0.001)
        #expect(abs(info.diskSizeMB   - expectedDiskMB)   < 0.001)
        #expect(abs(info.totalSizeMB  - expectedTotalMB)  < 0.001)
    }
}

// MARK: - CacheEntry Model Tests (value types — no shared state, safe to run in parallel)

@Suite("CacheEntry Model Tests")
struct CacheEntryModelTests {

    @Test("CacheEntry with no TTL is never expired")
    func testNilTTLNeverExpires() {
        let entry = CacheEntry(data: Data([1, 2, 3]), ttl: nil)
        #expect(entry.isExpired == false)
    }

    @Test("CacheEntry with large positive TTL is not expired immediately")
    func testLargeTTLNotExpired() {
        let entry = CacheEntry(data: Data([0xDE, 0xAD]), ttl: 9999)
        #expect(entry.isExpired == false)
    }

    @Test("CacheEntry with negative TTL is expired immediately")
    func testNegativeTTLIsExpired() {
        let entry = CacheEntry(data: Data([0xFF]), ttl: -1)
        #expect(entry.isExpired == true)
    }

    @Test("CacheEntry encodes and decodes via Codable")
    func testCacheEntryCodable() throws {
        let original = CacheEntry(data: Data("hello".utf8), ttl: 60)
        let encoded  = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(CacheEntry.self, from: encoded)

        #expect(decoded.data == original.data)
        #expect(decoded.ttl  == original.ttl)
    }
}

// MARK: - CacheStatistics Model Tests (value types — safe to run in parallel)

@Suite("CacheStatistics Model Tests")
struct CacheStatisticsModelTests {

    @Test("CacheStatistics has zero values by default")
    func testDefaultValues() {
        let stats = CacheStatistics()
        #expect(stats.hitRate == 0.0)
        #expect(stats.hits    == 0)
        #expect(stats.misses  == 0)
        #expect(stats.writes  == 0)
    }

    @Test("hitRate computes correctly after mixed hits and misses")
    func testHitRateComputation() {
        var stats = CacheStatistics()
        stats.recordCacheHit()
        stats.recordCacheHit()
        stats.recordCacheMiss()

        let expected = 2.0 / 3.0
        #expect(abs(stats.hitRate - expected) < 0.0001)
    }

    @Test("reset clears all counters to zero")
    func testReset() {
        var stats = CacheStatistics()
        stats.recordCacheHit()
        stats.recordCacheMiss()
        stats.recordCacheWrite()
        stats.recordMemoryPressureEvent()

        stats.reset()

        #expect(stats.hits                 == 0)
        #expect(stats.misses               == 0)
        #expect(stats.writes               == 0)
        #expect(stats.memoryPressureEvents == 0)
        #expect(stats.hitRate              == 0.0)
    }

    @Test("recordCacheWrite increments writes counter")
    func testRecordWrite() {
        var stats = CacheStatistics()
        stats.recordCacheWrite()
        stats.recordCacheWrite()
        #expect(stats.writes == 2)
    }

    @Test("recordMemoryPressureEvent increments memoryPressureEvents counter")
    func testRecordMemoryPressureEvent() {
        var stats = CacheStatistics()
        stats.recordMemoryPressureEvent()
        #expect(stats.memoryPressureEvents == 1)
    }

    @Test("hitRate is 0 when only writes have occurred (no reads)")
    func testHitRateZeroWithOnlyWrites() {
        var stats = CacheStatistics()
        stats.recordCacheWrite()
        stats.recordCacheWrite()
        // No hits or misses recorded — denominator is 0 → hitRate returns 0.
        #expect(stats.hitRate == 0.0)
    }
}

// MARK: - CacheSizeInfo Model Tests (value types — safe to run in parallel)

@Suite("CacheSizeInfo Model Tests")
struct CacheSizeInfoModelTests {

    @Test("CacheSizeInfo convenience MB properties compute correctly from bytes")
    func testMBConversions() {
        let info = CacheSizeInfo(
            memorySizeBytes: 10 * 1024 * 1024,
            diskSizeBytes:   20 * 1024 * 1024,
            totalSizeBytes:  30 * 1024 * 1024
        )

        #expect(abs(info.memorySizeMB - 10.0) < 0.001)
        #expect(abs(info.diskSizeMB   - 20.0) < 0.001)
        #expect(abs(info.totalSizeMB  - 30.0) < 0.001)
    }

    @Test("CacheSizeInfo with zero bytes yields zero MB values")
    func testZeroBytes() {
        let info = CacheSizeInfo(memorySizeBytes: 0, diskSizeBytes: 0, totalSizeBytes: 0)
        #expect(info.memorySizeMB == 0.0)
        #expect(info.diskSizeMB   == 0.0)
        #expect(info.totalSizeMB  == 0.0)
    }
}
