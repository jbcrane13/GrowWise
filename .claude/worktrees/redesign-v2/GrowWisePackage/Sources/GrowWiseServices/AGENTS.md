# GrowWiseServices - Agent Instructions

## OVERVIEW
Core business logic, security hotspot, and SwiftData/CloudKit persistence layer.

## STRUCTURE
- **Data Access**: `DataService` (God object), `SwiftDataCache`, `PlantDatabaseService`.
- **Security**: `KeychainManager` (massive), `EncryptionService`, `SecureEnclaveKeyManager`.
- **Cloud/Sync**: `CloudSyncService` (automagic sync), `TokenManagementService`.
- **Device**: `LocationService`, `NotificationService`, `PhotoService`, `BackgroundTaskManager`.
- **Domain**: `ReminderService`, `CompanionPlantingService`, `PlantDiagnosticService`.

## WHERE TO LOOK
- `DataService.swift`: Central hub for all SwiftData CRUD; handles 6-level fallback.
- `KeychainManager.swift`: Primary interface for all secure storage and biometric auth.
- `CloudSyncService.swift`: Manages CloudKit synchronization state and conflict resolution.
- `EncryptionService.swift`: AES-256-GCM implementation for sensitive data at rest.
- `ReminderService.swift`: Logic for weather-adjusted plant care notifications.
- `PerformanceMonitor.swift`: App launch timing and memory usage tracking.

## CONVENTIONS
- **Injection**: Services are `@Observable` and `@MainActor`. Injected via `.environment(Service())`.
- **Persistence**: Use `DataService` for all DB work. Never access `ModelContext` directly in Views.
- **Error Handling**: Multi-level fallback in `DataService` ensures app never crashes on DB init.
- **Caching**: `SwiftDataCache` uses TTL policies (`.short`, `.medium`, `.long`).
- **Pagination**: Enforce `min(limit, 50)` on all fetch queries.

## ANTI-PATTERNS
- **NO ViewModels**: Logic belongs in Services; state in Views or Services.
- **NO Direct SwiftData in Views**: Always go through `DataService` methods.
- **NO Hardcoded Secrets**: Use `KeychainManager` or `SecureEnclaveKeyManager`.
- **NO Blocking Main Thread**: Use `async/await` for all I/O and heavy computation.
- **NO Manual Sync**: CloudKit sync is automagic; don't trigger manual refreshes.
- **NO Forced Casts**: Avoid `as!` or `!` for service retrieval or data casting.
