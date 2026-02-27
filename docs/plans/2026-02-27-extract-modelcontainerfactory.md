# Extract ModelContainerFactory Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the massive initialization, async factory, and 6-level emergency fallback logic from `DataService.swift` into a dedicated `ModelContainerFactory`.

**Architecture:** We will create a new struct `ModelContainerFactory` that is strictly responsible for vending a valid `ModelContainer`. It will handle all the schema definition, CloudKit sync container setups, and the emergency fallback waterfalls. `DataService` will just call `ModelContainerFactory.make(...)` to get a container.

**Tech Stack:** Swift, SwiftData, Swift Concurrency, XCTest

---

### Task 1: Create ModelContainerFactory

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`

**Step 1: Write minimal implementation**

```swift
import SwiftData
import Foundation
import os.log
import GrowWiseModels
import CloudKit

@MainActor
public struct ModelContainerFactory {
    private static let logger = Logger(subsystem: "com.growwise.dataservice", category: "ModelContainerFactory")
    
    /// The single source of truth for the app's database schema
    public static let sharedSchema = Schema([
        Plant.self,
        Garden.self,
        User.self,
        PlantReminder.self,
        JournalEntry.self,
        SoilLog.self
    ])
    
    /// Factory method for normal initialization
    public static func make(isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting")) throws -> ModelContainer {
        let modelConfiguration: ModelConfiguration
        if isUITesting {
            modelConfiguration = ModelConfiguration(
                schema: sharedSchema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: sharedSchema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )
        }
        
        return try ModelContainer(for: sharedSchema, configurations: [modelConfiguration])
    }
    
    /// Factory method for testing (in-memory)
    public static func makeForTesting() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: sharedSchema, configurations: config)
    }
}
```

**Step 2: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift
git commit -m "feat: create base ModelContainerFactory with shared schema"
```

### Task 2: Port Emergency Fallback to Factory

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`

**Step 1: Add the emergency fallback method**

Copy the entire 6-level fallback logic from `DataService.init(emergencyStub:)` to `ModelContainerFactory.makeEmergencyFallback()`.

```swift
    public static func makeEmergencyFallback() -> ModelContainer {
        logger.critical("[Emergency] Creating emergency stub container")
        
        // Level 1: In-memory User schema
        do {
            let schema = Schema([User.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            logger.info("[Emergency] Level 1 fallback successful (in-memory User schema)")
            return container
        } catch {
            logger.critical("EMERGENCY: Cannot create even minimal ModelContainer: \(error.localizedDescription)")
            
            // Level 2: Default container
            do {
                let schema = Schema([User.self])
                let container = try ModelContainer(for: schema)
                logger.info("[Emergency] Level 2 fallback successful (default container)")
                return container
            } catch {
                logger.critical("CRITICAL SYSTEM FAILURE: Cannot initialize any ModelContainer: \(error.localizedDescription)")
                
                // Level 3: Temp-file-backed store
                do {
                    let fallbackSchema = Schema([User.self])
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("GrowWise-Emergency-\(UUID().uuidString).sqlite")
                    let tempConfig = ModelConfiguration(schema: fallbackSchema, url: tempURL)
                    if let tempContainer = try? ModelContainer(for: fallbackSchema, configurations: [tempConfig]) {
                        logger.warning("[Emergency] Level 3 fallback successful (temp file)")
                        return tempContainer
                    }
                }
                
                // Level 4: Read-only in-memory container
                do {
                    let fallbackSchema = Schema([User.self])
                    let memConfig = ModelConfiguration(
                        schema: fallbackSchema,
                        isStoredInMemoryOnly: true,
                        allowsSave: false
                    )
                    if let memContainer = try? ModelContainer(for: fallbackSchema, configurations: [memConfig]) {
                        logger.warning("[Emergency] Level 4 fallback successful (read-only in-memory)")
                        return memContainer
                    }
                }
                
                // Level 5: Default container
                do {
                    let fallbackSchema = Schema([User.self])
                    if let defaultContainer = try? ModelContainer(for: fallbackSchema) {
                        logger.warning("[Emergency] Level 5 fallback successful (default)")
                        return defaultContainer
                    }
                }
                
                // Level 6: Empty schema degraded mode
                logger.critical("[Emergency] All fallback attempts failed - attempting staged recovery")
                do {
                    let emptySchema = Schema([])
                    let emptyConfig = ModelConfiguration(
                        schema: emptySchema,
                        isStoredInMemoryOnly: true,
                        allowsSave: false
                    )
                    if let emergencyContainer = try? ModelContainer(for: emptySchema, configurations: [emptyConfig]) {
                        logger.warning("[Emergency] Level 6 fallback successful (empty schema - degraded mode)")
                        logger.critical("[Emergency] App is in severely degraded state - data operations will fail gracefully")
                        return emergencyContainer
                    }
                }
                
                // Absolute failure
                logger.critical("[Emergency] Critical system failure - all recovery attempts exhausted")
                fatalError("CRITICAL: Unrecoverable ModelContainer initialization failure. Please reinstall the application.")
            }
        }
    }
```

**Step 2: Check build**

Run: `cd GrowWisePackage && swift build --filter GrowWiseServices`

**Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift
git commit -m "feat: port emergency fallback logic to ModelContainerFactory"
```

### Task 3: Refactor DataService Initializers

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService.swift`

**Step 1: Simplify public init**

Find `public init(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) throws`. Replace the 35 lines of SwiftData setup with:

```swift
    public init(performanceMonitor: PerformanceMonitor = PerformanceMonitor()) throws {
        self.performanceMonitor = performanceMonitor
        
        let initStartTime = CFAbsoluteTimeGetCurrent()
        let memoryBefore = performanceMonitor.currentMemoryUsage

        logger.info("[DataService] Memory before init: \(memoryBefore, privacy: .private)MB")
        logger.info("[DataService] Pressure: \(String(describing: performanceMonitor.memoryPressureLevel), privacy: .private)")

        self.modelContainer = try ModelContainerFactory.make()
        self.cloudContainer = ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : CKContainer.default()
        
        // ... rest of init remains (memory check, assignment of repositories)
```

**Step 2: Simplify emergencyStub init**

Find `private init(emergencyStub: Bool, performanceMonitor: PerformanceMonitor)`. Replace the MASSIVE 100-line `do/catch` block with:

```swift
    /// Emergency stub initializer
    private init(emergencyStub: Bool, performanceMonitor: PerformanceMonitor) {
        self.performanceMonitor = performanceMonitor
        self.cloudContainer = ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : CKContainer.default()
        self.modelContainer = ModelContainerFactory.makeEmergencyFallback()
    }
```

**Step 3: Simplify makeForTesting**

Find `public static func makeForTesting() -> DataService`. Update it to use the new factory:

```swift
    public static func makeForTesting() -> DataService {
        do {
            let container = try ModelContainerFactory.makeForTesting()
            return DataService(testing: container, cloudContainer: nil, performanceMonitor: PerformanceMonitor())
        } catch {
            return __allocating_init_emergency_stub(performanceMonitor: PerformanceMonitor())
        }
    }
```

**Step 4: Cleanup Async Factories**

Make sure `createAsync()`, `makeAsync()`, `createFallback()`, etc., are updated to use `ModelContainerFactory.make()` or removed if they are redundant. (If they just duplicate the schema, replace the schema definition with `ModelContainerFactory.make()`).

**Step 5: Run tests**

Run: `cd GrowWisePackage && swift test --filter DataService`
Expected: Tests pass.

**Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/DataService.swift
git commit -m "refactor: replace inline DataService container logic with ModelContainerFactory"
```
