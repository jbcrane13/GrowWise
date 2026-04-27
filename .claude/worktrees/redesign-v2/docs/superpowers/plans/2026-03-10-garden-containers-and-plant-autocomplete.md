# Garden Containers & Plant Autocomplete Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the free-text `gardenLocation` field with a real `GardenBed` SwiftData model (with 8 predefined types + custom name), update `AddPlantSheet` to use garden/bed pickers, add a `MovePlantSheet` for reassignment, and wire `PlantDatabaseService.searchPlants()` to auto-fill plant fields when a database match is selected.

**Architecture:** `GardenBed` sits between `Garden` and `Plant` in the SwiftData hierarchy. Plants default to `nil` bed ("Unassigned"). The `GardenViewModel` groups plants by their `GardenBed` object instead of a free-text string. `AddPlantSheet` gains two new pickers (garden → bed) and a debounced autocomplete strip above the type picker. `MovePlantSheet` is a new two-step sheet (garden → bed) for reassigning any existing plant.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, `@Observable`, iOS 18+. `PlantDatabaseService` already injected via `@Environment`. Tests run on mac-mini via SSH (`platform=macOS`).

---

## File Map

| Action | File | Change |
|--------|------|--------|
| Create | `GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift` | `GardenBed` model + `BedType` enum with `displayName`/`iconName` |
| Modify | `GrowWisePackage/Sources/GrowWiseModels/Plant.swift` | Remove `gardenLocation: String?`, add `bed: GardenBed?` |
| Modify | `GrowWisePackage/Sources/GrowWiseModels/Garden.swift` | Add `beds: [GardenBed]?` cascade relationship |
| Modify | `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift` | Add `GardenBed.self` to schema, add store-wipe recovery |
| Modify | `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenViewModel.swift` | Replace `PlantGroup(locationKey:)` with `PlantGroup(bed:)`, update `rebuildGroups()` |
| Modify | `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenBedSection.swift` | Accept `PlantGroup` with `bed: GardenBed?` instead of string key |
| Create | `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/CreateBedSheet.swift` | `BedType` picker + name text field, saves `GardenBed` |
| Modify | `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift` | Replace `.alert` "Add Bed" with `CreateBedSheet` sheet |
| Modify | `GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift` | Replace `gardenLocation` string with `selectedBed: GardenBed?` picker; add debounced autocomplete strip |
| Create | `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/MovePlantSheet.swift` | Two-step garden → bed reassignment sheet |

---

## Chunk 1: Data Model & Schema Migration

### Task 1: Create GardenBed model

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift`
- Test: `GrowWisePackage/Tests/GrowWiseModelsTests/GardenBedTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GrowWisePackage/Tests/GrowWiseModelsTests/GardenBedTests.swift
import Testing
@testable import GrowWiseModels

@Suite("GardenBed")
struct GardenBedTests {
    @Test("BedType has displayName and iconName for all cases")
    func bedTypeMetadata() {
        for bedType in BedType.allCases {
            #expect(!bedType.displayName.isEmpty)
            #expect(!bedType.iconName.isEmpty)
        }
    }

    @Test("BedType raw values are stable strings")
    func bedTypeRawValues() {
        #expect(BedType.raisedBed.rawValue == "raised_bed")
        #expect(BedType.pot.rawValue == "pot")
        #expect(BedType.hangingBasket.rawValue == "hanging_basket")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseModelsTests/GardenBedTests 2>&1 | tail -20"
```
Expected: FAIL with "cannot find type 'BedType'"

- [ ] **Step 3: Create GardenBed.swift**

> **CloudKit pattern:** All properties are optional (matching `Plant` and `Garden` in this codebase) because CloudKit requires optionality for sync compatibility. The spec shows non-optional fields as intent, but the implementation uses the same optional-with-default-in-init pattern as the rest of the models.

```swift
// GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift
import Foundation
import SwiftData

@Model
public final class GardenBed {
    public var id: UUID?
    public var name: String?
    public var bedType: BedType?
    public var notes: String?
    public var createdDate: Date?
    public var garden: Garden?
    @Relationship(deleteRule: .cascade, inverse: \Plant.bed)
    public var plants: [Plant]? = []

    public init(name: String, bedType: BedType, garden: Garden? = nil) {
        id = UUID()
        self.name = name
        self.bedType = bedType
        self.garden = garden
        createdDate = Date()
    }
}

// MARK: - BedType

public enum BedType: String, CaseIterable, Codable, Sendable {
    case raisedBed       = "raised_bed"
    case planterBox      = "planter_box"
    case inGroundRow     = "in_ground_row"
    case pot             = "pot"
    case greenhouseBench = "greenhouse_bench"
    case windowBox       = "window_box"
    case hangingBasket   = "hanging_basket"
    case trellisVertical = "trellis_vertical"

    public var displayName: String {
        switch self {
        case .raisedBed:       "Raised Bed"
        case .planterBox:      "Planter Box"
        case .inGroundRow:     "In-Ground Row"
        case .pot:             "Pot"
        case .greenhouseBench: "Greenhouse Bench"
        case .windowBox:       "Window Box"
        case .hangingBasket:   "Hanging Basket"
        case .trellisVertical: "Trellis / Vertical"
        }
    }

    public var iconName: String {
        switch self {
        case .raisedBed:       "rectangle.split.3x1.fill"
        case .planterBox:      "shippingbox.fill"
        case .inGroundRow:     "line.3.horizontal"
        case .pot:             "cup.and.saucer.fill"
        case .greenhouseBench: "building.2.fill"
        case .windowBox:       "rectangle.fill"
        case .hangingBasket:   "circle.dotted"
        case .trellisVertical: "arrow.up.and.down.square.fill"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseModelsTests/GardenBedTests 2>&1 | tail -20"
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseModels/GardenBed.swift GrowWisePackage/Tests/GrowWiseModelsTests/GardenBedTests.swift
git commit -m "feat(models): add GardenBed SwiftData model and BedType enum"
```

---

### Task 2: Update Plant and Garden models

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseModels/Plant.swift:32-33`
- Modify: `GrowWisePackage/Sources/GrowWiseModels/Garden.swift:24-29`

- [ ] **Step 1: Remove `gardenLocation` from Plant, add `bed` relationship**

In `Plant.swift`, find the `// Location in garden` comment block. It currently contains:
```swift
    // Location in garden
    public var gardenLocation: String? // CloudKit: made optional or with default value
    public var containerType: ContainerType? // CloudKit: made optional or with default value
```
Replace `gardenLocation` line with:
```swift
    // Location in garden
    public var bed: GardenBed? // nil = Unassigned
    public var containerType: ContainerType? // CloudKit: made optional or with default value
```

- [ ] **Step 2: Add `beds` relationship to Garden**

In `Garden.swift`, find the `plants` `@Relationship` property. After that property block, add:
```swift
    @Relationship(deleteRule: .cascade, inverse: \GardenBed.garden)
    public var beds: [GardenBed]? = []
```

- [ ] **Step 3: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseModels/Plant.swift GrowWisePackage/Sources/GrowWiseModels/Garden.swift
git commit -m "feat(models): replace gardenLocation string with GardenBed relationship on Plant"
```

---

### Task 3: Update ModelContainerFactory schema

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`
- Test: `GrowWisePackage/Tests/GrowWiseServicesTests/ModelContainerFactoryTests.swift`

The current `sharedSchema` lists 6 model types. We need to add `GardenBed.self` and add store-wipe recovery so users upgrading from the old schema (with `gardenLocation`) don't crash.

- [ ] **Step 1: Write the failing test**

Check if an existing test file exists first. If `ModelContainerFactoryTests.swift` exists, add to it; otherwise create it.

```swift
// Append to or create: GrowWisePackage/Tests/GrowWiseServicesTests/ModelContainerFactoryTests.swift
import Testing
@testable import GrowWiseServices
import GrowWiseModels

@Suite("ModelContainerFactory")
struct ModelContainerFactoryTests {
    @Test("makeForTesting creates container without throwing")
    func makeForTestingSucceeds() throws {
        #expect(throws: Never.self) {
            _ = try ModelContainerFactory.makeForTesting()
        }
    }
}
```

- [ ] **Step 2: Run test to verify it currently passes (baseline)**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseServicesTests/ModelContainerFactoryTests 2>&1 | tail -20"
```
Expected: PASS (or FAIL with compile error because `GardenBed.self` is missing from schema — that's fine too)

- [ ] **Step 3: Update ModelContainerFactory**

Open `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`.

**3a. Add `GardenBed.self` to the schema in two places:**

In `sharedSchema` (the static let, ~line 24):
```swift
public static let sharedSchema = Schema([
    Plant.self,
    Garden.self,
    GardenBed.self,      // ← add this
    User.self,
    PlantReminder.self,
    JournalEntry.self,
    SoilLog.self,
] as [any PersistentModel.Type])
```

In `makeSchema()` (the private nonisolated helper, ~line 164):
```swift
private nonisolated static func makeSchema() -> Schema {
    Schema([
        Plant.self,
        Garden.self,
        GardenBed.self,      // ← add this
        User.self,
        PlantReminder.self,
        JournalEntry.self,
        SoilLog.self,
    ] as [any PersistentModel.Type])
}
```

**3b. Add store-wipe recovery to the non-testing path in `make()`:**

The current `make()` function's `else` branch (non-UITesting path) looks like:
```swift
} else {
    modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.growwise.gardening")
    )
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
}
```

Replace the last line with a do-catch that wipes SwiftData's default local SQLite files on schema incompatibility:

```swift
} else {
    modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.growwise.gardening")
    )
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // Schema incompatible with persisted store — wipe local SQLite and recreate.
        // Sole developer, no user data at risk. Approved approach per project decision.
        logger.warning("⚠️ ModelContainer init failed (schema mismatch), wiping local store: \(error.localizedDescription)")
        if let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first {
            // SwiftData names the default store "default.store" in Application Support
            for filename in ["default.store", "default.store-shm", "default.store-wal"] {
                try? FileManager.default.removeItem(at: appSupportURL.appending(path: filename))
            }
        }
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseServicesTests/ModelContainerFactoryTests 2>&1 | tail -20"
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift GrowWisePackage/Tests/GrowWiseServicesTests/ModelContainerFactoryTests.swift
git commit -m "feat(services): add GardenBed to schema, add store-wipe recovery for schema migration"
```

---

## Chunk 2: Garden View Refactoring

### Task 4: Refactor GardenViewModel to group by GardenBed

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenViewModel.swift`

The current `PlantGroup` has `locationKey: String?`. We change it to hold an optional `GardenBed` reference (nil = Unassigned). The `id` becomes the bed's UUID string or `"__unassigned__"`.

- [ ] **Step 1: Write the failing test**

```swift
// GrowWisePackage/Tests/GrowWiseFeatureTests/GardenViewModelTests.swift
// Note: This is a unit test of PlantGroup — no SwiftData needed.
import Testing
@testable import GrowWiseFeature
import GrowWiseModels

@Suite("PlantGroup")
struct PlantGroupTests {
    @Test("displayName returns bed name when bed is set")
    func displayNameWithBed() {
        let bed = GardenBed(name: "South Bed", bedType: .raisedBed)
        let group = PlantGroup(id: bed.id?.uuidString ?? "x", bed: bed, plants: [])
        #expect(group.displayName == "South Bed")
    }

    @Test("displayName returns Unassigned when bed is nil")
    func displayNameWithoutBed() {
        let group = PlantGroup(id: "__unassigned__", bed: nil, plants: [])
        #expect(group.displayName == "Unassigned")
    }

    @Test("bedType returns bed type when bed is set")
    func bedTypeWithBed() {
        let bed = GardenBed(name: "Herb Pots", bedType: .pot)
        let group = PlantGroup(id: "x", bed: bed, plants: [])
        #expect(group.bedType == .pot)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseFeatureTests/PlantGroupTests 2>&1 | tail -20"
```
Expected: FAIL with "argument 'locationKey' missing" or similar

- [ ] **Step 3: Update PlantGroup and GardenViewModel**

Replace the existing `PlantGroup` struct and `rebuildGroups()` in `GardenViewModel.swift`:

```swift
// MARK: - PlantGroup

/// A grouping of plants by their GardenBed.
/// bed == nil means "Unassigned" (plants with no container assigned).
public struct PlantGroup: Identifiable {
    public let id: String
    /// The GardenBed this group represents, or nil for unassigned plants.
    public let bed: GardenBed?
    public var plants: [Plant]

    public var displayName: String {
        bed?.name ?? "Unassigned"
    }

    public var bedType: BedType? {
        bed?.bedType
    }

    public var iconName: String {
        bed?.bedType?.iconName ?? "tray"
    }
}
```

Replace `rebuildGroups()`:

```swift
private func rebuildGroups() {
    let plants: [Plant] = if let selectedGarden {
        allPlants.filter { $0.garden?.id == selectedGarden.id }
    } else {
        allPlants
    }

    // Group by bed (nil → unassigned).
    var bedMap: [String: (GardenBed, [Plant])] = [:]
    var unassigned: [Plant] = []

    for plant in plants {
        if let bed = plant.bed, let bedID = bed.id?.uuidString {
            if bedMap[bedID] == nil {
                bedMap[bedID] = (bed, [])
            }
            bedMap[bedID]?.1.append(plant)
        } else {
            unassigned.append(plant)
        }
    }

    // Sort beds by name, then append unassigned.
    var groups: [PlantGroup] = bedMap.values
        .sorted { ($0.0.name ?? "") < ($1.0.name ?? "") }
        .map { bed, plants in
            PlantGroup(
                id: bed.id?.uuidString ?? UUID().uuidString,
                bed: bed,
                plants: plants.sorted { ($0.name ?? "") < ($1.name ?? "") }
            )
        }

    if !unassigned.isEmpty {
        groups.append(PlantGroup(
            id: "__unassigned__",
            bed: nil,
            plants: unassigned.sorted { ($0.name ?? "") < ($1.name ?? "") }
        ))
    }

    groupedPlants = groups
}
```

Also update `filteredGroups` — the `PlantGroup` initializer no longer has `locationKey`:
```swift
return PlantGroup(id: group.id, bed: group.bed, plants: matching)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:GrowWiseFeatureTests/PlantGroupTests 2>&1 | tail -20"
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenViewModel.swift GrowWisePackage/Tests/GrowWiseFeatureTests/GardenViewModelTests.swift
git commit -m "refactor(garden): group plants by GardenBed instead of gardenLocation string"
```

---

### Task 5: Update GardenBedSection to use GardenBed metadata

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenBedSection.swift`

`BedGroupHeader` currently receives `name:` and `subtitle:`. We now also have the bed type icon available from `group.iconName`.

- [ ] **Step 1: Read the current BedGroupHeader signature**

Look at what parameters `BedGroupHeader` accepts — it already has a `name` and `subtitle`. Check `GardenComponents.swift` for the full signature.

- [ ] **Step 2: Update GardenBedSection**

The main changes:
1. `companionTip(for:)` now uses `group.bed?.id?.uuidString ?? "__unassigned__"` as the hash key (replacing `group.locationKey`)
2. The `BedGroupHeader` call can optionally receive the `iconName` if that param exists

Update `companionTip(for:)`:
```swift
private func companionTip(for group: PlantGroup) -> String {
    let tips = [
        "Basil planted near tomatoes can improve their flavor and repel pests.",
        "Marigolds are excellent companions — they deter many common garden pests.",
        "Rotating crops each season helps prevent soil depletion and disease buildup.",
        "Nasturtiums attract aphids away from more valuable crops — a great sacrificial plant.",
        "Tall plants can shade heat-sensitive neighbors during the hottest part of the day.",
    ]
    let key = group.bed?.id?.uuidString ?? "__unassigned__"
    let index = abs(key.hashValue) % tips.count
    return tips[index]
}
```

Update `accessibilityIdentifier` on `BedGroupHeader`:
```swift
.accessibilityIdentifier("garden_section_\(group.displayName)")
```
(no change needed, `group.displayName` still works)

- [ ] **Step 3: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenBedSection.swift
git commit -m "refactor(garden): update GardenBedSection to use GardenBed metadata instead of string key"
```

---

### Task 6: Create CreateBedSheet

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/CreateBedSheet.swift`

- [ ] **Step 1: Create CreateBedSheet.swift**

```swift
// GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/CreateBedSheet.swift
import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

/// Sheet for creating a new GardenBed in a given garden.
/// Shows a BedType picker (horizontal scroll of icon+label chips)
/// and a text field for the custom name.
struct CreateBedSheet: View {
    let garden: Garden
    let onCreated: (GardenBed) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedType: BedType = .raisedBed
    @State private var bedName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    // Drag handle
                    Capsule()
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    // Type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Container Type")
                            .sectionLabelStyle()
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(BedType.allCases, id: \.self) { type in
                                    BedTypeChip(
                                        bedType: type,
                                        isSelected: selectedType == type
                                    ) {
                                        selectedType = type
                                        if bedName.isEmpty {
                                            bedName = type.displayName
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        }
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .sectionLabelStyle()
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                        HStack(spacing: 10) {
                            IconBubble(
                                systemName: selectedType.iconName,
                                color: CultivationTheme.Colors.brandLeaf,
                                size: 28,
                                iconSize: 13
                            )
                            TextField("e.g. South Bed, Herb Pots", text: $bedName)
                                .font(.system(.body))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                .accessibilityIdentifier("createbed_textfield_name")
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                        .glassCard()
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    Spacer()

                    // Save button
                    Button {
                        saveBed()
                    } label: {
                        Text("Add Container")
                    }
                    .buttonStyle(GradientButtonStyle(isDisabled: bedName.trimmingCharacters(in: .whitespaces).isEmpty))
                    .disabled(bedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .accessibilityIdentifier("createbed_button_save")
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Add Container")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("createbed_button_cancel")
                }
            }
        }
    }

    private func saveBed() {
        let trimmed = bedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let bed = GardenBed(name: trimmed, bedType: selectedType, garden: garden)
        modelContext.insert(bed)
        onCreated(bed)
        dismiss()
    }
}

// MARK: - BedTypeChip

private struct BedTypeChip: View {
    let bedType: BedType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: bedType.iconName)
                    .font(.system(size: 18, weight: .medium))
                Text(bedType.displayName)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 72)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(isSelected
                        ? CultivationTheme.Colors.brandLeaf.opacity(0.15)
                        : CultivationTheme.Colors.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .stroke(
                                isSelected
                                    ? CultivationTheme.Colors.brandLeaf
                                    : CultivationTheme.Colors.cardBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
            }
            .foregroundStyle(isSelected
                ? CultivationTheme.Colors.brandLeaf
                : CultivationTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createbed_chip_\(bedType.rawValue)")
    }
}
```

- [ ] **Step 2: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/CreateBedSheet.swift
git commit -m "feat(garden): add CreateBedSheet with BedType picker and custom name field"
```

---

### Task 7: Wire GardenView to use CreateBedSheet

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift`

Currently the "Add Bed" button shows an `.alert` that collects a name, then sets `bedLocationPreset` and opens `AddPlantSheet`. Replace this with `CreateBedSheet`.

- [ ] **Step 1: Update GardenView**

Remove these state vars:
```swift
@State private var showAddBed = false
@State private var newBedName = ""
@State private var bedLocationPreset = ""
```

Add:
```swift
@State private var showCreateBed = false
```

Remove `locationPreset` from `AddPlantSheet` init (it no longer needs a preset):
```swift
AddPlantSheet()
```

Replace the `.alert("New Bed or Area", ...)` block with:
```swift
.sheet(isPresented: $showCreateBed) {
    if let garden = viewModel.selectedGarden {
        CreateBedSheet(garden: garden) { _ in
            Task { await viewModel.load(dataService: dataService) }
        }
        .presentationDetents([.medium])
    }
}
```

Update `addBedButton` to toggle `showCreateBed`:
```swift
private var addBedButton: some View {
    Button {
        showCreateBed = true
    } label: {
        HStack {
            Image(systemName: "plus.circle")
            Text("Add Container")
        }
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .stroke(
                    CultivationTheme.Colors.brandLeaf.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [6])
                )
        }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("garden_button_addbed")
}
```

Also remove the `onDismiss` preset logic from the `AddPlantSheet` sheet — the `locationPreset` parameter is being removed:
```swift
.sheet(isPresented: $showAddPlant, onDismiss: {
    Task { await viewModel.load(dataService: dataService) }
}) {
    AddPlantSheet()
}
```

- [ ] **Step 2: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
git commit -m "feat(garden): replace alert-based Add Bed with CreateBedSheet"
```

---

## Chunk 3: Add/Move Plant Flows

### Task 8: Update AddPlantSheet — bed picker replaces gardenLocation

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift`

The `gardenLocation: String` field and `locationPreset` init param are removed. In their place, after the garden picker, show a bed picker listing the selected garden's beds.

- [ ] **Step 1: Update AddPlantSheet state and init**

Remove:
```swift
@State private var gardenLocation: String = ""
```
```swift
public init(locationPreset: String = "") {
    _gardenLocation = State(initialValue: locationPreset)
}
```

Add:
```swift
@State private var selectedBed: GardenBed? = nil
@State private var availableBeds: [GardenBed] = []
```

Change init:
```swift
public init() {}
```

- [ ] **Step 2: Replace gardenLocation field with bed picker in the form**

In the "Planting Information" `formSection`, remove the `styledTextField` for "Bed or Area", and replace the `onChange(of: selectedGarden)` block with one that also loads beds:

Find:
```swift
styledTextField(
    placeholder: "Bed or Area (e.g. South Bed)",
    text: $gardenLocation,
    systemImage: "square.split.2x2",
    color: CultivationTheme.Colors.brandSage,
    accessibilityID: "addplant_textfield_location"
)
```
Remove it entirely.

Update the garden `Picker`'s `onChange` to reload beds:
```swift
.onChange(of: selectedGarden) { _, newGarden in
    updateCompatibilityAnalysis()
    loadBeds(for: newGarden)
    selectedBed = nil
}
```

After the garden `Picker` row, add a bed picker (shown whenever a garden is selected):
```swift
if let _ = selectedGarden {
    Divider()
        .background(CultivationTheme.Colors.divider)

    HStack {
        IconBubble(systemName: "square.split.2x2", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
        Picker("Container", selection: $selectedBed) {
            Text("Unassigned").tag(nil as GardenBed?)
            ForEach(availableBeds) { bed in
                Label(bed.name ?? "Unnamed", systemImage: bed.bedType?.iconName ?? "tray")
                    .tag(bed as GardenBed?)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("addplant_picker_bed")
    }
}
```

- [ ] **Step 3: Add `loadBeds` helper and update `savePlant`**

Add private helper:
```swift
private func loadBeds(for garden: Garden?) {
    guard let garden else {
        availableBeds = []
        return
    }
    availableBeds = (garden.beds ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
}
```

In `savePlant()`, replace:
```swift
newPlant.gardenLocation = gardenLocation.isEmpty ? nil : gardenLocation
```
with:
```swift
newPlant.bed = selectedBed
```

Also update `loadGardens()` to pre-load beds for the first garden:
```swift
private func loadGardens() {
    do {
        availableGardens = try dataService.gardens.fetchAll()
        if let first = availableGardens.first {
            selectedGarden = first
            loadBeds(for: first)
        }
    } catch {
        errorMessage = "Could not load gardens: \(error.localizedDescription)"
        showingError = true
        availableGardens = []
    }
}
```

- [ ] **Step 4: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift
git commit -m "feat(plants): replace gardenLocation string with GardenBed picker in AddPlantSheet"
```

---

### Task 9: Add plant name autocomplete to AddPlantSheet

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift`

`PlantDatabaseService` is already injected into the environment by `MainAppView`. `searchPlants(query:)` returns `[Plant]` where each plant is a database reference plant (`isUserPlant == false`).

- [ ] **Step 1: Add autocomplete state variables**

After the existing `@State` declarations in `AddPlantSheet`, add:
```swift
// Autocomplete
@Environment(PlantDatabaseService.self) private var plantDatabaseService
@State private var suggestions: [Plant] = []
@State private var searchTask: Task<Void, Never>?
@State private var nameFieldCommitted = false
```

- [ ] **Step 2: Add debounced onChange on plantName**

The existing `onChange(of: plantName)` only calls `updateCompatibilityAnalysis()`. Add autocomplete search to it:

```swift
.onChange(of: plantName) { _, newValue in
    updateCompatibilityAnalysis()
    // Debounced autocomplete search
    searchTask?.cancel()
    nameFieldCommitted = false
    guard !newValue.isEmpty else {
        suggestions = []
        return
    }
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        suggestions = plantDatabaseService.searchPlants(query: newValue)
    }
}
```

- [ ] **Step 3: Add suggestion strip below the name field**

In the "Basic Information" `formSection`, after the `styledTextField` for plant name and before the `Divider`, insert the suggestion strip:

```swift
if !suggestions.isEmpty && !nameFieldCommitted {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    applyTemplate(suggestion)
                } label: {
                    Text(suggestion.name ?? "")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                                .overlay {
                                    Capsule()
                                        .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.3), lineWidth: 1)
                                }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addplant_suggestion_\(suggestion.name ?? "")")
            }
        }
        .padding(.top, 4)
    }
}
```

- [ ] **Step 4: Implement `applyTemplate`**

Add private method:
```swift
private func applyTemplate(_ plant: Plant) {
    plantName = plant.name ?? plantName
    scientificName = plant.scientificName ?? scientificName
    if let type = plant.plantType { selectedPlantType = type }
    if let diff = plant.difficultyLevel { selectedDifficultyLevel = diff }
    if let water = plant.wateringFrequency { selectedWateringFrequency = water }
    if let sun = plant.sunlightRequirement { selectedSunlightRequirement = sun }
    if let space = plant.spaceRequirement { selectedSpaceRequirement = space }
    suggestions = []
    nameFieldCommitted = true
}
```

> **Note:** `selectedWateringFrequency`, `selectedSunlightRequirement`, `selectedSpaceRequirement` may not yet be state variables in `AddPlantSheet` — check and add them if missing. The current form has `selectedDifficultyLevel` and `selectedPlantType`; the other fields may be shown read-only or be absent. Add state vars for any missing ones and wire them to the form sections as appropriate.

- [ ] **Step 5: Cancel search task on dismiss**

Add to `onDisappear` (already has `saveTask?.cancel()`):
```swift
.onDisappear {
    saveTask?.cancel()
    searchTask?.cancel()
}
```

- [ ] **Step 6: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift
git commit -m "feat(plants): add debounced plant name autocomplete with field auto-fill in AddPlantSheet"
```

---

### Task 10: Create MovePlantSheet

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/MovePlantSheet.swift`

- [ ] **Step 1: Create MovePlantSheet.swift**

```swift
// GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/MovePlantSheet.swift
import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

/// Two-step sheet to move a plant to a different garden and/or container.
/// Step 1: pick a garden. Step 2: pick a bed (or Unassigned).
struct MovePlantSheet: View {
    let plant: Plant

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DataService.self) private var dataService

    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var selectedBed: GardenBed?
    @State private var availableBeds: [GardenBed] = []
    @State private var step: MoveStep = .garden

    private enum MoveStep { case garden, bed }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    // Drag handle
                    Capsule()
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    if step == .garden {
                        gardenStep
                    } else {
                        bedStep
                    }
                }
            }
            .navigationTitle("Move Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("moveplant_button_cancel")
                }
                if step == .bed {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            step = .garden
                        } label: {
                            Image(systemName: "chevron.left")
                            Text("Garden")
                        }
                        .accessibilityIdentifier("moveplant_button_back")
                    }
                }
            }
            .task { loadGardens() }
        }
    }

    // MARK: - Garden Step

    private var gardenStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Garden")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            VStack(spacing: 0) {
                ForEach(gardens) { garden in
                    Button {
                        selectedGarden = garden
                        availableBeds = (garden.beds ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
                        selectedBed = nil
                        step = .bed
                    } label: {
                        HStack {
                            Text(garden.name ?? "Unnamed Garden")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Spacer()
                            if garden.id == plant.garden?.id {
                                Text("Current")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                    }
                    .accessibilityIdentifier("moveplant_garden_\(garden.id?.uuidString ?? "")")

                    if garden.id != gardens.last?.id {
                        Divider().background(CultivationTheme.Colors.divider)
                            .padding(.leading, CultivationTheme.Spacing.cardPadding)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            Spacer()
        }
    }

    // MARK: - Bed Step

    private var bedStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Container")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            VStack(spacing: 0) {
                // Unassigned option
                Button {
                    selectedBed = nil
                    confirmMove()
                } label: {
                    HStack {
                        IconBubble(systemName: "tray", color: CultivationTheme.Colors.textSecondary, size: 28, iconSize: 13)
                        Text("Unassigned")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Spacer()
                        if plant.bed == nil && selectedGarden?.id == plant.garden?.id {
                            Text("Current")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                }
                .accessibilityIdentifier("moveplant_bed_unassigned")

                ForEach(availableBeds) { bed in
                    Divider().background(CultivationTheme.Colors.divider)
                        .padding(.leading, CultivationTheme.Spacing.cardPadding)

                    Button {
                        selectedBed = bed
                        confirmMove()
                    } label: {
                        HStack {
                            IconBubble(
                                systemName: bed.bedType?.iconName ?? "tray",
                                color: CultivationTheme.Colors.brandLeaf,
                                size: 28,
                                iconSize: 13
                            )
                            Text(bed.name ?? "Unnamed")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Spacer()
                            if bed.id == plant.bed?.id {
                                Text("Current")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            }
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                    }
                    .accessibilityIdentifier("moveplant_bed_\(bed.id?.uuidString ?? "")")
                }
            }
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func loadGardens() {
        gardens = (try? dataService.gardens.fetchAll()) ?? []
    }

    private func confirmMove() {
        plant.garden = selectedGarden
        plant.bed = selectedBed
        dismiss()
    }
}
```

- [ ] **Step 2: Build to verify no compilation errors**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 3: Wire MovePlantSheet into PlantDetailView or PlantQuickCard**

Search for the plant detail view to find where to add the "Move to…" button:

```bash
grep -r "Move\|move" GrowWisePackage/Sources/GrowWiseFeature/Views --include="*.swift" -l
```

Add a "Move to…" button in the appropriate view (likely `PlantDetailView` or `PlantQuickCard`) that presents `MovePlantSheet` as a sheet:

```swift
// In the appropriate view, add state:
@State private var showMovePlant = false

// Button:
Button("Move to…") {
    showMovePlant = true
}
.accessibilityIdentifier("plant_button_move")

// Sheet:
.sheet(isPresented: $showMovePlant) {
    MovePlantSheet(plant: plant)
        .presentationDetents([.medium, .large])
}
```

- [ ] **Step 4: Final full build**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded'"
```
Expected: `Build succeeded`

- [ ] **Step 5: Run all tests**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWisePackage -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO 2>&1 | tail -30"
```
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/MovePlantSheet.swift
git add GrowWisePackage/Sources/GrowWiseFeature/Views/  # for any view wired with Move button
git commit -m "feat(plants): add MovePlantSheet for reassigning plants between gardens and containers"
```

- [ ] **Step 7: Push**

```bash
git push
```

---

## Summary

| Task | Files Changed | Key Outcome |
|------|--------------|-------------|
| 1 | `GardenBed.swift` (new) | SwiftData model + BedType enum with 8 types |
| 2 | `Plant.swift`, `Garden.swift` | `gardenLocation` removed; `bed: GardenBed?` added |
| 3 | `ModelContainerFactory.swift` | GardenBed in schema; store-wipe recovery |
| 4 | `GardenViewModel.swift` | Groups by GardenBed object, not string |
| 5 | `GardenBedSection.swift` | Uses GardenBed metadata |
| 6 | `CreateBedSheet.swift` (new) | BedType picker + custom name |
| 7 | `GardenView.swift` | Alert replaced with CreateBedSheet |
| 8 | `AddPlantSheet.swift` | Bed picker replaces gardenLocation field |
| 9 | `AddPlantSheet.swift` | Plant name autocomplete with field auto-fill |
| 10 | `MovePlantSheet.swift` (new) | Two-step garden → bed reassignment |

Beads issues: **GrowWise-3sn** (Tasks 1–8, 10) and **GrowWise-5e6** (Task 9)
