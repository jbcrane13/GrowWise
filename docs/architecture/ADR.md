# Architecture Decision Records — GrowWise

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

---

## ADR-004: Swift Testing framework over XCTest
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Prefer Swift Testing (`@Test`, `#expect`) over XCTest for new tests.  
**Context:** Swift Testing is the modern replacement — more expressive, better diagnostics, parameterized tests built in.  
**Consequences:**
- New tests use `import Testing` and `@Test` macro
- Existing XCTest tests can coexist during migration
- `.xctestplan` configured in project

---

## ADR-005: JWT-based authentication
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** JWT for authentication with secure keychain storage.  
**Context:** App requires user authentication. JWT is stateless and works well with REST APIs.  
**Consequences:**
- Keychain manager for secure token storage (see `docs/KEYCHAIN_MANAGER_SOLUTION.md`)
- JWT implementation guide in `docs/JWT_Implementation_Guide.md`
- Security audit completed (`docs/SECURITY_AUDIT_FINAL.md`)

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

---

## ADR-007: No silent `try?` for user-facing operations
**Date:** 2026-02-25
**Status:** Active
**Decision:** User-facing operations must use `do/catch` with error surfacing (alerts/state), never `try?`. Non-critical background operations (supplementary Keychain preferences, photo loading per-item) may use `try?` with a comment explaining why.
**Context:** Audit found 29 `try?` operations in view code silently swallowing errors. Users would tap "Add Reminder" and see no feedback when it failed. Onboarding completion errors were only logged to console. Journal saves could silently fail. This made features appear broken without any error message.
**Consequences:**
- All `try?` in views must have an explicit comment justifying why silent failure is acceptable, OR be converted to `do/catch` with error state
- Views that perform save/create/delete operations must have `@State private var showingError` + `.alert` modifier
- Print-only error handling (`print("error: \(error)")`) is not acceptable for user-facing operations
- Non-critical operations (e.g., supplementary Keychain preference storage where SwiftData is primary) may fail silently with a comment

---

## ADR-008: Service testability patterns — injectable dependencies
**Date:** 2026-02-25
**Status:** Active
**Decision:** Services that depend on system frameworks (UNNotificationCenter, CKContainer, Keychain) must provide test-friendly initialization paths that avoid crashing in the `swift test` runner.
**Context:** `DataService` crashed in tests due to `CKContainer.default()` init. `NotificationService` crashed due to `UNUserNotificationCenter.current()` without an app bundle. `ReminderService` couldn't be tested because its dependencies couldn't be constructed.
**Consequences:**
- `DataService.makeForTesting()` — public factory producing in-memory SwiftData store without CloudKit
- `NotificationService(notificationCenter: nil)` — optional UNNotificationCenter avoids crash in package tests
- `ReminderService` accepts `WeatherAdjustmentProviding` protocol for mock weather injection
- New services should follow this pattern: provide a test-friendly init or factory method
- Mark system-dependent test gaps with `// INTEGRATION GAP:` comments

---

---

## ADR-009: 4-tab navigation redesign (was 7 tabs)
**Date:** 2026-03-09
**Status:** Active
**Decision:** Collapse the previous 7-tab navigation into 4 tabs: Home (task dashboard), Garden (grouped plant list hero screen), Journal (timeline), Profile (settings + tutorials).
**Context:** The original app had too many tabs, making navigation confusing and the core garden management feature hard to reach. The redesign identified Garden as the center of gravity — the feature users come back to daily.
**Consequences:**
- `MainAppView` uses a 4-item `TabView`
- Garden is the primary tab; plants are the central data type
- Tutorials moved under Profile tab (not a standalone tab)
- TutorialsView presented via `.sheet` from Profile to avoid nested NavigationStack conflicts
- Home tab is a task dashboard (care tasks grouped by urgency), not a general overview
- UI tests for old navigation were skipped with `XCTSkip` pending rewrite

---

## ADR-010: CultivationTheme — centralized design token system
**Date:** 2026-03-09
**Status:** Active
**Decision:** All colors, spacing, radii, animation presets, typography helpers, and gradient definitions live in a single `CultivationTheme` enum in `GrowWiseFeature/Design/CultivationTheme.swift`. Views reference tokens, never hard-coded values.
**Context:** The pre-redesign codebase scattered magic numbers (colors, padding, radii) throughout view files. A centralized token system ensures visual consistency, enables future theme changes in one place, and makes design intent explicit.
**Consequences:**
- `CultivationTheme.Colors.*`, `Spacing.*`, `Radius.*`, `Animation.*`, `Gradients.*` are the only sources of design values
- Hard-coding colors or spacing is an anti-pattern and will be rejected in review
- Design language: dark `#0C0C0C` background, glass-morphism cards, brand green CTA gradient `#2d6a4f → #52b788`
- Status colors follow Apple system palette: alert=`#FF453A`, warning=`#FFD60A`, healthy=`#30D158`

---

## ADR-011: gardenLocation as String field — no GardenBed model entity
**Date:** 2026-03-09
**Status:** Active
**Decision:** Garden beds and areas are represented as a free-text `gardenLocation: String?` field on the `Plant` model, not as a separate `GardenBed` SwiftData entity with a relationship.
**Context:** Adding a `GardenBed` entity would require a migration, introduce a new SwiftData relationship requiring inverse, and add complexity for minimal benefit. The grouped-list UX can be achieved by grouping plants on the String value. Users simply type a location name when adding a plant.
**Consequences:**
- `GardenViewModel.rebuildGroups()` groups `allPlants` by `plant.gardenLocation` into `[PlantGroup]`
- `PlantGroup` is a non-persisted struct: `id: String`, `locationKey: String?`, `plants: [Plant]`
- Plants with nil/empty `gardenLocation` fall into an "Ungrouped" group
- "Add Bed or Area" UX: alert for bed name → pre-fills `AddPlantSheet(locationPreset:)` → first plant created with that location → bed appears automatically in the list
- Location names are not validated or enforced — users may have inconsistencies (e.g. "Back Yard" vs "Back yard")
- If a formal bed entity is needed later, a SwiftData migration will be required

---

## ADR-012: .sheet over navigationDestination for views with own NavigationStack
**Date:** 2026-03-09
**Status:** Active
**Decision:** When pushing a view that contains its own `NavigationStack` (e.g. `TutorialsView`), present it as a `.sheet` rather than via `navigationDestination`.
**Context:** Using `navigationDestination` to push a view that has its own `NavigationStack` inside causes a nested `NavigationStack` warning in SwiftUI and results in silent navigation failures — the view appears to navigate but nothing happens. `TutorialsView` has an internal navigation stack for tutorial step progression.
**Consequences:**
- `ProfileView` presents `TutorialsView` via `.sheet(isPresented: $showTutorials)`
- Any future view with its own `NavigationStack` must be presented as a sheet, not pushed
- This is a general SwiftUI constraint: `NavigationStack` must not be nested inside another `NavigationStack`

---

## ADR-013: locationPreset pattern for contextual sheet pre-filling
**Date:** 2026-03-09
**Status:** Active
**Decision:** When opening `AddPlantSheet` from a specific bed/area context, pass the location string via an `init(locationPreset:)` parameter that pre-fills the gardenLocation field using `State(initialValue:)`.
**Context:** After "Add Bed or Area" captures a bed name, the subsequent `AddPlantSheet` should default to that bed so the user doesn't have to re-enter it. A parameter-based init with `State(initialValue:)` is the correct SwiftUI pattern — `@Binding` would introduce unnecessary parent-child coupling for a one-time default value.
**Consequences:**
- `AddPlantSheet.init(locationPreset: String = "")` uses `_gardenLocation = State(initialValue: locationPreset)`
- `GardenView` tracks `bedLocationPreset: String` state, cleared on sheet dismiss via `.onDisappear`
- The pattern is reusable for any sheet that needs a contextual default value

---

## ADR-014: Sheet-to-push navigation with delay for PlantDetailView
**Date:** 2026-03-09
**Status:** Active
**Decision:** When "View Full Details" is tapped in `PlantQuickCard` (a `.sheet`), the navigation sequence is: dismiss the sheet, wait 350ms, then set `plantToNavigate` to trigger `navigationDestination` push.
**Context:** SwiftUI does not allow a sheet dismiss and a simultaneous `navigationDestination` push — the push is silently dropped if triggered while the sheet dismiss animation is in progress. A 350ms delay (longer than the sheet dismiss spring animation) reliably allows the push to succeed.
**Consequences:**
- `GardenView` maintains `@State private var plantToNavigate: Plant?`
- `PlantQuickCard.onViewDetails` closure: captures plant, sets `selectedPlant = nil`, then `Task { @MainActor in try? await Task.sleep(for: .milliseconds(350)); plantToNavigate = captured }`
- The 350ms delay is hardcoded; if sheet dismiss animation duration changes in future iOS versions, this may need adjustment
- `try?` is acceptable here — `Task.sleep` failure is a non-user-facing timing issue

---

## ADR-015: GardenViewModel exception to strict MV rule
**Date:** 2026-03-09
**Status:** Active
**Decision:** `GardenViewModel` and `HomeViewModel` exist as `@Observable @MainActor` classes, as an exception to the strict MV (no ViewModel) rule in ADR-002.
**Context:** The Garden tab requires grouping plants by location string, computing aggregate counts (total plants, alert count), filtering by search text, and managing the selected garden — all derived from live `DataService` data. Embedding all this logic inline in `GardenView` via `@State` and computed properties would create an unwieldy 400+ line view. A dedicated aggregation class improves testability and readability.
**Consequences:**
- `GardenViewModel` is NOT MVVM — it has no business logic, no service calls beyond data fetching, and no UI formatting
- It is an `@Observable` data aggregator: loads → groups → filters → exposes
- Instantiated via `@State private var viewModel = GardenViewModel()` (not `@StateObject`)
- `DataService` is passed in as a parameter (`load(dataService:)`), not stored — maintains DI discipline
- This pattern is only acceptable for tabs with complex multi-source data aggregation; simple views must remain pure MV

---

## ADR-016: Test execution via SSH to mac-mini
**Date:** 2026-03-09
**Status:** Active
**Decision:** All `xcodebuild test` and `swift test` commands must be run on the mac-mini (secondary build node) via SSH, never on the development machine.
**Context:** The primary development machine is the gateway/orchestration host. Running `xcodebuild` locally would consume excessive resources, and simulator availability/configuration is managed on the mac-mini. SourceKit on the local machine may also show false positive errors that do not reflect actual build state.
**Consequences:**
- SSH pattern: `ssh mac-mini "cd ~/Projects/GrowWise && <command>"`
- Build verification, test runs, and lint checks that require a full build should all SSH to mac-mini
- SwiftLint and SwiftFormat can run locally (file-only, no compilation needed)
- Local SourceKit/IDE errors should not be trusted — run a real build on mac-mini to confirm

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
