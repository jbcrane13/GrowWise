# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GrowWise (branded **Cultivation**) is an iOS gardening companion app — plant tracking, garden management, care reminders, plant journal, sharing-first Garden Club, and tutorials. iOS 17+ primary, macOS 14+ secondary. Swift 6 strict concurrency, SwiftData + CloudKit, SwiftUI.

**Status:** Cultivation 1.0 RC on TestFlight (build 1777504517, commit `289ae15`). The visual redesign (cream paper v2) and 4-tab navigation shipped via PR #270.

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
    GrowWiseModels/              # 15 @Model SwiftData classes + enums (no deps)
    GrowWiseServices/            # @Observable services, Repositories/, DataService+*.swift extensions
    GrowWiseFeature/             # SwiftUI views (strict MV)
      Design/                    # CultivationTheme.swift, ViewModifiers.swift, GardenComponents.swift
      Main/MainAppView.swift     # Root 4-tab container
      Views/
        GardenView.swift         # Top-level garden screen
        HomeView.swift           # Top-level home screen
        ProfileView.swift        # Top-level "Me" screen
        Garden/                  # GardenViewModel, GardenHeroHeader, GardenBedSection, PlantQuickCard, seed/shopping/AR sheets
        Home/                    # HomeViewModel, HomeHeroHeader, GardenHealthCardView, SeasonalTipCard, YourClubCard
        GardenClub/              # ClubChatView, ClubEventsView, GardenClubFeedView, ClubShareComposerSheet, GardenClubTabRoute
        Community/               # Forum, ask-question, public garden views (still reachable from Me tab)
        PlantDatabase/           # PerenualBrowseView
        Settings/                # AppSettingsView
        Tutorials/               # TutorialView, TutorialProgressView (presented via .sheet)
      Components/                # FilterChip, PlantCardView, PlantReminderCard, ReadyToPlantCard, StatCard, SuggestedSeedsCard, ValidatedTextField, ReminderRowView, PerenualEnrichmentCard
      OnboardingFlow/            # OnboardingView + Views/ (multi-step wizard)
  Tests/
    GrowWiseModelsTests/
    GrowWiseServicesTests/
    GrowWiseFeatureTests/        # CultivationThemeTests, GardenViewModelTests, HomeViewModelTests, GardenClubFeedRoutingTests, SmartTagTests
GrowWiseUITests/                 # XCUITest — care task flows, onboarding, paywall, etc.
```

**Dependency graph:** `GrowWiseFeature` → `GrowWiseServices` → `GrowWiseModels`

**External deps:** Sentry (error tracking), Amplitude (analytics), swift-docc-plugin

## Navigation — 4 Tabs (ADR-019)

```
MainAppView (TabView, coral accent tint, .paperGrain() overlay)
├── Home       — Care task dashboard + "Your Club" share card
├── Garden     — Hero header → grouped plant list by bed/area → PlantQuickCard → PlantDetailView
├── Club       — GardenClubTabContainer (feed, chat, events) — sharing as a primary pillar
└── Me         — Profile, settings, tutorials, achievements, forum, garden clubs (via navigationDestination)
```

Reminders and Journal are no longer top-level tabs (deleted in ADR-019). Reminder rows live on Home; journal entries render as a photo strip on Plant Detail. The `JournalEntry` and `PlantReminder` models are still present.

**Garden tab flow:** GardenHeroHeader (serif title, selector chips) → grouped LazyVStack of GardenBedSection → plant tap → PlantQuickCard bottom sheet → "View Full Details" → dismisses sheet, 350ms delay, pushes PlantDetailView via navigationDestination(item:).

**Home tab features:** Urgency-grouped tasks with inline quick-care icons (💧/🌿/✂️), weather card, garden health score card, seasonal planner, "Your Club" share card, post-care share prompt.

## Design System — CultivationTheme v2 ("Cream Paper Field Journal")

**Single source of truth:** `GrowWiseFeature/Design/CultivationTheme.swift`

Design language (ADR-019, v2 since 2026-04-20): **Cream paper field journal** — `.system(design: .serif)` display, `.system(design: .rounded)` body, warm cream/ink palette, sage greens, coral accent for actions. Light-first with adaptive dark mode (warm dark, not pure black).

Key tokens:
- `Colors.*` — `background` (`#F6F0E4` cream), `textPrimary` (`#1F2A22` ink), `brandLeaf` (`#7B9069` sage), `brandForest` (`#2E4631` moss), `accentCoral` (`#D9694B`), `accentAmber` (`#C99327` honey), `accentSky` (`#6F94A6`), `statusAlert`/`Warning`/`Healthy`
- `Spacing.*`, `Radius.*` (`card`, `chip`)
- `Animation.*` — `card`, `tab`, `selection`, `sheet`, `entrance` (no more `spring`/`snappy`)
- `Gradients.cta` (moss → sage), `Gradients.warmAccent` (coral → honey)

**Shared components (ViewModifiers.swift):** `.paperCard()` (paper card surface), `.paperGrain()` (subtle texture overlay), `.sectionLabel()`, `.heroBackground()`, `SmartTag`, `IconBubble`, `StatusDot`, `GlassPill`, `QuickStatCard`, `CoralButtonStyle`, `SecondaryButtonStyle`, `GradientButtonStyle`

**Garden components (GardenComponents.swift):** `PlantRow`, `BedGroupHeader`, `CompanionTipCard`, `TaskRow`

**Anti-patterns:** No system font defaults (use serif/rounded explicitly), no dark glass-morphism (deprecated in v2), no teal/purple gradients, no generic tech aesthetics.

## Key Services

| Service | Role |
|---------|------|
| `DataService` | SwiftData coordinator, owns 7 repositories (plants/gardens/reminders/journals/users/stats/seeds), `makeForTesting()` factory. Extended via `DataService+ClubChat`, `+ClubEvents`, `+GardenClub` for club CRUD. |
| `ModelContainerFactory` | Creates persistent or in-memory containers |
| `ReminderService` | Smart scheduling with weather adjustment |
| `NotificationService` | Local notification scheduling, permissions |
| `LocationService` | Hardiness zones, WeatherKit, CLLocationManager |
| `PlantDatabaseService` | 50+ plant JSON database seeding via PlantSeedingWorker |
| `PerenualAPIService` / `PerenualEnrichmentService` | Third-party plant database enrichment |
| `CloudSyncService` | CloudKit private user data + public garden showcase |
| `ClubCloudKitService` | CloudKit sync for shared club content |
| `GardenClubService` | Club membership, feed, smart-match logic |
| `SubscriptionService` | StoreKit 2 in-app purchases (annual + monthly tiers) |
| `ValidationService` | Input validation (Sendable singleton) |
| `KeychainService` / `BiometricService` | Secure storage and Face ID/Touch ID gating |
| `AnalyticsService` / `ObservabilityService` | Amplitude analytics + Sentry traces |
| `FeatureFlagService` | Runtime feature gating |
| `PlantCareAdviceService` | Contextual care tips for plant detail |
| `GardenHealthService` | Garden health score computation |
| `SeasonalPlannerService` | Zone-based seasonal calendar |
| `PlantDiagnosticService` | Plant health diagnostics (Vision-based) |
| `CompanionPlantingService` | Companion-planting compatibility lookups |
| `ShoppingListService` | Shopping list management |
| `SeedInventoryService` / `SeedScannerService` | Seed packet inventory + barcode scan |
| `AchievementService` | 21 achievements, progress milestones |
| `TutorialService` | Tutorial progression and content |
| `ForumService` | Community Q&A forum (CloudKit) |
| `PhotoService` | Plant/journal photo capture and storage |

## SwiftData & CloudKit

15 `@Model` classes: Plant, Garden, User, PlantReminder, JournalEntry, GardenBed, SoilLog, GardeningStats, CompostBatch, ShoppingItem, Seed, GardenClub, ClubActivity, ClubEvent, ClubMessage. All properties optional with defaults for CloudKit compatibility.

**CloudKit container:** `iCloud.com.growwise.gardening` — referenced in 3 places that must stay in sync:
1. `GrowWise/GrowWise.entitlements`
2. `ModelContainerFactory.make()`
3. `CloudSyncService.init()`

**BGTaskScheduler:** Info.plist declares `com.apple.coredata.cloudkit.private.push`. Without it, sync produces `BGSystemTaskSchedulerErrorDomain Code=8` on real devices.

**Push notifications:** The `aps-environment` key in `GrowWise.entitlements` is commented out — uncomment (set to `"development"` or `"production"`) once push notifications are enabled in the App ID on the developer portal.

## Testing

Uses **Swift Testing** (`@Test`, `@Suite`, `#expect`, `#require`). XCTest coexists.

```swift
// In-memory DataService for tests (avoids CloudKit entitlement crash)
let service = try await DataService.makeForTesting()
```

**Launch arguments for UI tests:** `--uitesting` (in-memory SwiftData, skip CloudKit), `--skip-onboarding`, `--reset-data`, `--reset-onboarding`

**CI:** `.github/workflows/qa.yml` runs XCUITest flows on PRs (macos-15 runner, iPhone 16 simulator). Local QA flows live in `.factory/skills/qa-ios/`. `ci.yml`, `coverage.yml`, `security.yml`, `docc.yml`, `agent-code-review.yml`, and `droid-wiki-refresh.yml` round out the workflow set.

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

Uses **GitHub Issues** via `gh` CLI. Repo: `jbcrane13/GrowWise`. **Beads (`bd`) is deprecated — do not use it.**

```bash
gh issue list --repo jbcrane13/GrowWise --state open
gh issue create --repo jbcrane13/GrowWise --title "Title" --body "Details" --label "type:feature,priority:medium,status:ready"
gh issue close <number> --repo jbcrane13/GrowWise --comment "Done: summary"
```

Labels: `type:{bug,feature,task,epic,chore}`, `priority:{critical,high,medium,low,backlog}`, `status:{ready,in-progress,blocked,review}`
