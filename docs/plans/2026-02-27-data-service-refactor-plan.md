# DataService Domain Repository Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Break up the 1,300-line `DataService` God-object into domain-specific repositories (`PlantRepository`, `GardenRepository`, etc.) while keeping CloudKit sync intact.

**Architecture:** `DataService` will remain the `ModelContainer` owner and handle the complex 6-level fallback initialization. It will instantiate and vend domain repositories (e.g., `dataService.plants`) by passing them its `ModelContext`.

**Tech Stack:** Swift 6, SwiftData, Swift Testing

---

### Task 1: Create Domain Error Types

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/Models/RepositoryErrors.swift`

**Step 1: Write the minimal implementation**

```swift
import Foundation

public enum PlantError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notFound: return "Plant not found in the database."
        case .saveFailed(let err): return "Failed to save plant: \(err.localizedDescription)"
        }
    }
}

public enum GardenError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum ReminderError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum JournalError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum UserError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}
```

**Step 2: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/Models/RepositoryErrors.swift
git commit -m "feat: add domain-specific repository errors"
```

---

### Task 2: Create PlantRepository

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/Repositories/PlantRepository.swift`
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/PlantRepositoryTests.swift`

**Step 1: Write the failing test**
```swift
import Testing
import SwiftData
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("PlantRepository Tests")
@MainActor
struct PlantRepositoryTests {
    @Test("Add and fetch plant")
    func testAddAndFetchPlant() async throws {
        let container = try ModelContainer(for: Plant.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repo = PlantRepository(context: container.mainContext)
        
        let plant = Plant(name: "Test Fern")
        try repo.add(plant)
        
        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Fern")
    }
}
```

**Step 2: Run test to verify it fails**
Run: `cd GrowWisePackage && swift test --filter PlantRepositoryTests`
Expected: FAIL (PlantRepository not found)

**Step 3: Write minimal implementation**
```swift
import SwiftData
import Foundation
import GrowWiseModels

@MainActor
public final class PlantRepository {
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    public func fetchAll() throws -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }
    
    public func add(_ plant: Plant) throws {
        context.insert(plant)
        do {
            try context.save()
        } catch {
            throw PlantError.saveFailed(error)
        }
    }
    
    public func delete(_ plant: Plant) throws {
        context.delete(plant)
        do {
            try context.save()
        } catch {
            throw PlantError.saveFailed(error)
        }
    }
}
```

**Step 4: Run test to verify it passes**
Run: `cd GrowWisePackage && swift test --filter PlantRepositoryTests`
Expected: PASS

**Step 5: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/Repositories/PlantRepository.swift GrowWisePackage/Tests/GrowWiseServicesTests/PlantRepositoryTests.swift
git commit -m "feat: implement PlantRepository and tests"
```

---

### Task 3: Create GardenRepository

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/Repositories/GardenRepository.swift`

**Step 1: Write implementation**
```swift
import SwiftData
import Foundation
import GrowWiseModels

@MainActor
public final class GardenRepository {
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    public func fetchAll() throws -> [Garden] {
        let descriptor = FetchDescriptor<Garden>()
        return try context.fetch(descriptor)
    }
    
    public func add(_ garden: Garden) throws {
        context.insert(garden)
        try context.save()
    }
    
    public func delete(_ garden: Garden) throws {
        context.delete(garden)
        try context.save()
    }
}
```

**Step 2: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/Repositories/GardenRepository.swift
git commit -m "feat: implement GardenRepository"
```

---

### Task 4: Integrate Repositories into DataService

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService.swift`

**Step 1: Update DataService to vend repositories**
Add the repository properties to `DataService` and initialize them using the `mainContext`.

```swift
// In DataService.swift
@MainActor
@Observable
public final class DataService {
    public let container: ModelContainer
    public let mainContext: ModelContext
    
    // Domain Repositories
    public let plants: PlantRepository
    public let gardens: GardenRepository
    
    // ... inside initialization after setting context:
    self.plants = PlantRepository(context: self.mainContext)
    self.gardens = GardenRepository(context: self.mainContext)
}
```

**Step 2: Commit**
```bash
git add GrowWisePackage/Sources/GrowWiseServices/DataService.swift
git commit -m "refactor: integrate domain repositories into DataService"
```

---

### Task 5: Migrate Call Sites (Plants & Gardens)

**Files:**
- Modify: Various Views and Services calling `dataService.addPlant()`, `dataService.fetchPlants()`, etc.

**Step 1: Replace legacy calls with repository calls**
Find and replace all instances:
- `dataService.addPlant(p)` -> `try? dataService.plants.add(p)`
- `dataService.fetchPlants()` -> `try? dataService.plants.fetchAll()`

**Step 2: Remove legacy methods from DataService**
Delete `addPlant`, `fetchPlants`, `deletePlant`, `addGarden`, etc. from `DataService.swift`.

**Step 3: Run UI & Unit Tests**
Run: `xcodebuild test -workspace GrowWise.xcworkspace -scheme GrowWise -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
Expected: PASS

**Step 4: Commit**
```bash
git commit -am "refactor: migrate call sites to use new domain repositories"
```

---

### Task 6: Repeat for Reminders, Journals, Users (Iterative)

Follow the same pattern for `ReminderRepository`, `JournalRepository`, and `UserRepository`.
Extract methods from `DataService`, create repository class, update `DataService` to vend it, migrate call sites, run tests, commit.

