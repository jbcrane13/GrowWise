# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Key Documents

- **`docs/ADR.md`** — Architecture Decision Records. Read before making structural changes. Append when making new decisions.
- **`AGENTS.md`** — Project conventions, architecture overview, build commands.
- **`gardening-app-prd.md`** — Product Requirements Document.

## Project Overview

GrowWise is an iOS gardening companion app that helps users track plants, manage gardens, set care reminders, keep a plant journal, and learn through tutorials.

**Target Platform**: iOS 17+ (macOS 14+ secondary)
**Architecture**: Strict MV (Model-View) — NO ViewModels (see ADR-002)
**Language**: Swift 6 with strict concurrency
**Persistence**: SwiftData with CloudKit sync
**UI**: SwiftUI with `@Observable` services

## Architecture: Strict MV

**No ViewModel classes.** Views consume `@Observable` services directly via `@Environment`. Business logic lives in service/manager objects. See ADR-002.

```swift
// ✅ Correct pattern
struct PlantDetailView: View {
    @Environment(DataService.self) private var dataService
    @State private var isEditing = false
}

// ❌ Never create ViewModel classes
class PlantDetailViewModel: ObservableObject { ... }
```

## Project Structure

```
GrowWise/                        # App shell (entry point, assets, entitlements)
GrowWisePackage/                 # Core Swift Package
  Sources/
    GrowWiseModels/              # SwiftData @Model classes + enums
    GrowWiseServices/            # @Observable services, actors, managers
    GrowWiseFeature/             # SwiftUI views (strict MV)
      Views/                     # Main screens
      Components/                # Reusable UI components
      OnboardingFlow/            # Onboarding wizard
      Main/MainAppView.swift     # Root tab container
  Tests/
    GrowWiseModelsTests/
    GrowWiseServicesTests/
    GrowWiseFeatureTests/
GrowWiseUITests/                 # Xcode UI tests
docs/                            # ADR, security docs, guides
```

**Dependency graph**: `GrowWiseFeature` → `GrowWiseServices` → `GrowWiseModels`

## Build & Test

```bash
# Build (use workspace, not xcodeproj)
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build

# Package tests (fast, no simulator needed)
cd GrowWisePackage && swift test

# Specific test target
swift test --filter GrowWiseServicesTests

# UI tests
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Conventions

- **No ViewModels** — strict MV architecture
- **@Observable** over `ObservableObject` — modern observation
- **SwiftData** over CoreData — all `@Model` properties optional for CloudKit
- **Swift Testing** (`@Test`, `#expect`) for new tests, XCTest can coexist
- **async/await** over completion handlers or Combine
- **@MainActor** on UI-bound services; actors for concurrent state
- **os.Logger** with `.private` for user data
- **Every interactive element** needs `.accessibilityIdentifier("screen_element_descriptor")`
- **Files in appropriate subdirs** — never save to root folder
- **No silent `try?` in views** — user-facing operations must surface errors via alerts (see ADR-007)
- **Test-friendly services** — system-dependent services must provide test init/factory (see ADR-008)

## Issue Tracking

This project uses **bd (beads)** for issue tracking.

```bash
bd ready              # Find unblocked work
bd show <id>          # View details
bd create "Title" --type task --priority 2
bd update <id> --status in_progress
bd close <id>
bd sync               # Sync with git
```

## Testing

587 tests across 60 suites (as of 2026-02-25). Test targets:
- **GrowWiseModelsTests** — Plant, Garden, User, PlantReminder, JournalEntry, SoilLog, GardeningStats, SecureCredentials
- **GrowWiseServicesTests** — CompanionPlanting, Location, Subscription, Reminder, Validation, CloudSync, DataService, CacheManager, BackgroundTaskManager, PlantDatabaseService, TutorialService, NotificationService
- **GrowWiseFeatureTests** — Basic view instantiation
- Many security test files (Keychain, JWT, Encryption) exist but are **excluded from Package.swift** — gated behind `KEYCHAIN_TESTS_ENABLED=1`

```bash
# Run all package tests
cd GrowWisePackage && swift test

# Run specific suite
swift test --filter "ReminderServiceIntegration"

# For in-memory DataService in tests
let service = try await DataService.makeForTesting()
```

## Current State

~70% complete. Core features implemented: gardens, plants, reminders, journal, tutorials, onboarding. Security services (JWT, Keychain, encryption) are overbuilt for a gardening app — may simplify. Known issues exist. See beads for tracked work.
