# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-27
**Commit:** $(git rev-parse --short HEAD 2026-02-27 2>/dev/null || echo "Unknown")
**Branch:** $(git rev-parse --abbrev-ref HEAD 2026-02-27 2>/dev/null || echo "Unknown")

## Agent Readiness

Before starting work, read **`docs/agent-readiness/README.md`** (when it exists). It describes the current readiness level, coding conventions introduced by previous sessions (TODO format, log scrubbing rules, lint config, etc.), and which skill files to use for common agent tasks.

| Resource | Location | Purpose |
|----------|----------|---------|
| Agent Readiness | `docs/agent-readiness/README.md` | Current readiness score, conventions, key files — **read first** |
| Skills | `.factory/skills/` | Reusable agent skill definitions |
| Droids | `.factory/droids/` | Agent droid configurations |
| Session Reports | `docs/agent-readiness/NN-*.md` | Per-session change reports |

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

# Lint (SwiftLint — must pass before commit)
swiftlint lint --strict --config .swiftlint.yml
swiftlint lint --fix --config .swiftlint.yml   # auto-fix

# Format (SwiftFormat — must pass before commit)
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise   # check
swiftformat --config .swiftformat GrowWisePackage/Sources GrowWise          # fix

# Install quality git hooks (one-time per clone)
./scripts/install-hooks.sh
```

## TOOLING & QUALITY GATES
- **SwiftLint** — `.swiftlint.yml` in root. Run before every commit.
- **SwiftFormat** — `.swiftformat` in root. Run before every commit.
- **Pre-commit hooks** — `./scripts/install-hooks.sh` to install chained hooks (beads + quality).
- **CI** — `.github/workflows/ci.yml` runs lint, format, tests, tech debt scan, large file check.
- **Skills** — `.factory/skills/` contains `ios-swift-development` and `beads-issue-workflow` skills.

## ENVIRONMENT SETUP
See `.env.example` for required Apple developer account configuration.
No runtime secrets needed for local development — all secrets managed via iOS Keychain on-device.

## ARCHITECTURE DIAGRAMS
See `docs/architecture/diagrams/app-architecture.md` for Mermaid diagrams covering:
- Package structure
- Data flow (MV pattern)
- Security architecture
- CloudKit sync flow
- Service dependencies

## LOGGING & SECURITY
- **Never use `print()`** — use `OSLog.Logger` with privacy annotations.
- All user PII must use `.private` or `.sensitive` privacy level.
- Security events must go through `AuditLogger`.
- See `docs/security/log-scrubbing.md` for full redaction guidelines.

## DEPLOYMENT & OBSERVABILITY
- **Deploy target:** TestFlight (internal → external → App Store)
- **Deploy workflow:** `.github/workflows/deploy.yml` — triggered on `v*` tag push
- **Post-deploy monitoring:**
  - Crashes: [App Store Connect → TestFlight](https://appstoreconnect.apple.com/apps/crashes)
  - CloudKit: [CloudKit Console](https://icloud.developer.apple.com/dashboard)
  - Xcode Organizer: Window → Organizer → Crashes (for symbolicated stack traces)
- **Runbooks:** `docs/runbooks/` — CloudKit sync, Keychain loss, crash on launch, migration failure, key rotation

## SECURITY WORKFLOWS
- **CodeQL:** `.github/workflows/security.yml` — runs on push to main + weekly
- **Secret scan:** Gitleaks on every PR
- **Swift security patterns:** Checked in CI (insecure HTTP, NSLog, UserDefaults for secrets, weak crypto)

## TECH DEBT TRACKING
TODOs and FIXMEs must reference a beads issue:
```swift
// TODO(GW-123): description of what needs doing
// FIXME(GW-456): description of the problem
```
Unlinked TODOs are flagged in CI (`tech-debt` job in `.github/workflows/ci.yml`).

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
