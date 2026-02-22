# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-21
**Commit:** $(git rev-parse --short HEAD 2026-02-21 2>/dev/null || echo "Unknown")
**Branch:** $(git rev-parse --abbrev-ref HEAD 2026-02-21 2>/dev/null || echo "Unknown")

## OVERVIEW
GrowWise is an iOS gardening companion app using Swift 6 strict concurrency, SwiftData with CloudKit sync, and SwiftUI. It tracks plants, sets care reminders, and manages plant journals.

## STRUCTURE
```
GrowWise/                    # App shell (entry point, assets, info.plist, CloudKit schemas)
GrowWisePackage/             # Core Swift Package (All logic)
  Sources/
    GrowWiseModels/          # @Model classes, Enums (No dependencies)
    GrowWiseServices/        # Business logic, Security, CloudKit (@Observable, Actors)
    GrowWiseFeature/         # SwiftUI views (Strict MV architecture)
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
| UI / Screens | `GrowWisePackage/Sources/GrowWiseFeature/Views/` | Tab-based navigation, strict MV |
| Data / Persistence | `GrowWisePackage/Sources/GrowWiseModels/` | SwiftData models, all properties optional |
| Business Logic / Auth | `GrowWisePackage/Sources/GrowWiseServices/` | Services injected via `@Environment` |
| App Entry Point | `GrowWise/` | MainAppView initialization, CloudKit schemas |
| Test Suites | `GrowWisePackage/Tests/` | Mostly Swift Testing (`@Test`) with XCTest |

## CONVENTIONS
- **Architecture:** Strict MV (Model-View). NO ViewModels.
- **State:** Views use `@Environment(Service.self)` and `@State` for local state.
- **Concurrency:** `@MainActor` for UI-bound services; Actors for concurrent state; `async/await`.
- **Persistence:** SwiftData. All `@Model` properties optional or have defaults for CloudKit compatibility.
- **Error Handling:** Multi-level fallback pattern (see DataService).
- **Issue Tracking:** Use `bd` (beads) for issue tracking (`bd ready`, `bd show`, `bd close`, `bd sync`).

## ANTI-PATTERNS (THIS PROJECT)
- **DO NOT** create `ObservableObject` ViewModels.
- **NEVER** use `as any`, `@ts-ignore` (or Swift equivalent forced casts like `as!`).
- **NEVER** crash on init failure. Follow multi-level fallback.
- **NEVER** hardcode keys/secrets. Use `KeychainStorageService` or `SecureEnclaveKeyManager`.
- **DO NOT** save files to the root folder. Place inside appropriate package target.

## UNIQUE STYLES
- Uses `@Observable` instead of `ObservableObject`.
- Explicit `#expect` instead of XCTAssert where Swift Testing is used.
- Accessibility is mandatory: `.accessibilityIdentifier()` on all interactive elements.

## COMMANDS
```bash
# Build
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build
# Tests
cd GrowWisePackage && swift test
swift test --filter GrowWiseServicesTests
```
