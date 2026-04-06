# Seed Inventory Design

**Date:** 2026-04-03
**Status:** Approved
**GitHub Issue:** #137

---

## Problem

Users buy seed packets but have no way to track what they own, when to plant them, or which seeds fit their garden conditions. The app's plant database, garden beds, and seasonal planner already have the data needed for smart recommendations — but there's no seed inventory to connect them.

## Solution

A seed inventory system that lets users catalog seeds they own (manually or via packet scanner), links seeds to the plant database for inherited care data, and surfaces contextual recommendations on garden bed detail views and the Home dashboard.

---

## Data Model

### New: `Seed` (@Model)

All properties optional with defaults for CloudKit compatibility, following existing model patterns.

```swift
@Model
public final class Seed {
    public var id: UUID?
    public var varietyName: String?              // e.g. "Roma Tomato", "Sugar Snap Pea"
    public var brand: String?                    // e.g. "Burpee", "Johnny's Selected Seeds"
    public var quantity: Int?                    // packet count (default 1)
    public var expirationYear: Int?             // e.g. 2027
    public var plantType: PlantType?            // vegetable, herb, flower, etc.

    // Growing requirements (for smart matching when no plant database link)
    public var sunRequirement: SunExposure?
    public var wateringFrequency: WateringFrequency?
    public var spaceRequirement: SpaceRequirement?
    public var plantingDepthInches: Double?
    public var seedSpacingInches: Double?
    public var daysToGermination: Int?
    public var daysToHarvest: Int?
    public var indoorStartWeeks: Int?           // weeks before last frost to start indoors

    // Companion planting (fallback when no plant database link)
    public var companionPlants: [String]?
    public var incompatiblePlants: [String]?

    // Plant database link — inherits care data, companions, incompatibles when set
    public var plantDatabaseID: String?

    // Metadata
    public var packetPhotoURL: String?
    public var notes: String?
    public var dateAdded: Date?

    // Relationships
    public var garden: Garden?                  // which garden's inventory this seed belongs to
    public var gardenBed: GardenBed?            // which container/bed this seed is assigned to (optional — unassigned seeds are general inventory)
}
```

**Plant database link behavior:** When `plantDatabaseID` is set, the UI defers to the linked Plant's care data, companion/incompatible lists, and other metadata. The Seed's own growing requirement fields serve as overrides or for seeds without a database match.

**Garden vs GardenBed relationship:** A seed belongs to a garden's inventory (`garden`). It can optionally be assigned to a specific container/bed (`gardenBed`). Unassigned seeds are general inventory — available for suggestion on any bed in the garden. Assigned seeds are "earmarked" for a specific container and show on that bed's detail view.

### Modified: `GardenBed`

Add inverse relationship for seeds:

```swift
@Relationship(deleteRule: .nullify, inverse: \Seed.gardenBed)
public var seeds: [Seed]? = []
```

`deleteRule: .nullify` — deleting a bed unassigns its seeds back to general inventory rather than deleting them.

---

## Repository & Service Layer

### `SeedRepository` (new, in Repositories/)

Standard CRUD following existing repository patterns (`@MainActor`):
- `fetchAll(for garden: Garden?) -> [Seed]`
- `fetchUnassigned(for garden: Garden?) -> [Seed]` — seeds not assigned to any bed
- `fetch(for bed: GardenBed) -> [Seed]` — seeds assigned to a specific bed
- `add(_ seed: Seed) throws`
- `update(_ seed: Seed) throws`
- `delete(_ seed: Seed) throws`
- `assignToBed(_ seed: Seed, bed: GardenBed) throws`
- `unassign(_ seed: Seed) throws` — moves seed back to general inventory
- `fetchByPlantType(_ type: PlantType, garden: Garden?) -> [Seed]`
- `search(query: String) -> [Seed]`

Added to `DataService` as: `public let seeds: SeedRepository`

### `SeedInventoryService` (new, @Observable @MainActor)

Smart matching and seasonal logic:
- `compatibleSeeds(for bed: GardenBed) -> [Seed]` — filters the garden's unassigned seed inventory by the bed's parent garden sun exposure, bed type space constraints, and companion/incompatible rules against existing plants in the bed. Seeds already assigned to other beds are excluded.
- `readyToPlant(zone: String, currentDate: Date) -> [Seed]` — returns seeds that should be started now based on hardiness zone, `indoorStartWeeks`, and current date relative to estimated last frost.
- `suggestPlantDatabaseLink(for seed: Seed) -> String?` — fuzzy matches `varietyName` against the plant database to auto-suggest a `plantDatabaseID`.

### `SeedScannerService` (new, @MainActor)

Vision framework OCR:
- `recognizeText(from image: UIImage) async throws -> SeedScanResult` — runs `VNRecognizeTextRequest`, returns structured result with raw text and best-effort parsed fields.
- `SeedScanResult` struct: `rawText: String`, `suggestedVariety: String?`, `suggestedBrand: String?`, `suggestedDepth: Double?`, `suggestedSpacing: Double?`, `suggestedDaysToGermination: Int?`, `suggestedDaysToHarvest: Int?`, `suggestedSun: SunExposure?`

Text parsing uses keyword heuristics (e.g. "full sun", "partial shade", "depth: 1/4 inch", "space 12 inches apart", "harvest in 60 days"). No external API dependency.

---

## Views & Navigation

### Entry Points

1. **Garden tab hero header** — new "Seeds" chip alongside existing bed/area chips. Tapping navigates to `SeedInventoryView`.
2. **Garden bed detail view** — "Suggested Seeds" card showing compatible seeds from inventory. Tapping a suggestion offers to create a Plant in that bed from the seed's data.
3. **Home tab dashboard** — "Ready to Plant" card showing seeds to start now based on zone + season. Only visible when the user has seeds with `indoorStartWeeks` data and it's planting season.

### New Views

**`SeedInventoryView`** — Primary seed list
- Search bar at top
- Grouped by `plantType` (Vegetables, Herbs, Flowers, etc.)
- Each row shows: variety name, brand, quantity badge, expiration year
- Rows with linked plant database entries show a small leaf icon
- Tap row → `SeedDetailView`
- Floating "+" button → `AddSeedSheet`
- Follows existing list patterns (LazyVStack, glassCard rows)

**`SeedDetailView`** — View/edit a seed
- Packet photo (if available) at top
- Editable fields matching the model
- If plant database linked: shows inherited care data section (read-only, from the linked plant)
- "Scan Packet" button to re-scan and update fields
- Delete button

**`AddSeedSheet`** — Add a new seed (.sheet presentation)
- Manual entry form with all fields
- "Scan Packet" button at top → launches `SeedScannerView`, returns pre-filled data
- Auto-suggest plant database link after variety name is entered (inline suggestion chip)
- Save adds to the current garden's seed inventory

**`SeedScannerView`** — Camera/photo OCR
- Camera capture using `UIImagePickerController` (camera or photo library)
- After capture: shows processing indicator, then returns `SeedScanResult`
- Pre-fills `AddSeedSheet` fields — user reviews and corrects
- Stores packet photo as `packetPhotoURL`

**`SuggestedSeedsCard`** — Reusable card for bed detail and Home
- Horizontal scroll of seed suggestions with variety name + compatibility reason
- Tap a seed → option to "Plant this seed" (assigns seed to the bed, creates a Plant in the bed, decrements seed quantity)
- "View All Seeds" link → navigates to `SeedInventoryView`

### Accessibility Identifiers

All interactive elements follow `{screen}_{element}_{descriptor}` pattern:
- `seed_inventory_list`, `seed_inventory_search`, `seed_inventory_button_add`
- `seed_detail_field_variety`, `seed_detail_button_scan`, `seed_detail_button_delete`
- `add_seed_button_scan`, `add_seed_button_save`, `add_seed_field_variety`
- `seed_scanner_button_capture`, `seed_scanner_button_library`
- `suggested_seeds_card`, `suggested_seeds_cell_{id}`

---

## Integration Points

### Shopping List

When a seed's `quantity` reaches 0 after "planting," show an inline prompt: "Add more [variety] to shopping list?" If accepted, creates a `ShoppingItem` with category `.seeds`.

### Seasonal Planner

`SeasonalPlannerService` already generates monthly tasks. Extend it to include "Start [variety] seeds indoors" tasks when the user has seeds with `indoorStartWeeks` data and it's the right time window for their zone.

### Plant Database Link

When the user enters a variety name in `AddSeedSheet`, `SeedInventoryService.suggestPlantDatabaseLink` runs a fuzzy match against the plant database. If a match is found, show an inline chip: "Link to [Plant Name]?" Accepting sets `plantDatabaseID` and inherits care data.

---

## Scanner Implementation Details

### Vision Framework Flow

1. User taps "Scan Packet" → `UIImagePickerController` with `.camera` source (fallback to `.photoLibrary`)
2. Captured image → `VNRecognizeTextRequest` with `.accurate` recognition level
3. Raw recognized text → keyword parser extracts structured fields
4. Return `SeedScanResult` with suggestions pre-filled

### Keyword Parser Heuristics

- **Sun:** match "full sun", "partial shade", "partial sun", "shade" → `SunExposure` enum
- **Depth:** match patterns like "1/4 inch", "1/2\"", "0.25in" → `plantingDepthInches`
- **Spacing:** match "thin to X inches", "space X apart", "X\" apart" → `seedSpacingInches`
- **Days:** match "X days to germination", "harvest in X days", "matures in X days"
- **Brand:** first line or largest text block often contains brand name
- **Variety:** second largest text or text near "variety:" label

This is best-effort — the user always reviews and corrects. The scanner saves time, not replaces judgment.

---

## Testing Strategy

### Unit Tests (GrowWiseServicesTests)

- `SeedRepositoryTests` — CRUD operations, search, fetch by plant type
- `SeedInventoryServiceTests` — `compatibleSeeds` filtering logic, `readyToPlant` seasonal logic, `suggestPlantDatabaseLink` fuzzy matching
- `SeedScannerServiceTests` — text parsing heuristics against sample packet text

### Feature Tests (GrowWiseFeatureTests)

- `SeedInventoryViewTests` — list rendering, search filtering, navigation
- `AddSeedSheetTests` — form validation, plant database link suggestion

### In-memory DataService

All tests use `DataService.makeForTesting()` — no CloudKit dependency.
