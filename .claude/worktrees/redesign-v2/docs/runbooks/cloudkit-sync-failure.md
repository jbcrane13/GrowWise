# Runbook: CloudKit Sync Failure

**Severity:** P1 — Data not syncing across user's devices

## Symptoms

- Plant data added on iPhone not appearing on iPad (or vice versa)
- `CloudSyncService` logs showing repeated sync errors
- User reports "data missing after reinstall"

## Diagnostic Steps

### 1. Check CloudKit Console
Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard) → select GrowWise container:
- Check **Logs** tab for recent errors
- Look for schema mismatches or quota errors
- Verify the `CKSyncEngine` status

### 2. Check Device iCloud Status
```
Settings → [Apple ID] → iCloud → GrowWise → verify iCloud is ON
Settings → [Apple ID] → iCloud → iCloud Drive → verify enabled
```

### 3. Reproduce Locally
```bash
# Enable CloudKit debug logging in scheme
# Edit scheme → Run → Arguments → Add: -com.apple.CoreData.CloudKitDebugLogging 3
```

### 4. Check CloudSyncService Logs
```swift
// In Xcode Console, filter for "CloudSync" category
// Look for: "sync error", "conflict resolution", "schema mismatch"
```

## Common Causes & Fixes

### Schema Mismatch After Model Change
**Cause:** A new `@Model` property was added that isn't `Optional` — CloudKit requires all properties to be optional.

**Fix:**
1. Ensure the new property is `Optional` or has a default value
2. Deploy a new app version — CloudKit schema updates automatically on first launch with new schema version

### Conflict Resolution Loop
**Cause:** `CloudSyncService` conflict resolution increments creating an infinite update loop.

**Code reference:** `CloudSyncService.swift` — `resolveConflict()` method

**Fix:** Check the `conflictResolutionStrategy` — simple increment strategy should break cycles after 3 iterations.

### iCloud Quota Exceeded
**Cause:** User's iCloud storage is full.

**Fix:** Cannot fix on app side. Show user a graceful message directing them to iCloud settings. File issue to add user-facing quota exceeded handling.
```bash
bd add "Show user-friendly error when iCloud quota is exceeded" --label "enhancement,area: sync"
```

### Network Connectivity
**Cause:** Device offline or iCloud servers unreachable.

**Fix:** This is expected behavior — CKSyncEngine will retry automatically when connectivity resumes.

## Escalation

If sync failure persists after above steps:
1. Capture full CloudKit logs from device
2. Check [Apple System Status](https://www.apple.com/support/systemstatus/) for iCloud outages
3. File a feedback report via Feedback Assistant if Apple-side issue confirmed
