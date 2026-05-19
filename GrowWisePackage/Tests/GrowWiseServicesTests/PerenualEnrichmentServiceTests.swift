import Foundation
import GrowWiseModels
import Testing

// swiftlint:disable cyclomatic_complexity

// MARK: - PerenualEnrichmentResult Tests

@Suite("PerenualEnrichmentResult Tests")
struct PerenualEnrichmentResultTests {
    @Test("PerenualEnrichmentResult clamps confidence score to valid range")
    func testEnrichmentResultClampsConfidence() {
        // Test upper bound
        let result1 = PerenualEnrichmentResult(detail: mockDetail(), confidenceScore: 1.5)
        #expect(result1.confidenceScore == 1.0)

        // Test lower bound
        let result2 = PerenualEnrichmentResult(detail: mockDetail(), confidenceScore: -0.5)
        #expect(result2.confidenceScore == 0.0)

        // Test valid value
        let result3 = PerenualEnrichmentResult(detail: mockDetail(), confidenceScore: 0.75)
        #expect(result3.confidenceScore == 0.75)
    }

    @Test("PerenualEnrichmentResult stores detail correctly")
    func testEnrichmentResultStoresDetail() {
        let detail = mockDetail()
        let result = PerenualEnrichmentResult(detail: detail, confidenceScore: 0.8)
        #expect(result.detail.id == 123)
        #expect(result.detail.commonName == "Tomato")
    }
}

// MARK: - PerenualImageCache Tests

@Suite("PerenualImageCache Tests")
struct PerenualImageCacheTests {
    @Test("Cache initializes with correct default size")
    func testCacheInitializesWithDefaultSize() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 50)
        #expect(await cache.maxCacheSize == 50 * 1024 * 1024)
    }

    @Test("Cache stores and retrieves image data")
    func testCacheStoreAndRetrieve() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 10)
        let testData = "test image data".data(using: .utf8)!
        let testKey = "test_plant_123"

        // Store
        await cache.storeImage(testData, for: testKey)

        // Retrieve
        let retrieved = await cache.image(for: testKey)
        #expect(retrieved != nil)
        #expect(retrieved == testData)
    }

    @Test("Cache containsImage returns true for stored key")
    func testCacheContainsImage() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 10)
        let testData = "test data".data(using: .utf8)!
        let testKey = "test_key_456"

        #expect(await cache.containsImage(for: testKey) == false)

        await cache.storeImage(testData, for: testKey)

        #expect(await cache.containsImage(for: testKey) == true)
    }

    @Test("Cache clearAll removes all entries")
    func testCacheClearAll() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 10)

        // Add multiple entries
        for i in 0 ..< 3 {
            let data = "data\(i)".data(using: .utf8)!
            await cache.storeImage(data, for: "key_\(i)")
        }

        // Verify entries exist
        #expect(await cache.containsImage(for: "key_0") == true)

        // Clear
        await cache.clearAll()

        // Verify all removed
        #expect(await cache.containsImage(for: "key_0") == false)
        #expect(await cache.containsImage(for: "key_1") == false)
        #expect(await cache.containsImage(for: "key_2") == false)
    }

    @Test("Cache returns nil for non-existent key")
    func testCacheReturnsNilForMissingKey() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 10)
        let result = await cache.image(for: "non_existent_key")
        #expect(result == nil)
    }

    @Test("Cache currentSize reports accurate size")
    func testCacheCurrentSize() async {
        let cache = PerenualImageCache(maxCacheSizeMB: 10)

        let initialSize = await cache.currentSize
        #expect(initialSize == 0)

        let testData = "x".data(using: .utf8)!
        await cache.storeImage(testData, for: "size_test_key")

        let afterStore = await cache.currentSize
        #expect(afterStore > 0)
    }
}

// MARK: - Mock Helpers

private func mockDetail() -> PerenualSpeciesDetail {
    PerenualSpeciesDetail(
        id: 123,
        commonName: "Tomato",
        scientificName: ["Solanum lycopersicum"],
        otherName: nil,
        family: "Solanaceae",
        origin: ["South America"],
        type: "Vegetable",
        cycle: "Annual",
        watering: "average",
        wateringGeneralBenchmark: nil,
        sunlight: ["full sun"],
        pruningMonth: nil,
        hardiness: PerenualHardiness(min: "3", max: "11"),
        growthRate: "fast",
        careLevel: "Easy",
        maintenance: "moderate",
        droughtTolerant: false,
        saltTolerant: false,
        thorny: false,
        invasive: false,
        tropical: false,
        indoor: false,
        flowers: true,
        floweringSeason: "Summer",
        fruits: true,
        edibleFruit: true,
        leaf: true,
        edibleLeaf: false,
        medicinal: false,
        poisonousToHumans: false,
        poisonousToPets: true,
        description: "A popular garden vegetable",
        defaultImage: nil,
        dimensions: nil,
        soil: nil,
        pestSusceptibility: .empty,
        attracts: nil,
        propagation: nil
    )
}

// swiftlint:enable cyclomatic_complexity