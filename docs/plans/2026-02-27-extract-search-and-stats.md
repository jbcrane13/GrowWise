# Extract Search and Statistics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `searchPlants`, `filterPlants`, and all read-only analytics/count queries from `DataService.swift` into `PlantRepository` and a new `StatsRepository`.

**Architecture:** 
- `PlantRepository` will gain search and filtering logic since it's fundamentally plant querying.
- A new `StatsRepository` will handle raw database counts and aggregated metrics, injected into `DataService`.

**Tech Stack:** Swift, SwiftData, Swift Concurrency

---

### Task 1: Move Search and Filter to PlantRepository

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/Repositories/PlantRepository.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService.swift`

**Step 1: Move search and filter logic**
Copy the `searchPlants(query:limit:)` and `filterPlants(byType:difficulty:limit:)` methods from `DataService` to `PlantRepository`. Update references from `modelContext` to `context` and remove `cache` references (or inject caching strategy, but for now we can simplify or maintain caching inside DataService by wrapping the repository calls). Wait, the caching logic relies on `DataService`'s cache. Let's just pass `cache` into the repository or leave cache in DataService. Let's pass the cache to the repository.

Actually, it's cleaner to just move the `FetchDescriptor` creation to `PlantRepository` and let it fetch.

```swift
    // In PlantRepository.swift
    public func search(query: String, limit: Int = 20) throws -> [Plant] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return [] }
        let clampedLimit = max(1, min(limit, 50))
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.name.localizedStandardContains(trimmedQuery) ||
                (plant.scientificName != nil && plant.scientificName!.localizedStandardContains(trimmedQuery))
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = clampedLimit
        return try context.fetch(descriptor)
    }

    public func filter(byType type: PlantType? = nil, difficulty: DifficultyLevel? = nil, limit: Int = 50) throws -> [Plant] {
        let clampedLimit = max(1, min(limit, 100))
        var descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchLimit = clampedLimit
        
        if let type = type, let difficulty = difficulty {
            let typeRaw = type.rawValue
            let diffRaw = difficulty.rawValue
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.plantTypeRaw == typeRaw && plant.difficultyLevelRaw == diffRaw
            }
        } else if let type = type {
            let typeRaw = type.rawValue
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.plantTypeRaw == typeRaw
            }
        } else if let difficulty = difficulty {
            let diffRaw = difficulty.rawValue
            descriptor.predicate = #Predicate<Plant> { plant in
                plant.difficultyLevelRaw == diffRaw
            }
        }
        return try context.fetch(descriptor)
    }
```

**Step 2: Update DataService**
Update `DataService.searchPlants` and `filterPlants` to call `plants.search` and `plants.filter`, preserving the cache layer.

```swift
    public func searchPlants(query: String, limit: Int = 20) -> [Plant] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return [] }
        let cacheKey = "plants:search:\(trimmedQuery):limit:\(limit)"
        if let cached = cache.get(cacheKey, as: [Plant].self) { return cached }
        let result = (try? plants.search(query: query, limit: limit)) ?? []
        cache.set(cacheKey, value: result, policy: .short)
        return result
    }

    public func filterPlants(byType type: PlantType? = nil, difficulty: DifficultyLevel? = nil, limit: Int = 50) -> [Plant] {
        let typeKey = type?.rawValue ?? "all"
        let diffKey = difficulty?.rawValue ?? "all"
        let cacheKey = "plants:filter:\(typeKey):\(diffKey):limit:\(limit)"
        if let cached = cache.get(cacheKey, as: [Plant].self) { return cached }
        let result = (try? plants.filter(byType: type, difficulty: difficulty, limit: limit)) ?? []
        cache.set(cacheKey, value: result, policy: .medium)
        return result
    }
```

**Step 3: Run Tests**
Run: `cd GrowWisePackage && swift test --filter DataService`

**Step 4: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/
git commit -m "refactor: extract search and filter logic to PlantRepository"
```

### Task 2: Create StatsRepository

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/Repositories/StatsRepository.swift`

**Step 1: Write StatsRepository**

```swift
import SwiftData
import Foundation
import GrowWiseModels

@MainActor
public final class StatsRepository {
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    public func getPlantCount() -> Int {
        let descriptor = FetchDescriptor<Plant>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    public func getGardenCount() -> Int {
        let descriptor = FetchDescriptor<Garden>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    public func getReminderCount() -> Int {
        let descriptor = FetchDescriptor<PlantReminder>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    public func getJournalEntryCount() -> Int {
        let descriptor = FetchDescriptor<JournalEntry>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    public func getPlantDatabaseCount() -> Int {
        var descriptor = FetchDescriptor<Plant>()
        descriptor.predicate = #Predicate<Plant> { $0.isUserPlant == false || $0.isUserPlant == nil }
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
```

**Step 2: Add to DataService**

In `DataService.swift`, add the property:
```swift
    public var stats: StatsRepository {
        StatsRepository(context: mainContext)
    }
```

**Step 3: Update DataService count methods**
Refactor the methods in DataService to use the new `stats` repository, maintaining their caching.

```swift
    public func getPlantCount() -> Int {
        let cacheKey = "stats:count:plants"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        let count = stats.getPlantCount()
        cache.set(cacheKey, value: count, policy: .long)
        return count
    }
    
    public func getGardenCount() -> Int {
        let cacheKey = "stats:count:gardens"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        let count = stats.getGardenCount()
        cache.set(cacheKey, value: count, policy: .long)
        return count
    }
    
    public func getReminderCount() -> Int {
        let cacheKey = "stats:count:reminders"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        let count = stats.getReminderCount()
        cache.set(cacheKey, value: count, policy: .long)
        return count
    }
    
    public func getJournalEntryCount() -> Int {
        let cacheKey = "stats:count:journals"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        let count = stats.getJournalEntryCount()
        cache.set(cacheKey, value: count, policy: .long)
        return count
    }
    
    public func getPlantDatabaseCount() -> Int {
        let cacheKey = "stats:count:plantdatabase"
        if let count = cache.get(cacheKey, as: Int.self) { return count }
        let count = stats.getPlantDatabaseCount()
        cache.set(cacheKey, value: count, policy: .long)
        return count
    }
```

**Step 4: Update GardeningStats in DataService**

```swift
    public func getGardeningStats() -> GardeningStats {
        let cacheKey = "stats:gardening_summary"
        if let cached = cache.get(cacheKey, as: GardeningStats.self) {
            return cached
        }
        
        let totalPlants = getPlantCount()
        var healthyPlants = 0
        var needsAttention = 0
        var plantsToHarvest = 0
        
        // This still requires fetching plants to check states, we can optimize later
        let plants = (try? self.plants.fetchAll()) ?? []
        for plant in plants {
            if plant.healthStatus == .healthy || plant.healthStatus == .excellent { healthyPlants += 1 }
            if plant.healthStatus == .poor || plant.healthStatus == .dead { needsAttention += 1 }
            if plant.growthStage == .harvesting { plantsToHarvest += 1 }
        }
        
        let activeReminders = getReminderCount()
        
        let stats = GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: healthyPlants,
            needsAttention: needsAttention,
            plantsToHarvest: plantsToHarvest,
            activeReminders: activeReminders
        )
        
        cache.set(cacheKey, value: stats, policy: .medium)
        return stats
    }
```

**Step 5: Run Tests**
Run: `cd GrowWisePackage && swift test --filter DataService`

**Step 6: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/
git commit -m "feat: extract Statistics queries to StatsRepository"
```

