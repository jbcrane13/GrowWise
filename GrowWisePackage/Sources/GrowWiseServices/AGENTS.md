# GrowWiseServices - Agent Instructions

## Purpose

Service layer providing business logic, data access, security, and external integrations. Depends on `GrowWiseModels`. Services use the `@Observable` macro and are injected into SwiftUI views via `@Environment`.

## Key Architecture Patterns

### DataService (central data access)
- `@MainActor @Observable public final class DataService`
- Owns the `ModelContainer` and `ModelContext` for all SwiftData operations
- **Async initialization**: Prefer `DataService.createAsync()` or `DataService.makeAsync()` over synchronous `init()`
- **Multi-level fallback**: 6 levels of fallback initialization to prevent crashes (persistent -> in-memory -> temp file -> read-only -> default -> empty schema)
- **Caching**: Uses `SwiftDataCache` with TTL policies. Always invalidate caches on writes.
- **Pagination**: All fetch methods support `offset`/`limit` parameters, capped at 50

### Service Injection Pattern
```swift
// In GrowWiseApp.swift:
@State private var locationService = LocationService()
// In MainAppView:
@Environment(DataService.self) private var dataService
```

## Files by Domain

### Data Access
| File | Class | Notes |
|------|-------|-------|
| `DataService.swift` | `DataService` | Central CRUD for all models. ~1200 lines. Includes caching, batch loading, statistics, export |
| `SwiftDataCache.swift` | `SwiftDataCache` | In-memory cache with `.short`/`.medium`/`.long` TTL policies |
| `CacheManager.swift` | `CacheManager` | General-purpose cache utilities |
| `DataTransformationService.swift` | `DataTransformationService` | Data format conversions |
| `ValidationService.swift` | `ValidationService` | Input validation rules |
| `PlantDatabaseService.swift` | `PlantDatabaseService` | Reference plant database queries |
| `PlatformImage.swift` | `PlatformImage` | Cross-platform image type alias |

### Security & Authentication
| File | Class | Notes |
|------|-------|-------|
| `EncryptionService.swift` | `EncryptionService` | AES-256-GCM encryption, key rotation, compliance enforcement |
| `KeychainStorageService.swift` | `KeychainStorageService` | Low-level Keychain read/write |
| `KeychainManager.swift` | `KeychainManager` | High-level Keychain operations |
| `KeyRotationManager.swift` | `KeyRotationManager` | Automatic key rotation policies |
| `SecureEnclaveKeyManager.swift` | `SecureEnclaveKeyManager` | Hardware-backed key storage via Secure Enclave |
| `JWTValidator.swift` | `JWTValidator` | JWT token validation and claims parsing |
| `TokenManagementService.swift` | `TokenManagementService` | Token lifecycle (refresh, store, revoke) |
| `BiometricAuthenticationManager.swift` | `BiometricAuthenticationManager` | Face ID / Touch ID |
| `AuthenticationInitializer.swift` | `AuthenticationInitializer` | Auth bootstrap at app launch |
| `AuthenticationProtocols.swift` | Auth protocols | Protocol definitions for auth abstraction |
| `AuditLogger.swift` | `AuditLogger` | Security event audit trail |
| `RateLimiter.swift` | `RateLimiter` | API/operation rate limiting |
| `MigrationIntegrityService.swift` | `MigrationIntegrityService` | Data migration verification |
| `LegacyEncryptionMigrationService.swift` | `LegacyEncryptionMigrationService` | Legacy encryption format migration |

### Device Services
| File | Class | Notes |
|------|-------|-------|
| `LocationService.swift` | `LocationService` | CoreLocation wrapper with authorization handling |
| `NotificationService.swift` | `NotificationService` | Local/remote notification scheduling |
| `PhotoService.swift` | `PhotoService` | Photo capture, storage, and retrieval |
| `BackgroundTaskManager.swift` | `BackgroundTaskManager` | BGTaskScheduler for background refresh |

### Plant Care
| File | Class | Notes |
|------|-------|-------|
| `ReminderService.swift` | `ReminderService` | Smart reminder logic, weather-adjusted scheduling |
| `TutorialService.swift` | `TutorialService` | Tutorial progression and completion tracking |

### Performance
| File | Class | Notes |
|------|-------|-------|
| `PerformanceMonitor.swift` | `PerformanceMonitor` | App launch timing, memory usage, performance scoring |

## Critical Rules

1. **`@MainActor` isolation**: DataService and UI-bound services must be `@MainActor`. Use `nonisolated` only for thread-safe read-only accessors.
2. **Never crash on init failure**: Follow the multi-level fallback pattern in DataService.
3. **Cache invalidation**: Always call `cache.invalidate()` or `cache.invalidateAll(withPrefix:)` when modifying data.
4. **Privacy logging**: Use `os.Logger` with `.private` for any user data in log statements.
5. **Pagination caps**: Enforce `min(limit, 50)` on all fetch queries to prevent memory issues.
6. **Security**: Never hardcode keys/secrets. All credentials through Keychain/SecureEnclave. Use `EncryptionService` for at-rest encryption.

## Adding a New Service

1. Create `NewService.swift` in this directory
2. Use `@Observable public final class` (add `@MainActor` if UI-bound)
3. Inject via `@Environment` - add `@State private var` in `GrowWiseApp.swift` and pass with `.environment()`
4. Write tests in `Tests/GrowWiseServicesTests/`
