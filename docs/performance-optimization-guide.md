# Performance Optimization Guide

## Overview

This guide provides comprehensive guidelines for maintaining optimal performance in the GrowWise iOS app. Following these best practices ensures a smooth user experience with fast app launch, responsive UI, and efficient resource usage.

## Performance Goals

- **App Launch Time**: < 2 seconds
- **Memory Usage**: < 50MB during normal operation
- **Frame Rate**: Consistent 60 FPS
- **Query Response**: < 500ms for database operations
- **Photo Operations**: < 1 second for processing
- **UI Response**: < 100ms for user interactions

## Memory Management Guidelines

### SwiftUI Best Practices

1. **Use @StateObject wisely**
```swift
// ❌ Bad: Creates new instance on every view update
struct MyView: View {
    var dataService = DataService()
}

// ✅ Good: Maintains single instance
struct MyView: View {
    @StateObject private var dataService = DataService()
}
```

2. **Lazy Loading**
```swift
// ✅ Load data only when needed
LazyVStack {
    ForEach(items, id: \.id) { item in
        ItemView(item: item)
    }
}
```

3. **Image Memory Management**
```swift
// ✅ Use cache-aware image loading
func loadImage(from url: URL) async -> UIImage? {
    // Check cache first
    if let cached = imageCache.object(forKey: url.absoluteString as NSString) {
        return cached
    }
    
    // Load with memory-efficient options
    let image = await loadFromDisk(url: url)
    
    // Cache with size limit
    if let image = image {
        imageCache.setObject(image, forKey: url.absoluteString as NSString)
    }
    
    return image
}
```

### SwiftData Optimization

1. **Use Fetch Limits**
```swift
// ❌ Bad: Loads entire dataset
let descriptor = FetchDescriptor<Plant>()

// ✅ Good: Paginated loading
var descriptor = FetchDescriptor<Plant>()
descriptor.fetchLimit = 20
descriptor.fetchOffset = currentPage * 20
```

2. **Batch Operations**
```swift
// ✅ Batch relationship loading
func batchLoadPlantRelationships(plantIds: [UUID]) async -> [Plant] {
    // Single query instead of N+1
    let predicate = #Predicate<Plant> { plant in
        plantIds.contains(plant.id)
    }
    return await fetch(with: predicate)
}
```

3. **Cache Query Results**
```swift
// ✅ Cache frequently accessed data
func fetchPlants() async -> [Plant] {
    let cacheKey = "all_plants"
    
    if let cached = cache.get(cacheKey) {
        return cached
    }
    
    let plants = await dataService.fetchPlants()
    cache.set(cacheKey, value: plants, ttl: 300) // 5 minutes
    
    return plants
}
```

## Database Optimization

### Query Optimization

1. **Use Predicates Efficiently**
```swift
// ❌ Bad: Complex nested predicates
let predicate = #Predicate<Plant> { plant in
    (plant.type == .vegetable && plant.difficulty == .easy) ||
    (plant.type == .herb && plant.difficulty == .medium) ||
    // ... many more conditions
}

// ✅ Good: Simplified predicates with indexing
let predicate = #Predicate<Plant> { plant in
    allowedTypes.contains(plant.type) &&
    allowedDifficulties.contains(plant.difficulty)
}
```

2. **Optimize Sort Descriptors**
```swift
// ✅ Sort by indexed fields
let descriptor = FetchDescriptor<Plant>(
    sortBy: [SortDescriptor(\.name)] // Indexed field
)
```

3. **Prefetch Relationships**
```swift
// ✅ Eagerly load relationships when needed
let descriptor = FetchDescriptor<Plant>()
descriptor.relationshipKeyPathsForPrefetching = [\.reminders, \.journalEntries]
```

## Image Handling Best Practices

### Efficient Photo Processing

1. **Background Processing**
```swift
// ✅ Process images off main thread
func processImage(_ image: UIImage) async -> UIImage? {
    await Task.detached(priority: .userInitiated) {
        // Resize, compress, apply filters
        let processed = resizeImage(image, maxSize: 2048)
        return processed
    }.value
}
```

2. **Progressive Loading**
```swift
// ✅ Load thumbnails first, full images on demand
func loadPhotoGallery(for plant: Plant) async {
    // Load thumbnails immediately
    let thumbnails = await loadThumbnails(for: plant)
    displayThumbnails(thumbnails)
    
    // Load full images as needed
    for photo in selectedPhotos {
        let fullImage = await loadFullImage(photo)
        updateDisplay(with: fullImage)
    }
}
```

3. **Memory-Aware Caching**
```swift
// ✅ Configure cache with memory limits
imageCache.countLimit = 30
imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

// Clear on memory pressure
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification
) { _ in
    imageCache.removeAllObjects()
}
```

## UI Performance Guidelines

### SwiftUI Performance

1. **Optimize View Updates**
```swift
// ❌ Bad: Causes unnecessary redraws
struct PlantView: View {
    @ObservedObject var plant: Plant // Updates entire view
}

// ✅ Good: Targeted updates
struct PlantView: View {
    let plant: Plant // Immutable reference
    @State private var isEditing = false // Local state only
}
```

2. **Use Stable IDs**
```swift
// ✅ Stable IDs prevent view recreation
ForEach(plants, id: \.id) { plant in
    PlantRow(plant: plant)
}
```

3. **Defer Heavy Computations**
```swift
// ✅ Calculate expensive values once
struct StatsView: View {
    @State private var statistics: Statistics?
    
    var body: some View {
        Group {
            if let stats = statistics {
                StatsDisplay(stats: stats)
            } else {
                ProgressView()
                    .task {
                        statistics = await calculateStatistics()
                    }
            }
        }
    }
}
```

### Search Optimization

1. **Implement Debouncing**
```swift
// ✅ Prevent excessive search operations
@State private var searchTask: Task<Void, Never>?

func onSearchTextChanged(_ text: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        if !Task.isCancelled {
            await performSearch(text)
        }
    }
}
```

2. **Cache Search Results**
```swift
// ✅ Cache recent searches
private var searchCache = LRUCache<String, [Plant]>(maxSize: 20)

func search(query: String) async -> [Plant] {
    if let cached = searchCache.get(query) {
        return cached
    }
    
    let results = await dataService.searchPlants(query: query)
    searchCache.set(query, value: results)
    return results
}
```

## Background Processing Patterns

### Task Management

1. **Priority-Based Execution**
```swift
// ✅ Use appropriate task priorities
Task(priority: .userInitiated) {
    // User-facing operations
}

Task(priority: .background) {
    // Non-urgent operations
}
```

2. **Resource-Aware Processing**
```swift
// ✅ Adjust based on system resources
func processInBackground() async {
    let resources = await getSystemResources()
    
    if resources.memoryPressure == .critical {
        // Defer or cancel non-essential tasks
        return
    }
    
    if resources.cpuUsage > 0.8 {
        // Reduce concurrency
        await processSequentially()
    } else {
        // Process in parallel
        await processInParallel()
    }
}
```

## Performance Monitoring

### Using PerformanceMonitor

```swift
// Track app launch
performanceMonitor.recordAppLaunchStart()
// ... initialization code ...
performanceMonitor.recordAppLaunchComplete()

// Track queries
let tracker = performanceMonitor.startQueryTracking(identifier: "fetchPlants")
let plants = await dataService.fetchPlants()
tracker.setResultCount(plants.count)
tracker.complete()

// Track photo operations
let photoTracker = performanceMonitor.startPhotoOperation(type: .process)
let processed = await processImage(image)
photoTracker.complete()
```

### Performance Budgets

Monitor and enforce performance budgets:

```swift
struct PerformanceBudgets {
    static let appLaunchTime: TimeInterval = 2.0
    static let queryTime: TimeInterval = 0.5
    static let memoryLimit: Double = 50.0 // MB
    static let minimumFrameRate: Double = 50.0
}
```

## Troubleshooting Guide

### Common Performance Issues

1. **Slow App Launch**
   - Check for synchronous initialization in MainAppView
   - Defer non-critical setup
   - Use async initialization for DataService

2. **High Memory Usage**
   - Review image caching strategy
   - Check for retained view models
   - Verify SwiftData fetch limits

3. **UI Lag**
   - Check for main thread blocking
   - Review ForEach implementations
   - Verify search debouncing

4. **Slow Queries**
   - Add appropriate indexes
   - Use fetch limits and pagination
   - Cache frequent queries

### Debugging Tools

1. **Instruments**
   - Time Profiler: Identify slow methods
   - Allocations: Track memory usage
   - Core Data: Monitor database operations

2. **Debug Gauges**
   - Monitor CPU, Memory, Disk, Network in Xcode

3. **Performance Tests**
   - Run PerformanceTests regularly
   - Monitor for regressions

## Performance Testing

### Writing Performance Tests

```swift
func testQueryPerformance() async throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    _ = await dataService.fetchPlants()
    
    let duration = CFAbsoluteTimeGetCurrent() - startTime
    
    XCTAssertLessThan(duration, 0.5, "Query too slow: \(duration)s")
}
```

### Continuous Monitoring

1. Run performance tests in CI/CD
2. Set up alerts for performance regressions
3. Track metrics over time

## Optimization Checklist

Before each release, verify:

- [ ] App launches in < 2 seconds
- [ ] Memory usage stays under 50MB
- [ ] All queries complete in < 500ms
- [ ] Photo operations complete in < 1 second
- [ ] UI maintains 60 FPS
- [ ] Search is debounced (300ms)
- [ ] Pagination is implemented for large datasets
- [ ] Caches are configured with size limits
- [ ] Background tasks use appropriate priorities
- [ ] Memory warnings are handled
- [ ] Performance tests pass
- [ ] No memory leaks detected

## Best Practices Summary

1. **Always use pagination** for large datasets
2. **Cache aggressively** but with limits
3. **Process images** in background
4. **Debounce user input** (300ms minimum)
5. **Monitor performance** continuously
6. **Test with large datasets** regularly
7. **Handle memory pressure** gracefully
8. **Use async/await** for I/O operations
9. **Batch database operations** when possible
10. **Profile regularly** with Instruments

## References

- [Apple Performance Best Practices](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [SwiftUI Performance Tips](https://developer.apple.com/documentation/swiftui/view-performance)
- [SwiftData Optimization](https://developer.apple.com/documentation/swiftdata)
- [Memory Management Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/)