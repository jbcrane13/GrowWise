# Runbook: SwiftData Migration Failure

**Severity:** P1 — Users lose access to existing data after app update

## Symptoms

- App launches but all existing data is gone
- `ModelContainerFactory` logs show migration error
- Error: `NSMigrationError`, `NSInvalidMigrationPolicyError`, or `NSPersistentStoreIncompatibleVersionHashError`

## Diagnostic Steps

### 1. Identify the Migration Path
Check which model version changed. All `@Model` classes are in `GrowWisePackage/Sources/GrowWiseModels/`.

```bash
git log --oneline -- GrowWisePackage/Sources/GrowWiseModels/
```

### 2. Check ModelContainerFactory
```swift
// ModelContainerFactory.swift uses staged migrations
// Verify the migration plan covers the version delta
```

### 3. Simulate Migration Locally
```bash
# Install previous app version on simulator
# Populate with data
# Install new version — check logs for migration errors
```

## Safe Migration Rules

| Allowed | Not Allowed |
|---------|------------|
| Add `Optional` property | Remove property |
| Add property with default value | Rename property |
| Add new `@Model` class | Change property type |
| Add enum case | Remove enum case used in stored data |

## Fix Procedure

### If Migration is Recoverable
1. Add a `MigrationStage` in `ModelContainerFactory` mapping old → new schema
2. Test migration path on a fresh simulator with old data populated
3. Deploy

### If Migration Caused Data Loss (Worst Case)
1. Roll back to previous TestFlight build immediately
2. Do NOT push another build until migration is verified
3. If CloudKit sync is enabled, check if remote data is intact
4. Add a `LightweightMigration` stage that preserves existing records

## Prevention Checklist

Before merging any `GrowWiseModels/` change:
- [ ] All new properties are `Optional` or have a default value
- [ ] No existing properties removed or renamed
- [ ] `ModelContainerFactory` migration plan updated if needed
- [ ] Tested migration from N-1 version on simulator with real data
