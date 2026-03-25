# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GrowWise (branded **Cultivation**) is an iOS gardening companion app — plant tracking, garden management, care reminders, plant journal, and tutorials. iOS 17+ primary, macOS 14+ secondary. Swift 6 strict concurrency, SwiftData + CloudKit, SwiftUI.

## Key Documents

| Resource | Location |
|----------|----------|
| ADRs | `docs/architecture/ADR.md` — read before structural changes, append when making decisions |
| Design spec | `docs/superpowers/specs/2026-03-09-full-ui-redesign-design.md` |
| PRD | `docs/product/gardening-app-prd.md` |

## Build & Test

> **CRITICAL:** NEVER run `xcodebuild test` on this machine. Tests run on mac-mini via SSH.

```bash
# Build the Swift package (fast, local)
cd GrowWisePackage && swift build

# Build the full app (via SSH)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"

# Run all package tests
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"

# Run a specific test target
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter GrowWiseServicesTests 2>&1 | tail -20"

# Run a single test by name
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter 'PlantRepositoryTests/testAddAndFetchPlant' 2>&1 | tail -20"

# UI tests (requires GUI session on mac-mini)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -30"

# SwiftLint
swiftlint lint --strict --config .swiftlint.yml
swiftlint lint --fix --config .swiftlint.yml

# SwiftFormat
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise
swiftformat --config .swiftformat GrowWisePackage/Sources GrowWise
```

Pre-commit hooks run lint + format automatically.

## Architecture: Strict MV (Not MVVM)

**No ViewModel classes.** Views consume `@Observable` services directly via `@Environment`. Business logic lives in service/manager objects (ADR-002).

**Exception:** `GardenViewModel` and `HomeViewModel` exist as `@Observable @MainActor` classes for complex grouped data assembly — they aggregate/transform data for display, NOT own business logic (ADR-015).

```
View (@State/@Binding)
  → Service (@MainActor @Observable, injected via @Environment)
    → Repository (@MainActor, owned by DataService)
      → ModelContext (SwiftData)
```

## Project Structure

```
GrowWise/                        # App shell (entry point, assets, entitlements)
GrowWisePackage/                 # All development happens here
  Sources/
    GrowWiseModels/              # SwiftData @Model classes + enums (no deps)
    GrowWiseServices/            # @Observable services, repositories, managers
    GrowWiseFeature/             # SwiftUI views (strict MV)
      Design/                    # CultivationTheme.swift — single source of truth
      Views/{Garden,Home,Journal,Community,Tutorials}/
      Components/                # ViewModifiers.swift, GardenComponents.swift, StatCard
      OnboardingFlow/            # 7-step onboarding wizard
      Main/MainAppView.swift     # Root TabView (Home, Garden, Journal, Profile)
  Tests/
    GrowWiseModelsTests/
    GrowWiseServicesTests/       # 6 test files excluded from compilation (see Package.swift)
    GrowWiseFeatureTests/
GrowWiseUITests/                 # XCUITest (some skipped post-redesign)
```

**Dependency graph:** `GrowWiseFeature` → `GrowWiseServices` → `GrowWiseModels`

**External deps:** Sentry (error tracking), Amplitude (analytics), swift-docc-plugin

## Navigation — 4 Tabs

```
MainAppView (TabView)
├── Home       — Care task dashboard (today's tasks, urgency grouped)
├── Garden     — Grouped plant list by bed/area (hero header, primary tab)
├── Journal    — Timeline of plant journal entries
└── Profile    — Settings + tutorials
```

**Garden tab flow:** GardenHeroHeader (selector chips) → grouped LazyVStack of GardenBedSection → plant tap → PlantQuickCard bottom sheet → "View Full Details" → dismisses sheet, 350ms delay, pushes PlantDetailView via navigationDestination(item:).

## Design System — CultivationTheme

**Single source of truth:** `GrowWiseFeature/Design/CultivationTheme.swift`

Design language: clean minimal + premium glass-morphism. Dark-first adaptive colors.

Key tokens: `CultivationTheme.Colors.*`, `CultivationTheme.Spacing.*`, `CultivationTheme.Radius.*`, `CultivationTheme.Animation.*`, `CultivationTheme.Gradients.ctaGradient`

**Shared components in ViewModifiers.swift:** `.glassCard()`, `GlassPill`, `IconBubble`, `StatusDot`, `GradientButtonStyle`, `QuickStatCard`

## Key Services

| Service | Role |
|---------|------|
| `DataService` | SwiftData coordinator, owns 6 repositories, `makeForTesting()` factory |
| `ModelContainerFactory` | Creates persistent or in-memory containers |
| `ReminderService` | Smart scheduling with weather adjustment |
| `LocationService` | Hardiness zones, WeatherKit, CLLocationManager |
| `PlantDatabaseService` | 50+ plant JSON database seeding via PlantSeedingWorker |
| `CloudSyncService` | CloudKit private user data + public garden showcase |
| `SubscriptionService` | StoreKit 2 in-app purchases |
| `ValidationService` | Input validation (Sendable singleton) |

## SwiftData & CloudKit

10 `@Model` classes: Plant, Garden, User, PlantReminder, JournalEntry, GardenBed, SoilLog, GardeningStats, CompostBatch, ShoppingItem. All properties optional with defaults for CloudKit compatibility.

**CloudKit container:** `iCloud.com.growwise.gardening` — referenced in 3 places that must stay in sync:
1. `GrowWise/GrowWise.entitlements`
2. `ModelContainerFactory.make()`
3. `CloudSyncService.init()`

**BGTaskScheduler:** Info.plist declares `com.apple.coredata.cloudkit.private.push`. Without it, sync produces `BGSystemTaskSchedulerErrorDomain Code=8` on real devices.

## Testing

Uses **Swift Testing** (`@Test`, `@Suite`, `#expect`, `#require`). XCTest coexists.

```swift
// In-memory DataService for tests (avoids CloudKit entitlement crash)
let service = try await DataService.makeForTesting()
```

**Launch arguments for UI tests:** `--uitesting` (in-memory SwiftData, skip CloudKit), `--skip-onboarding`, `--reset-data`, `--reset-onboarding`

**Excluded test files** (see Package.swift `exclude` list): DataServiceNilSelfTests, DataServiceStorageConfigurationTests, DataServiceTests, DataTransformationServiceTests, NotificationServiceTests, ValidationServiceTests

## Conventions

- **@Observable** over ObservableObject — never `@Published` or `@StateObject`
- **SwiftData** over CoreData — all `@Model` properties optional for CloudKit
- **async/await** over completion handlers or Combine — never `DispatchQueue`
- **`.task { }`** on views for async work, never `Task { }` in `.onAppear`
- **os.Logger** with `.private` for user data — never `print()`
- **Every interactive element** needs `.accessibilityIdentifier("screen_element_descriptor")`
- **No silent `try?` in views** — user-facing operations must surface errors via alerts (ADR-007)
- **`.sheet` over `navigationDestination`** for views that own their own NavigationStack (ADR-012)
- **`locationPreset` pattern** for pre-filling contextual sheets (ADR-013)

## Known Gotchas

- **Nested NavigationStack:** `TutorialsView` has its own NavigationStack. Present via `.sheet` only — pushing via `navigationDestination` causes silent navigation failure (ADR-012).
- **Sheet → push timing:** Dismissing `.sheet` then pushing via `navigationDestination` requires ~350ms delay or the push is silently dropped (ADR-014).
- **`modelContext.insert()` doesn't throw:** Don't put `dismiss()` in a catch block after insert — it never executes. Call `dismiss()` explicitly after insert.
- **SourceKit false positives:** This machine's SourceKit shows spurious errors. Always confirm with a real build via SSH before treating an error as real.
- **CloudKit in tests:** `CKContainer` crashes on simulators without iCloud entitlements. Both `CloudSyncService` and `DataService` guard on `--uitesting` to skip CloudKit init.
- **`WindowGroup("Title") {` ambiguous in macOS 26 SDK** — use `WindowGroup("Title", content: { ... })` explicitly.
- **`didSet` in @Observable** causes init ambiguity — use explicit setter helper.
- **`Task { }` in Button action (Swift 6)** — use `Task<Void, Never> { }`.

## Issue Tracking

Uses **GitHub Issues** via `gh` CLI. Repo: `jbcrane13/GrowWise`.

```bash
gh issue list --repo jbcrane13/GrowWise --state open
gh issue create --repo jbcrane13/GrowWise --title "Title" --body "Details" --label "type:feature,priority:medium,status:ready"
gh issue close <number> --repo jbcrane13/GrowWise --comment "Done: summary"
```

Labels: `type:{bug,feature,task,epic,chore}`, `priority:{critical,high,medium,low,backlog}`, `status:{ready,in-progress,blocked,review}`
