# 1.0 Release Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close every known 1.0 blocker for Cultivation and leave the deferred ambitious onboarding work clearly queued for 1.1.

**Architecture:** Work from `codex/1.0-release-readiness`, branched from current `origin/master`. Keep changes grouped by GitHub issue and land the safest release gates first: test/build infrastructure, small correctness fixes, copy/branding cleanup, then the larger Club and onboarding/database flows. The 1.0 onboarding scope is intentionally pragmatic; #287 captures the richer 1.1 personalization roadmap.

**Tech Stack:** SwiftUI, SwiftData, Swift 6 strict concurrency, Swift Testing, XCUITest, StoreKit 2, CloudKit, Perenual API integration, SwiftLint, SwiftFormat. Package tests and app build verification run on `mac-mini` by SSH per ADR-016 and project instructions.

---

## Current 1.0 Board

- #271 Club sharing: composer lacks photo, club selection, CloudKit publish/offline/retry
- #272 Club feed photos still render placeholders
- #259 Scanner still exposes diagnosis/sample-diagnosis copy
- #273 Pro tier presentation remains confusing on the 1.0 paywall
- #275 Remaining user-facing GrowWise resource strings
- #285 Stale UI tests for Cultivation/current flows
- #286 Reminder delete action does not remove persisted reminder
- #296 Completing a reminder can reload stale active-reminder cache
- #288 Persist onboarding level/goals and use them in personalization
- #289 Onboarding creates a real first garden, skippable
- #290 First plant onboarding creates a database-backed plant in the selected garden
- #291 Unified plant database integration across picker, Add Plant, suggestions, and Perenual
- #292 Lightweight starter plan after onboarding

Deferred, not 1.0:

- #287 Ambitious onboarding/personalization fast follow for 1.1.

## Baseline Verification

- `swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise` is clean on the worktree.
- `swiftlint lint --strict --config .swiftlint.yml` is clean on the worktree.
- `ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"` succeeds on current `origin/master`.
- `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && set -o pipefail && swift test"` passes on current `origin/master` when run serially. A previous parallel build/test run caused transient dependency-resolution noise; #295 was closed as not a codebase blocker.

## Execution Order

1. Close small isolated 1.0 gaps: #286, #259, #275, #273.
2. Fix the Club share loop: #271 and #272 together.
3. Implement onboarding/database activation: #288, #289, #291, #290, #292.
4. Update UI tests and run release verification: #285 plus full build/test/lint/format.

---

### Task 1: Persist Reminder Mutations (#286 + #296)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift:432`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService.swift:446`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/DataServiceEdgeCaseTests.swift:580`
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/HomeViewModelTests.swift:300`

**Progress:** Completed.

**Step 1: Write/update the failing service test**

Remove the manual `service.invalidateAllCaches()` from `deleteReminderRemovesFromActiveReminders()` and assert that `fetchActiveReminders()` no longer returns the deleted reminder after `deleteReminder(_:)`.

**Step 2: Run focused test**

Run:

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && set -o pipefail && swift test --filter DataServiceEdgeCaseTests/deleteReminderRemovesFromActiveReminders 2>&1 | tail -60"
```

Expected before implementation: FAIL because `DataService.deleteReminder(_:)` does not invalidate reminder caches.

**Step 3: Implement service cache invalidation**

Update reminder mutation methods to invalidate reminder/stat caches after repository changes:

```swift
public func deleteReminder(_ reminder: PlantReminder) throws {
    try reminders.delete(reminder)
    cache.invalidateAll(withPrefix: "reminders:")
    cache.invalidateAll(withPrefix: "stats:count:")
    cache.invalidate("stats:gardening_summary")
}
```

Apply the same cache policy to `completeReminder(_:)` so Home reloads do not keep stale completed reminders.

**Step 4: Implement view delete persistence**

Update `PlantReminderDetailView.deleteReminder(_:)`:

```swift
private func deleteReminder(_ reminder: PlantReminder) {
    do {
        reminderService.cancelNotification(for: reminder)
        try dataService.deleteReminder(reminder)
        loadReminders()
    } catch {
        errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
        showingError = true
    }
}
```

**Step 5: Verify**

Run:

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && set -o pipefail && swift test --filter DataServiceEdgeCaseTests/deleteReminderRemovesFromActiveReminders 2>&1 | tail -60"
swiftlint lint --strict --config .swiftlint.yml --path GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift --path GrowWisePackage/Sources/GrowWiseServices/DataService.swift --path GrowWisePackage/Tests/GrowWiseServicesTests/DataServiceEdgeCaseTests.swift
```

Expected: focused test passes; touched files lint clean.

**Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift GrowWisePackage/Sources/GrowWiseServices/DataService.swift GrowWisePackage/Tests/GrowWiseServicesTests/DataServiceEdgeCaseTests.swift
git commit -m "fix: persist reminder deletes"
```

---

### Task 2: Reframe Scanner Copy (#259)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantScannerView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/PlantDiagnosticService.swift`
- Modify tests that assert scanner copy, likely `GrowWiseUITests/PhaseOneTwoUITests.swift`

**Progress:** Completed.

**Steps:**
1. Replace user-facing `Diagnosis` / `diagnosis` copy with `Plant Health Check`, `Care Guidance`, or `Plant Health Guidance`.
2. Keep internal type names unless a user-facing string leaks.
3. Run `rg -n 'Diagnosis|diagnosis|diagnose|AI' GrowWisePackage/Sources/GrowWiseFeature GrowWisePackage/Sources/GrowWiseServices`.
4. Update stale UI tests.
5. Run focused tests and touched-file lint.
6. Commit with `fix: reframe plant health scanner copy`.

---

### Task 3: Sweep Branding Resources (#275)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Resources/en.lproj/Localizable.strings`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Resources/fr.lproj/Localizable.strings`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Resources/es.lproj/Localizable.strings`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Resources/de.lproj/Localizable.strings`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/Resources/tutorials.json`

**Progress:** Completed.

**Steps:**
1. Replace user-facing `GrowWise` with `Cultivation` only in resource strings/content.
2. Do not rename module IDs, bundle IDs, product IDs, CloudKit IDs, logger subsystems, or source imports per ADR-020.
3. Run `rg -n 'Welcome to GrowWise|Unlock GrowWise|use the GrowWise app|GrowWise Premium|Grow Wise' GrowWisePackage/Sources`.
4. Run format/lint.
5. Commit with `fix: sweep remaining Cultivation branding resources`.

---

### Task 4: Clean Paywall Pro Presentation (#273)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/PaywallView.swift`
- Modify/add tests in `GrowWisePackage/Tests/GrowWiseServicesTests/SubscriptionContractTests.swift` or feature tests if practical.

**Progress:** Completed.

**Steps:**
1. Keep Premium monthly/annual actionable.
2. Remove the Pro comparison column or mark it clearly as unavailable without implying purchase.
3. Ensure comparison table does not advertise purchasable Pro-only benefits in 1.0.
4. Verify `SubscriptionService.purchasableProductIDs` remains Premium-only.
5. Run subscription/paywall focused tests and lint.
6. Commit with `fix: simplify 1.0 paywall tiers`.

---

### Task 5: Complete Club Share Loop (#271 + #272)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift`
- Reuse: `GrowWisePackage/Sources/GrowWiseServices/PhotoService.swift`

**Steps:**
1. Add photo attachment to composer.
2. Add selected club handling where the composer can be launched without an explicit club.
3. Persist local post with optional photo reference.
4. Publish via `ClubCloudKitService.publishActivity(_:)` with offline/retry-safe behavior.
5. Render real feed photos and remove gradient placeholder as the default post media.
6. Add tests for photo mapping, local create, publish handoff, and fallback behavior.
7. Commit in small slices: composer photo, publish handoff, feed rendering.

---

### Task 6: Build Useful 1.0 Onboarding (#288 + #289 + #291 + #290 + #292)

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/OnboardingView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardeningGoalsView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardenSetupView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/FirstPlantStepView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/CompletionView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingNavigationView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantDatabase/PerenualBrowseView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/PlantDatabaseService.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/TutorialService.swift`
- Add/modify tests under `GrowWisePackage/Tests/GrowWiseServicesTests/` and `GrowWisePackage/Tests/GrowWiseFeatureTests/`

**Steps:**
1. Persist onboarding level/goals onto `User`, including `gardeningGoals` and derived `preferredPlantTypes`.
2. Replace passive garden type selection with skippable first garden creation.
3. Build or consolidate a unified plant picker/search model over local database and Perenual results.
4. Make first plant selection copy the selected database/Perenual template into a user-owned `Plant` attached to the onboarding garden.
5. Confirm or create the first watering reminder from database-backed watering data.
6. Add a lightweight starter plan card/section after onboarding.
7. Keep the 1.1 ambitious scope out of 1.0 and linked to #287.
8. Commit in issue-sized slices.

---

### Task 7: Update Critical UI Tests (#285)

**Files:**
- Modify: `GrowWiseUITests/OnboardingFlowUITests.swift`
- Modify: `GrowWiseUITests/GardenClubUITests.swift`
- Modify: `GrowWiseUITests/GrowWiseUITests.swift`
- Modify: `GrowWiseUITests/CompostShoppingProfileUITests.swift`
- Modify: `GrowWiseUITests/Phase3And4UITests.swift`

**Steps:**
1. Replace stale user-facing `GrowWise` expectations with `Cultivation` where appropriate.
2. Replace brittle visible text assertions with accessibility identifiers where stable IDs exist.
3. Update Club tests for top-level Club tab, not old Profile navigation.
4. Update onboarding progress expectations after the 1.0 onboarding flow changes.
5. Run focused UI tests on mac-mini/simulator if feasible, plus app build.
6. Commit with `test: refresh 1.0 UI tests`.

---

### Task 8: Final Release Verification

**Commands:**

```bash
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise
swiftlint lint --strict --config .swiftlint.yml
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && set -o pipefail && swift test 2>&1 | tail -80"
ssh mac-mini "cd ~/Projects/GrowWise && set -o pipefail && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -60"
gh issue list --repo jbcrane13/GrowWise --state open --limit 200 --json number,title,labels,url
```

**Expected:**
- Format clean.
- Lint clean.
- Package tests run and pass.
- App build succeeds.
- Open 1.0 board has no remaining blockers except explicitly deferred #287.
