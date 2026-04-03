# Seed Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a seed inventory system that lets users catalog owned seeds, scan packets via OCR, and get smart planting recommendations per garden bed.

**Architecture:** New `Seed` SwiftData model linked to Garden (inventory) and GardenBed (assignment). `SeedRepository` for CRUD, `SeedInventoryService` for smart matching, `SeedScannerService` for Vision OCR. Views follow existing MV pattern — views consume services via `@Environment`.

**Tech Stack:** SwiftData, SwiftUI, Vision framework, Swift Testing

**Spec:** `docs/superpowers/specs/2026-04-03-seed-inventory-design.md`

---

## Task 1: Seed Model and Error Type (GH-147, part 1)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseModels/Seed.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/Models/RepositoryErrors.swift`

- [ ] **Step 1: Create the Seed model**

Create `GrowWisePackage/Sources/GrowWiseModels/Seed.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class Seed {
    public var id: UUID? = UUID()
    public var varietyName: String?
    public var brand: String?
    public var quantity: Int? = 1
    public var expirationYear: Int?
    public var plantType: PlantType?

    // Growing requirements
    public var sunRequirement: SunExposure?
    public var wateringFrequency: WateringFrequency?
    public var spaceRequirement: SpaceRequirement?
    public var plantingDepthInches: Double?
    public var seedSpacingInches: Double?
    public var daysToGermination: Int?
    public var daysToHarvest: Int?
    public var indoorStartWeeks: Int?

    // Companion planting (fallback when no plant database link)
    public var companionPlants: [String]?
    public var incompatiblePlants: [String]?

    // Plant database link
    public var plantDatabaseID: String?

    // Metadata
    public var packetPhotoURL: String?
    public var notes: String?
    public var dateAdded: Date?

    // Relationships
    public var garden: Garden?
    public var gardenBed: GardenBed?

    public init(
        varietyName: String,
        plantType: PlantType = .vegetable,
        quantity: Int = 1
    ) {
        id = UUID()
        self.varietyName = varietyName
        self.plantType = plantType
        self.quantity = quantity
        dateAdded = Date()
        companionPlants = []
        incompatiblePlants = []
    }
}
```

Note: `SunExposure` is defined in `GrowWiseModels/Garden.swift`. `WateringFrequency`, `SpaceRequirement`, and `PlantType` are in `GrowWiseModels/Plant.swift`. All are already `Codable` + `Sendable`.

- [ ] **Step 2: Add SeedError to RepositoryErrors.swift**

Append to the end of `GrowWisePackage/Sources/GrowWiseServices/Models/RepositoryErrors.swift`:

```swift
public enum SeedError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
    case insufficientQuantity

    public var errorDescription: String? {
        switch self {
        case .notFound: "Seed not found in the database."
        case .saveFailed(let err): "Failed to save seed: \(err.localizedDescription)"
        case .insufficientQuantity: "Not enough seeds remaining."
        }
    }
}
```

- [ ] **Step 3: Add inverse relationship on GardenBed**

In `GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift`, add after the existing `plants` relationship:

```swift
@Relationship(deleteRule: .nullify, inverse: \Seed.gardenBed)
public var seeds: [Seed]? = []
```

- [ ] **Step 4: Register Seed in ModelContainerFactory**

In `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`, add `Seed.self` to both schema arrays.

In `sharedSchema` (line 24-34), add `Seed.self` after `CompostBatch.self`:

```swift
public static let sharedSchema = Schema([
    Plant.self,
    Garden.self,
    GardenBed.self,
    User.self,
    PlantReminder.self,
    JournalEntry.self,
    SoilLog.self,
    ShoppingItem.self,
    CompostBatch.self,
    Seed.self,
] as [any PersistentModel.Type])
```

In `makeSchema()` (line 182-194), add `Seed.self` after `CompostBatch.self` the same way.

- [ ] **Step 5: Build to verify model compiles**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds (warnings OK, no errors).

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseModels/Seed.swift \
       GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift \
       GrowWisePackage/Sources/GrowWiseServices/Models/RepositoryErrors.swift \
       GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift
git commit -m "feat: add Seed SwiftData model and register in schema (#147)"
```

---

## Task 2: SeedRepository (GH-147, part 2)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/Repositories/SeedRepository.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService.swift`

- [ ] **Step 1: Create SeedRepository**

Create `GrowWisePackage/Sources/GrowWiseServices/Repositories/SeedRepository.swift`:

```swift
import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class SeedRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Seed] {
        let descriptor = FetchDescriptor<Seed>(sortBy: [SortDescriptor(\.varietyName)])
        return try context.fetch(descriptor)
    }

    public func fetchAll(for garden: Garden) throws -> [Seed] {
        let gardenID = garden.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.garden?.id == gardenID
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetchUnassigned(for garden: Garden) throws -> [Seed] {
        let gardenID = garden.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.garden?.id == gardenID && seed.gardenBed == nil
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetch(for bed: GardenBed) throws -> [Seed] {
        let bedID = bed.id
        var descriptor = FetchDescriptor<Seed>(
            predicate: #Predicate<Seed> { seed in
                seed.gardenBed?.id == bedID
            },
            sortBy: [SortDescriptor(\.varietyName)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    public func fetchByPlantType(_ type: PlantType, garden: Garden? = nil) throws -> [Seed] {
        if let garden {
            let gardenID = garden.id
            var descriptor = FetchDescriptor<Seed>(
                predicate: #Predicate<Seed> { seed in
                    seed.plantType == type && seed.garden?.id == gardenID
                },
                sortBy: [SortDescriptor(\.varietyName)]
            )
            descriptor.fetchLimit = 200
            return try context.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<Seed>(
                predicate: #Predicate<Seed> { seed in
                    seed.plantType == type
                },
                sortBy: [SortDescriptor(\.varietyName)]
            )
            descriptor.fetchLimit = 200
            return try context.fetch(descriptor)
        }
    }

    public func search(query: String) throws -> [Seed] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        var descriptor = FetchDescriptor<Seed>(sortBy: [SortDescriptor(\.varietyName)])
        descriptor.fetchLimit = 200

        let allSeeds = try context.fetch(descriptor)
        let lowercased = trimmed.lowercased()
        return allSeeds.filter { seed in
            seed.varietyName?.lowercased().contains(lowercased) == true ||
                seed.brand?.lowercased().contains(lowercased) == true
        }
    }

    public func add(_ seed: Seed) throws {
        context.insert(seed)
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func update(_ seed: Seed) throws {
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func delete(_ seed: Seed) throws {
        context.delete(seed)
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func assignToBed(_ seed: Seed, bed: GardenBed) throws {
        seed.gardenBed = bed
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }

    public func unassign(_ seed: Seed) throws {
        seed.gardenBed = nil
        do {
            try context.save()
        } catch {
            throw SeedError.saveFailed(error)
        }
    }
}
```

- [ ] **Step 2: Register SeedRepository in DataService**

Add `public let seeds: SeedRepository` to the repository declarations in `DataService.swift` (after line 31, the `stats` declaration).

Then add `self.seeds = SeedRepository(context: ctx)` in all four init methods:
1. `public init() throws` — after line 74 (`self.stats = ...`)
2. `private init(minimal container:)` — after line 154 (`self.stats = ...`)
3. `private init(testing container:cloudContainer:)` — after line 169 (`self.stats = ...`)
4. In `createFallbackOrThrow()` — search for where `stats` is initialized there and add after it

- [ ] **Step 3: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/Repositories/SeedRepository.swift \
       GrowWisePackage/Sources/GrowWiseServices/DataService.swift
git commit -m "feat: add SeedRepository and register in DataService (#147)"
```

---

## Task 3: SeedRepository Tests (GH-154, part 1)

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/SeedRepositoryTests.swift`

- [ ] **Step 1: Write SeedRepository tests**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/SeedRepositoryTests.swift`:

```swift
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct SeedRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Add and fetch seed")
    func addAndFetchSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed = Seed(varietyName: "Roma Tomato", plantType: .vegetable, quantity: 3)
        try repo.add(seed)

        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.varietyName == "Roma Tomato")
        #expect(fetched.first?.quantity == 3)
    }

    @Test("Fetch seeds for garden")
    func fetchForGarden() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        try ctx.save()

        let seed1 = Seed(varietyName: "Basil", plantType: .herb)
        seed1.garden = garden
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Mint", plantType: .herb)
        try repo.add(seed2) // No garden

        let gardenSeeds = try repo.fetchAll(for: garden)
        #expect(gardenSeeds.count == 1)
        #expect(gardenSeeds.first?.varietyName == "Basil")
    }

    @Test("Fetch unassigned seeds")
    func fetchUnassigned() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Raised Bed", bedType: .raisedBed, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed1 = Seed(varietyName: "Tomato", plantType: .vegetable)
        seed1.garden = garden
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Pepper", plantType: .vegetable)
        seed2.garden = garden
        seed2.gardenBed = bed
        try repo.add(seed2)

        let unassigned = try repo.fetchUnassigned(for: garden)
        #expect(unassigned.count == 1)
        #expect(unassigned.first?.varietyName == "Tomato")
    }

    @Test("Fetch seeds for bed")
    func fetchForBed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Herb Pot", bedType: .pot, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Cilantro", plantType: .herb)
        seed.garden = garden
        seed.gardenBed = bed
        try repo.add(seed)

        let bedSeeds = try repo.fetch(for: bed)
        #expect(bedSeeds.count == 1)
        #expect(bedSeeds.first?.varietyName == "Cilantro")
    }

    @Test("Assign and unassign seed to bed")
    func assignAndUnassign() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Window Box", bedType: .windowBox, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Lettuce", plantType: .vegetable)
        seed.garden = garden
        try repo.add(seed)

        // Assign
        try repo.assignToBed(seed, bed: bed)
        let bedSeeds = try repo.fetch(for: bed)
        #expect(bedSeeds.count == 1)

        // Unassign
        try repo.unassign(seed)
        let bedSeedsAfter = try repo.fetch(for: bed)
        #expect(bedSeedsAfter.count == 0)
        let unassigned = try repo.fetchUnassigned(for: garden)
        #expect(unassigned.count == 1)
    }

    @Test("Delete seed")
    func deleteSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed = Seed(varietyName: "Carrot", plantType: .vegetable)
        try repo.add(seed)
        #expect(try repo.fetchAll().count == 1)

        try repo.delete(seed)
        #expect(try repo.fetchAll().count == 0)
    }

    @Test("Search seeds by variety name and brand")
    func searchSeeds() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        let seed1 = Seed(varietyName: "Cherry Tomato", plantType: .vegetable)
        seed1.brand = "Burpee"
        try repo.add(seed1)

        let seed2 = Seed(varietyName: "Roma Tomato", plantType: .vegetable)
        seed2.brand = "Johnny's"
        try repo.add(seed2)

        let seed3 = Seed(varietyName: "Sweet Basil", plantType: .herb)
        try repo.add(seed3)

        let tomatoResults = try repo.search(query: "tomato")
        #expect(tomatoResults.count == 2)

        let burpeeResults = try repo.search(query: "burpee")
        #expect(burpeeResults.count == 1)
        #expect(burpeeResults.first?.varietyName == "Cherry Tomato")

        let emptyResults = try repo.search(query: "")
        #expect(emptyResults.count == 0)
    }

    @Test("Fetch seeds by plant type")
    func fetchByPlantType() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)

        try repo.add(Seed(varietyName: "Tomato", plantType: .vegetable))
        try repo.add(Seed(varietyName: "Basil", plantType: .herb))
        try repo.add(Seed(varietyName: "Sunflower", plantType: .flower))

        let herbs = try repo.fetchByPlantType(.herb)
        #expect(herbs.count == 1)
        #expect(herbs.first?.varietyName == "Basil")
    }

    @Test("GardenBed deletion nullifies seed assignment")
    func bedDeletionNullifiesSeed() throws {
        let container = try makeContainer()
        let repo = SeedRepository(context: container.mainContext)
        let ctx = container.mainContext

        let garden = Garden(name: "Test Garden")
        ctx.insert(garden)
        let bed = GardenBed(name: "Temp Bed", bedType: .pot, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Dill", plantType: .herb)
        seed.garden = garden
        seed.gardenBed = bed
        try repo.add(seed)

        // Delete the bed
        ctx.delete(bed)
        try ctx.save()

        // Seed should still exist but be unassigned
        let allSeeds = try repo.fetchAll()
        #expect(allSeeds.count == 1)
        #expect(allSeeds.first?.gardenBed == nil)
    }
}
```

- [ ] **Step 2: Run tests on mac-mini**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SeedRepositoryTests 2>&1 | tail -30"`

Expected: All 9 tests pass. If tests fail due to `Seed.self` not being in the test container schema, the `makeContainer()` helper includes all model types — verify it matches.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseServicesTests/SeedRepositoryTests.swift
git commit -m "test: add SeedRepository tests (#147, #154)"
```

---

## Task 4: SeedInventoryService (GH-148)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/SeedInventoryService.swift`

- [ ] **Step 1: Create SeedInventoryService**

Create `GrowWisePackage/Sources/GrowWiseServices/SeedInventoryService.swift`:

```swift
import Foundation
import GrowWiseModels
import os.log

@MainActor
@Observable
public final class SeedInventoryService {
    private let logger = Logger(subsystem: "com.growwise.seeds", category: "SeedInventoryService")

    public init() {}

    // MARK: - Compatible Seeds for a Bed

    /// Returns unassigned seeds from the bed's garden that are compatible with the bed's conditions.
    /// Filters by sun exposure (from parent garden) and checks companion/incompatible rules
    /// against plants already in the bed.
    public func compatibleSeeds(
        for bed: GardenBed,
        unassignedSeeds: [Seed],
        plantDatabase: [Plant]
    ) -> [Seed] {
        let gardenSun = bed.garden?.sunExposure
        let existingPlantNames = Set(
            (bed.plants ?? []).compactMap { $0.name?.lowercased() }
        )

        return unassignedSeeds.filter { seed in
            // Sun compatibility check
            if let gardenSun, let seedSun = seedSunRequirement(seed, plantDatabase: plantDatabase) {
                if !isSunCompatible(seedSun: seedSun, gardenSun: gardenSun) {
                    return false
                }
            }

            // Incompatible plants check
            let incompatibles = seedIncompatiblePlants(seed, plantDatabase: plantDatabase)
            for name in incompatibles {
                if existingPlantNames.contains(name.lowercased()) {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Ready to Plant

    /// Returns seeds that should be started now based on zone and indoor start offset.
    /// Uses a simple last-frost lookup by zone and checks if current date is within
    /// the indoor start window.
    public func readyToPlant(
        seeds: [Seed],
        zone: String,
        currentDate: Date
    ) -> [Seed] {
        guard let lastFrostDate = estimatedLastFrost(zone: zone, year: Calendar.current.component(.year, from: currentDate)) else {
            return []
        }

        let calendar = Calendar.current
        return seeds.filter { seed in
            guard let weeksBeforeFrost = seed.indoorStartWeeks, weeksBeforeFrost > 0 else {
                return false
            }
            guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeksBeforeFrost, to: lastFrostDate) else {
                return false
            }
            // Show seeds in a 2-week window around their ideal start date
            guard let windowStart = calendar.date(byAdding: .weekOfYear, value: -1, to: startDate),
                  let windowEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate)
            else {
                return false
            }
            return currentDate >= windowStart && currentDate <= windowEnd
        }
    }

    // MARK: - Plant Database Link Suggestion

    /// Fuzzy match a seed's variety name against the plant database.
    /// Returns the plantDatabaseID (plant's id as string) if a reasonable match is found.
    public func suggestPlantDatabaseLink(
        for seed: Seed,
        plantDatabase: [Plant]
    ) -> String? {
        guard let varietyName = seed.varietyName?.lowercased(), !varietyName.isEmpty else {
            return nil
        }

        // Try exact substring match first
        for plant in plantDatabase {
            guard let plantName = plant.name?.lowercased() else { continue }
            if plantName == varietyName || varietyName.contains(plantName) || plantName.contains(varietyName) {
                return plant.id?.uuidString
            }
        }

        // Try word-level match: if any word in the variety name matches a plant name
        let varietyWords = Set(varietyName.split(separator: " ").map { String($0) })
        for plant in plantDatabase {
            guard let plantName = plant.name?.lowercased() else { continue }
            let plantWords = Set(plantName.split(separator: " ").map { String($0) })
            let overlap = varietyWords.intersection(plantWords)
            // Require at least one meaningful word match (skip short words like "a", "of")
            if overlap.contains(where: { $0.count > 2 }) {
                return plant.id?.uuidString
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func seedSunRequirement(_ seed: Seed, plantDatabase: [Plant]) -> SunExposure? {
        if let directSun = seed.sunRequirement {
            return directSun
        }
        // Fall back to linked plant database entry
        if let dbID = seed.plantDatabaseID,
           let plant = plantDatabase.first(where: { $0.id?.uuidString == dbID })
        {
            return sunExposureFromSunlight(plant.sunlightRequirement)
        }
        return nil
    }

    private func seedIncompatiblePlants(_ seed: Seed, plantDatabase: [Plant]) -> [String] {
        if let direct = seed.incompatiblePlants, !direct.isEmpty {
            return direct
        }
        // No incompatible list on Plant model currently, return empty
        return []
    }

    /// Convert SunlightLevel (Plant model) to SunExposure (Garden model) for comparison
    private func sunExposureFromSunlight(_ level: SunlightLevel?) -> SunExposure? {
        guard let level else { return nil }
        switch level {
        case .fullSun: return .fullSun
        case .partialSun: return .partialSun
        case .partialShade: return .partialShade
        case .fullShade: return .fullShade
        }
    }

    /// Check if a seed's sun needs are met by the garden's sun exposure.
    /// A seed requiring less sun than available is OK. A seed requiring more is not.
    private func isSunCompatible(seedSun: SunExposure, gardenSun: SunExposure) -> Bool {
        let sunOrder: [SunExposure] = [.fullShade, .partialShade, .partialSun, .fullSun, .artificial]
        let seedIndex = sunOrder.firstIndex(of: seedSun) ?? 0
        let gardenIndex = sunOrder.firstIndex(of: gardenSun) ?? 0
        // Garden must provide at least as much sun as seed needs
        // .artificial counts as providing full sun equivalent
        return gardenIndex >= seedIndex || gardenSun == .artificial
    }

    /// Rough last frost date estimate by USDA hardiness zone.
    /// Returns an approximate date for the given year.
    private func estimatedLastFrost(zone: String, year: Int) -> Date? {
        let calendar = Calendar.current
        // Zone prefix (strip a/b suffix)
        let zoneNum = Int(zone.prefix(while: { $0.isNumber })) ?? 0

        // Approximate last frost month/day by zone
        let (month, day): (Int, Int) = switch zoneNum {
        case 1 ... 3: (6, 1)   // June 1
        case 4: (5, 15)        // May 15
        case 5: (5, 1)         // May 1
        case 6: (4, 15)        // April 15
        case 7: (4, 1)         // April 1
        case 8: (3, 15)        // March 15
        case 9: (2, 15)        // February 15
        case 10 ... 13: (1, 31) // January 31 (rarely frosts)
        default: return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/SeedInventoryService.swift
git commit -m "feat: add SeedInventoryService with smart matching and seasonal logic (#148)"
```

---

## Task 5: SeedInventoryService Tests (GH-154, part 2)

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/SeedInventoryServiceTests.swift`

- [ ] **Step 1: Write SeedInventoryService tests**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/SeedInventoryServiceTests.swift`:

```swift
@testable import GrowWiseModels
@testable import GrowWiseServices
import SwiftData
import Testing

@MainActor
struct SeedInventoryServiceTests {
    let service = SeedInventoryService()

    // MARK: - Compatible Seeds

    @Test("Compatible seeds filters by sun exposure")
    func compatibleSeedsFiltersBySun() throws {
        let container = try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        let garden = Garden(name: "Shade Garden")
        garden.sunExposure = .partialShade
        ctx.insert(garden)
        let bed = GardenBed(name: "Bed 1", bedType: .raisedBed, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let fullSunSeed = Seed(varietyName: "Tomato", plantType: .vegetable)
        fullSunSeed.sunRequirement = .fullSun

        let shadeSeed = Seed(varietyName: "Lettuce", plantType: .vegetable)
        shadeSeed.sunRequirement = .partialShade

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [fullSunSeed, shadeSeed],
            plantDatabase: []
        )

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Lettuce")
    }

    @Test("Compatible seeds filters by incompatible plants")
    func compatibleSeedsFiltersIncompatibles() throws {
        let container = try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        let garden = Garden(name: "Garden")
        garden.sunExposure = .fullSun
        ctx.insert(garden)
        let bed = GardenBed(name: "Veggie Bed", bedType: .raisedBed, garden: garden)
        ctx.insert(bed)

        let tomato = Plant(name: "Tomato", plantType: .vegetable)
        tomato.bed = bed
        ctx.insert(tomato)
        try ctx.save()

        let fennelSeed = Seed(varietyName: "Fennel", plantType: .herb)
        fennelSeed.incompatiblePlants = ["Tomato"]

        let basilSeed = Seed(varietyName: "Basil", plantType: .herb)
        basilSeed.companionPlants = ["Tomato"]

        let result = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: [fennelSeed, basilSeed],
            plantDatabase: []
        )

        #expect(result.count == 1)
        #expect(result.first?.varietyName == "Basil")
    }

    @Test("Compatible seeds with no garden sun returns all seeds")
    func compatibleSeedsNoGardenSun() throws {
        let container = try ModelContainer(
            for: Seed.self, Garden.self, GardenBed.self, Plant.self,
            PlantReminder.self, JournalEntry.self, SoilLog.self,
            ShoppingItem.self, CompostBatch.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        let garden = Garden(name: "Garden")
        // No sun exposure set
        ctx.insert(garden)
        let bed = GardenBed(name: "Bed", bedType: .pot, garden: garden)
        ctx.insert(bed)
        try ctx.save()

        let seed = Seed(varietyName: "Basil", plantType: .herb)
        seed.sunRequirement = .fullSun

        let result = service.compatibleSeeds(for: bed, unassignedSeeds: [seed], plantDatabase: [])
        #expect(result.count == 1)
    }

    // MARK: - Ready to Plant

    @Test("Ready to plant returns seeds in start window")
    func readyToPlantInWindow() throws {
        let calendar = Calendar.current

        // Zone 6 last frost ~ April 15
        // Seed with 6 weeks indoor start → start ~March 4
        let seed = Seed(varietyName: "Pepper", plantType: .vegetable)
        seed.indoorStartWeeks = 6

        // Test date: March 5 (within 1-week window of March 4)
        let testDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!

        let result = service.readyToPlant(seeds: [seed], zone: "6a", currentDate: testDate)
        #expect(result.count == 1)
    }

    @Test("Ready to plant excludes seeds outside window")
    func readyToPlantOutsideWindow() throws {
        let calendar = Calendar.current

        let seed = Seed(varietyName: "Pepper", plantType: .vegetable)
        seed.indoorStartWeeks = 6

        // Zone 6 start ~March 4, test in January (way outside window)
        let testDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!

        let result = service.readyToPlant(seeds: [seed], zone: "6a", currentDate: testDate)
        #expect(result.count == 0)
    }

    @Test("Ready to plant skips seeds without indoor start weeks")
    func readyToPlantSkipsNoStartWeeks() throws {
        let seed = Seed(varietyName: "Radish", plantType: .vegetable)
        // No indoorStartWeeks set — direct sow only

        let testDate = Date()
        let result = service.readyToPlant(seeds: [seed], zone: "6a", currentDate: testDate)
        #expect(result.count == 0)
    }

    // MARK: - Plant Database Link Suggestion

    @Test("Suggest link finds exact match")
    func suggestLinkExactMatch() throws {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        let seed = Seed(varietyName: "Tomato", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])
        #expect(result == plant.id?.uuidString)
    }

    @Test("Suggest link finds substring match")
    func suggestLinkSubstringMatch() throws {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        let seed = Seed(varietyName: "Cherry Tomato", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])
        #expect(result == plant.id?.uuidString)
    }

    @Test("Suggest link returns nil for no match")
    func suggestLinkNoMatch() throws {
        let plant = Plant(name: "Carrot", plantType: .vegetable)
        let seed = Seed(varietyName: "Sunflower", plantType: .flower)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])
        #expect(result == nil)
    }

    @Test("Suggest link handles empty variety name")
    func suggestLinkEmptyName() throws {
        let plant = Plant(name: "Tomato", plantType: .vegetable)
        let seed = Seed(varietyName: "", plantType: .vegetable)

        let result = service.suggestPlantDatabaseLink(for: seed, plantDatabase: [plant])
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run tests on mac-mini**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SeedInventoryServiceTests 2>&1 | tail -30"`

Expected: All 10 tests pass.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseServicesTests/SeedInventoryServiceTests.swift
git commit -m "test: add SeedInventoryService tests (#148, #154)"
```

---

## Task 6: SeedScannerService (GH-149)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/SeedScannerService.swift`

- [ ] **Step 1: Create SeedScannerService**

Create `GrowWisePackage/Sources/GrowWiseServices/SeedScannerService.swift`:

```swift
#if canImport(UIKit)
import GrowWiseModels
import os.log
import UIKit
import Vision

public struct SeedScanResult: Sendable {
    public let rawText: String
    public let suggestedVariety: String?
    public let suggestedBrand: String?
    public let suggestedDepth: Double?
    public let suggestedSpacing: Double?
    public let suggestedDaysToGermination: Int?
    public let suggestedDaysToHarvest: Int?
    public let suggestedSun: SunExposure?

    public init(
        rawText: String,
        suggestedVariety: String? = nil,
        suggestedBrand: String? = nil,
        suggestedDepth: Double? = nil,
        suggestedSpacing: Double? = nil,
        suggestedDaysToGermination: Int? = nil,
        suggestedDaysToHarvest: Int? = nil,
        suggestedSun: SunExposure? = nil
    ) {
        self.rawText = rawText
        self.suggestedVariety = suggestedVariety
        self.suggestedBrand = suggestedBrand
        self.suggestedDepth = suggestedDepth
        self.suggestedSpacing = suggestedSpacing
        self.suggestedDaysToGermination = suggestedDaysToGermination
        self.suggestedDaysToHarvest = suggestedDaysToHarvest
        self.suggestedSun = suggestedSun
    }
}

@MainActor
public final class SeedScannerService {
    private let logger = Logger(subsystem: "com.growwise.seeds", category: "SeedScanner")

    public init() {}

    /// Recognize text from a seed packet image and parse into structured fields.
    public func recognizeText(from image: UIImage) async throws -> SeedScanResult {
        guard let cgImage = image.cgImage else {
            return SeedScanResult(rawText: "")
        }

        let rawText = try await performOCR(on: cgImage)
        return parsePacketText(rawText)
    }

    // MARK: - OCR

    private nonisolated func performOCR(on image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Text Parsing

    /// Parse raw OCR text from a seed packet into structured fields.
    /// This is best-effort — the user always reviews and corrects.
    public nonisolated func parsePacketText(_ text: String) -> SeedScanResult {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let lowered = text.lowercased()

        let sun = parseSunExposure(lowered)
        let depth = parseDepth(lowered)
        let spacing = parseSpacing(lowered)
        let germination = parseDays(lowered, keywords: ["germination", "germinate", "emerge", "sprout"])
        let harvest = parseDays(lowered, keywords: ["harvest", "mature", "maturity", "days to harvest"])
        let brand = parseBrand(lines)
        let variety = parseVariety(lines, brand: brand)

        return SeedScanResult(
            rawText: text,
            suggestedVariety: variety,
            suggestedBrand: brand,
            suggestedDepth: depth,
            suggestedSpacing: spacing,
            suggestedDaysToGermination: germination,
            suggestedDaysToHarvest: harvest,
            suggestedSun: sun
        )
    }

    private nonisolated func parseSunExposure(_ text: String) -> SunExposure? {
        if text.contains("full sun") { return .fullSun }
        if text.contains("partial sun") || text.contains("part sun") { return .partialSun }
        if text.contains("partial shade") || text.contains("part shade") { return .partialShade }
        if text.contains("full shade") || text.contains("shade") { return .fullShade }
        return nil
    }

    private nonisolated func parseDepth(_ text: String) -> Double? {
        // Match patterns like "1/4 inch", "0.25 in", "1/2\"", "depth: 1/4"
        let patterns = [
            #"(?:depth|plant|sow)[:\s]*(\d+/\d+)\s*(?:inch|in|\")"#,
            #"(?:depth|plant|sow)[:\s]*(\d+\.?\d*)\s*(?:inch|in|\")"#,
            #"(\d+/\d+)\s*(?:inch|in|\")\s*(?:deep|depth)"#,
            #"(\d+\.?\d*)\s*(?:inch|in|\")\s*(?:deep|depth)"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                return extractNumber(from: matched)
            }
        }
        return nil
    }

    private nonisolated func parseSpacing(_ text: String) -> Double? {
        let patterns = [
            #"(?:space|spacing|thin)[:\s]*(\d+\.?\d*)\s*(?:inch|in|\")"#,
            #"(\d+\.?\d*)\s*(?:inch|in|\")\s*(?:apart|spacing)"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                return extractNumber(from: matched)
            }
        }
        return nil
    }

    private nonisolated func parseDays(_ text: String, keywords: [String]) -> Int? {
        for keyword in keywords {
            let patterns = [
                "(\(keyword))[:\\s]*(\\d+)\\s*(?:days|day)",
                "(\\d+)\\s*(?:days?\\s*(?:to|until)\\s*\(keyword))",
                "(\\d+)[-–](\\d+)\\s*(?:days?\\s*(?:to|until)?\\s*\(keyword))",
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex ..< text.endIndex, in: text)
                    if let match = regex.firstMatch(in: text, range: range) {
                        // Extract the last group that contains digits
                        for i in stride(from: match.numberOfRanges - 1, through: 1, by: -1) {
                            let groupRange = match.range(at: i)
                            if groupRange.location != NSNotFound,
                               let swiftRange = Range(groupRange, in: text),
                               let num = Int(text[swiftRange])
                            {
                                return num
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Brand is typically the first or most prominent line
    private nonisolated func parseBrand(_ lines: [String]) -> String? {
        // First non-empty line that's short enough to be a brand name
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, trimmed.count <= 30, !trimmed.lowercased().contains("seed") {
                return trimmed
            }
        }
        return nil
    }

    /// Variety is often the second prominent line or one containing the plant name
    private nonisolated func parseVariety(_ lines: [String], brand: String?) -> String? {
        let brandLower = brand?.lowercased()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.lowercased() == brandLower { continue }
            if trimmed.count >= 3, trimmed.count <= 50 {
                return trimmed
            }
        }
        return nil
    }

    private nonisolated func extractNumber(from text: String) -> Double? {
        // Handle fractions like "1/4"
        if let slashIndex = text.firstIndex(of: "/") {
            let beforeSlash = text[text.startIndex ..< slashIndex]
            let afterSlash = text[text.index(after: slashIndex)...]
            // Extract numerator (last digits before slash)
            let numerStr = String(beforeSlash.reversed().prefix(while: { $0.isNumber }).reversed())
            let denomStr = String(afterSlash.prefix(while: { $0.isNumber }))
            if let num = Double(numerStr), let den = Double(denomStr), den > 0 {
                return num / den
            }
        }
        // Handle decimals
        let pattern = #"(\d+\.?\d*)"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Double(text[match])
        }
        return nil
    }
}
#endif
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds. Note: The `#if canImport(UIKit)` guard means this only compiles on iOS/macOS with UIKit.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/SeedScannerService.swift
git commit -m "feat: add SeedScannerService with Vision OCR and text parsing (#149)"
```

---

## Task 7: SeedScannerService Parser Tests (GH-154, part 3)

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/SeedScannerServiceTests.swift`

- [ ] **Step 1: Write parser tests**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/SeedScannerServiceTests.swift`:

```swift
#if canImport(UIKit)
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

@MainActor
struct SeedScannerServiceTests {
    let scanner = SeedScannerService()

    @Test("Parse sun exposure from packet text")
    func parseSunExposure() {
        let fullSun = scanner.parsePacketText("Plant in full sun location\nDepth: 1/4 inch")
        #expect(fullSun.suggestedSun == .fullSun)

        let partShade = scanner.parsePacketText("Grows best in partial shade")
        #expect(partShade.suggestedSun == .partialShade)

        let noSun = scanner.parsePacketText("Plant 1 inch deep")
        #expect(noSun.suggestedSun == nil)
    }

    @Test("Parse planting depth from packet text")
    func parseDepth() {
        let quarter = scanner.parsePacketText("Sow seeds at depth: 1/4 inch")
        #expect(quarter.suggestedDepth == 0.25)

        let half = scanner.parsePacketText("Plant 1/2 inch deep")
        #expect(half.suggestedDepth == 0.5)
    }

    @Test("Parse spacing from packet text")
    func parseSpacing() {
        let result = scanner.parsePacketText("Thin to 12 inches apart\nFull sun")
        #expect(result.suggestedSpacing == 12.0)
    }

    @Test("Parse days to germination")
    func parseGermination() {
        let result = scanner.parsePacketText("Germination: 7 days\nHarvest in 60 days")
        #expect(result.suggestedDaysToGermination == 7)
    }

    @Test("Parse days to harvest")
    func parseHarvest() {
        let result = scanner.parsePacketText("Days to harvest: 75 days\nFull sun")
        #expect(result.suggestedDaysToHarvest == 75)

        let result2 = scanner.parsePacketText("60 days to maturity")
        #expect(result2.suggestedDaysToHarvest == 60)
    }

    @Test("Parse brand and variety from lines")
    func parseBrandAndVariety() {
        let result = scanner.parsePacketText("Burpee\nCherry Tomato\nFull Sun\nDepth: 1/4 inch")
        #expect(result.suggestedBrand == "Burpee")
        #expect(result.suggestedVariety == "Cherry Tomato")
    }

    @Test("Empty text returns empty result")
    func emptyText() {
        let result = scanner.parsePacketText("")
        #expect(result.rawText == "")
        #expect(result.suggestedVariety == nil)
        #expect(result.suggestedSun == nil)
    }
}
#endif
```

- [ ] **Step 2: Run tests on mac-mini**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SeedScannerServiceTests 2>&1 | tail -30"`

Expected: All 7 tests pass. If tests don't compile due to `#if canImport(UIKit)`, ensure mac-mini builds with iOS SDK or remove the guard for test target.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseServicesTests/SeedScannerServiceTests.swift
git commit -m "test: add SeedScannerService parser tests (#149, #154)"
```

---

## Task 8: SeedInventoryView — Seed List UI (GH-150)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedInventoryView.swift`

- [ ] **Step 1: Create SeedInventoryView**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedInventoryView.swift`:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct SeedInventoryView: View {
    @Environment(DataService.self) private var dataService

    @State private var seeds: [Seed] = []
    @State private var searchText = ""
    @State private var showAddSeed = false

    public init() {}

    private var filteredSeeds: [Seed] {
        if searchText.isEmpty {
            return seeds
        }
        let query = searchText.lowercased()
        return seeds.filter { seed in
            seed.varietyName?.lowercased().contains(query) == true ||
                seed.brand?.lowercased().contains(query) == true
        }
    }

    private var groupedSeeds: [(PlantType, [Seed])] {
        let grouped = Dictionary(grouping: filteredSeeds) { $0.plantType ?? .vegetable }
        return grouped.sorted { $0.key.displayName < $1.key.displayName }
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    searchBar

                    if groupedSeeds.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedSeeds, id: \.0) { type, typeSeeds in
                            seedSection(type: type, seeds: typeSeeds)
                        }
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)

            addButton
        }
        .navigationTitle("Seed Inventory")
        .sheet(isPresented: $showAddSeed) {
            AddSeedSheet()
                .onDisappear { loadSeeds() }
        }
        .task { loadSeeds() }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            TextField("Search seeds...", text: $searchText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .accessibilityIdentifier("seed_inventory_search")
        }
        .padding(12)
        .glassCard()
    }

    // MARK: - Sections

    private func seedSection(type: PlantType, seeds: [Seed]) -> some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text(type.displayName + "s")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(seeds.enumerated()), id: \.element.id) { index, seed in
                    NavigationLink(value: seed.id) {
                        seedRow(seed)
                    }
                    .buttonStyle(.plain)

                    if index < seeds.count - 1 {
                        Divider()
                            .background(CultivationTheme.Colors.divider)
                            .padding(.leading, 64)
                    }
                }
            }
            .glassCard()
        }
    }

    private func seedRow(_ seed: Seed) -> some View {
        HStack(spacing: 14) {
            IconBubble(
                systemName: iconForPlantType(seed.plantType),
                color: CultivationTheme.Colors.brandLeaf,
                size: 36,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(seed.varietyName ?? "Unknown Seed")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    if seed.plantDatabaseID != nil {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    }
                }

                HStack(spacing: 8) {
                    if let brand = seed.brand {
                        Text(brand)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                    if let year = seed.expirationYear {
                        Text("Exp \(String(year))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(
                                year <= Calendar.current.component(.year, from: Date())
                                    ? CultivationTheme.Colors.statusAlert
                                    : CultivationTheme.Colors.textTertiary
                            )
                    }
                }
            }

            Spacer()

            // Quantity badge
            Text("\(seed.quantity ?? 0)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (seed.quantity ?? 0) > 0
                        ? CultivationTheme.Colors.brandLeaf
                        : CultivationTheme.Colors.textTertiary
                )
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .accessibilityIdentifier("seed_inventory_cell_\(seed.id?.uuidString ?? "unknown")")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 48))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Text(searchText.isEmpty ? "No seeds yet" : "No seeds match your search")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            if searchText.isEmpty {
                Text("Tap + to add seeds from your collection")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityIdentifier("seed_inventory_empty")
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button { showAddSeed = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(CultivationTheme.Gradients.warmAccent)
                .clipShape(Circle())
                .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.trailing, CultivationTheme.Spacing.screenPadding)
        .padding(.bottom, 24)
        .accessibilityIdentifier("seed_inventory_button_add")
    }

    // MARK: - Helpers

    private func loadSeeds() {
        seeds = (try? dataService.seeds.fetchAll()) ?? []
    }

    private func iconForPlantType(_ type: PlantType?) -> String {
        switch type {
        case .vegetable: "carrot"
        case .herb: "leaf"
        case .flower: "camera.macro"
        case .fruit: "fork.knife"
        case .houseplant: "house"
        case .succulent: "drop"
        case .tree: "tree"
        case .shrub: "leaf.arrow.circlepath"
        case nil: "questionmark.circle"
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10`

Expected: Build succeeds. If `AddSeedSheet` is not yet defined, temporarily comment out the `.sheet` modifier and the reference to `AddSeedSheet()`. We create it in the next task.

**Important:** If the build fails because `AddSeedSheet` doesn't exist yet, add a placeholder at the bottom of the file:

```swift
// Placeholder until Task 9 creates the real AddSeedSheet
struct AddSeedSheet: View {
    var body: some View {
        Text("Add Seed — Coming Soon")
    }
}
```

Remove this placeholder when Task 9 creates the real file.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedInventoryView.swift
git commit -m "feat: add SeedInventoryView with grouped list and search (#150)"
```

---

## Task 9: AddSeedSheet and SeedDetailView (GH-151)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/AddSeedSheet.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedDetailView.swift`

- [ ] **Step 1: Create AddSeedSheet**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/AddSeedSheet.swift`:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct AddSeedSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    @State private var varietyName = ""
    @State private var brand = ""
    @State private var quantity = 1
    @State private var expirationYear: Int = Calendar.current.component(.year, from: Date()) + 2
    @State private var plantType: PlantType = .vegetable
    @State private var sunRequirement: SunExposure?
    @State private var wateringFrequency: WateringFrequency?
    @State private var spaceRequirement: SpaceRequirement?
    @State private var plantingDepth = ""
    @State private var seedSpacing = ""
    @State private var daysToGermination = ""
    @State private var daysToHarvest = ""
    @State private var indoorStartWeeks = ""
    @State private var notes = ""

    // Scanner
    @State private var showScanner = false
    @State private var scanResult: SeedScanResult?

    // Plant database link
    @State private var suggestedPlantID: String?
    @State private var linkedPlantName: String?

    private let seedInventoryService = SeedInventoryService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    scanButton
                    basicInfoSection
                    growingRequirementsSection
                    notesSection
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Add Seed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("add_seed_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSeed() }
                        .disabled(varietyName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("add_seed_button_save")
                }
            }
            .sheet(isPresented: $showScanner) {
                SeedScannerView { result in
                    applyScanResult(result)
                }
            }
            .onChange(of: varietyName) { _, newValue in
                suggestPlantLink(for: newValue)
            }
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button { showScanner = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .medium))
                Text("Scan Seed Packet")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CultivationTheme.Gradients.warmAccent)
            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
        }
        .accessibilityIdentifier("add_seed_button_scan")
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Basic Info")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                formField(title: "Variety Name", text: $varietyName, id: "add_seed_field_variety")

                // Plant database link suggestion
                if let plantName = linkedPlantName {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        Text("Linked to \(plantName)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        Spacer()
                        Button("Unlink") {
                            suggestedPlantID = nil
                            linkedPlantName = nil
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("add_seed_link_suggestion")
                }

                formDivider
                formField(title: "Brand", text: $brand, id: "add_seed_field_brand")
                formDivider

                HStack {
                    Text("Type")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Picker("", selection: $plantType) {
                        ForEach(PlantType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CultivationTheme.Colors.textSecondary)
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .accessibilityIdentifier("add_seed_picker_type")

                formDivider

                HStack {
                    Text("Quantity")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Stepper("\(quantity)", value: $quantity, in: 0 ... 999)
                        .font(.system(.body, design: .rounded))
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .accessibilityIdentifier("add_seed_stepper_quantity")

                formDivider

                HStack {
                    Text("Expiration Year")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Stepper(
                        "\(String(expirationYear))",
                        value: $expirationYear,
                        in: 2020 ... 2040
                    )
                    .font(.system(.body, design: .rounded))
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .accessibilityIdentifier("add_seed_stepper_expiration")
            }
            .glassCard()
        }
    }

    // MARK: - Growing Requirements

    private var growingRequirementsSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Growing Requirements")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                optionalPicker(title: "Sun", selection: $sunRequirement, cases: SunExposure.allCases, id: "add_seed_picker_sun") { $0.displayName }
                formDivider
                optionalPicker(title: "Water", selection: $wateringFrequency, cases: WateringFrequency.allCases, id: "add_seed_picker_water") { $0.displayName }
                formDivider
                optionalPicker(title: "Space", selection: $spaceRequirement, cases: SpaceRequirement.allCases, id: "add_seed_picker_space") { $0.displayName }
                formDivider
                formField(title: "Planting Depth (in)", text: $plantingDepth, id: "add_seed_field_depth", keyboard: .decimalPad)
                formDivider
                formField(title: "Spacing (in)", text: $seedSpacing, id: "add_seed_field_spacing", keyboard: .decimalPad)
                formDivider
                formField(title: "Days to Germination", text: $daysToGermination, id: "add_seed_field_germination", keyboard: .numberPad)
                formDivider
                formField(title: "Days to Harvest", text: $daysToHarvest, id: "add_seed_field_harvest", keyboard: .numberPad)
                formDivider
                formField(title: "Indoor Start (weeks)", text: $indoorStartWeeks, id: "add_seed_field_indoor_start", keyboard: .numberPad)
            }
            .glassCard()
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Notes")
                .sectionLabelStyle()
                .padding(.leading, 4)

            TextEditor(text: $notes)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .frame(minHeight: 80)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("add_seed_field_notes")
        }
    }

    // MARK: - Form Helpers

    private func formField(title: String, text: Binding<String>, id: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Spacer()
            TextField("", text: text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .accessibilityIdentifier(id)
    }

    private func optionalPicker<T: Hashable>(
        title: String,
        selection: Binding<T?>,
        cases: [T],
        id: String,
        displayName: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Spacer()
            Picker("", selection: selection) {
                Text("Not Set").tag(nil as T?)
                ForEach(cases, id: \.self) { value in
                    Text(displayName(value)).tag(value as T?)
                }
            }
            .pickerStyle(.menu)
            .tint(CultivationTheme.Colors.textSecondary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .accessibilityIdentifier(id)
    }

    private var formDivider: some View {
        Divider()
            .background(CultivationTheme.Colors.divider)
            .padding(.leading, 16)
    }

    // MARK: - Actions

    private func saveSeed() {
        let seed = Seed(
            varietyName: varietyName.trimmingCharacters(in: .whitespaces),
            plantType: plantType,
            quantity: quantity
        )
        seed.brand = brand.isEmpty ? nil : brand
        seed.expirationYear = expirationYear
        seed.sunRequirement = sunRequirement
        seed.wateringFrequency = wateringFrequency
        seed.spaceRequirement = spaceRequirement
        seed.plantingDepthInches = Double(plantingDepth)
        seed.seedSpacingInches = Double(seedSpacing)
        seed.daysToGermination = Int(daysToGermination)
        seed.daysToHarvest = Int(daysToHarvest)
        seed.indoorStartWeeks = Int(indoorStartWeeks)
        seed.notes = notes.isEmpty ? nil : notes
        seed.plantDatabaseID = suggestedPlantID

        try? dataService.seeds.add(seed)
        dismiss()
    }

    private func applyScanResult(_ result: SeedScanResult) {
        scanResult = result
        if let variety = result.suggestedVariety { varietyName = variety }
        if let brand = result.suggestedBrand { self.brand = brand }
        if let depth = result.suggestedDepth { plantingDepth = String(depth) }
        if let spacing = result.suggestedSpacing { seedSpacing = String(Int(spacing)) }
        if let germ = result.suggestedDaysToGermination { daysToGermination = String(germ) }
        if let harvest = result.suggestedDaysToHarvest { daysToHarvest = String(harvest) }
        if let sun = result.suggestedSun { sunRequirement = sun }
    }

    private func suggestPlantLink(for name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            suggestedPlantID = nil
            linkedPlantName = nil
            return
        }

        let allPlants = (try? dataService.plants.fetchAll()) ?? []
        let databasePlants = allPlants.filter { $0.isUserPlant != true }
        let seed = Seed(varietyName: trimmed, plantType: plantType)

        if let id = seedInventoryService.suggestPlantDatabaseLink(for: seed, plantDatabase: databasePlants) {
            suggestedPlantID = id
            linkedPlantName = databasePlants.first(where: { $0.id?.uuidString == id })?.name
        } else {
            suggestedPlantID = nil
            linkedPlantName = nil
        }
    }
}
```

- [ ] **Step 2: Create SeedDetailView**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedDetailView.swift`:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct SeedDetailView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let seed: Seed

    @State private var varietyName: String = ""
    @State private var brand: String = ""
    @State private var quantity: Int = 1
    @State private var expirationYear: Int = 2028
    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                // Packet photo
                if let photoURL = seed.packetPhotoURL, !photoURL.isEmpty {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .fill(CultivationTheme.Colors.cardSurface)
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    .accessibilityIdentifier("seed_detail_photo")
                }

                infoSection
                growingInfoSection

                if seed.plantDatabaseID != nil {
                    linkedPlantSection
                }

                deleteButton
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle(seed.varietyName ?? "Seed Details")
        .task { loadSeedData() }
        .alert("Delete Seed", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteSeed() }
        } message: {
            Text("Are you sure you want to remove this seed from your inventory?")
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Details")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                infoRow(label: "Variety", value: seed.varietyName ?? "—")
                infoDivider
                infoRow(label: "Brand", value: seed.brand ?? "—")
                infoDivider
                infoRow(label: "Type", value: seed.plantType?.displayName ?? "—")
                infoDivider
                infoRow(label: "Quantity", value: "\(seed.quantity ?? 0)")
                infoDivider
                infoRow(
                    label: "Expiration",
                    value: seed.expirationYear.map { String($0) } ?? "—",
                    alert: seed.expirationYear.map { $0 <= Calendar.current.component(.year, from: Date()) } ?? false
                )
            }
            .glassCard()
        }
    }

    // MARK: - Growing Info

    private var growingInfoSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Growing Requirements")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                infoRow(label: "Sun", value: seed.sunRequirement?.displayName ?? "—")
                infoDivider
                infoRow(label: "Water", value: seed.wateringFrequency?.displayName ?? "—")
                infoDivider
                infoRow(label: "Space", value: seed.spaceRequirement?.displayName ?? "—")
                infoDivider
                infoRow(label: "Planting Depth", value: seed.plantingDepthInches.map { "\($0) in" } ?? "—")
                infoDivider
                infoRow(label: "Spacing", value: seed.seedSpacingInches.map { "\(Int($0)) in" } ?? "—")
                infoDivider
                infoRow(label: "Germination", value: seed.daysToGermination.map { "\($0) days" } ?? "—")
                infoDivider
                infoRow(label: "Harvest", value: seed.daysToHarvest.map { "\($0) days" } ?? "—")
                infoDivider
                infoRow(label: "Indoor Start", value: seed.indoorStartWeeks.map { "\($0) weeks before frost" } ?? "—")
            }
            .glassCard()
        }
    }

    // MARK: - Linked Plant

    private var linkedPlantSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Plant Database")
                .sectionLabelStyle()
                .padding(.leading, 4)

            HStack(spacing: 14) {
                IconBubble(
                    systemName: "leaf.fill",
                    color: CultivationTheme.Colors.brandLeaf,
                    size: 36,
                    iconSize: 16
                )
                Text("Linked to plant database")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .accessibilityIdentifier("seed_detail_linked_plant")
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button { showDeleteConfirmation = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Remove from Inventory")
            }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(CultivationTheme.Colors.statusAlert)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard()
        }
        .accessibilityIdentifier("seed_detail_button_delete")
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, alert: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(alert ? CultivationTheme.Colors.statusAlert : CultivationTheme.Colors.textPrimary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
    }

    private var infoDivider: some View {
        Divider()
            .background(CultivationTheme.Colors.divider)
            .padding(.leading, 16)
    }

    private func loadSeedData() {
        varietyName = seed.varietyName ?? ""
        brand = seed.brand ?? ""
        quantity = seed.quantity ?? 1
        expirationYear = seed.expirationYear ?? Calendar.current.component(.year, from: Date()) + 2
        notes = seed.notes ?? ""
    }

    private func deleteSeed() {
        try? dataService.seeds.delete(seed)
        dismiss()
    }
}
```

- [ ] **Step 3: Remove AddSeedSheet placeholder from SeedInventoryView (if added in Task 8)**

If a placeholder `AddSeedSheet` was added in Task 8, remove it now that the real file exists.

- [ ] **Step 4: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10`

Expected: Build succeeds. Note: `SeedScannerView` is referenced but not yet created — if build fails, add a placeholder in `AddSeedSheet.swift`:

```swift
// Placeholder until SeedScannerView is created in Task 10
struct SeedScannerView: View {
    let onResult: (SeedScanResult) -> Void
    var body: some View { Text("Scanner") }
}
```

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/AddSeedSheet.swift \
       GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedDetailView.swift
git commit -m "feat: add AddSeedSheet and SeedDetailView (#151)"
```

---

## Task 10: SeedScannerView (GH-151, part 2)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedScannerView.swift`

- [ ] **Step 1: Create SeedScannerView**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedScannerView.swift`:

```swift
#if canImport(UIKit)
import GrowWiseServices
import SwiftUI
import UIKit

struct SeedScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let onResult: (SeedScanResult) -> Void

    @State private var showImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let scannerService = SeedScannerService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .accessibilityIdentifier("seed_scanner_icon")

                Text("Scan Seed Packet")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("Take a photo of your seed packet and we'll extract the details for you.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if isProcessing {
                    ProgressView("Reading packet...")
                        .padding()
                        .accessibilityIdentifier("seed_scanner_processing")
                } else {
                    VStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                imageSource = .camera
                                showImagePicker = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(CultivationTheme.Gradients.warmAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                            }
                            .accessibilityIdentifier("seed_scanner_button_capture")
                        }

                        Button {
                            imageSource = .photoLibrary
                            showImagePicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassCard()
                        }
                        .accessibilityIdentifier("seed_scanner_button_library")
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }

                Spacer()
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Scan Packet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("seed_scanner_button_cancel")
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imageSource) { image in
                    processImage(image)
                }
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Failed to read the seed packet.")
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task<Void, Never> {
            do {
                let result = try await scannerService.recognizeText(from: image)
                onResult(result)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - UIImagePickerController Wrapper

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
```

- [ ] **Step 2: Remove SeedScannerView placeholder from AddSeedSheet (if added)**

If a placeholder was added in Task 9, remove it.

- [ ] **Step 3: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/SeedScannerView.swift
git commit -m "feat: add SeedScannerView with camera and photo library support (#151)"
```

---

## Task 11: Wire Seeds into Garden Tab Navigation (GH-150, part 2)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift`

- [ ] **Step 1: Read GardenView to find the QuickStatCard section and navigation setup**

Read `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift` to find:
1. The `QuickStatCard` HStack in `dashboardHeader` — add a Seeds stat card
2. The `navigationDestination` modifiers — add one for seed inventory
3. Add `@State private var showSeedInventory = false`

- [ ] **Step 2: Add Seeds QuickStatCard to the dashboard header**

In the `dashboardHeader` computed property, find the `HStack(spacing: 10)` containing `QuickStatCard` items. Add a tappable Seeds stat card after the existing ones:

```swift
QuickStatCard(
    value: seedCount,
    label: "Seeds",
    icon: "leaf.circle",
    color: CultivationTheme.Colors.accentCoral
)
.onTapGesture { showSeedInventory = true }
.accessibilityIdentifier("garden_stat_seeds")
```

Add the state variable and seed count:
```swift
@State private var showSeedInventory = false
```

Add a computed property or load seeds in the existing `loadData()` / `.task` block:
```swift
private var seedCount: Int {
    (try? dataService.seeds.fetchAll().count) ?? 0
}
```

- [ ] **Step 3: Add navigationDestination for SeedInventoryView**

Add after the existing `navigationDestination` modifiers:

```swift
.navigationDestination(isPresented: $showSeedInventory) {
    SeedInventoryView()
}
```

Also add a `navigationDestination(item:)` for seed detail from the inventory list:

```swift
.navigationDestination(for: UUID.self) { seedID in
    if let seed = (try? dataService.seeds.fetchAll())?.first(where: { $0.id == seedID }) {
        SeedDetailView(seed: seed)
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10`

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
git commit -m "feat: add Seeds chip to Garden tab and wire navigation (#150)"
```

---

## Task 12: SuggestedSeedsCard on Bed Detail (GH-152)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Components/SuggestedSeedsCard.swift`

- [ ] **Step 1: Create SuggestedSeedsCard**

Create `GrowWisePackage/Sources/GrowWiseFeature/Components/SuggestedSeedsCard.swift`:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct SuggestedSeedsCard: View {
    @Environment(DataService.self) private var dataService

    let bed: GardenBed
    let onPlantSeed: (Seed) -> Void

    @State private var suggestedSeeds: [Seed] = []

    private let service = SeedInventoryService()

    var body: some View {
        if !suggestedSeeds.isEmpty {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
                HStack {
                    Text("Suggested Seeds")
                        .sectionLabelStyle()
                    Spacer()
                    Text("\(suggestedSeeds.count) compatible")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestedSeeds, id: \.id) { seed in
                            seedSuggestionChip(seed)
                        }
                    }
                }

                NavigationLink(value: "seed_inventory") {
                    HStack(spacing: 6) {
                        Text("View All Seeds")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
                .accessibilityIdentifier("suggested_seeds_view_all")
            }
            .task { loadSuggestions() }
            .accessibilityIdentifier("suggested_seeds_card")
        }
    }

    private func seedSuggestionChip(_ seed: Seed) -> some View {
        Button {
            onPlantSeed(seed)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(seed.varietyName ?? "Seed")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Text("Qty: \(seed.quantity ?? 0)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .padding(12)
            .frame(minWidth: 120, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("suggested_seeds_cell_\(seed.id?.uuidString ?? "unknown")")
    }

    private func loadSuggestions() {
        guard let garden = bed.garden else { return }
        let unassigned = (try? dataService.seeds.fetchUnassigned(for: garden)) ?? []
        suggestedSeeds = service.compatibleSeeds(
            for: bed,
            unassignedSeeds: unassigned,
            plantDatabase: (try? dataService.plants.fetchAll()) ?? []
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -5`

Expected: Build succeeds. The card is created but not yet placed in any bed detail view — that integration depends on where the bed detail view is. The card is standalone and ready to be dropped into any view that has a `GardenBed` reference.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Components/SuggestedSeedsCard.swift
git commit -m "feat: add SuggestedSeedsCard component for bed detail views (#152)"
```

---

## Task 13: Final Build Verification and Test Run

**Files:** None — verification only.

- [ ] **Step 1: Full local build**

Run: `cd /Users/blake/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10`

Expected: Build succeeds with no errors.

- [ ] **Step 2: Run all seed-related tests on mac-mini**

First, sync code to mac-mini:
```bash
git push
```

Then run tests:
```bash
ssh mac-mini "cd ~/Projects/GrowWise && git pull && cd GrowWisePackage && swift test --filter 'Seed' 2>&1 | tail -40"
```

Expected: All SeedRepositoryTests, SeedInventoryServiceTests, and SeedScannerServiceTests pass.

- [ ] **Step 3: Run full test suite**

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"
```

Expected: No regressions — all existing tests still pass alongside new seed tests.

- [ ] **Step 4: Commit any fixes needed, then push**

```bash
git push
```

- [ ] **Step 5: Close completed GitHub issues**

```bash
gh issue close 147 --repo jbcrane13/GrowWise --comment "Done: Seed model, SeedRepository, schema registration"
gh issue close 148 --repo jbcrane13/GrowWise --comment "Done: SeedInventoryService with compatible seeds, ready to plant, and plant database link suggestion"
gh issue close 149 --repo jbcrane13/GrowWise --comment "Done: SeedScannerService with Vision OCR and keyword text parser"
gh issue close 150 --repo jbcrane13/GrowWise --comment "Done: SeedInventoryView with grouped list, search, and Garden tab navigation"
gh issue close 151 --repo jbcrane13/GrowWise --comment "Done: AddSeedSheet, SeedDetailView, and SeedScannerView"
gh issue close 152 --repo jbcrane13/GrowWise --comment "Done: SuggestedSeedsCard component for bed detail views"
gh issue close 154 --repo jbcrane13/GrowWise --comment "Done: Unit tests for SeedRepository, SeedInventoryService, and SeedScannerService"
```
