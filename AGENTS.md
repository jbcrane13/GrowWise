# PROJECT KNOWLEDGE BASE

**Updated:** 2026-03-10
**Status:** Post full-UI-redesign (March 2026)

## Agent Readiness

Before starting work, read **`docs/architecture/CLAUDE.md`** for current conventions and **`docs/architecture/ADR.md`** for architecture decisions.

| Resource | Location | Purpose |
|----------|----------|---------|
| Architecture guide | `docs/architecture/CLAUDE.md` | Build commands, conventions, design system |
| ADRs | `docs/architecture/ADR.md` | Architecture decisions with rationale |
| Design spec | `docs/superpowers/specs/2026-03-09-full-ui-redesign-design.md` | Full UI redesign specification |
| PRD | `docs/product/gardening-app-prd.md` | Product requirements |

## OVERVIEW

GrowWise (branded **Cultivation**) is an iOS gardening companion app (iOS 17+) using Swift 6 strict concurrency, SwiftData with CloudKit sync, and SwiftUI. After a full UI redesign (March 2026), it uses a 4-tab navigation structure with a premium glass-morphism design language defined by `CultivationTheme`.

## STRUCTURE

```
GrowWise/                    # App shell (entry point, assets, info.plist, CloudKit schemas)
GrowWisePackage/             # Core Swift Package (all logic)
  Sources/
    GrowWiseModels/          # @Model classes, Enums (no dependencies, CloudKit-ready)
    GrowWiseServices/        # Business logic, security, CloudKit (@Observable, Actors)
    GrowWiseFeature/         # SwiftUI views (Strict MV architecture)
      Design/                # CultivationTheme.swift — single source of truth for all tokens
      Views/
        Garden/              # GardenView, GardenViewModel, GardenHeroHeader,
        │                    #   GardenBedSection, PlantQuickCard
        Home/                # HomeView, HomeViewModel, HomeHeroHeader
        Journal/             # JournalView
      Components/            # Shared UI: ViewModifiers.swift, GardenComponents.swift,
      │                      #   StatCard.swift
      OnboardingFlow/        # Onboarding wizard
      Main/MainAppView.swift # Root 4-tab TabView
  Tests/
    GrowWiseModelsTests/     # Model generation & defaults tests
    GrowWiseServicesTests/   # Logic and service tests
    GrowWiseFeatureTests/    # View and integration tests (GardenRepositoryTests)
GrowWiseUITests/             # Xcode UI tests (some skipped post-redesign)
docs/                        # ADRs, specs, runbooks, security docs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| UI / Screens | `GrowWiseFeature/Views/` | 4-tab: Home, Garden, Journal, Profile |
| Design tokens | `GrowWiseFeature/Design/CultivationTheme.swift` | Colors, spacing, radius, animation, gradients |
| Shared UI components | `GrowWiseFeature/Components/ViewModifiers.swift` | GlassCard, GlassPill, IconBubble, StatusDot, GradientButtonStyle |
| Garden components | `GrowWiseFeature/Components/GardenComponents.swift` | PlantRow, BedGroupHeader, CompanionTipCard, TaskRow |
| Garden hero/bed | `GrowWiseFeature/Views/Garden/` | GardenHeroHeader, GardenBedSection, PlantQuickCard |
| Data / Persistence | `GrowWiseModels/` | SwiftData models, all properties optional |
| Business logic / Auth | `GrowWiseServices/` | DataService, KeychainManager, NotificationService, etc. |
| App entry point | `GrowWise/` | MainAppView init, CloudKit schemas |
| Tests | `GrowWisePackage/Tests/` | Swift Testing (`@Test`) + XCTest |

## NAVIGATION — 4 TABS

```
MainAppView (TabView)
├── Home    — Task dashboard (today's care tasks, grouped by urgency)
├── Garden  — Hero screen: plant list grouped by bed/area (primary feature tab)
├── Journal — Timeline of plant journal entries
└── Profile — Settings + learning tutorials
```

**Garden tab detail:**
- `GardenHeroHeader`: garden selector chips + total plant count + alert badge
- Grouped `LazyVStack`: plants grouped by `Plant.bed` (`GardenBed?` — nil = "Unassigned" section)
- Plant tap → `PlantQuickCard` bottom sheet → "View Full Details" → `PlantDetailView` push
- "Add Container" → `CreateBedSheet` → saves `GardenBed` linked to selected `Garden`
- `AddPlantSheet`: garden picker → bed picker (or inline "New Garden"/"New Container" creation)
- Long-press plant row → context menu → "Delete Plant"

## DESIGN SYSTEM — CultivationTheme

**File:** `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

Design language: **Clean Minimal + Premium** with glass-morphism.

Key tokens:
- Background: `#0C0C0C` (adaptive dark/light)
- Card surface: `rgba(255,255,255,0.04)` + `.ultraThinMaterial` + 1px border
- CTA gradient: `#2d6a4f → #52b788` (brand green)
- Status: alert=`#FF453A`, warning=`#FFD60A`, healthy=`#30D158`
- Typography: `.fontDesign(.rounded)` for headlines/CTAs
- Animations: spring-based throughout

Shared UI components (all in `ViewModifiers.swift`):
- `.glassCard()` — glass-morphism card modifier
- `GlassPill` — chip/toggle selector
- `IconBubble(systemName:color:size:iconSize:)` — tinted icon bubble
- `StatusDot(status:)` — health status indicator
- `GradientButtonStyle()` — full-width CTA button

## NAMING CONVENTIONS

All naming rules are enforced by SwiftLint (`.swiftlint.yml`). Violations block CI.

### Swift identifiers

| Construct | Convention | Example |
|-----------|------------|---------|
| Types, structs, classes, enums, protocols | `UpperCamelCase` | `GardenBed`, `BedType`, `DataService` |
| Enum cases | `lowerCamelCase` | `raisedBed`, `planterBox` |
| Enum raw values (String) | `snake_case` | `"raised_bed"`, `"planter_box"` |
| Functions and methods | `lowerCamelCase` | `loadGardens()`, `savePlant()` |
| Properties and variables | `lowerCamelCase` | `selectedBed`, `availableGardens` |
| Constants | `lowerCamelCase` (Swift style) | `brandLeaf`, `screenPadding` |
| Generic type parameters | Single `UpperCamelCase` letter or short noun | `T`, `Content`, `Element` |
| Acronyms in names | Treat as single word | `urlString` not `URLString`; `id` not `ID` |

### File naming

| Content | Convention | Example |
|---------|------------|---------|
| SwiftUI View | `UpperCamelCase` matching the primary type | `GardenView.swift`, `CreateBedSheet.swift` |
| `@Model` class | `UpperCamelCase` matching the type | `GardenBed.swift`, `Plant.swift` |
| `@Observable` service | `UpperCamelCase` + `Service` suffix | `DataService.swift`, `NotificationService.swift` |
| ViewModel | `UpperCamelCase` + `ViewModel` suffix | `GardenViewModel.swift` |
| Test file | Mirrors source file + `Tests` suffix | `GardenViewModelTests.swift` |

### Accessibility identifiers

Pattern: `{screen}_{element}_{descriptor}` — all `snake_case`.

```swift
// Good
.accessibilityIdentifier("garden_button_addbed")
.accessibilityIdentifier("addplant_textfield_name")
.accessibilityIdentifier("moveplant_bed_unassigned")

// Bad — wrong case, wrong separator
.accessibilityIdentifier("gardenButtonAddBed")
.accessibilityIdentifier("add-plant-text-field")
```

### SwiftData model properties

All `@Model` properties use `lowerCamelCase` and are optional for CloudKit compatibility:

```swift
// Good
public var gardenType: GardenType?
public var createdDate: Date?

// Bad — wrong case
public var GardenType: GardenType?
public var created_date: Date?
```

### Enforced by SwiftLint

- `identifier_name` — enforces `lowerCamelCase` for variables/functions, min length 2
- `type_name` — enforces `UpperCamelCase` for types, min length 3
- `modifier_order` — consistent modifier ordering (`public nonisolated static`)
- Custom `no_print_statements`, `todo_with_issue`, `fixme_with_issue` rules

---

## CONVENTIONS

- **Architecture:** Strict MV (Model-View). NO ViewModels (ADR-002). Exception: `GardenViewModel`/`HomeViewModel` for complex data grouping (ADR-015).
- **State:** `@State private var viewModel = GardenViewModel()` (not `@StateObject`)
- **Services:** Injected via `@Environment(Service.self)` — never instantiated locally in views
- **Observation:** `@Observable` only — never `ObservableObject`/`@Published`
- **Concurrency:** `@MainActor` for UI-bound services; Actors for concurrent state; `async/await`
- **Persistence:** SwiftData. All `@Model` properties optional or have defaults for CloudKit compatibility
- **Navigation:** `.sheet` for views that own their own `NavigationStack`; `navigationDestination(item:)` for standard pushes (ADR-012)
- **Error Handling:** No silent `try?` in views (ADR-007). `do/catch` with error state + alert for user-facing ops
- **Security:** Custom encryption stack (KeychainStorageService, SecureEnclaveKeyManager, KeyRotationManager) — may simplify in future
- **Issue Tracking:** Use `bd` (beads) — `bd ready`, `bd show`, `bd close`, `bd dolt push`

## ANTI-PATTERNS (DO NOT DO)

- **DO NOT** create `ObservableObject`/`@Published` ViewModels
- **DO NOT** use `@StateObject` — use `@State`
- **DO NOT** use `DispatchQueue` — use `async/await`
- **DO NOT** use `CoreData` — use SwiftData
- **DO NOT** hard-code colors, spacing, or radii — use `CultivationTheme.*`
- **DO NOT** use `.navigationDestination` for views that own their own `NavigationStack` (use `.sheet`)
- **NEVER** force-unwrap optionals (`plant.name!`)
- **NEVER** crash on init failure — multi-level fallback pattern
- **DO NOT** save files to root folder — place inside appropriate package target
- **DO NOT** initialize services locally in views — inject via `@Environment`
- **DO NOT** use `print()` — use `OSLog.Logger` with privacy annotations
- **DO NOT** run `xcodebuild test` locally — always SSH to mac-mini

## BUILD & TEST COMMANDS

> **CRITICAL:** Tests run on mac-mini via SSH, never locally.

```bash
# Build verification
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"

# Swift package tests (fast)
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"

# SwiftLint
swiftlint lint --strict --config .swiftlint.yml
swiftlint lint --fix --config .swiftlint.yml

# SwiftFormat
swiftformat --config .swiftformat GrowWisePackage/Sources GrowWise

# Beads sync
bd dolt push
```

## TOOLING & QUALITY GATES

- **SwiftLint** — `.swiftlint.yml` in root. Runs via pre-commit hook.
- **SwiftFormat** — `.swiftformat` in root. Runs via pre-commit hook.
- **Pre-commit hooks** — beads hook + quality hook chained. If broken: `bd hooks install`
- **CI** — `.github/workflows/ci.yml` runs lint, format, tests, tech debt scan
- **Deploy** — `.github/workflows/deploy.yml` — triggered on `v*` tag push

## ACCESSIBILITY

**Mandatory:** Every interactive element MUST have `.accessibilityIdentifier("screen_element_descriptor")`.

Pattern: `{screen}_{element}_{descriptor}` (e.g., `garden_button_addbed`, `quickcard_button_water`)

No identifier = rejected.

## ENVIRONMENT & SECURITY

- No runtime secrets needed for local development — all secrets managed via iOS Keychain on-device
- See `.env.example` for Apple developer account configuration
- **Never log PII** — `OSLog.Logger` with `.private`/`.sensitive` annotations
- All security events through `AuditLogger`
- See `docs/security/` for full security documentation

## TECH DEBT TRACKING

TODOs must reference a beads issue:
```swift
// TODO(GW-123): description of what needs doing
// FIXME(GW-456): description of the problem
```

## DEPLOYMENT & OBSERVABILITY

- **Deploy target:** TestFlight → App Store
- **Crashes:** App Store Connect → TestFlight / Xcode Organizer
- **CloudKit:** CloudKit Console
- **Error tracking:** Sentry (integrated in GrowWiseServices)
- **Analytics:** Amplitude (integrated in GrowWiseServices)
- **Runbooks:** `docs/runbooks/` — CloudKit sync, Keychain loss, crash on launch, migration failure

## SESSION CLOSE PROTOCOL

Before ending a session:
1. `git status` — verify what changed
2. `git add <files>` — stage code changes
3. `git commit -m "..."` — commit
4. `git push` — push to remote (mandatory)
5. `bd dolt push` — sync beads
