---
name: ios-swift-development
description: Use when implementing features, fixing bugs, or refactoring in the GrowWise iOS codebase. Enforces Swift 6 concurrency, MV architecture, SwiftData/CloudKit conventions, and security requirements.
---

# GrowWise iOS Development Skill

## Prerequisites

Before writing any code, verify the current state:

```bash
# Check which branch you're on
git rev-parse --abbrev-ref HEAD

# See current beads issues
bd show

# Run existing tests to ensure a clean baseline
cd GrowWisePackage && swift test
```

## Architecture Rules (Non-Negotiable)

**MV Pattern only — NO ViewModels:**
- Views get data via `@Environment(Service.self)` injected from the app root
- Local ephemeral state uses `@State` in the view itself
- Never create `class MyViewModel: ObservableObject`
- Never use `@StateObject` or `@ObservedObject`

**Concurrency:**
- UI-bound services must be `@MainActor`
- Background operations use Swift `Actor` or `async/await`
- Never use `DispatchQueue` or completion handlers
- Structured concurrency only — no `Task.detached` without justification

**SwiftData:**
- All `@Model` properties must be `Optional` or have defaults (CloudKit requirement)
- Never use `ModelConfiguration(isStoredInMemoryOnly: true)` in production
- Migrations must be additive — never delete properties from models

## Code Quality Requirements

**Never acceptable:**
```swift
// WRONG — force unwrap
let name = plant.name!

// WRONG — force cast
let service = object as! DataService

// WRONG — silencing errors in views
try? service.save()

// WRONG — no issue reference
// TODO: fix this later
```

**Always required:**
```swift
// CORRECT — safe unwrap
guard let name = plant.name else { return }

// CORRECT — typed error handling
do {
    try service.save()
} catch {
    // handle with fallback or surface to user
}

// CORRECT — linked tech debt
// TODO(GW-123): refactor this after migration completes
```

**Accessibility (mandatory):**
```swift
Button("Add Plant") { ... }
    .accessibilityIdentifier("addPlantButton")
    .accessibilityLabel("Add a new plant")
```

**Logging (never use print):**
```swift
import OSLog
private let logger = Logger(subsystem: "com.growwise", category: "DataService")
logger.info("Plant saved: \(plant.id, privacy: .public)")
// For sensitive data, always use .private or omit
logger.debug("Key rotation: \(keyID, privacy: .private)")
```

## Security Rules

For any change touching `GrowWiseServices/Keychain*`, `Encryption*`, `SecureEnclave*`, `KeyRotation*`, `Token*`, or `JWT*`:

1. Never log key material, tokens, or user secrets — even at debug level
2. Never store sensitive data in `UserDefaults` — use `KeychainStorageService`
3. Always use the `AuditLogger` for security-relevant events
4. Follow the multi-level fallback pattern from `DataService`

## Testing

```bash
# All tests
cd GrowWisePackage && swift test

# Specific module
swift test --filter GrowWiseServicesTests
swift test --filter GrowWiseModelsTests
swift test --filter GrowWiseFeatureTests
```

Tests use Swift Testing framework (`@Test`, `#expect`, `#require`). Never use `XCTAssert*` in new tests.

## Build Verification

```bash
xcodebuild \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build \
  CODE_SIGNING_ALLOWED=NO
```

## Quality Gates Before Commit

```bash
# Lint check
swiftlint lint --strict --config .swiftlint.yml

# Format check
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise

# Tests
cd GrowWisePackage && swift test
```

## Completing Work

1. File any follow-up issues: `bd add "description"`
2. Mark resolved issues: `bd close GW-XXX`
3. Sync beads state: `bd sync`
4. Push: `git push`

---

## ⚠️ Test Quality Standards — Mock Trap Prevention

> **Critical:** These rules apply to ALL test writing, including when using Droid/Factory agents.

### The Mock Trap (learn from NM2's 349-test incident)
Mock-only tests prove plumbing works. They do NOT prove real services produce output.
Before writing any test, ask: *"If I deleted the mock and used the real service, would this test still pass?"*
If no → mock-only gap. You need an integration or contract test too.

### Required test types by service kind
| Service Type | Required |
|-------------|---------|
| Pure logic (calculators, parsers) | Unit tests with known inputs |
| `@Observable` services | Mock-based unit tests (plumbing only) |
| Network/CloudKit API services | **Contract test** — real parser + fixture JSON |
| Services that produce user-visible output | **Integration test** — real service + verify non-empty output |
| Any service with `catch {}` or `try?` | **P0 bug first** — fix error surfacing before writing tests |

### Silent failure audit (run before writing ANY tests)
Scan the real service implementation for:
- `catch { }` or `catch { _ = error }` — error swallowed, user sees blank screen
- `try?` without logging — failure invisible
- `guard else { return }` — silent no-op

These are P0 bugs. Fix them first. Then write tests.

### ❌ Reject (shallow)
```swift
XCTAssertTrue(app.buttons["Save"].exists)           // existence only
#expect(vm.items.count == 2)  // with mock service  // mock-only
```

### ✅ Require (functional)
```swift
// Outcome validation
app.buttons["Save"].tap()
XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 2))

// Contract test — real parser + fixture
let fixture = Data("""{"status":"ok","count":3}""".utf8)
let result = try JSONDecoder().decode(MyResponse.self, from: fixture)
#expect(result.count == 3)

// Integration test — real service
let svc = PlantService()  // REAL, not mock
let plants = try await svc.fetchPlants(query: "tomato")
#expect(!plants.isEmpty, "Real service must return results")
```
