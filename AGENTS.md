# GrowWise - Agent Instructions

## Project Overview

GrowWise is an iOS/macOS gardening companion app built with **Swift 6.1**, **SwiftUI**, and **SwiftData**. It helps users track plants, manage gardens, set care reminders, keep a plant journal, and learn through tutorials. The app targets **iOS 17+ / macOS 14+** and uses **CloudKit** for sync.

## Architecture

The codebase follows a **modular Swift Package** architecture:

```
GrowWise/                    # App shell (entry point, assets, entitlements)
GrowWisePackage/             # Core Swift Package with 3 library targets
  Sources/
    GrowWiseModels/          # SwiftData @Model classes + enums (no dependencies)
    GrowWiseServices/        # Service layer (depends on GrowWiseModels)
    GrowWiseFeature/         # SwiftUI views (depends on Models + Services)
  Tests/
    GrowWiseModelsTests/     # Model unit tests
    GrowWiseServicesTests/   # Service unit tests (extensive security tests)
    GrowWiseFeatureTests/    # Feature/integration tests
GrowWiseUITests/             # Xcode UI tests
```

**Dependency graph**: `GrowWiseFeature` -> `GrowWiseServices` -> `GrowWiseModels`

## Key Technical Decisions

- **SwiftData** for persistence (not Core Data) with persistent on-disk storage
- **CloudKit** sync via `CKContainer` (schema in `GrowWise/Data/CloudKit/`)
- **@Observable** macro (not ObservableObject) for services
- **@Environment** injection for services (DataService, LocationService, NotificationService, PerformanceMonitor)
- **Swift 6 strict concurrency** with `@MainActor` isolation on DataService and views
- **SwiftDataCache** with TTL policies (short/medium/long) for query optimization
- **Multi-level fallback** initialization in DataService to prevent crashes
- **CryptoKit AES-256-GCM** for credential encryption; Secure Enclave for key management
- All model properties are **optional** for CloudKit compatibility

## Data Models (SwiftData @Model)

| Model | Purpose | Key Relationships |
|-------|---------|-------------------|
| `Plant` | Plant with care tracking, growth stages, health | -> Garden, -> [PlantReminder], -> [JournalEntry], -> [Plant] (companions) |
| `Garden` | Garden space with location, soil, exposure | -> [Plant], -> User |
| `User` | User profile, skill level, subscription, achievements | -> [Garden], -> [PlantReminder], -> [JournalEntry] |
| `PlantReminder` | Scheduled care reminders with snooze/recurrence | -> Plant, -> User |
| `JournalEntry` | Plant observations with measurements and media | -> Plant, -> User |
| `ReminderSettings` | Notification preferences per user | -> User |
| `SecureCredentials` | JWT token pair (Codable struct, not @Model) | standalone |
| `GardeningStats` | Aggregated dashboard metrics (Sendable struct) | standalone |

## Services Layer

| Service | Responsibility |
|---------|---------------|
| `DataService` | SwiftData CRUD, caching, CloudKit sync status, batch operations |
| `EncryptionService` | AES-256-GCM encryption, key rotation, compliance enforcement |
| `KeychainStorageService` | Keychain read/write with access groups |
| `KeychainManager` | High-level keychain operations |
| `KeyRotationManager` | Automatic key rotation policies |
| `SecureEnclaveKeyManager` | Hardware-backed key storage |
| `JWTValidator` | JWT token validation and parsing |
| `TokenManagementService` | Token lifecycle (refresh, revoke) |
| `BiometricAuthenticationManager` | Face ID / Touch ID authentication |
| `AuthenticationInitializer` | Auth bootstrap at app launch |
| `AuditLogger` | Security event audit trail |
| `LocationService` | CoreLocation with authorization handling |
| `NotificationService` | Local/remote notification scheduling |
| `ReminderService` | Smart reminder logic with weather adjustment |
| `PhotoService` | Photo capture and storage |
| `PlantDatabaseService` | Reference plant database queries |
| `TutorialService` | Tutorial progression tracking |
| `CacheManager` / `SwiftDataCache` | In-memory cache with TTL policies |
| `PerformanceMonitor` | App launch timing, memory tracking |
| `BackgroundTaskManager` | Background refresh tasks |
| `ValidationService` | Input validation rules |
| `DataTransformationService` | Data format conversions |
| `RateLimiter` | API/operation rate limiting |
| `MigrationIntegrityService` | Data migration verification |
| `LegacyEncryptionMigrationService` | Legacy encryption format migration |

## Build & Test

```bash
# Build via Xcode
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build

# Run package tests
cd GrowWisePackage && swift test

# Run specific test target
swift test --filter GrowWiseServicesTests
```

## Conventions

- **Concurrency**: Use `@MainActor` for UI-bound services. Use `Task.detached` for background work. Use `nonisolated` for thread-safe accessors.
- **Error handling**: Multi-level fallback pattern (see `DataService.createFallback()`). Never crash on initialization failure.
- **Caching**: Use `SwiftDataCache` with `.short` (2min), `.medium` (5min), `.long` (15min) TTL policies. Invalidate relevant caches on writes.
- **Logging**: Use `os.Logger` with privacy annotations (`.private` for user data).
- **Models**: All `@Model` properties must be optional or have defaults for CloudKit compatibility.
- **File organization**: Views in `GrowWiseFeature/Views/`, components in `Components/`, onboarding in `OnboardingFlow/`.
- **No hardcoded secrets**: All credentials flow through Keychain/SecureEnclave.

## Issue Tracking

This project uses **bd** (beads) for issue tracking.

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Session Completion Checklist

1. Create issues for remaining work (`bd create`)
2. Run quality gates if code changed
3. Close finished issues (`bd close <id>`)
4. Push to remote:
   ```bash
   git pull --rebase && bd sync && git push && git status
   ```
