# Architecture Decision Records — GrowWise (Cultivation)

A running log of significant architecture and design decisions. Both Daneel (OpenClaw) and Claude Code sessions should consult this before making structural changes, and append new entries when decisions are made.

**Format:** Date → Decision → Context → Consequences

---

## ADR-001: Workspace + SPM package architecture
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Xcworkspace with a minimal app shell (`GrowWise/`) and all feature code in a local SPM package (`GrowWisePackage/`).  
**Context:** Clean separation between app lifecycle and feature code. SPM packages build faster, test independently, and reduce xcodeproj conflicts.  
**Consequences:**
- Open `GrowWise.xcworkspace` (not `.xcodeproj`)
- `GrowWisePackage/Sources/GrowWiseFeature/` is where most development happens
- App target just imports and displays the package
- Xcode 16 buildable folders — files added to filesystem auto-appear

---

## ADR-002: No ViewModels — pure SwiftUI state management
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Use `@Observable` directly in views without separate ViewModel classes. Embrace SwiftUI's native state management.  
**Context:** Modern SwiftUI with `@Observable` (iOS 17+) makes ViewModels largely redundant for most screens. Reduces boilerplate and indirection.  
**Consequences:**
- `@Observable` classes for shared state
- `@State` for view-local state
- No MVVM pattern — views consume observable objects directly
- Complex business logic lives in service/manager objects, not ViewModels
- **Exception:** GardenViewModel and HomeViewModel exist as data aggregators (see ADR-015)

---

## ADR-003: Swift 6+ strict concurrency
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Swift 6 language mode with modern async/await concurrency.  
**Context:** Consistent with all Blake's projects. Prevents data races at compile time.  
**Consequences:**
- `async/await` over legacy patterns (completion handlers, Combine)
- Actor isolation for concurrent state
- All cross-boundary types must be Sendable
- `Task<Void, Never> { }` in Button actions (Swift 6 requirement)
- `didSet` in `@Observable` causes init ambiguity — use explicit setter helpers

---

## ADR-004: Swift Testing framework over XCTest
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Prefer Swift Testing (`@Test`, `#expect`) over XCTest for new tests.  
**Context:** Swift Testing is the modern replacement — more expressive, better diagnostics, parameterized tests built in.  
**Consequences:**
- New tests use `import Testing` and `@Test` macro
- Existing XCTest tests coexist
- 50 test files, 647 tests passing as of April 2026
- Key path shorthand in `#expect` can cause throwing expansion issues — use explicit closures

---

## ADR-005: JWT-based authentication
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** JWT for authentication with secure keychain storage.  
**Context:** App requires user authentication. JWT is stateless and works well with REST APIs.  
**Consequences:**
- KeychainService for secure token storage
- BiometricService for Face ID / Touch ID
- Security audit completed

---

## ADR-006: iOS 18+ with optional iOS 26 features
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Target iOS 18+ as minimum, with optional adoption of iOS 26 APIs where available.  
**Context:** Balance between reach and modern API usage. iOS 18 gives us `@Observable`, latest SwiftUI features.  
**Consequences:**
- `@available(iOS 26, *)` guards for newest APIs
- Core functionality works on iOS 18+
- Liquid Glass and other iOS 26 features are progressive enhancements
- `WindowGroup("Title", content: { ... })` explicit syntax required for macOS 26 SDK ambiguity

---

## ADR-007: No silent `try?` for user-facing operations
**Date:** 2026-02-25  
**Status:** Active  
**Decision:** User-facing operations must use `do/catch` with error surfacing (alerts/state), never `try?`. Non-critical background operations may use `try?` with a comment.  
**Context:** Audit found 29 `try?` operations silently swallowing errors. Users saw no feedback on failures. Fixed across community, subscription, and reminder flows (#116–#121).  
**Consequences:**
- All `try?` in views must have explicit comment justifying silent failure, OR be converted to `do/catch`
- Views performing save/create/delete must have `@State private var showingError` + `.alert`
- Print-only error handling is not acceptable for user-facing operations

---

## ADR-008: Service testability patterns — injectable dependencies
**Date:** 2026-02-25  
**Status:** Active  
**Decision:** Services depending on system frameworks must provide test-friendly initialization paths.  
**Context:** `DataService` crashed in tests due to `CKContainer.default()`. `NotificationService` crashed without app bundle.  
**Consequences:**
- `DataService.makeForTesting()` — in-memory SwiftData without CloudKit
- `NotificationService(notificationCenter: nil)` — avoids crash in package tests
- `ReminderService` accepts `WeatherAdjustmentProviding` protocol for mock weather
- Mark gaps with `// INTEGRATION GAP:` comments

---

## ADR-009: Tab navigation redesign (was 7 → 4 → 5 tabs)
**Date:** 2026-03-09  
**Updated:** 2026-03-27  
**Status:** Active  
**Decision:** 5-tab navigation: Home, Garden, Journal, Reminders, Profile.  
**Context:** Original 7-tab layout was confusing. Redesigned to 4 tabs (Mar 9), then added dedicated Reminders tab (#125, #128) for a total of 5.  
**Consequences:**
- `MainAppView` uses a 5-item `TabView` with coral accent tint
- Garden is the primary tab; plants are the central data type
- Reminders has its own `NavigationStack` wrapper
- Tutorials moved under Profile (presented via `.sheet` per ADR-012)
- Home is a care task dashboard with weather, health score, seasonal planner

---

## ADR-010: CultivationTheme — centralized design token system
**Date:** 2026-03-09  
**Updated:** 2026-03-12 (Botanical Field Journal palette)  
**Status:** Active  
**Decision:** All design tokens in `CultivationTheme.swift`. Views reference tokens, never hard-coded values.  
**Context:** Centralized system ensures visual consistency and enables one-place theme changes.  
**Consequences:**
- `CultivationTheme.Colors.*`, `Spacing.*`, `Radius.*`, `Animation.*`, `Gradients.*`
- **Botanical Field Journal** palette: stone/sage bed colors, coral accents (`accentCoral`), serif titles
- Dark `#0C0C0C` background, glass-morphism cards
- Shared components: `.glassCard()`, `GlassPill`, `IconBubble`, `StatusDot`, `GradientButtonStyle`, `QuickStatCard`
- Status colors: Apple system palette (alert `#FF453A`, warning `#FFD60A`, healthy `#30D158`)

---

## ADR-011: gardenLocation as String field — no GardenBed model entity
**Date:** 2026-03-09  
**Status:** Active  
**Decision:** Garden beds represented as free-text `gardenLocation: String?` on `Plant`, grouped in UI. `GardenBed` model exists but the string-grouping UX is primary.  
**Context:** String grouping avoids migration complexity for simple grouped-list UX.  
**Consequences:**
- `GardenViewModel.rebuildGroups()` groups by `plant.gardenLocation`
- `PlantGroup` is non-persisted struct
- Nil/empty falls into "Ungrouped"
- "Add Bed or Area" captures name → pre-fills `AddPlantSheet(locationPreset:)`

---

## ADR-012: .sheet over navigationDestination for views with own NavigationStack
**Date:** 2026-03-09  
**Status:** Active  
**Decision:** Present views with their own `NavigationStack` as `.sheet`, not via `navigationDestination`.  
**Context:** Nested `NavigationStack` causes silent navigation failures.  
**Consequences:**
- `TutorialsView` presented via `.sheet` from Profile
- General SwiftUI constraint: never nest NavigationStack

---

## ADR-013: locationPreset pattern for contextual sheet pre-filling
**Date:** 2026-03-09  
**Status:** Active  
**Decision:** `AddPlantSheet.init(locationPreset:)` uses `State(initialValue:)` for one-time defaults.  
**Context:** After "Add Bed" captures a name, the sheet should default to it without parent-child binding coupling.  
**Consequences:**
- Pattern reusable for any sheet needing contextual defaults
- `GardenView` clears preset on dismiss via `.onDisappear`

---

## ADR-014: Sheet-to-push navigation with delay for PlantDetailView
**Date:** 2026-03-09  
**Status:** Active  
**Decision:** Dismiss PlantQuickCard sheet → 350ms delay → push PlantDetailView via `navigationDestination`.  
**Context:** SwiftUI silently drops pushes during sheet dismiss animation.  
**Consequences:**
- `GardenView` maintains `@State private var plantToNavigate: Plant?`
- 350ms hardcoded delay — may need adjustment in future iOS versions
- `try?` acceptable here (non-user-facing timing)

---

## ADR-015: GardenViewModel & HomeViewModel exception to strict MV rule
**Date:** 2026-03-09  
**Updated:** 2026-03-27  
**Status:** Active  
**Decision:** `GardenViewModel` and `HomeViewModel` exist as `@Observable @MainActor` data aggregator classes.  
**Context:** Garden and Home tabs require complex multi-source data aggregation that would make views unwieldy.  
**Consequences:**
- NOT MVVM — no business logic, no service calls beyond fetching
- Instantiated via `@State private var viewModel = GardenViewModel()`
- `DataService` passed as parameter, not stored
- HomeViewModel manages care tasks grouped by urgency, inline quick-care with contextual icons (#144), garden health score (#142)
- Only acceptable for tabs with complex aggregation; simple views must remain pure MV

---

## ADR-016: Test execution via SSH to mac-mini
**Date:** 2026-03-09  
**Status:** Active  
**Decision:** All `xcodebuild test` and `swift test` must run on mac-mini via SSH.  
**Context:** Primary machine is gateway/orchestration host. SourceKit shows false positives locally.  
**Consequences:**
- `ssh mac-mini "cd ~/Projects/GrowWise && <command>"`
- SwiftLint/SwiftFormat can run locally (no compilation)
- Never trust local SourceKit errors — build on mac-mini to confirm

---

## ADR-017: Botanical Field Journal design language
**Date:** 2026-03-12  
**Status:** Active  
**Decision:** Adopt "Botanical Field Journal" as the app's design language — serif typography, warm earth tones, coral accents.  
**Context:** Previous design used generic system fonts and teal/green gradients. The field journal aesthetic creates a distinctive premium feel that matches the gardening domain.  
**Consequences:**
- Serif fonts for titles and plant names (committed in c9d68b2 through 48a3d1f)
- Stone/sage bed colors in GardenCardView
- Coral accent (`CultivationTheme.Colors.accentCoral`) for FAB, tab tint, buttons
- Seasonal context in Home hero header
- All new UI must follow this language — no system defaults or tech-teal gradients

---

## ADR-018: Inline quick-care buttons with contextual icons
**Date:** 2026-04-02  
**Status:** Active  
**Decision:** TaskRow "Done" button shows contextual care icons instead of a generic checkmark.  
**Context:** Users need visual feedback that connects the completion action to the care type (watering vs fertilizing vs pruning). Generic checkmarks don't communicate what was done.  
**Consequences:**
- 💧 Drop icon (blue) for watering tasks
- 🌿 Leaf icon (green) for fertilizing tasks
- ✂️ Scissors icon (orange) for pruning tasks
- ✓ Checkmark (gray) for other task types
- `HomeViewModel.complete` updates `plant.lastWatered` / `lastFertilized` / `lastPruned` dates accordingly
- Checkmark feedback animation on tap (#144)

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
