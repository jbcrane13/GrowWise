# Issue #275 — Cultivation Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every user-visible "GrowWise" string with "Cultivation" and add a SwiftLint custom rule to prevent regression.

**Architecture:** Mechanical TDD pass over 6 string sites in 5 SwiftUI views. Each site is refactored to a static helper/constant on the owning view (so the test can assert the literal without spinning up SwiftUI rendering), the helper is asserted in a Swift Testing suite, then the inline call site is updated to use the helper. After all sites are migrated, an internal SQLite filename is renamed and the SwiftLint custom rule is added; the rule's regex uses `(?![A-Za-z])` to ignore module-name strings like `"GrowWiseServices"`.

**Tech Stack:** Swift 6, Swift Testing (`@Suite`/`@Test`/`#expect`), SwiftLint custom rules, SwiftUI.

**Working branch:** `feat/issue-275-cultivation-rename` (already created with the design spec committed).

**Spec:** [`docs/superpowers/specs/2026-05-01-issue-275-cultivation-rename-design.md`](../specs/2026-05-01-issue-275-cultivation-rename-design.md)

---

## File inventory

**Will create:**
- `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

**Will modify:**
- `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift` (extract helper + 2 string sites)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/ReminderSettingsView.swift` (extract constant + 1 string site)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/ARGardenView.swift` (extract constant + 1 string site)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/CreateClubSheet.swift` (use shared helper, 2 strings)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubDetailView.swift` (use shared helper, 2 strings)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubInviteSharing.swift` *(new helper file holding `clubInviteShareItem(code:)` and `clubInviteShareMessage(clubName:code:)`)*
- `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift` (rename emergency SQLite filename prefix)
- `.swiftlint.yml` (add `no_growwise_user_facing` custom rule)

---

## Task 1: ProfileView paywall row — extract `tierDisplayName(_:)` helper

**Files:**
- Test (create): `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift:346`

- [ ] **Step 1: Create the failing test file**

Create `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`:

```swift
@testable import GrowWiseFeature
import GrowWiseModels
import Testing

@Suite("Cultivation branding")
struct CultivationBrandingTests {
    // MARK: - ProfileView paywall row

    @Test("Tier display name uses Cultivation Pro for .pro tier")
    func tierDisplayNameProUsesCultivation() {
        #expect(ProfileView.tierDisplayName(.pro) == "Cultivation Pro")
    }

    @Test("Tier display name uses Cultivation Premium for .premium tier")
    func tierDisplayNamePremiumUsesCultivation() {
        #expect(ProfileView.tierDisplayName(.premium) == "Cultivation Premium")
    }
}
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: Compile error — `'tierDisplayName' is not a member of 'ProfileView'`. (This is the failing-test signal for TDD.)

- [ ] **Step 3: Add the helper and update the call site**

In `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`, locate the `activeSubscriptionCard(tier:expiryDate:)` function around line 339. Add a static helper inside the same `extension ProfileView` (or create one if absent — match what the file already does for other helpers) and update the inline ternary:

```swift
extension ProfileView {
    static func tierDisplayName(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .pro: return "Cultivation Pro"
        case .premium: return "Cultivation Premium"
        case .free: return "Cultivation Free"
        }
    }
}
```

Then change line 346 from:

```swift
Text(tier == .pro ? "GrowWise Pro" : "GrowWise Premium")
```

to:

```swift
Text(ProfileView.tierDisplayName(tier))
```

> **Note on `.free`:** the original ternary only handled `.pro` and `.premium` because `activeSubscriptionCard` is unreachable for `.free` users (gated by the surrounding paywall logic). Including `.free` in the `switch` keeps it exhaustive without a `default:` clause and gives a sensible fallback if the call site is ever broadened.

- [ ] **Step 4: Run tests to verify they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift
git commit -m "$(cat <<'EOF'
feat(#275): rename paywall tier label to Cultivation Pro/Premium

Extracts the inline ternary in activeSubscriptionCard into a static
ProfileView.tierDisplayName(_:) so the rendered string can be unit-tested
without spinning up SwiftUI.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ProfileView "Unlock Premium" headline

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift:379`
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

- [ ] **Step 1: Add the failing test**

Append to `CultivationBrandingTests`:

```swift
    // MARK: - ProfileView paywall headline

    @Test("Paywall unlock headline uses Cultivation")
    func paywallUnlockHeadlineUsesCultivation() {
        #expect(ProfileView.unlockPremiumHeadline == "Unlock Cultivation Premium")
    }
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter 'CultivationBrandingTests/paywallUnlockHeadlineUsesCultivation' 2>&1 | tail -10"`

Expected: Compile error — `'unlockPremiumHeadline' is not a member of 'ProfileView'`.

- [ ] **Step 3: Extract constant and update call site**

In `ProfileView.swift`, add to the same extension as Task 1:

```swift
    static let unlockPremiumHeadline = "Unlock Cultivation Premium"
```

Change line 379 from:

```swift
Text("Unlock GrowWise Premium")
```

to:

```swift
Text(ProfileView.unlockPremiumHeadline)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift
git commit -m "$(cat <<'EOF'
feat(#275): rename paywall headline to "Unlock Cultivation Premium"

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: ReminderSettingsView test-notification body

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ReminderSettingsView.swift:339`
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

- [ ] **Step 1: Add the failing test**

Append to `CultivationBrandingTests`:

```swift
    // MARK: - Test notification body

    @Test("Test-notification body uses Cultivation")
    func testNotificationBodyUsesCultivation() {
        #expect(ReminderSettingsView.testNotificationBody.hasPrefix("This is a test notification from Cultivation"))
    }
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter 'CultivationBrandingTests/testNotificationBodyUsesCultivation' 2>&1 | tail -10"`

Expected: Compile error — `'testNotificationBody' is not a member of 'ReminderSettingsView'`.

- [ ] **Step 3: Extract constant and update call site**

In `ReminderSettingsView.swift`, add at the bottom of the file before the final closing brace:

```swift
extension ReminderSettingsView {
    static let testNotificationBody =
        "This is a test notification from Cultivation. Your reminder settings are working correctly!"
}
```

Change line 339 from:

```swift
body: "This is a test notification from GrowWise. Your reminder settings are working correctly!",
```

to:

```swift
body: ReminderSettingsView.testNotificationBody,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/ReminderSettingsView.swift
git commit -m "$(cat <<'EOF'
feat(#275): rename test-notification body to Cultivation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: ARGardenView camera-permission message

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/ARGardenView.swift:83`
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

- [ ] **Step 1: Add the failing test**

Append to `CultivationBrandingTests`:

```swift
    // MARK: - AR camera permission

    @Test("AR camera permission message uses Cultivation")
    func arCameraPermissionMessageUsesCultivation() {
        #expect(ARGardenView.cameraPermissionMessage.hasPrefix("Cultivation needs camera access"))
    }
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter 'CultivationBrandingTests/arCameraPermissionMessageUsesCultivation' 2>&1 | tail -10"`

Expected: Compile error — `'cameraPermissionMessage' is not a member of 'ARGardenView'`.

- [ ] **Step 3: Extract constant and update call site**

In `ARGardenView.swift`, add at the bottom of the file before the final closing brace:

```swift
extension ARGardenView {
    static let cameraPermissionMessage =
        "Cultivation needs camera access for AR visualization. Please enable it in Settings."
}
```

Change line 83 from:

```swift
Text("GrowWise needs camera access for AR visualization. Please enable it in Settings.")
```

to:

```swift
Text(ARGardenView.cameraPermissionMessage)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/ARGardenView.swift
git commit -m "$(cat <<'EOF'
feat(#275): rename AR camera permission copy to Cultivation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Shared club invite share helper (CreateClubSheet + ClubDetailView)

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubInviteSharing.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/CreateClubSheet.swift:167-169`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubDetailView.swift:346-348`
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

- [ ] **Step 1: Add the failing test**

Append to `CultivationBrandingTests`:

```swift
    // MARK: - Club invite share copy

    @Test("Club invite share item uses Cultivation")
    func clubInviteShareItemUsesCultivation() {
        let item = ClubInviteSharing.shareItem(code: "ABC123")
        #expect(item == "Join my garden club on Cultivation! Use invite code: ABC123")
    }

    @Test("Club invite share message uses Cultivation and includes club name")
    func clubInviteShareMessageUsesCultivation() {
        let message = ClubInviteSharing.shareMessage(clubName: "My Garden", code: "ABC123")
        #expect(message == "Join My Garden on Cultivation with code ABC123")
    }

    @Test("Club invite share message defaults club name when nil")
    func clubInviteShareMessageDefaultsClubName() {
        let message = ClubInviteSharing.shareMessage(clubName: nil, code: "XYZ")
        #expect(message == "Join our club on Cultivation with code XYZ")
    }
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: Compile error — `Cannot find 'ClubInviteSharing' in scope`.

- [ ] **Step 3: Create the helper**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubInviteSharing.swift`:

```swift
import Foundation

/// Builders for the user-facing strings used by club-invite ShareLinks.
///
/// Centralized so CreateClubSheet and ClubDetailView render the same copy
/// and so unit tests can assert the rendered text without instantiating
/// SwiftUI views.
enum ClubInviteSharing {
    /// Primary share-sheet item (the "subject" of the share).
    static func shareItem(code: String) -> String {
        "Join my garden club on Cultivation! Use invite code: \(code)"
    }

    /// Secondary share-sheet message (shown next to the item in some
    /// share targets). Falls back to "our club" when the club has no name.
    static func shareMessage(clubName: String?, code: String) -> String {
        let resolvedName = clubName ?? "our club"
        return "Join \(resolvedName) on Cultivation with code \(code)"
    }
}
```

- [ ] **Step 4: Update CreateClubSheet call site**

In `CreateClubSheet.swift`, change lines 166-170 from:

```swift
ShareLink(
    item: "Join my garden club on GrowWise! Use invite code: \(code)",
    subject: Text("Garden Club Invite"),
    message: Text("Join \(club.name ?? "our club") on GrowWise with code \(code)")
) {
```

to:

```swift
ShareLink(
    item: ClubInviteSharing.shareItem(code: code),
    subject: Text("Garden Club Invite"),
    message: Text(ClubInviteSharing.shareMessage(clubName: club.name, code: code))
) {
```

- [ ] **Step 5: Update ClubDetailView call site**

In `ClubDetailView.swift`, change lines 345-349 from:

```swift
ShareLink(
    item: "Join my garden club on GrowWise! Invite code: \(code)",
    subject: Text("Garden Club Invite"),
    message: Text("Use code \(code) to join on GrowWise")
) {
```

to:

```swift
ShareLink(
    item: ClubInviteSharing.shareItem(code: code),
    subject: Text("Garden Club Invite"),
    message: Text(ClubInviteSharing.shareMessage(clubName: club.name, code: code))
) {
```

> **Note:** The original `ClubDetailView` message text was `"Use code … to join on GrowWise"` (different wording from `CreateClubSheet`). We deliberately unify on the `CreateClubSheet` phrasing here since the helper is the new source of truth and the wording difference was incidental.

- [ ] **Step 6: Run tests to verify they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 | tail -10"`

Expected: 8 tests pass.

- [ ] **Step 7: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubInviteSharing.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/CreateClubSheet.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubDetailView.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift
git commit -m "$(cat <<'EOF'
feat(#275): unify club invite share copy under ClubInviteSharing helper

Both CreateClubSheet and ClubDetailView now render share-sheet text via
ClubInviteSharing.shareItem(code:) and shareMessage(clubName:code:),
which use "Cultivation" instead of "GrowWise". The two views had
slightly different message wording before; they now share the same
helper so the strings stay in lockstep.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Rename emergency SQLite filename in `ModelContainerFactory`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift:129`

This filename is internal-only (UUID-suffixed temp path used during catastrophic ModelContainer init failure). Renaming it to `Cultivation-Emergency-…` removes the only string that would otherwise trip the new SwiftLint rule.

- [ ] **Step 1: Update the filename literal**

Change line 129 from:

```swift
.appendingPathComponent("GrowWise-Emergency-\(UUID().uuidString).sqlite")
```

to:

```swift
.appendingPathComponent("Cultivation-Emergency-\(UUID().uuidString).sqlite")
```

- [ ] **Step 2: Build to confirm nothing else references the old prefix**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`

Expected: Build succeeds.

- [ ] **Step 3: Confirm no other code references the prefix**

Run: `grep -rn "GrowWise-Emergency" GrowWisePackage/ GrowWise/ 2>/dev/null`

Expected: No output (other than this plan/spec, which lives in `docs/`).

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift
git commit -m "$(cat <<'EOF'
chore(#275): rename emergency SQLite filename prefix to Cultivation

The L3 emergency-fallback temp file in ModelContainerFactory used the
prefix "GrowWise-Emergency-…". The path is ephemeral (UUID-suffixed)
and not visible to users, but renaming it lets the upcoming SwiftLint
no_growwise_user_facing rule run clean across the source tree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add SwiftLint custom rule and verify clean

**Files:**
- Modify: `.swiftlint.yml`

- [ ] **Step 1: Append the custom rule to `.swiftlint.yml`**

Inside the existing `custom_rules:` block (after `fixme_with_issue`), append:

```yaml
  no_growwise_user_facing:
    name: "GrowWise in user-facing string"
    message: "User-facing strings should say 'Cultivation', not 'GrowWise'. Use module/type names like GrowWiseServices in code, but never in standalone literals."
    regex: '"[^"]*\bGrowWise(?![A-Za-z])[^"]*"'
    severity: error
```

> **Note:** The `regex` value is a YAML single-quoted scalar. To include a literal single quote inside it, double it (`''`) — there are no single quotes in this regex so no escaping is needed. Do not switch to double-quoted YAML; the backslashes would have to be doubled.

- [ ] **Step 2: Run SwiftLint locally to verify the rule fires only where expected**

Run: `swiftlint lint --strict --config .swiftlint.yml 2>&1 | grep -i "no_growwise_user_facing\|error\|warning" | head -40`

Expected: No `no_growwise_user_facing` violations. (Tasks 1-6 already removed every match.)

If any violation appears, halt and fix it — do not proceed to Step 3.

- [ ] **Step 3: Run the full lint --strict pass**

Run: `swiftlint lint --strict --config .swiftlint.yml 2>&1 | tail -20`

Expected: `Done linting!` with 0 violations.

- [ ] **Step 4: Run the full test suite**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"`

Expected: All tests pass, including the 8 new `CultivationBrandingTests`.

- [ ] **Step 5: Sanity-check that the rule actually catches a regression**

Locally, temporarily edit `ProfileView.swift` line 346 area to reintroduce the bug, e.g. add this somewhere safe:

```swift
private let _regressionProbe = "Welcome to GrowWise"
```

Run: `swiftlint lint --strict --config .swiftlint.yml 2>&1 | grep "no_growwise_user_facing"`

Expected: One violation reported pointing at the new line.

Then **revert the probe change** (`git checkout -- GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`) and re-run lint to confirm the tree is clean again.

- [ ] **Step 6: Commit**

```bash
git add .swiftlint.yml
git commit -m "$(cat <<'EOF'
chore(#275): add SwiftLint no_growwise_user_facing custom rule

Fails the build on any string literal containing the standalone word
"GrowWise" (lookahead excludes module-name suffixes like GrowWiseServices,
GrowWiseFeature, GrowWiseModels). Manually verified the rule catches a
regression by injecting a probe literal and reverting.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Open PR and verify CI

**Files:** none (workflow only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/issue-275-cultivation-rename
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --repo jbcrane13/GrowWise \
    --title "fix(#275): rename user-facing strings to Cultivation + SwiftLint guard" \
    --body "$(cat <<'EOF'
## Summary
- Replace 6 user-visible "GrowWise" string literals with "Cultivation" across ProfileView, ReminderSettingsView, ARGardenView, CreateClubSheet, and ClubDetailView.
- Unify the two club-invite ShareLink copies under a new `ClubInviteSharing` helper.
- Rename the internal emergency-fallback SQLite filename prefix from `GrowWise-Emergency-…` to `Cultivation-Emergency-…` so the lint rule runs clean.
- Add a `no_growwise_user_facing` SwiftLint custom rule that fails the build on any future regression while still permitting module/type names like `GrowWiseServices` in non-user-facing strings.
- Add `CultivationBrandingTests` (8 tests) asserting each helper renders the expected Cultivation copy.

Closes #275.

## Test plan
- [ ] `swiftlint lint --strict --config .swiftlint.yml` reports 0 violations
- [ ] `swift build` succeeds locally (`cd GrowWisePackage && swift build`)
- [ ] `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test"` reports 0 failures
- [ ] Manual smoke (mac-mini sim): paywall row → "Cultivation Pro/Premium"; paywall headline → "Unlock Cultivation Premium"; AR camera prompt → "Cultivation needs camera access…"; Reminders → Test Notification → body says "from Cultivation"; club detail → Share Invite → text says "Join … on Cultivation".

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Wait for CI checks**

```bash
gh pr checks $(gh pr view --json number --jq .number) --repo jbcrane13/GrowWise --watch
```

Expected: All checks pass (Build, Test, SwiftLint, SwiftFormat, Coverage, etc.). CodeQL may finish later — that's fine.

- [ ] **Step 4: Stop and hand back to the user**

Once checks are green, comment in the conversation:

> "PR opened, all required checks green. Awaiting your review/merge approval."

Do **not** auto-merge. Do **not** close issue #275 yourself — `gh pr merge` (when invoked by the maintainer with the `Closes #275` keyword in the body) will close the issue on merge.

---

## Verification (final, after Task 8)

- [ ] PR opened and linked to issue #275 (the body says `Closes #275`).
- [ ] Required CI checks (Build, Test, SwiftLint, SwiftFormat, Coverage Threshold, QA — iOS Simulator) are green.
- [ ] No regressions to existing tests (full `swift test` is part of CI).
- [ ] No new SwiftLint violations.
- [ ] Issue #275 will close automatically when the maintainer merges.

## Notes for the implementer

- **Working branch is already created:** `feat/issue-275-cultivation-rename` was branched from master and has the design spec committed. Do not re-branch.
- **Tests run on mac-mini, not locally.** Every `swift test` invocation in this plan goes through `ssh mac-mini "..."`. Do not run `swift test` or `xcodebuild test` on the local machine — see CLAUDE.md.
- **SwiftLint and SwiftFormat run as pre-commit hooks.** If a commit gets rewritten by the formatter hook, accept it and re-stage; that's expected.
- **One commit per task.** Frequent commits make rollback easy if anything goes wrong.
- **If `swift test --filter` includes a slash, quote it.** `--filter 'CultivationBrandingTests/testNotificationBodyUsesCultivation'`.
