# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-27
**Commit:** $(git rev-parse --short HEAD 2026-02-27 2>/dev/null || echo "Unknown")
**Branch:** $(git rev-parse --abbrev-ref HEAD 2026-02-27 2>/dev/null || echo "Unknown")

## OVERVIEW
GrowWise is an iOS gardening companion app (iOS 17+) using Swift 6 strict concurrency, SwiftData with CloudKit sync, and SwiftUI. It features a heavy custom security layer (Keychain, AES-256-GCM, Secure Enclave) alongside standard gardening tracking and journal features.

## STRUCTURE
```
GrowWise/                    # App shell (entry point, assets, info.plist, CloudKit schemas)
GrowWisePackage/             # Core Swift Package (All logic)
  Sources/
    GrowWiseModels/          # @Model classes, Enums (No dependencies, CloudKit-ready)
    GrowWiseServices/        # Business logic, Security, CloudKit (@Observable, Actors)
    GrowWiseFeature/         # SwiftUI views (Strict MV architecture)
      Components/            # Shared UI utilities and widgets
  Tests/
    GrowWiseModelsTests/     # Model generation & defaults tests
    GrowWiseServicesTests/   # Heavy security & logic testing (Keychain, Encryption)
    GrowWiseFeatureTests/    # View and integration tests
GrowWiseUITests/             # Xcode UI tests
docs/                        # ADRs, Product requirements
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| UI / Screens | `GrowWiseFeature/Views/` | Tab-based navigation, strict MV |
| Reusable UI | `GrowWiseFeature/Components/` | Shared widgets (Weather, Stats, Reminders) |
| Data / Persistence | `GrowWiseModels/` | SwiftData models, all properties optional |
| Business Logic / Auth | `GrowWiseServices/` | Heavy logic: KeychainManager, DataService |
| App Entry Point | `GrowWise/` | MainAppView initialization, CloudKit schemas |
| Test Suites | `GrowWisePackage/Tests/` | Mostly Swift Testing (`@Test`) with XCTest |

## CONVENTIONS
- **Architecture:** Strict MV (Model-View). NO ViewModels (ADR-002).
- **State:** Views use `@Environment(Service.self)` and `@State` for local state.
- **Concurrency:** `@MainActor` for UI-bound services; Actors for concurrent state; `async/await`.
- **Persistence:** SwiftData. All `@Model` properties optional or have defaults for CloudKit compatibility.
- **Security:** Extensive custom encryption (KeychainStorageService, SecureEnclaveKeyManager, KeyRotationManager).
- **Error Handling:** Multi-level fallback pattern (see DataService). No silent `try?` in views (ADR-007).
- **Issue Tracking:** Use `bd` (beads) for issue tracking (`bd ready`, `bd show`, `bd close`, `bd sync`).

## ANTI-PATTERNS (THIS PROJECT)
- **DO NOT** create `ObservableObject` ViewModels.
- **NEVER** use `as any`, `@ts-ignore` (or Swift equivalent forced casts like `as!`).
- **NEVER** crash on init failure. Follow multi-level fallback.
- **NEVER** use `ModelConfiguration(isStoredInMemoryOnly: true)` in production.
- **NEVER** force-unwrap optionals (`plant.name!`).
- **DO NOT** save files to the root folder. Place inside appropriate package target.
- **DO NOT** place static data in service classes (e.g. CompanionPlantingService).
- **DO NOT** initialize services locally in views; inject via `@Environment`.

## UNIQUE STYLES
- Uses `@Observable` instead of `ObservableObject`.
- Explicit `#expect` instead of XCTAssert where Swift Testing is used.
- Accessibility is mandatory: `.accessibilityIdentifier()` on all interactive elements.
- Deeply nested sub-views currently exist in massive view files (e.g. `JournalEntryDetailView.swift`).

## COMMANDS
```bash
# Build
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build
# Tests
cd GrowWisePackage && swift test
swift test --filter GrowWiseServicesTests
```
