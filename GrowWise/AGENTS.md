# GrowWise App Shell - Agent Instructions

## Purpose

Thin app entry point that bootstraps services and delegates to `GrowWiseFeature`. Contains Xcode project configuration, assets, entitlements, and app-level data definitions.

## Files

| File | Purpose |
|------|---------|
| `GrowWiseApp.swift` | `@main` App struct. Initializes LocationService, NotificationService, PerformanceMonitor. Runs encryption bootstrap. Injects services into MainAppView via `.environment()`. |
| `Info.plist` | Configures `UIBackgroundModes: remote-notification` |
| `GrowWise.entitlements` | App entitlements (production) |
| `GrowWiseDebug.entitlements` | Debug entitlements |
| `Assets.xcassets/` | App icon, accent color |
| `Data/CloudKit/CloudKitSchema.swift` | CloudKit record types, field mappings, subscription setup, CKRecord creation helpers |
| `Data/Models/DataValidationRules.swift` | Data validation rule definitions |
| `Data/Sample/PlantDatabase.swift` | Sample plant data for seeding |

## App Startup Sequence

1. `GrowWiseApp.init()`:
   - Calls `ensureEncryptionReady()` - bootstraps encryption keys via `EncryptionService`
   - Calls `AuthenticationInitializer.initialize()` on `@MainActor`
2. `GrowWiseApp.body` renders `MainAppView` with environment services
3. `MainAppView.initializeDataService()`:
   - Creates `DataService` via `DataService.makeAsync()`
   - Validates memory usage (flags fallback mode if delta > 10MB)
   - Warms cache in background
   - Seeds database if needed

## CloudKit Integration

`CloudKitSchema.swift` defines:
- Record types: User, Plant, Garden, PlantReminder, JournalEntry
- Field enums mapping model properties to CKRecord keys
- `createXxxRecord(from:)` helpers for converting models to CKRecords
- `setupCloudKitSubscriptions()` for push notification on data changes
- Container identifier: `iCloud.com.growwise.gardening`

## Critical Rules

1. **Keep this layer thin** - business logic belongs in `GrowWiseServices`, UI in `GrowWiseFeature`.
2. **Encryption must initialize before any data access** - `ensureEncryptionReady()` runs synchronously in `init()`.
3. **CloudKit schema changes** must be reflected in both `CloudKitSchema.swift` and the corresponding `@Model` class.
