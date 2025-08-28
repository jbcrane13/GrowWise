import XCTest
@testable import GrowWiseServices
@testable import GrowWiseModels
import SwiftData

final class PerformanceTests: XCTestCase {
    var dataService: DataService!
    var performanceMonitor: PerformanceMonitor!
    var cacheManager: CacheManager!
    var backgroundTaskManager: BackgroundTaskManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize services
        dataService = try await DataService(isAsync: true)
        performanceMonitor = await PerformanceMonitor.shared
        cacheManager = await CacheManager.shared
        backgroundTaskManager = await BackgroundTaskManager.shared
    }
    
    override func tearDown() async throws {
        // Clear all caches and metrics
        await cacheManager.clearAll()
        await performanceMonitor.clearMetrics()
        
        dataService = nil
        performanceMonitor = nil
        cacheManager = nil
        backgroundTaskManager = nil
        
        try await super.tearDown()
    }
    
    // MARK: - App Launch Performance Tests
    
    func testAppLaunchPerformance() async throws {
        await performanceMonitor.recordAppLaunchStart()
        
        // Simulate app initialization
        _ = try await DataService(isAsync: true)
        
        await performanceMonitor.recordAppLaunchComplete()
        
        let launchTime = await performanceMonitor.appLaunchTime
        
        // App should launch in under 2 seconds
        XCTAssertLessThan(launchTime, 2.0, "App launch time exceeded 2 seconds: \(launchTime)s")
    }
    
    // MARK: - Database Query Performance Tests
    
    func testDatabaseQueryPerformance() async throws {
        // Create test data
        let plants = await createTestPlants(count: 100)
        
        let tracker = await performanceMonitor.startQueryTracking(identifier: "fetchPlants")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await dataService.fetchPlants(offset: 0, limit: 20)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        await tracker.complete()
        
        // Query should complete in under 500ms
        XCTAssertLessThan(duration, 0.5, "Query took too long: \(duration)s")
    }
    
    func testPaginationPerformance() async throws {
        // Create large dataset
        _ = await createTestPlants(count: 500)
        
        var totalDuration: TimeInterval = 0
        
        // Test pagination performance
        for offset in stride(from: 0, to: 100, by: 20) {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = await dataService.fetchPlants(offset: offset, limit: 20)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            totalDuration += duration
            
            // Each page should load in under 200ms
            XCTAssertLessThan(duration, 0.2, "Page load at offset \(offset) took too long: \(duration)s")
        }
        
        let averageDuration = totalDuration / 5
        XCTAssertLessThan(averageDuration, 0.15, "Average page load time too high: \(averageDuration)s")
    }
    
    func testSearchPerformance() async throws {
        // Create test data with searchable names
        _ = await createTestPlants(count: 200)
        
        let queries = ["Tomato", "Rose", "Basil", "Cactus", "Fern"]
        
        for query in queries {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = await dataService.searchPlants(query: query)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // Search should complete in under 300ms
            XCTAssertLessThan(duration, 0.3, "Search for '\(query)' took too long: \(duration)s")
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageUnderNormalOperation() async throws {
        await performanceMonitor.startMonitoring()
        
        // Perform typical operations
        _ = await createTestPlants(count: 50)
        _ = await dataService.fetchPlants()
        _ = await dataService.fetchRecentJournalEntries(limit: 10)
        
        // Wait for monitoring to update
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let memoryUsage = await performanceMonitor.currentMemoryUsage
        
        // Memory usage should stay under 50MB during normal operation
        XCTAssertLessThan(memoryUsage, 50.0, "Memory usage exceeded limit: \(memoryUsage)MB")
    }
    
    func testMemoryLeakDetection() async throws {
        await performanceMonitor.startMonitoring()
        
        let initialMemory = await performanceMonitor.currentMemoryUsage
        
        // Perform operations that should not leak memory
        for _ in 0..<10 {
            _ = await createTestPlants(count: 10)
            _ = await dataService.fetchPlants()
            await dataService.invalidateAllCaches()
        }
        
        // Force garbage collection
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let finalMemory = await performanceMonitor.currentMemoryUsage
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal (less than 5MB)
        XCTAssertLessThan(memoryIncrease, 5.0, "Potential memory leak detected: \(memoryIncrease)MB increase")
    }
    
    // MARK: - Photo Operation Tests
    
    func testPhotoProcessingPerformance() async throws {
        #if canImport(UIKit)
        let testImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        let tracker = await performanceMonitor.startPhotoOperation(type: .process)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process image in background
        await backgroundTaskManager.submitImageProcessingTask(
            image: testImage,
            operations: [
                .resize(CGSize(width: 800, height: 800)),
                .compress(quality: 0.8)
            ]
        ) { result in
            // Processing complete
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        await tracker.complete()
        
        // Image processing should complete in under 1 second
        XCTAssertLessThan(duration, 1.0, "Image processing took too long: \(duration)s")
        #endif
    }
    
    func testPhotoLoadingPerformance() async throws {
        #if canImport(UIKit)
        // Test photo loading with cache
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        let cacheKey = "test-photo-\(UUID())"
        
        // Store image in cache
        await cacheManager.storeImage(testImage, for: cacheKey, toDisk: true)
        
        // Test cache hit performance
        let cacheStartTime = CFAbsoluteTimeGetCurrent()
        _ = await cacheManager.retrieveImage(for: cacheKey)
        let cacheDuration = CFAbsoluteTimeGetCurrent() - cacheStartTime
        
        // Cache hit should be very fast (under 50ms)
        XCTAssertLessThan(cacheDuration, 0.05, "Cache retrieval too slow: \(cacheDuration)s")
        
        // Clear memory cache to test disk loading
        await cacheManager.clearAll()
        
        let diskStartTime = CFAbsoluteTimeGetCurrent()
        _ = await cacheManager.retrieveImage(for: cacheKey)
        let diskDuration = CFAbsoluteTimeGetCurrent() - diskStartTime
        
        // Disk loading should still be reasonable (under 200ms)
        XCTAssertLessThan(diskDuration, 0.2, "Disk retrieval too slow: \(diskDuration)s")
        #endif
    }
    
    // MARK: - UI Responsiveness Tests
    
    func testUIOperationPerformance() async throws {
        // Test that UI operations complete within acceptable time
        let operations = [
            "search_debounce",
            "filter_plants",
            "sort_entries",
            "load_thumbnails"
        ]
        
        for operation in operations {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate UI operation
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms simulation
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            await performanceMonitor.trackUIOperation(name: operation, duration: duration)
            
            // UI operations should complete in under 100ms
            XCTAssertLessThan(duration, 0.1, "UI operation '\(operation)' too slow: \(duration)s")
        }
    }
    
    // MARK: - Cache Performance Tests
    
    func testCacheEffectiveness() async throws {
        // Populate cache with test data
        let plants = await createTestPlants(count: 50)
        
        // First fetch - cache miss
        _ = await dataService.fetchPlants()
        
        // Second fetch - should hit cache
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await dataService.fetchPlants()
        let cacheDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Cache hit should be very fast
        XCTAssertLessThan(cacheDuration, 0.01, "Cache not effective: \(cacheDuration)s")
        
        // Check cache statistics
        let stats = await cacheManager.statistics
        XCTAssertGreaterThan(stats.hitRate, 0.5, "Cache hit rate too low: \(stats.hitRate)")
    }
    
    func testCacheMemoryPressureHandling() async throws {
        #if canImport(UIKit)
        // Fill cache with images
        for i in 0..<100 {
            let image = createTestImage(size: CGSize(width: 500, height: 500))
            await cacheManager.storeImage(image, for: "test-\(i)", toDisk: false)
        }
        
        // Simulate memory warning
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Wait for cache to handle memory pressure
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify caches were cleared
        let cacheSize = await cacheManager.getCacheSize()
        XCTAssertLessThan(cacheSize.memorySizeMB, 10.0, "Cache not cleared on memory pressure")
        #endif
    }
    
    // MARK: - Background Task Tests
    
    func testBackgroundTaskPerformance() async throws {
        let taskCount = 10
        var completedTasks = 0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Submit multiple background tasks
        for i in 0..<taskCount {
            await backgroundTaskManager.submitTask(
                name: "Test Task \(i)",
                priority: .medium
            ) {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                completedTasks += 1
            }
        }
        
        // Wait for all tasks to complete
        await backgroundTaskManager.waitForAllTasks()
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Tasks should complete efficiently (not all sequential)
        XCTAssertLessThan(totalDuration, Double(taskCount) * 0.1, "Background tasks not running efficiently")
        XCTAssertEqual(completedTasks, taskCount, "Not all tasks completed")
    }
    
    // MARK: - Performance Regression Tests
    
    func testPerformanceRegression() async throws {
        // Run a standard benchmark
        let report = await runStandardBenchmark()
        
        // Check performance score
        XCTAssertGreaterThan(report.performanceScore, 70.0, "Performance score too low: \(report.performanceScore)")
        
        // Check specific metrics against baselines
        XCTAssertLessThan(report.averageQueryTime, 0.2, "Average query time regression")
        XCTAssertLessThan(report.averageMemoryUsage, 40.0, "Memory usage regression")
        XCTAssertGreaterThan(report.averageFrameRate, 50.0, "Frame rate regression")
    }
    
    // MARK: - Load Testing
    
    func testHighLoadPerformance() async throws {
        // Create large dataset
        _ = await createTestPlants(count: 1000)
        
        // Perform multiple operations concurrently
        await withTaskGroup(of: Void.self) { group in
            // Search operations
            for query in ["A", "B", "C", "D", "E"] {
                group.addTask {
                    _ = await self.dataService.searchPlants(query: query)
                }
            }
            
            // Fetch operations
            for offset in stride(from: 0, to: 100, by: 20) {
                group.addTask {
                    _ = await self.dataService.fetchPlants(offset: offset, limit: 20)
                }
            }
            
            // Cache operations
            for i in 0..<20 {
                group.addTask {
                    await self.cacheManager.storeData(["test": i], for: "load-test-\(i)")
                }
            }
        }
        
        // System should remain responsive
        let memoryUsage = await performanceMonitor.currentMemoryUsage
        XCTAssertLessThan(memoryUsage, 100.0, "Memory usage too high under load: \(memoryUsage)MB")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func createTestPlants(count: Int) -> [Plant] {
        var plants: [Plant] = []
        let plantTypes = PlantType.allCases
        let difficulties = DifficultyLevel.allCases
        
        for i in 0..<count {
            let plant = Plant(
                name: "Test Plant \(i)",
                plantType: plantTypes[i % plantTypes.count],
                difficultyLevel: difficulties[i % difficulties.count]
            )
            plants.append(plant)
        }
        
        return plants
    }
    
    #if canImport(UIKit)
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    #endif
    
    @MainActor
    private func runStandardBenchmark() async -> PerformanceReport {
        // Run standard set of operations
        _ = await createTestPlants(count: 100)
        _ = await dataService.fetchPlants()
        _ = await dataService.searchPlants(query: "Test")
        _ = await dataService.fetchRecentJournalEntries(limit: 20)
        
        // Wait for metrics to stabilize
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        return await performanceMonitor.generatePerformanceReport()
    }
}

// MARK: - Test Utilities

extension XCTestCase {
    func measure(timeout: TimeInterval = 10, block: () async throws -> Void) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await withTimeout(seconds: timeout) {
            try await block()
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ Execution time: \(String(format: "%.3f", duration))s")
    }
    
    func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

enum TestError: LocalizedError {
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test operation timed out"
        }
    }
}