# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Key Documents

- **`docs/architecture/ADR.md`** — Architecture Decision Records. Read before making structural changes. Append when making new decisions.
- **`AGENTS.md`** — Project conventions, architecture overview, build commands.
- **`docs/product/gardening-app-prd.md`** — Product Requirements Document.
- **`docs/superpowers/specs/2026-03-09-full-ui-redesign-design.md`** — Full UI redesign spec (current design language).

## Project Overview

GrowWise (branded **Cultivation**) is an iOS gardening companion app that helps users track plants, manage gardens, set care reminders, keep a plant journal, and learn through tutorials.

**Target Platform**: iOS 17+ (macOS 14+ secondary)
**Architecture**: Strict MV (Model-View) — NO ViewModels (see ADR-002, exception in ADR-015)
**Language**: Swift 6 with strict concurrency
**Persistence**: SwiftData with CloudKit sync
**UI**: SwiftUI with `@Observable` services
**Design**: CultivationTheme — clean minimal + premium glass-morphism

## Architecture: Strict MV

**No ViewModel classes.** Views consume `@Observable` services directly via `@Environment`. Business logic lives in service/manager objects. See ADR-002.

**Exception:** `GardenViewModel` and `HomeViewModel` exist as `@Observable` + `@MainActor` classes that orchestrate complex grouped data assembly. They are NOT MVVM — they do not own business logic, they aggregate and transform data for display. See ADR-015.

```swift
// ✅ Standard pattern — service injected via @Environment
struct PlantDetailView: View {
    @Environment(DataService.self) private var dataService
    @State private var isEditing = false
}

// ✅ Acceptable — data aggregation helper, not MVVM
@MainActor @Observable final class GardenViewModel {
    var groupedPlants: [PlantGroup] = []
    func load(dataService: DataService) async { ... }
}

// ❌ Never — MVVM ViewModel with business logic
class PlantDetailViewModel: ObservableObject { ... }
```

## Project Structure

```
GrowWise/                        # App shell (entry point, assets, entitlements)
GrowWisePackage/                 # Core Swift Package
  Sources/
    GrowWiseModels/              # SwiftData @Model classes + enums
    GrowWiseServices/            # @Observable services, actors, managers
    GrowWiseFeature/             # SwiftUI views (strict MV)
      Design/                    # CultivationTheme.swift — single source of truth
      Views/                     # Main screens
        Garden/                  # GardenView, GardenViewModel, GardenHeroHeader,
        │                        #   GardenBedSection, PlantQuickCard
        Home/                    # HomeView, HomeViewModel, HomeHeroHeader
        Journal/                 # JournalView
      Components/                # Reusable UI (ViewModifiers.swift, GardenComponents.swift, ...)
      OnboardingFlow/            # Onboarding wizard (steps, navigation, state)
      Main/MainAppView.swift     # Root 4-tab container
  Tests/
    GrowWiseModelsTests/
    GrowWiseServicesTests/
    GrowWiseFeatureTests/
GrowWiseUITests/                 # Xcode UI tests
docs/                            # ADR, security docs, guides, specs
```

**Dependency graph**: `GrowWiseFeature` → `GrowWiseServices` → `GrowWiseModels`

## Navigation — 4 Tabs

```
MainAppView (TabView)
├── Home       — Task dashboard (today's care tasks, urgency grouped)
├── Garden     — Grouped plant list by bed/area (hero screen, primary tab)
├── Journal    — Timeline of plant journal entries
└── Profile    — Settings + learning tutorials
```

**Garden tab flow:**
1. `GardenHeroHeader` — garden selector chips + plant/alert counts
2. Grouped `LazyVStack` of `GardenBedSection` (plants grouped by `Plant.gardenLocation`)
3. Plant tap → `PlantQuickCard` bottom sheet (`.medium`/`.large` detents)
4. "View Full Details" → dismisses sheet, sleeps 350ms, pushes `PlantDetailView` via `navigationDestination(item:)`
5. "Add Bed or Area" → alert for name → pre-fills `AddPlantSheet(locationPreset:)`

## Design System — CultivationTheme

**Single source of truth:** `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

Design language: **Clean Minimal + Premium** with glass-morphism.

```swift
// Colors
CultivationTheme.Colors.background        // #0C0C0C adaptive dark
CultivationTheme.Colors.backgroundSecondary
CultivationTheme.Colors.cardSurface       // rgba(255,255,255,0.04)
CultivationTheme.Colors.brandLeaf         // CTA green
CultivationTheme.Colors.brandForest
CultivationTheme.Colors.textPrimary / .textSecondary / .textTertiary
CultivationTheme.Colors.statusAlert       // #FF453A
CultivationTheme.Colors.statusWarning     // #FFD60A
CultivationTheme.Colors.statusHealthy     // #30D158

// Spacing
CultivationTheme.Spacing.screenPadding    // 20
CultivationTheme.Spacing.cardPadding      // 16
CultivationTheme.Spacing.sectionGap       // 24

// Radius
CultivationTheme.Radius.card              // 16
CultivationTheme.Radius.chip              // 20

// Animation
CultivationTheme.Animation.spring         // spring(duration:0.4, bounce:0.2)
CultivationTheme.Animation.snappy         // spring(duration:0.25, bounce:0.1)

// CTA gradient
CultivationTheme.Gradients.ctaGradient    // #2d6a4f → #52b788
```

## Shared UI Components

**`ViewModifiers.swift`** — Glass-morphism building blocks:
- `.glassCard()` — `rgba(255,255,255,0.04)` fill + `.ultraThinMaterial` + 1px border + 16pt radius
- `GlassPill` — chip/toggle selector with tinted background
- `IconBubble(systemName:color:size:iconSize:)` — rounded square icon bubble
- `StatusDot(status:)` — colored health status dot
- `GradientButtonStyle()` — full-width CTA button with brand gradient
- `QuickStatCard` — compact stat display used in quick cards

**`GardenComponents.swift`** — Garden-specific reusables:
- `PlantRow(plant:onTap:)` — single plant row with health indicator + care countdown
- `BedGroupHeader(group:)` — bed section header with plant count badge
- `CompanionTipCard` — companion planting suggestion card
- `TaskRow` — care task item for Home tab

**`StatCard.swift`** — Garden statistics card
**`GardenHeroHeader.swift`** — Hero header with garden picker + alert badge
**`GardenBedSection.swift`** — Collapsible bed section (header + plant list)
**`PlantQuickCard.swift`** — Bottom sheet card (water/prune/log/details actions)

## Build & Test

> **CRITICAL:** NEVER run `xcodebuild test` on this machine. Tests MUST run on the mac-mini via SSH.

```bash
# Build verification (safe to run locally — build only, no tests)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"

# Swift package tests (unit tests, fast)
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"

# Specific test target
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter GrowWiseServicesTests 2>&1 | tail -20"

# UI tests
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -30"
```

## Conventions

- **No ViewModels** — strict MV; use `GardenViewModel` pattern only for complex grouping/aggregation (ADR-015)
- **@Observable** over `ObservableObject` — modern observation, never `@Published`
- **@State** over `@StateObject` — `@State private var viewModel = GardenViewModel()`
- **SwiftData** over CoreData — all `@Model` properties optional for CloudKit
- **Swift Testing** (`@Test`, `#expect`) for new tests, XCTest can coexist
- **async/await** over completion handlers or Combine
- **@MainActor** on UI-bound services; actors for concurrent state
- **os.Logger** with `.private` for user data — never `print()`
- **Every interactive element** needs `.accessibilityIdentifier("screen_element_descriptor")`
- **Files in appropriate subdirs** — never save to root folder
- **No silent `try?` in views** — user-facing operations must surface errors via alerts (ADR-007)
- **Test-friendly services** — system-dependent services must provide test init/factory (ADR-008)
- **`.sheet` over `navigationDestination`** for views that own their own `NavigationStack` (ADR-012)
- **`locationPreset` pattern** for pre-filling contextual sheets (ADR-013)

## Accessibility Identifiers

Required on ALL interactive elements. Pattern: `{screen}_{element}_{descriptor}`.

```swift
Button("Save") { }
    .accessibilityIdentifier("settings_button_save")
TextField("Name", text: $name)
    .accessibilityIdentifier("profile_textfield_name")
Toggle("Notifications", isOn: $enabled)
    .accessibilityIdentifier("settings_toggle_notifications")
ForEach(items) { item in
    ItemRow(item: item)
        .accessibilityIdentifier("home_cell_item_\(item.id)")
}
```

Key identifiers currently in use:
- `garden_view`, `garden_loading_indicator`, `garden_button_addbed`, `garden_button_addplant_empty`
- `garden_alert_textfield_bedname`
- `quickcard_sheet`, `quickcard_button_water`, `quickcard_button_prune`, `quickcard_button_log`, `quickcard_button_viewdetails`
- `addplant_*`, `addreminder_*`, `journal_*`, `profile_*`

## Issue Tracking

This project uses **bd (beads)** for issue tracking.

```bash
bd ready              # Find unblocked work
bd show <id>          # View details
bd create --title="..." --type task --priority 2
bd update <id> --status in_progress
bd close <id>
bd dolt push          # Sync to remote
```

## Testing

Test targets:
- **GrowWiseModelsTests** — Plant, Garden, User, PlantReminder, JournalEntry, SoilLog, GardeningStats, SecureCredentials
- **GrowWiseServicesTests** — CompanionPlanting, Location, Subscription, Reminder, Validation, CloudSync, DataService, CacheManager, BackgroundTaskManager, PlantDatabaseService, TutorialService, NotificationService
- **GrowWiseFeatureTests** — Basic view instantiation, GardenRepositoryTests
- Security test files (Keychain, JWT, Encryption) are **excluded from Package.swift** — gated behind `KEYCHAIN_TESTS_ENABLED=1`
- Several UI tests are **skipped** (`XCTSkip`) due to the full UI redesign changing navigation and hero headers

```bash
# In-memory DataService for tests
let service = try await DataService.makeForTesting()
```

## Quality Gates

```bash
# SwiftLint — must pass before commit
swiftlint lint --strict --config .swiftlint.yml
swiftlint lint --fix --config .swiftlint.yml   # auto-fix

# SwiftFormat — must pass before commit
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise   # check
swiftformat --config .swiftformat GrowWisePackage/Sources GrowWise          # fix

# Pre-commit hooks — already installed; runs lint + format + beads automatically
# If hooks broken: bd hooks install
```

## CloudKit & Background Tasks

**CloudKit container:** `iCloud.com.growwise.gardening` — used consistently in:
- `GrowWise/GrowWise.entitlements` → `com.apple.developer.icloud-container-identifiers`
- `ModelContainerFactory.make()` → `cloudKitDatabase: .private("iCloud.com.growwise.gardening")`
- `CloudSyncService.init()` → `CKContainer(identifier: "iCloud.com.growwise.gardening")`

If you ever change the container identifier, update all three places or CloudKit sync silently breaks.

**BGTaskSchedulerPermittedIdentifiers:** `Info.plist` declares `com.apple.coredata.cloudkit.private.push`. SwiftData's `NSPersistentCloudKitContainer` submits background tasks under this identifier internally. Without it, every sync attempt is rejected and retried until hitting the 10-request system cap, producing `BGSystemTaskSchedulerErrorDomain Code=8 (tooManyPendingTaskRequests)` on real devices.

**Push notifications entitlement:** The `aps-environment` key in `GrowWise.entitlements` is commented out — uncomment (set to `"development"` or `"production"`) once push notifications are enabled in the App ID on the developer portal.

## Known Gotchas

- **Nested NavigationStack:** `TutorialsView` has its own `NavigationStack`. Always present via `.sheet`, never push via `navigationDestination` — the latter causes silent navigation failure. See ADR-012.
- **Sheet → push timing:** When dismissing a `.sheet` and then pushing via `navigationDestination`, the push must be delayed ~350ms or it is silently dropped by SwiftUI. See ADR-014 and `GardenView`.
- **SwiftData `modelContext.insert()` doesn't throw:** Don't put `dismiss()` in a `catch` block after insert — it will never be called. Call `dismiss()` explicitly after insert succeeds. This was a real bug in `AddPlantSheet`.
- **`@Observable` + `@State` initialization:** When an `@Observable` class needs a default value from an init parameter, use `_property = State(initialValue: value)` inside `init`. Do NOT use `@StateObject` — it's not available with `@Observable`.
- **SourceKit false positives:** The development machine's SourceKit may show spurious errors that don't reflect actual build state. Always confirm with a real build on mac-mini via SSH before treating an error as real.
- **CloudKit in UI tests:** `CKContainer` crashes on simulators without iCloud entitlements. `CloudSyncService.init()` and `DataService` both guard on `--uitesting` launch argument to skip CloudKit initialization during tests.
- **Security services are overbuilt:** The JWT, KeychainManager, and encryption layer were designed for a more sensitive app. They work but may be simplified in a future refactor — don't add complexity to them without discussion.

## Current State

Full UI redesign complete (March 2026). 4-tab navigation, CultivationTheme design system, glass-morphism throughout. Core features: gardens, plants, reminders, journal, tutorials, onboarding. See beads for tracked work.
