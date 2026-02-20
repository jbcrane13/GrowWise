# AGENTS.md — GrowWise

## Architecture: Strict MV (Model-View)

**No ViewModels.** This is a strict MV architecture per ADR-002. Views consume `@Observable` services directly via `@Environment`. Business logic lives in service/manager classes, not ViewModel wrappers.

### Pattern
```swift
// ✅ Correct — view uses service directly
struct MyView: View {
    @Environment(DataService.self) private var dataService
    @State private var localState = ""
    // ...
}

// ❌ Wrong — no ViewModel layer
class MyViewModel: ObservableObject { ... }
```

### State Management
- `@State` for view-local state
- `@Environment` for injected `@Observable` services (DataService, LocationService, etc.)
- `@Observable` macro on service classes (not `ObservableObject`)
- Complex business logic → service/manager objects, never in views directly

## Project Structure

```
GrowWise/                    # App shell (entry point, assets, entitlements)
GrowWisePackage/             # Core Swift Package
  Sources/
    GrowWiseModels/          # SwiftData @Model classes + enums
    GrowWiseServices/        # Service layer (@Observable, actors)
    GrowWiseFeature/         # SwiftUI views (strict MV — no ViewModels)
  Tests/
    GrowWiseModelsTests/
    GrowWiseServicesTests/
    GrowWiseFeatureTests/
GrowWiseUITests/             # Xcode UI tests
docs/                        # ADR.md, PRD, guides
```

**Dependency graph:** `GrowWiseFeature` → `GrowWiseServices` → `GrowWiseModels`

## Key Technical Decisions

- **SwiftData** (not CoreData) with CloudKit sync
- **Swift 6 strict concurrency** — `@MainActor`, actors, Sendable
- **Swift Testing** (`@Test`, `#expect`) preferred over XCTest for new tests (ADR-004)
- **All @Model properties optional** for CloudKit compatibility
- **iOS 17+ / macOS 14+** deployment targets
- Open `GrowWise.xcworkspace` (not `.xcodeproj`)

## Build & Test

```bash
# Build
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build

# Package tests (fast, no simulator)
cd GrowWisePackage && swift test

# Specific test target
swift test --filter GrowWiseServicesTests
```

## Issue Tracking (Beads)

```bash
bd ready              # Find unblocked work
bd show <id>          # View details
bd create "Title" --type task --priority 2
bd update <id> --status in_progress
bd close <id>
bd sync               # Sync with git
```

## Conventions

- **No ViewModels** — strict MV, services via @Environment
- **Concurrency**: `@MainActor` for UI-bound services, actors for concurrent state
- **Error handling**: Multi-level fallback pattern (see DataService)
- **Caching**: SwiftDataCache with TTL policies (.short/.medium/.long)
- **Logging**: `os.Logger` with `.private` for user data
- **Accessibility**: Every interactive element needs `.accessibilityIdentifier()`
- **Files**: Views in `GrowWiseFeature/Views/`, components in `Components/`

## ADR

All architecture decisions in `docs/ADR.md`. Read before structural changes, append when making new decisions.

## Current Status

~70% complete demo app with known issues. Core features (gardens, plants, reminders, journal, tutorials, onboarding) are implemented. Security services (JWT, Keychain, encryption) are overbuilt for current needs — may simplify later.
