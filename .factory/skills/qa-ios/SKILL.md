---
name: qa-ios
description: >
  QA tests for the GrowWise iOS app. Runs XCUITest flows via xcodebuild on an
  iPhone 16 simulator. Covers onboarding, garden management, reminders, journal,
  plant database, garden club, subscription/paywall, and profile. Used by the
  qa orchestrator — not invoked directly.
---

# qa-ios — GrowWise iOS App

## App Notes

- **Bundle:** `com.growwise.gardening`
- **Scheme:** `GrowWise`
- **Workspace:** `GrowWise.xcworkspace`
- **Simulator:** iPhone 16 (iOS 17+)
- **UI Test target:** `GrowWiseUITests`
- **Unit test package:** `GrowWisePackage` (run via `swift test` on mac-mini, not via this skill)

## Testing Target

All tests run against a locally-built app on the iPhone 16 simulator. There are no
web deployments or preview URLs — this is a native iOS app.

Always use `--uitesting` launch argument. It enables:
- In-memory SwiftData store (no CloudKit, no persistent data between runs)
- Skips background tasks and sync
- Safe in CI without iCloud entitlements

## Base xcodebuild Command

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -testenv UITEST_SKIP_ONBOARDING=1 \
  -only-testing GrowWiseUITests/<TestClass>/<testMethod> \
  2>&1 | grep -E "(Test Case|PASS|FAIL|error:|** TEST|passed|failed)"
```

## Persona Launch Configurations

| Persona | Launch Arguments |
|---|---|
| `fresh_install` | `--uitesting --reset-onboarding --reset-data` |
| `returning_user` | `--uitesting --skip-onboarding` |
| `subscribed_user` | `--uitesting --skip-onboarding` (plus StoreKit sandbox purchase) |

Pass launch arguments via `-testenv`:
```bash
-testenv UITEST_ARGS="--uitesting --skip-onboarding"
```

Or rely on the existing `--uitesting` support in `MainAppView.swift` which reads
`ProcessInfo.processInfo.arguments`. The test classes in `GrowWiseUITests/` already
set `app.launchArguments = ["--uitesting", ...]` in `setUpWithError()`.

---

## Flow Menu

### Flow 1: Onboarding (fresh_install persona)

**Test class:** `OnboardingFlowUITests`
**Persona:** fresh_install
**When to run:** Changes in `OnboardingFlow/**`, `OnboardingView.swift`, or any onboarding step view

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/OnboardingFlowUITests \
  2>&1 | tee ./qa-results/onboarding.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

**What it verifies:**
- Welcome screen → Skill assessment → Goals → Location → Notifications → Completion
- Back navigation works
- Continue button disabled until goal selected
- Progress indicator updates (1 of 6 → 2 of 6 → …)
- Completion → main tab bar appears

**Key assertions:**
- "GrowWise" title visible on welcome
- "Get Started" button navigates to main TabView
- Tab bar appears after onboarding completes

---

### Flow 2: Garden Management (returning_user persona)

**Test class:** `MyGardenUITests`
**Persona:** returning_user
**When to run:** Changes in `Views/Garden/**`, `GardenView.swift`, `GardenViewModel.swift`,
`AddPlantSheet.swift`, `PlantQuickCard`, `GardenBedSection`, `GardenHeroHeader`

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/MyGardenUITests \
  2>&1 | tee ./qa-results/garden.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

**What it verifies:**
- Garden tab navigates to `screen_garden`
- Hero header add button (`garden_button_add`) opens AddPlantSheet
- Plant name text field (`addplant_textfield_name`) accepts input
- Save button dismisses sheet, plant appears in list
- Add Bed/Area alert flow opens and accepts a name
- Plant row tap opens PlantQuickCard bottom sheet
- "View Full Details" navigates to PlantDetailView
- Long-press plant row → context menu → "Delete Plant" removes the plant

---

### Flow 3: Reminders (returning_user persona)

**Test class:** `RemindersUITests`
**Persona:** returning_user
**When to run:** Changes in `AddReminderView.swift`, `ReminderService.swift`,
`PlantReminderDetailView.swift`, `ReminderSettingsView.swift`

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/RemindersUITests \
  2>&1 | tee ./qa-results/reminders.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

**What it verifies:**
- Reminders tab accessible from tab bar
- Add reminder flow opens AddReminderView
- Reminder saved and appears in list
- Reminder can be dismissed/deleted

---

### Flow 4: Garden Club (returning_user persona)

**Test class:** `GardenClubUITests`
**Persona:** returning_user
**When to run:** Changes in `Views/GardenClub/**`, `ClubCloudKitService.swift`,
`ForumService.swift`, `GardenClubService.swift`

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/GardenClubUITests \
  2>&1 | tee ./qa-results/club.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

**What it verifies:**
- Club tab shows join/create prompt when no clubs exist
- "Join a club" button opens JoinClubSheet
- "Create a club" button opens CreateClubSheet
- Club feed loads after joining/creating

---

### Flow 5: Plant Database (returning_user persona)

**Test class:** `DiscoveryUITests`
**Persona:** returning_user
**When to run:** Changes in `PlantDatabaseView.swift`, `PlantDatabaseService.swift`,
`DatabasePlantCustomizationSheet.swift`, `DatabasePlantRowView.swift`

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/DiscoveryUITests \
  2>&1 | tee ./qa-results/plant-database.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

**What it verifies:**
- Plant database tab accessible
- Plant list loads with results
- Search filters plants correctly
- Plant row tap opens detail/customization sheet

---

### Flow 6: Compost & Shopping (returning_user persona)

**Test class:** `CompostShoppingProfileUITests`
**Persona:** returning_user
**When to run:** Changes in compost, shopping list, or profile features

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/CompostShoppingProfileUITests \
  2>&1 | tee ./qa-results/compost-shopping.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

---

### Flow 7: Seed Inventory (returning_user persona)

**Test class:** `SeedInventoryUITests`
**Persona:** returning_user
**When to run:** Changes in seed inventory features

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/SeedInventoryUITests \
  2>&1 | tee ./qa-results/seeds.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

---

### Flow 8: Full UI Suite (broad changes)

Run the entire UITest suite when changes touch core infrastructure:
`DataService.swift`, `GrowWiseModels/**`, `CultivationTheme.swift`, `MainAppView.swift`

```bash
xcodebuild test \
  -workspace GrowWise.xcworkspace \
  -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests \
  2>&1 | tee ./qa-results/full-suite.txt | \
  grep -E "(Test Case|passed|failed|** TEST)"
```

---

## Evidence Extraction

After any xcodebuild test run, extract a clean summary:

```bash
grep -E "Test Case '.*' (passed|failed)" ./qa-results/<flow>.txt | \
  sed "s/Test Case '-\[//" | sed "s/\]'//" | \
  awk '{print $1, $2, $3}' | sort
```

Count results:
```bash
echo "PASSED: $(grep -c 'passed' ./qa-results/<flow>.txt)"
echo "FAILED: $(grep -c 'failed' ./qa-results/<flow>.txt)"
```

## Screenshots (ImageMagick)

After a test run, capture the simulator state:
```bash
xcrun simctl io booted screenshot ./qa-results/<flow>-after.png
```

Generate animated diff between before/after screenshots (if both exist):
```bash
magick -delay 80 ./qa-results/<flow>-before.png ./qa-results/<flow>-after.png \
  -loop 0 ./qa-results/<flow>-diff.gif
```

## Known Failure Modes

1. **CloudKit crash in test runner.** If `--uitesting` launch arg is missing, CloudKit
   init crashes in Simulator without iCloud entitlements. Always ensure test classes set
   `app.launchArguments = ["--uitesting", ...]` in `setUpWithError()`.

2. **Simulator not booted.** `xcodebuild test` may fail with "No device found" if the
   iPhone 16 simulator is not booted. Run `xcrun simctl boot "iPhone 16"` and wait 5s
   before running tests in CI.

3. **Sheet → push timing (350ms delay).** Dismissing a `.sheet` and then pushing via
   `navigationDestination` requires a ~350ms delay in the app code. If a test taps
   "View Full Details" and the navigation doesn't occur, the app is mid-transition.
   Add a 1s wait in the test before asserting the destination view.

4. **AddPlantSheet Save button requires a non-empty name.** The Save button is disabled
   until at least one character is entered in `addplant_textfield_name`. Always type
   a plant name before tapping Save.

5. **StoreKit sandbox requires simulator Apple ID.** Testing `subscribed_user` flows in
   CI requires a sandboxed Apple ID signed into the Simulator's App Store settings.
   Without this, StoreKit purchase flows will hang. If not configured, report the
   subscription flow as BLOCKED with instructions to sign in.
