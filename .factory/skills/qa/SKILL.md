---
name: qa
description: >
  Run QA tests for GrowWise (Cultivation). Analyzes git diff to determine
  affected iOS app areas, runs relevant XCUITest flows via xcodebuild on an
  iPhone 16 simulator, and generates a diff-targeted test report. Use when
  testing PRs or smoke-testing before TestFlight builds.
---

# QA Orchestrator — GrowWise (Cultivation)

**SCOPE: This skill performs functional QA only — verifying the iOS app actually
works by running XCUITests on the simulator as a real user would. Do NOT report
on CI checks, SwiftLint, SwiftFormat, unit tests, or static analysis. Those are
handled by ci.yml.**

## Step 1: Load Configuration

Read `.factory/skills/qa/config.yaml` for simulator target, personas, app definitions,
integrations, and feature flag overrides.

## Step 2: Determine Target Environment

Default: iOS Simulator — iPhone 16. The `xcodebuild` tool is the test runner for all flows.

## Step 3: Analyze Git Diff

Run:
```bash
git diff origin/master...HEAD --name-only
```

Map changed files to apps using the `path_patterns` in config.yaml:

- `GrowWise/**`, `GrowWisePackage/Sources/**`, `GrowWiseUITests/**` → `ios` app affected
- `.factory/skills/**`, `docs/**`, `.github/**`, `*.md`, `*.yml` (CI only) → NO app affected

If NO app is affected (docs-only, CI-only, skill-only change), report:
> INCONCLUSIVE: No app code changed — QA not applicable for this diff.

Do NOT run any test flows. Stop after the report.

## Step 4: Pre-flight Checks (iOS only)

Run ONLY if the `ios` app is affected by the diff.

**1. Boot simulator:**
```bash
xcrun simctl boot "iPhone 16" 2>/dev/null || true
open -a Simulator 2>/dev/null || true
sleep 5
```

**2. Build the app:**
```bash
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | tail -10
```

If the build fails, report ALL flows as BLOCKED with the build error output. Do not proceed.

## Step 5: Map Diff to Relevant Flows

Read `.factory/skills/qa-ios/SKILL.md` for the full menu of flows.

Select flows based on changed paths:

| Changed path(s) | Run these flows |
|---|---|
| `OnboardingFlow/**` | Onboarding flows (fresh_install persona) |
| `Views/Garden/**`, `GardenView.swift`, `GardenViewModel.swift` | Garden management flows |
| `AddReminderView.swift`, `ReminderService.swift`, `PlantReminderDetailView.swift` | Reminder flows |
| `Views/Journal/**`, `JournalView.swift` | Journal flows |
| `PlantDatabaseView.swift`, `PlantDatabaseService.swift` | Plant database flows |
| `Views/GardenClub/**`, `ClubCloudKitService.swift`, `ForumService.swift` | Garden Club flows |
| `PaywallView.swift`, `SubscriptionService.swift` | Subscription/paywall flows (subscribed_user persona) |
| `ProfileView.swift`, `Views/Settings/**` | Profile & settings flows |
| `HomeView.swift`, `HomeViewModel.swift` | Home dashboard flows |
| `GrowWisePackage/Sources/GrowWiseModels/**` | Core data integrity flows (returning_user persona) |
| `DataService.swift`, `Repositories/**` | Core data integrity flows (returning_user persona) |
| `CultivationTheme.swift`, `ViewModifiers.swift` | UI component flows (spot-check affected screens) |

If no existing flow covers the change, write an ad-hoc xcodebuild invocation:
```bash
xcodebuild test -workspace GrowWise.xcworkspace -scheme GrowWise \
  -sdk iphonesimulator \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing GrowWiseUITests/<RelevantTestClass> \
  2>&1 | grep -E "(Test Case|PASS|FAIL|error:|** TEST)"
```

Do NOT run flows for completely unrelated features.

## Step 6: Execute Flows

For each selected flow, run the `xcodebuild test` command from the sub-skill.
Capture output to `./qa-results/<flow-name>.txt`.

Create the output directory first:
```bash
mkdir -p ./qa-results
```

Use the appropriate persona's launch arguments (set via `-testenv` or the
`-destination-timeout` block in the sub-skill).

## Step 7: Evidence Capture

After each xcodebuild test run, extract the summary:
```bash
grep -E "(Test Case '.*'|** TEST SUCCEEDED|** TEST FAILED|passed|failed|error:)" \
  ./qa-results/<flow-name>.txt | tail -20
```

If ImageMagick is available (`imagemagick: true`), capture simulator screenshots:
```bash
xcrun simctl io booted screenshot ./qa-results/<flow-name>-screenshot.png
```

Embed test result summaries as fenced code blocks in the report. Reference screenshot
filenames for visual proof (available in downloadable artifacts).

## Step 8: Test Quality Gate

1. **Change-specific first** — at least half of tests must directly verify the changed behavior.
2. **Integration tests are valid** — verifying the change integrates with adjacent features is good.
3. **No unrelated flows** — do not test features the diff didn't touch.
4. **Negative tests** — include at least one boundary/error-handling test per flow.
5. **Multiple personas** — run with both `fresh_install` and `returning_user` if the change affects state-dependent behavior.
6. **INCONCLUSIVE if unsure** — if you cannot articulate what the PR changes, mark INCONCLUSIVE.

## Step 9: Handle Failures

Never silently skip a flow. If `xcodebuild test` fails to launch (simulator issue, signing,
build error, missing entitlement), report the flow as BLOCKED with:
- What was tried (the exact command)
- The error output
- How to fix it

Then continue with remaining flows.

## Step 10: Generate Report

Write report to `./qa-results/report.md` using `.factory/skills/qa/REPORT-TEMPLATE.md`.

Rules:
- Start with `## QA Report`
- Result emojis: :white_check_mark: PASS, :x: FAIL, :no_entry: BLOCKED, :warning: FLAKY, :grey_question: INCONCLUSIVE
- Concise: table + "Action Required" (if any) + single collapsed evidence block
- Do NOT list build/boot steps as test rows — only user-facing behavior counts

## Step 11: Suggest Skill Updates (Failure Learning)

After generating the report, check if any BLOCKED or FAIL results revealed a new
**environment insight** not already in the sub-skill's Known Failure Modes.

Good suggestions:
- "iPhone 16 simulator requires `xcrun simctl boot` before xcodebuild"
- "GrowWiseUITests requires `--uitesting` launch arg or CloudKit crashes the test runner"
- "StoreKit sandbox requires a signed-in Apple ID in Simulator settings"

Bad suggestions (do NOT include):
- Wrong XCUITest selectors (fix directly)
- Expected behavior changes from the PR

Write `qa-results/skill-updates.json` for the workflow to auto-commit:
```json
[
  {
    "file": ".factory/skills/qa-ios/SKILL.md",
    "section": "Known Failure Modes",
    "action": "append",
    "content": "<exact markdown to insert>"
  }
]
```
