# Cultivation — v2 redesign execution + user-facing rename

**Date:** 2026-04-22
**Status:** In progress
**Supersedes (partially):** N/A — this is the execution plan for the pending v2 pivot described below.

## What this document is

This is the execution plan for two linked initiatives:

1. Shipping the "Simplified UI v2" redesign that was fully specced on 2026-04-20 but never implemented in code (the Cowork session that produced the spec had no Swift toolchain, so the spec + implementation guide exist and nothing else).
2. Completing the user-facing rename of the app from **GrowWise** to **Cultivation**.

The visual design and screen-by-screen specifics are *not* re-designed here. Those live in the v2 design doc (see Source-of-truth inputs below). This document covers **how the work is sequenced and landed**, **what the rename scope is**, and **what "done" looks like**.

## Source-of-truth inputs

At the start of execution the following three files — currently in `growwise redesigfn/` at the repo root — get moved into their proper homes on the redesign branch, and `growwise redesigfn/` is deleted:

| Source | Destination |
|---|---|
| `growwise redesigfn/2026-04-20-simplified-ui-v2-design.md` | `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md` |
| `growwise redesigfn/2026-04-20-simplified-ui-v2-implementation.md` | `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md`. Kept as a reference for code shapes (ViewModifier replacements, Club feed layout, etc.). Its Phase 2 ("font registration") section is obsolete under our system-font decision — a one-line note is added at the top of the file when moved to say so. |
| `growwise redesigfn/cultivation-simplified-wireflow.html` | `docs/mockups/cultivation-simplified-wireflow.html` |
| ADR-019 (the v2 pivot entry at the bottom of `growwise redesigfn/ADR.md`) | Appended to `docs/architecture/ADR.md` verbatim. Master's ADR.md currently stops at ADR-018. |

The 2026-04-20 design doc remains **authoritative for visual design** — palette tokens, screen layouts, copy, micro-interactions. If any ambiguity surfaces during implementation, the 2026-04-20 spec wins over this document for visual decisions. This document wins for sequencing, rename scope, and acceptance criteria.

## Decisions locked during brainstorming

1. **Rename scope: user-facing only.** Change what humans see, keep every code-level identifier. Explicitly unchanged: bundle ID `com.growwiser.app`, CloudKit container `iCloud.com.growwise.gardening`, app group `group.com.growwiser.app`, keychain service `com.growwiser.app`, StoreKit product IDs `com.growwise.premium.*` / `com.growwise.pro.*`, logger subsystems `com.growwise.*`, Swift modules `GrowWiseFeature` / `GrowWiseServices` / `GrowWiseModels`, folder names `GrowWise/` / `GrowWisePackage/`, workspace and xcodeproj file names, repo name `jbcrane13/GrowWise`. Reason: this scope is reversible, requires no data migration, and ships today. The identifier-level rebrand (with an iCloud data migration and a StoreKit remap) is out of scope — it would be its own project with its own risk discussion.
2. **Execute the 2026-04-20 v2 spec as written,** except:
   - **No custom font download.** Use iOS system fonts as the nearest match: `.system(design: .serif)` (New York) where the spec calls for Fraunces, and `.system(design: .rounded)` (SF Pro Rounded) where it calls for Manrope. The `FontRegistration.swift` bootstrap, the `Resources/Fonts/` folder, and the `UIAppFonts` `Info.plist` entries are *not* added. `CultivationTheme.Fonts` is a thin pass-through to system fonts.
3. **Phased PRs into a long-lived redesign branch.** Branch `redesign/v2` off current `master`. Each phase PRs into `redesign/v2`. When all phases are green, one final PR merges `redesign/v2` → `master`.
4. **Drop the current `redesign/v2-simplified-ui` branch entirely** (it has only the DataService-test merge on it, no redesign code) and remove its locked, broken worktree at `/sessions/relaxed-keen-mendel/mnt/GrowWise/.claude/worktrees/redesign-v2`.
5. **No worktree.** Work directly on `redesign/v2` from `/Users/blake/Projects/GrowWise`.

## Prep commit (before Phase 1)

On `master`, create `redesign/v2`, then on `redesign/v2`:

1. `git worktree remove --force /sessions/relaxed-keen-mendel/mnt/GrowWise/.claude/worktrees/redesign-v2 || git worktree prune`
2. Delete the old redesign branch: `git branch -D redesign/v2-simplified-ui && git push origin --delete redesign/v2-simplified-ui`
3. Move the three source-of-truth files per the table above. Delete `growwise redesigfn/`.
4. Append ADR-019 (copy verbatim from `growwise redesigfn/ADR.md`) to `docs/architecture/ADR.md`. Then edit existing ADRs to flag their relationship to ADR-019:
   - ADR-009 (5-tab navigation) — append `**Updated:** 2026-04-22 → superseded by ADR-019 (4 tabs).`
   - ADR-010 (dark-glass palette) — append `**Updated:** 2026-04-22 → palette and surfaces superseded by ADR-019; centralization in `CultivationTheme` stays.`
   - ADR-017 (Botanical Field Journal) — append `**Updated:** 2026-04-22 → design-language *direction* (serif, warm earth tones, coral accents) stays in force; surface shifts from dark glass to cream paper per ADR-019.`
5. Append a new ADR-020 describing the user-facing-only rename scope (see "ADR-020 draft" below).
6. Commit the spec you are reading now, plus all of the above, as the first commit on `redesign/v2`.

## Phase table

Each phase ends with `swift build` clean on mac-mini as a hard gate. Later gates add tests and lint.

| # | Phase | Scope | Validation |
|---|---|---|---|
| 1 | Theme tokens + ViewModifiers | Replace palette in `CultivationTheme.Colors`, add `Gradients.warmAccent` / update `Gradients.hero`, add `Radius.statCard`, bump `Spacing` values, keep `heroGlow` / `brandGold` as legacy aliases. Replace `GlassCardModifier` with `PaperCardModifier`, keep `.glassCard()` alias routing to `.paperCard()`. Update `HeroBackgroundModifier`, `GradientButtonStyle` (flat moss), add `CoralButtonStyle`, add `SmartTag`, update `GlassPill` / `QuickStatCard`. | `swift build` clean |
| 2 | Typography | Simplify `CultivationTheme.Fonts` to return system fonts directly (no availability checks, no registration). `Typography.*` helpers unchanged at call sites. | `swift build` clean |
| 3 | Tab restructure | `TabSelection` enum becomes `home`/`garden`/`club`/`profile`. `MainAppView` renders 4 tabs in that order with coral tint. `ProfileView` is relabeled "Me" in the tab bar and adds a link to the existing Community Forum view. `GardenClubFeedView` is stubbed at this phase so the Club tab compiles — body is a placeholder until Phase 5. | App boots, all 4 tabs render |
| 4 | Delete Reminders + Journal tabs | Remove `Views/RemindersListView.swift`, `Views/Journal/JournalView.swift`, `JournalEntryRow.swift`, `JournalEntryDetailView.swift`, `AddJournalEntryView.swift`. Remove any tests that import them. Remove or rewrite XCUITests that target `tab_journal` / `tab_reminders`. `JournalEntry` and `PlantReminder` models stay. `ReminderService` stays. | `grep -rn "JournalView\|RemindersListView" GrowWisePackage/Sources` returns zero; `swift build` clean |
| 5 | GardenClubFeedView | Implement `Views/GardenClub/GardenClubFeedView.swift` per v2 spec §4: share prompt with avatar + 📷, segmented control (Club feed / Nearby / Following), post cards (avatar + zone tag + caption + photo with meta pill + ♥/💬/↗), smart-match dashed-sage card. First cut uses in-memory seeded sample posts. CloudKit wiring via `ClubCloudKitService` is deferred to a later issue. | Club tab renders with sample data on simulator |
| 6 | Home rewrite | Restyle `HomeView`, `Home/HomeHeroHeader`, `Home/SeasonalTipCard`, `Home/GardenHealthCardView` to cream paper per v2 spec §1. Add `Home/YourClubCard.swift` with coral/honey gradient banner. `HomeViewModel` gains a `latestClubPost` property assembled during `load()`; no other behavior changes (urgency grouping, inline quick-care icons per ADR-018, garden health score per #142, seasonal planner per #141 all preserved). | Home screen renders |
| 7 | Garden rewrite | Restyle `GardenView` and `Views/Garden/GardenComponents.swift` (PlantRow, BedGroupHeader, TaskRow, CompanionTipCard) to cream paper per v2 spec §2. Remove glass backgrounds. Filter chips use new moss-active state. Plant cards use 56pt thumbnail + serif name + italic latin + status dot + next-care line. | Garden screen renders |
| 8 | Plant Detail rewrite | Restyle `Views/MyGardenPlantDetailView.swift` per v2 spec §3: hero photo (180pt), serif plant name + italic latin + `Auto-identified` SmartTag, 3 stat cards (Sun/Water/Soil), two-button row (moss Log-care + paper Get-advice), coral Share-to-Club button, sage-bordered advice card, photo-journal strip reading from the plant's `JournalEntry` records with a dashed `+` add cell. | Plant Detail renders |
| 9 | Rename sweep | `CFBundleDisplayName = Cultivation` in both Debug and Release build configs of `GrowWise.xcodeproj/project.pbxproj`. User-visible strings swept and changed. Docs/READMEs updated. Audit grep (below) returns only expected-identifier matches. | `plutil -p` on built app shows `"Cultivation"`; `swift build` clean; audit grep clean |
| 10 | Tests + lint + format + code-review | Repair broken tests, add new tests (see Testing below), run `swiftlint --strict`, `swiftformat --lint`, run `code-review` skill. Capture `ui-verify` screenshot walkthrough. | `swift test` green on mac-mini; lint/format clean; code-reviewer returns no FAILs |
| 11 | Final PR | `redesign/v2` → `master` with screenshots, acceptance checklist in description. | All phase gates confirmed green |

**Ordering rationale.** Phases 1 and 2 land tokens first so every later screen rewrite compiles against the new palette from the outset. Phase 3 restructures tabs with Club stubbed before Phase 4 deletes the old tabs, so we never have a state with zero Club tab and zero Journal/Reminders tabs simultaneously (that would leave the test and XCUITest targets mid-broken). Phase 4 happens before Phase 5 so the Club view can be built against a clean tree without Journal/Reminders symbols in scope. Phase 9 (rename) lands late because earlier phases produce a lot of new user-visible strings that need to use "Cultivation" from birth; doing the rename sweep last catches those too.

## Theme + typography specifics

**Palette (from v2 spec, unchanged).** Cream `#F6F0E4`, paperDeep `#EFE6D3`, card `#FFFDF7`, ink `#1F2A22`, inkSoft `#3F4A40`, inkQuiet `#6E7368`, sage `#7B9069`, sageDeep `#4F6B49`, moss `#2E4631`, coral `#D9694B`, coralDeep `#B14F33`, honey `#C99327`, sky `#6F94A6`. Dark-mode pairs per v2 spec §Color palette. Status colors (`statusAlert` / `statusWarning` / `statusHealthy`) shift from the current vivid Apple palette to the cream-friendly hues in the v2 spec.

**CultivationTheme.Fonts — final shape:**

```swift
public enum Fonts {
    public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    public static func displayItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }
    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
```

Call sites continue to go through `CultivationTheme.Typography.title/body/etc.` — those helpers route through `Fonts`, so replacing system fonts with Fraunces/Manrope in a future pass would be a single-file change.

**Kept public API surface.** `CultivationTheme.Colors.*`, `Gradients.*`, `Radius.*`, `Spacing.*`, `Animation.*`, `Typography.*`, plus the new `Fonts` namespace. Legacy aliases `Colors.heroGlow` and `Colors.brandGold` are retained through Phase 1 so the ~20 call sites that reference them keep compiling; they're reviewed for deletion in Phase 10.

**ViewModifiers — required changes in Phase 1.** See `growwise redesigfn/2026-04-20-simplified-ui-v2-implementation.md` §Phase 1 for the full replacement source of `PaperCardModifier`, `HeroBackgroundModifier`, `GradientButtonStyle`, `CoralButtonStyle`, `SmartTag`, `GlassPill`, `QuickStatCard`. That file is not checked in — copy the shapes verbatim and cite them in the PR description.

**Global background.** `MainAppView` root applies `CultivationTheme.Colors.background` (cream paper on light, near-black warm dark on dark mode). No paper-grain texture image in v1 of the redesign — solid cream first; grain overlay is a follow-up issue if the review pass judges the screens too flat.

## Rename scope — exact change list

**Changes (Phase 9).**

1. `GrowWise.xcodeproj/project.pbxproj`: both `INFOPLIST_KEY_CFBundleDisplayName = GrowWise;` entries become `Cultivation;`.
2. `Config/Shared.xcconfig`: `PRODUCT_NAME` and `PRODUCT_DISPLAY_NAME` already `Cultivation`; no change.
3. User-visible Swift strings — swept via `grep -rn "GrowWise\|Grow Wise\|growwise" GrowWisePackage/Sources --include="*.swift"` filtered to `Text("…")`, `LocalizedStringKey`, `UNMutableNotificationContent`, alert titles/messages, onboarding copy, StoreKit `localizedDescription`/`localizedTitle`, share-sheet subject lines, About / Settings footer strings, empty-state copy.
4. Analytics **display names** (not keys). If Amplitude/Sentry event definitions contain a human-readable `title` or `description`, update those. Underlying event keys (`"plant_added"`, etc.) are identifiers and stay.
5. Docs: `README.md`, `GrowWise/Data/README.md`, marketing release notes. `CLAUDE.md` and `AGENTS.md` keep "GrowWise (branded **Cultivation**)" — that phrasing accurately describes the post-rename reality for developers.
6. Xcode scheme display names stay as `GrowWise` — devs see them, not users. (Revisit only if a user complains about a tooltip.)

**No changes.**

- Bundle ID, CloudKit container, app group, keychain service, StoreKit product IDs, logger subsystems, Swift module names, folder names, workspace/xcodeproj filenames, repo name.
- Comments referring to GrowWise are not touched in Phase 9. They're fixed opportunistically if a nearby code change touches the lines.

**Audit command (Phase 9 acceptance).**

```bash
grep -rn "GrowWise\|Grow Wise\|growwise" GrowWisePackage/Sources --include="*.swift" \
  | grep -v "import GrowWise\|GrowWiseFeature\|GrowWiseServices\|GrowWiseModels\|Logger(subsystem: \"com.growwise\|com.growwiser.app\|iCloud.com.growwise"
```

Expected: empty output. Any remaining line gets a by-hand judgment.

## Tab/nav changes

**`MainAppView.swift`.** `TabSelection` becomes `home` / `garden` / `club` / `profile`. Four tab items: Home (`house.fill`), Garden (`leaf.fill`), Club (`sparkles`), Me (`person.fill`). Accessibility IDs `tab_home`, `tab_garden`, `tab_club`, `tab_profile`. Coral tint via `.tint(CultivationTheme.Colors.accentCoral)`. Club tab wrapped in its own `NavigationStack` (same pattern that currently wraps Reminders).

**Deleted files (Phase 4).** `Views/RemindersListView.swift`, `Views/Journal/JournalView.swift`, `Views/Journal/JournalEntryRow.swift`, `Views/Journal/JournalEntryDetailView.swift`, `Views/Journal/AddJournalEntryView.swift`, plus any tests that import them.

**Retained.**

- `JournalEntry` model (`GrowWiseModels`) — rendered as photo strip on Plant Detail.
- `PlantReminder` model and `ReminderService` — drive Home's urgency-grouped task list.
- `Views/AddReminderView.swift`, `Views/PlantReminderDetailView.swift`, `Views/ReminderSettingsView.swift`, `Views/Components/PlantReminderCard.swift` — reachable from Home and Plant Detail, not from the deleted Reminders tab. Retained.
- `Views/Community/*.swift` (`ForumView`, `CommunityFeedView`, `AskQuestionSheet`, `QuestionDetailView`, `PublicGardenCardView`, `PublishGardenSheet`) — reachable from the Me tab, not promoted, not deleted.
- `Views/GardenClub/ClubListView.swift`, `ClubDetailView.swift`, `ClubChatView.swift`, `ClubEventsView.swift`, `CreateClubSheet.swift`, `JoinClubSheet.swift` — existing multi-club infrastructure. Retained; see Open questions for reconciliation with the single-"your club" model implied by the v2 spec.

**New file (Phase 5).** `Views/GardenClub/GardenClubFeedView.swift`. First cut uses in-memory seeded sample posts; CloudKit wiring through the existing `ClubCloudKitService` is deferred and will be filed as its own GitHub issue at Phase 10.

**`ProfileView` (Phase 3) changes.** Tab label changes to "Me". A row is added linking to the existing Community Forum. Tutorials continues to present via `.sheet` (ADR-012 unchanged).

## ADR-020 draft (to be appended to `docs/architecture/ADR.md` during prep commit)

```markdown
## ADR-020: Rename scope — user-facing only (Cultivation)
**Date:** 2026-04-22
**Status:** Active
**Decision:** "Complete the Cultivation rename" means user-facing only. All code-level identifiers stay on `GrowWise` / `com.growwiser.app` / `com.growwise.*` / `iCloud.com.growwise.gardening`.
**Context:** Existing app may have TestFlight installs. Changing bundle ID, CloudKit container, StoreKit product IDs, keychain service, or app group would require a data migration and would invalidate subscriptions. The user-facing display name (`CFBundleDisplayName`, UI copy, docs) is reversible and safe to change today. The identifier-level rebrand is a separate, larger project that needs its own migration design.
**Consequences:**
- `CFBundleDisplayName` becomes "Cultivation" in both build configs.
- User-visible strings swept to "Cultivation" under an audit grep (see 2026-04-22 redesign spec, §Rename scope).
- Swift modules, folder names, workspace/project filenames, repo name, and all code identifiers stay as "GrowWise".
- `CLAUDE.md`'s "GrowWise (branded **Cultivation**)" phrasing continues to describe reality.
- Future work to also rebrand identifiers is tracked as a separate initiative with its own ADR.
```

## Testing

**Deleted tests.** Any test or XCUITest whose primary target is `JournalView`, `JournalEntryRow`, `JournalEntryDetailView`, `AddJournalEntryView`, or `RemindersListView`. Any test referencing `TabSelection.journal` / `TabSelection.reminders`. Any XCUITest navigating to `tab_journal` / `tab_reminders` — rewritten to target `tab_club`, or deleted outright.

**New tests.**

- `GardenClubFeedViewTests` — basic render + seeded-data assertion. Swift Testing (`@Test`, `#expect`).
- `HomeViewModelTests` — assert `latestClubPost` populates from an injected protocol (per ADR-008 protocol-injection pattern).
- `SmartTagTests` — assert the accessibility label is `"Smart enrichment: \(label)"`.

**Out of scope for this redesign.**

- Full CloudKit integration tests for the new Club feed.
- Snapshot/visual-regression tests (we use `ui-verify` manually instead).
- Migration tests for users on pre-v2 TestFlight builds.

## Accessibility IDs (new — per CLAUDE.md policy)

Every interactive element added by this redesign carries an identifier. At minimum:

- `tab_club`, `tab_home`, `tab_garden`, `tab_profile`
- `club_button_share_prompt`
- `club_segcontrol_feed`, `club_segcontrol_nearby`, `club_segcontrol_following`
- `club_cell_post_<id>`, `club_button_like_<id>`, `club_button_comment_<id>`, `club_button_share_<id>`
- `home_card_your_club`, `home_button_view_club`
- `plantdetail_button_share_to_club`, `plantdetail_button_get_advice`, `plantdetail_button_log_care`
- `smart_tag_<slug>` on each `SmartTag` instance

`ui-test:check-ids` skill runs during Phase 10 to audit for missing identifiers across all new views.

## What "done" looks like

Acceptance gates for the final PR `redesign/v2` → `master`:

1. `cd GrowWisePackage && swift build` clean on mac-mini.
2. `ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"` clean.
3. `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test"` green. Count ≥ old count minus deletions (~20 tests expected to be deleted).
4. `swiftlint lint --strict --config .swiftlint.yml` clean.
5. `swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise` clean.
6. `code-review` skill on the redesign diff — no FAILs on MV / Swift 6 strict concurrency / SwiftData / force-unwrap / `print` / silent `try?` (ADR-007).
7. App boots on iPhone 16 simulator: Home renders cream paper with serif greeting and Your Club card; all four tabs render; Plant Detail shows Share-to-Club; Club tab shows seeded data. `ui-verify` screenshot walkthrough captured and attached to the final PR.
8. `plutil -p` on the built `.app` `Info.plist` shows `CFBundleDisplayName = "Cultivation"`.
9. Rename audit grep (see Rename section) returns zero unexpected lines.
10. `docs/architecture/ADR.md` contains ADR-019 and ADR-020 entries. `docs/superpowers/specs/` contains the moved 2026-04-20 design doc and this execution spec. `docs/mockups/` contains the moved wireflow HTML. `growwise redesigfn/` is gone.
11. GitHub issues filed on master for: CloudKit wiring of `GardenClubFeedView` (deferred from Phase 5), grain-texture overlay (if Phase 6–8 review pass judges the cream too flat), any `TODO: v2.1` items the redesign leaves behind.

## Out of scope

- Social features beyond the v2 spec (comments UX, @mentions, Club-derived push notifications).
- Real-time Club sync; initial implementation uses seeded sample data.
- Any identifier-level rename (bundle ID, CloudKit container, StoreKit products, keychain, app group). Tracked as a separate future initiative.
- A migration from old local data schemas to new ones (none required — only UI changes).
- Grain-texture overlay on the cream background in v1. Added as a follow-up issue only if the review pass judges it necessary.
- Custom Fraunces + Manrope font registration. System serif + rounded are the shipping choice. Revisiting custom fonts would be a single-file edit to `CultivationTheme.Fonts`.

## Open questions that still need a human call during implementation

- **"Mark all done" batching semantics.** V2 spec §Home says "Mark all done" should batch by care type (don't mark fertilized when user only watered). Phase 6 implementer will need to confirm with the user whether the v1 of this button marks all *watering* tasks only (narrowest), all tasks of the top-urgency group (middle), or all visible tasks regardless of type (broadest, per literal reading of "all"). Propose: narrowest — match the top task's care type.
- **"Nearby" and "Following" segments of the Club feed.** V2 spec shows the segmented control with three tabs but only describes the "Club feed" content. Phase 5 implementer will need to decide whether "Nearby" and "Following" ship with sample data, as empty states with `SmartTag("Coming soon")`, or as disabled chips. Propose: show them with empty-state copy ("No posts in your zone yet" / "Follow someone to see their posts") — consistent with the "invisible enrichment" principle and avoids shipping fake data.
- ~~**Reconciliation with existing multi-club data model.**~~ **RESOLVED 2026-04-22:** option (a). The codebase has `GardenClub`, `ClubActivity`, `ClubEvent`, `ClubMessage` SwiftData models and `ClubListView` / `ClubDetailView` / `ClubChatView` / `ClubEventsView` / `CreateClubSheet` / `JoinClubSheet` views supporting a user in multiple clubs. The v2 spec uses singular "your club" throughout. Resolution:
  - Club tab routes by membership count at render time. Zero clubs → join/create prompt (uses existing `JoinClubSheet` / `CreateClubSheet`). Exactly one club → tab opens directly on `GardenClubFeedView` for that club. More than one club → tab opens on `ClubListView` (restyled to cream paper); tapping a row pushes `GardenClubFeedView`.
  - `GardenClubFeedView` is the per-club body — it takes a `GardenClub` argument. It hosts the share prompt, the three-segment feed (Club feed / Nearby / Following), post cards, and the smart-match card.
  - `ClubDetailView` either gets folded into `GardenClubFeedView` or kept as a "club settings / about" subview reachable from the feed header. Phase 5 implementer picks based on read of existing `ClubDetailView` — if it's already a loose aggregator, fold it in; if it has dense non-feed content (member list, announcements), keep it as a pushed sub-screen.
  - Home's "Your Club" card shows the user's most-recently-active club (max `updatedAt` on `GardenClub`). If zero clubs, the card is hidden; if the user taps it, they land on `GardenClubFeedView` for that club.
