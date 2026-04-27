# Garden Containers & Plant Autocomplete Design

**Date:** 2026-03-10
**Status:** Approved
**Beads:** GrowWise-3sn (containers), GrowWise-5e6 (autocomplete)

---

## Feature 1: Garden Container Model (GardenBed)

### Problem

Currently there is no `GardenBed` model. Areas/planters are simulated via a free-text `gardenLocation: String?` field on `Plant`. This means:
- Beds have no identity, type, or metadata
- Plants can't be moved between beds without string editing
- Adding a plant requires knowing the bed name in advance
- Garden structure is impossible to manage independently of plants

### Solution

Introduce a real `GardenBed` SwiftData model. Plants are assigned to a bed (nullable = Unassigned). Beds belong to a garden. Plants can be moved freely between beds and gardens.

---

## Data Model

### New: `GardenBed`

```swift
@Model
public final class GardenBed {
    public var id: UUID
    public var name: String                          // e.g. "South Bed", "Herb Pots"
    public var bedType: BedType
    public var notes: String?
    public var createdDate: Date
    public var garden: Garden?                       // required — every bed belongs to one garden
    @Relationship(deleteRule: .cascade, inverse: \Plant.bed)
    public var plants: [Plant]? = []
}

public enum BedType: String, CaseIterable, Codable, Sendable {
    case raisedBed        = "raised_bed"
    case planterBox       = "planter_box"
    case inGroundRow      = "in_ground_row"
    case pot              = "pot"
    case greenhouseBench  = "greenhouse_bench"
    case windowBox        = "window_box"
    case hangingBasket    = "hanging_basket"
    case trellisVertical  = "trellis_vertical"
}
```

Each `BedType` has a `displayName` and SF Symbol `iconName`.

### Modified: `Plant`

- **Remove:** `gardenLocation: String?`
- **Add:** `bed: GardenBed?` — nullable; nil = "Unassigned"

### Modified: `Garden`

- **Add:** `@Relationship(deleteRule: .cascade, inverse: \GardenBed.garden) var beds: [GardenBed]? = []`

### Schema Migration

`ModelContainerFactory` bumps the schema version. On first launch with the incompatible schema, SwiftData will fail to open the old store. The factory catches this error, deletes the store file, and recreates it clean. No migration stages needed (sole developer, approved clean wipe).

---

## Flows

### Create Garden → Add Containers

1. Existing `CreateGardenSheet`: name + type + indoor toggle → save garden
2. After save, parent view shows a **"Add containers to [name]?"** prompt (non-blocking bottom sheet or inline card)
   - "Add Container" button → opens `CreateBedSheet`
   - "Skip for Now" dismisses
3. `CreateBedSheet`: pick `BedType` from a styled list + enter a name → save → can add another
4. User taps "Done" to finish

### Add Plant (updated `AddPlantSheet`)

1. **Name field** — live search with 300ms debounce (see Feature 2)
2. **Garden picker** — required; selects which garden
3. **Container picker** — shows beds for the selected garden + "Unassigned" at top; defaults to Unassigned
4. Type, difficulty, notes, photos → Save

### Move a Plant

- In plant detail view: **"Move to…"** button → `MovePlantSheet`
- `MovePlantSheet`: two-step — pick garden → pick container (or Unassigned)
- Saves immediately on confirm

### GardenView

- Plants grouped by `GardenBed` object (replaces `gardenLocation` string grouping)
- Bed section header: type icon + name + plant count
- Plants with `nil` bed appear in **"Unassigned"** section at bottom
- **"Add Bed"** button per garden → `CreateBedSheet`

---

## New Files

| File | Purpose |
|---|---|
| `GrowWiseModels/GardenBed.swift` | SwiftData model + `BedType` enum |
| `GrowWiseFeature/Views/Garden/CreateBedSheet.swift` | Type picker + name field |
| `GrowWiseFeature/Views/Garden/MovePlantSheet.swift` | Garden + bed reassignment picker |

## Modified Files

| File | Change |
|---|---|
| `GrowWiseModels/Plant.swift` | Remove `gardenLocation`, add `bed: GardenBed?` |
| `GrowWiseModels/Garden.swift` | Add `beds: [GardenBed]?` relationship |
| `GrowWiseServices/ModelContainerFactory.swift` | Bump schema version, add store-wipe recovery |
| `GrowWiseFeature/Views/Garden/GardenViewModel.swift` | Group by `GardenBed` not string |
| `GrowWiseFeature/Views/Garden/GardenBedSection.swift` | Accept `GardenBed` model instead of `PlantGroup` string key |
| `GrowWiseFeature/Views/GardenView.swift` | "Add Bed" button, post-garden-create container prompt |
| `GrowWiseFeature/Views/AddPlantSheet.swift` | Garden + bed pickers, "Move to…" action |
| `GrowWiseFeature/Views/MyGardenView.swift` | Post-create "Add containers?" prompt |

---

## Feature 2: Plant Name Autocomplete

### Problem

`AddPlantSheet` has name and scientific name fields that require manual entry. The codebase already has `PlantDatabaseService` with 25+ curated plants including type, difficulty, watering frequency, sun requirements, and more — but it's not wired to the add-plant UI.

### Solution

As the user types a plant name, search `PlantDatabaseService` with a 300ms debounce. Show a compact suggestion strip below the name field. Tapping a suggestion auto-fills all matching fields. User can override any value.

### Auto-filled fields

When a database match is selected:
- `scientificName`
- `selectedPlantType` (PlantType)
- `selectedDifficultyLevel` (DifficultyLevel)
- `selectedWateringFrequency` (WateringFrequency)
- `selectedSunlightRequirement` (SunlightLevel)
- `selectedSpaceRequirement` (SpaceRequirement)

### Implementation

In `AddPlantSheet`:

```swift
@State private var suggestions: [PlantDatabaseEntry] = []
@State private var searchTask: Task<Void, Never>?
```

`.onChange(of: plantName)`:
```swift
searchTask?.cancel()
searchTask = Task {
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    suggestions = plantDatabaseService.searchPlants(query: plantName)
}
```

Suggestion strip (shown when `!suggestions.isEmpty && !nameFieldCommitted`):
- Horizontal `ScrollView` of pill chips with plant name
- Tap → `applyTemplate(_ entry: PlantDatabaseEntry)` fills state vars + sets `nameFieldCommitted = true` to hide strip

### Environment

`PlantDatabaseService` is already available via `@Environment`. Confirm it's injected in the app's environment setup; if not, add it alongside `DataService`.
