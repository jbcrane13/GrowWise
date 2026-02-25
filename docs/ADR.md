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

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
