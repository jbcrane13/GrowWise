# Runbook: App Crash on Launch

**Severity:** P0 — App unusable for affected users

## Symptoms

- App immediately crashes after opening (before main UI appears)
- Crash appears in Xcode Organizer or TestFlight crash reports
- Users reporting "app won't open" after an update

## Immediate Response

### 1. Check Xcode Organizer
```
Xcode → Window → Organizer → Crashes
```
Filter by the problematic build version. Look for the crash type and stack trace.

### 2. Check TestFlight Feedback
```
App Store Connect → TestFlight → [build] → Crashes
```

### 3. Reproduce Locally
```bash
xcodebuild \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build \
  CODE_SIGNING_ALLOWED=NO
```

## Common Crash Causes

### ModelContainer Initialization Failure
**Cause:** `ModelContainerFactory` failed to create the SwiftData container — usually a schema migration issue.

**Code reference:** `ModelContainerFactory.swift` — multi-level fallback should prevent this crash.

**Fix:** Check that all new `@Model` properties are `Optional` or have defaults. Verify `ModelConfiguration` is not using `isStoredInMemoryOnly: true` in production.

### Keychain Access on Background Launch
**Cause:** App launched in background while device is locked — Keychain items with `afterFirstUnlock` accessibility not yet available.

**Code reference:** `AuthenticationInitializer.swift`

**Fix:** `AuthenticationInitializer` should defer Keychain access until device is unlocked. Verify `kSecAttrAccessibleAfterFirstUnlock` is used for background-accessible items.

### CloudKit Schema Migration Error
**Cause:** New model deployed with a breaking CloudKit schema change (removed/renamed a field).

**Fix:**
1. Roll back to previous TestFlight build immediately
2. Fix the schema change to be additive (never remove properties)
3. Re-deploy

## Rollback Procedure

```
App Store Connect → TestFlight → [previous stable build] → Distribute
```
If on App Store:
```
App Store Connect → Pricing and Availability → Remove from Sale (as last resort)
```

## Post-Crash Action

```bash
# File a P0 issue
bd add "P0: App crash on launch - [describe crash type]" --label "P0: Critical,bug"
bd start GW-XXX
```
