# Issue #275 — User-facing strings: "GrowWise" → "Cultivation"

**Date:** 2026-05-01
**Issue:** [#275](https://github.com/jbcrane13/GrowWise/issues/275) — User-facing strings still say GrowWise instead of Cultivation
**Type:** bug, priority:high
**Author:** Blake Crane

## Problem

The app is branded "Cultivation" but six user-facing string literals still say "GrowWise" — the legacy module/repo name. This leaks engineering nomenclature into the user experience (paywall, profile, AR camera prompt, club invite share sheet, test notification).

There is no current guard preventing future regressions. New strings can drift back to "GrowWise" silently.

## Goals

1. Replace every user-visible "GrowWise" string with "Cultivation".
2. Add a SwiftLint custom rule that fails the build on future regressions, while still permitting internal module/type names (`GrowWiseServices`, `GrowWiseFeature`, etc.) used in non-user-facing strings.

## Non-Goals

- Localization (`.strings` / `String Catalog`) — no localized strings exist in the repo today.
- App Store metadata or display name — handled by the app-shell `Info.plist` (`CFBundleDisplayName`).
- Renaming Swift modules, repo, package, or types. Identifiers stay `GrowWise*`.

## Sites to change (6 string sites, 5 source files)

| File | Line | Current | New |
|---|---|---|---|
| `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift` | 346 | `"GrowWise Pro"` / `"GrowWise Premium"` (ternary) | `"Cultivation Pro"` / `"Cultivation Premium"` |
| `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift` | 379 | `"Unlock GrowWise Premium"` | `"Unlock Cultivation Premium"` |
| `GrowWisePackage/Sources/GrowWiseFeature/Views/ReminderSettingsView.swift` | 339 | `"This is a test notification from GrowWise…"` | `"This is a test notification from Cultivation…"` |
| `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/ARGardenView.swift` | 83 | `"GrowWise needs camera access for AR visualization. Please enable it in Settings."` | `"Cultivation needs camera access for AR visualization. Please enable it in Settings."` |
| `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/CreateClubSheet.swift` | 167–169 | `"Join my garden club on GrowWise! Use invite code: …"` and message text | `"Join my garden club on Cultivation! Use invite code: …"` |
| `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubDetailView.swift` | 346–348 | `"Join my garden club on GrowWise! Invite code: …"` and message text | `"Join my garden club on Cultivation! Invite code: …"` |

### Internal (non-user-facing) string to rename for cleanliness

| File | Line | Current | New |
|---|---|---|---|
| `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift` | 129 | `"GrowWise-Emergency-\(UUID().uuidString).sqlite"` | `"Cultivation-Emergency-\(UUID().uuidString).sqlite"` |

This filename is for an emergency-fallback SwiftData container. It is never displayed to a user, but renaming it lets the SwiftLint rule run without a one-off `// swiftlint:disable:this …` annotation. The path is ephemeral (UUID-suffixed), so the rename does not affect any persisted user data.

## SwiftLint rule

Append to `.swiftlint.yml`:

```yaml
custom_rules:
  # … existing rules …
  no_growwise_user_facing:
    name: "GrowWise in user-facing string"
    message: "User-facing strings should say 'Cultivation', not 'GrowWise'. Use module/type names like GrowWiseServices in code, but never in standalone literals."
    regex: '"[^"]*\bGrowWise(?![A-Za-z])[^"]*"'
    severity: error
```

The regex matches a string literal containing `GrowWise` not followed by another letter, so:

- `"GrowWise Pro"` ❌ (matches — letter is space)
- `"Cultivation"` ✅ (no match)
- `"Missing plant_database.json in GrowWiseServices bundle"` ✅ (no match — `S` follows `GrowWise`)
- `"GrowWiseFeature/Resources"` ✅ (no match)

`included`/`excluded` are inherited from the file-level `included:` block (`GrowWisePackage/Sources` and `GrowWise`), so the rule fires throughout the source tree.

## Tests

### `CultivationBrandingTests` (new file in `GrowWisePackage/Tests/GrowWiseFeatureTests`)

A small Swift Testing suite that asserts the user-facing brand-name guarantees we just created. The goal is **functional verification** (the strings actually render "Cultivation" at runtime) — not a static-text assertion that duplicates SwiftLint's job.

Approach for each site:

| Site | Test approach |
|---|---|
| ProfileView paywall row | Extract the inline ternary at line 346 into a `static func tierDisplayName(_ tier: SubscriptionTier) -> String` on `ProfileView`. Assert `ProfileView.tierDisplayName(.pro) == "Cultivation Pro"`, `ProfileView.tierDisplayName(.premium) == "Cultivation Premium"`. |
| ProfileView "Unlock …" | Same: extract a `static let unlockPremiumLabel = "Unlock Cultivation Premium"` and assert it. |
| ReminderSettingsView test-notification body | Move literal to a `static let testNotificationBody = "..."` constant; assert it begins with `"This is a test notification from Cultivation"`. |
| ARGardenView camera prompt | Move literal to `static let cameraPermissionMessage = "..."`; assert it begins with `"Cultivation needs camera access"`. |
| CreateClubSheet / ClubDetailView share copy | Extract a single shared helper `static func clubInviteShareItem(code: String) -> String` returning `"Join my garden club on Cultivation! …"`; assert with a fixed code. |

Extracting these into `static let`/`static func` is mild and serves a real purpose (unit-testable, and the share-copy helper deduplicates two near-identical strings across `CreateClubSheet` and `ClubDetailView`). It is **not** speculative refactoring — every extracted constant is referenced by a test or by the dedup site.

### SwiftLint regression check

Run `swiftlint lint --strict --config .swiftlint.yml` as part of the verification step. CI already runs SwiftLint via `.github/workflows/ci.yml`; the new rule will surface there too.

## Verification

| Step | Command / check |
|---|---|
| 1. Local lint passes (existing + new rule clean) | `swiftlint lint --strict --config .swiftlint.yml` |
| 2. Package builds | `cd GrowWisePackage && swift build` |
| 3. Tests pass on mac-mini | `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationBrandingTests 2>&1 \| tail -20"` |
| 4. Full suite green | `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 \| tail -20"` |
| 5. Manual smoke (mac-mini sim) | Open Profile → paywall row text says "Cultivation Pro/Premium". Test notification copy says Cultivation. AR camera prompt says Cultivation. Club invite share sheet says Cultivation. |

## File inventory

**Modified (7):**
- `.swiftlint.yml`
- `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`
- `GrowWisePackage/Sources/GrowWiseFeature/Views/ReminderSettingsView.swift`
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/ARGardenView.swift`
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/CreateClubSheet.swift`
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubDetailView.swift`
- `GrowWisePackage/Sources/GrowWiseServices/ModelContainerFactory.swift`

**Added (1):**
- `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationBrandingTests.swift`

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| SwiftLint regex false-positives on new code containing `"…GrowWise…"` substrings legitimately (e.g., a debug log mentioning the package). | The negative lookahead `(?![A-Za-z])` already excludes module-name suffixes. For any genuinely needed exception, contributors can add `// swiftlint:disable:this no_growwise_user_facing` with a justification. |
| Pre-commit hook now fails on existing branches that still say "GrowWise". | Acceptable — the rename is the point. Branches in flight either rebase or fix-up. |
| `ModelContainerFactory` filename change unexpectedly affects sandbox state. | The path is ephemeral (UUID-suffixed) and only used by the *emergency fallback* path. No persisted user data depends on the prefix. |

## Out of scope (deferred)

- Localization scaffolding. Tracked separately if/when localization ships.
- Renaming the GitHub repo, Swift package name, or module names. Engineering-facing only; no user impact.
- Updating in-flight branches that already use "GrowWise". Branch authors handle on rebase.

## Sequencing

This issue is independent of #271/#272/#274 and can ship as its own PR. Recommended order in the broader queue: land **#275 first** (smallest, lowest risk) once PR #276 is merged.
