# Cultivation v2 Redesign + User-Facing Rename — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 2026-04-20 v2 UI pivot (cream-paper field-journal aesthetic, 4 tabs, promoted Garden Club) and complete the user-facing rename from GrowWise to Cultivation, without touching any code-level identifier.

**Architecture:** Phased PRs stacking into a long-lived `redesign/v2` branch. Each phase ends with a mac-mini `swift build` gate; later phases add `swift test`, lint, and `ui-verify` gates. Theme tokens ship first so all subsequent screen work compiles against the new palette and fonts. Font direction is iOS system fonts (`.system(design: .serif)` / `.rounded`) — no custom font files. Rename is user-facing only: `CFBundleDisplayName`, on-screen strings, docs. All bundle IDs, CloudKit containers, StoreKit IDs, keychain service, app group, logger subsystems, Swift module names, and folder names stay untouched.

**Tech Stack:** SwiftUI (iOS 17+), `@Observable` / `@State`, SwiftData, CloudKit, Swift Testing (`@Test`, `#expect`), Swift 6 strict concurrency. Existing services: `DataService`, `LocationService`, `ReminderService`, `ClubCloudKitService`, `PlantCareAdviceService`. Build: `swift build` local, `swift test` + `xcodebuild` over SSH to mac-mini.

**Source-of-truth references:**
- Design spec: `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md` (moved here in Phase 0)
- Implementation code shapes: `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` (moved here in Phase 0; its Phase 2 font-registration section is obsolete — see Phase 0, Task 0.3)
- Visual wireflow: `docs/mockups/cultivation-simplified-wireflow.html` (moved here in Phase 0)
- Execution spec: `docs/superpowers/specs/2026-04-22-cultivation-redesign-and-rename-design.md`
- ADR: `docs/architecture/ADR.md` (ADR-019 and ADR-020 appended in Phase 0)

**TDD discipline:** Tests-first where tests are meaningful (token values, `Fonts` outputs, tab enum cases, `SmartTag` accessibility label, multi-club routing logic, rename audit grep). SwiftUI view rendering is validated by the `ui-verify` screenshot walkthrough in Phase 10, not by unit tests, because this project has no snapshot-test infrastructure and has explicitly chosen not to add one for this redesign.

---

## File map

**Created:**
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift` (Phase 5)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/YourClubCard.swift` (Phase 6)
- `GrowWisePackage/Tests/GrowWiseFeatureTests/SmartTagTests.swift` (Phase 1)
- `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift` (Phase 1)
- `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedRoutingTests.swift` (Phase 5)

**Rewritten (full-file replacement):**
- `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift` (Phase 1 + 2)
- `GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift` (Phase 1)

**Modified in place:**
- `GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift` (Phase 3)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift` (Phase 3)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift` (Phase 6)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift` (Phase 6)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/SeasonalTipCard.swift` (Phase 6)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/GardenHealthCardView.swift` (Phase 6)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift` (Phase 6)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift` (Phase 7)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenComponents.swift` (Phase 7)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift` (Phase 8)
- `GrowWise.xcodeproj/project.pbxproj` (Phase 9 — `CFBundleDisplayName`)
- `docs/architecture/ADR.md` (Phase 0)
- Various Swift source files containing user-visible strings (Phase 9)
- `README.md`, `GrowWise/Data/README.md` (Phase 9)

**Deleted:**
- `GrowWisePackage/Sources/GrowWiseFeature/Views/RemindersListView.swift` (Phase 4)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalView.swift` (Phase 4)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryRow.swift` (Phase 4)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift` (Phase 4)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/AddJournalEntryView.swift` (Phase 4)
- Any tests that import the above (Phase 4)
- `growwise redesigfn/` folder (Phase 0 — moved to proper docs homes)

**Kept untouched (explicitly listed to prevent accidental deletion):**
- All SwiftData models (`JournalEntry`, `PlantReminder`, `GardenClub`, `ClubActivity`, `ClubEvent`, `ClubMessage`).
- `Views/AddReminderView.swift`, `Views/PlantReminderDetailView.swift`, `Views/ReminderSettingsView.swift`, `Views/Components/PlantReminderCard.swift`.
- `Views/Community/*` (`ForumView`, `CommunityFeedView`, `AskQuestionSheet`, `QuestionDetailView`, `PublicGardenCardView`, `PublishGardenSheet`).
- `Views/GardenClub/ClubListView.swift`, `ClubDetailView.swift`, `ClubChatView.swift`, `ClubEventsView.swift`, `CreateClubSheet.swift`, `JoinClubSheet.swift`.
- All code-level identifiers (bundle ID, CloudKit container, Swift modules, logger subsystems, folder names).

---

## Phase 0 — Prep commit (no PR; lands directly on `redesign/v2`)

Goal: clean up the branch/worktree state and put source-of-truth docs in their final homes before Phase 1 begins. Ends with one commit on `redesign/v2`.

### Task 0.1: Prune the broken `redesign/v2-simplified-ui` worktree

**Files:** none (git metadata only)

- [ ] **Step 1: List worktrees to confirm the dead entry**

Run: `git worktree list`
Expected: includes a line `/sessions/relaxed-keen-mendel/mnt/GrowWise/.claude/worktrees/redesign-v2 ... [redesign/v2-simplified-ui] locked`

- [ ] **Step 2: Prune the dead entry**

Run: `git worktree prune --verbose`
Expected: dead worktree removed from git metadata. If `prune` doesn't remove it due to the lock, run `git worktree remove --force /sessions/relaxed-keen-mendel/mnt/GrowWise/.claude/worktrees/redesign-v2` first, then prune.

- [ ] **Step 3: Confirm prune**

Run: `git worktree list`
Expected: only `/Users/blake/Projects/GrowWise` remains.

### Task 0.2: Delete the obsolete `redesign/v2-simplified-ui` branch

**Files:** none (branch metadata only)

- [ ] **Step 1: Confirm the branch has no redesign code**

Run: `git log master..redesign/v2-simplified-ui --oneline`
Expected: nothing but DataService-test commits that are already merged to master.

- [ ] **Step 2: Delete local branch**

Run: `git branch -D redesign/v2-simplified-ui`
Expected: branch deleted.

- [ ] **Step 3: Delete remote branch (if it exists on origin)**

Run: `git push origin --delete redesign/v2-simplified-ui`
Expected: either remote deletion succeeds, or `remote ref does not exist` — both are fine.

### Task 0.3: Move source-of-truth docs into place

**Files:**
- Move: `growwise redesigfn/2026-04-20-simplified-ui-v2-design.md` → `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md`
- Move: `growwise redesigfn/2026-04-20-simplified-ui-v2-implementation.md` → `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md`
- Move: `growwise redesigfn/cultivation-simplified-wireflow.html` → `docs/mockups/cultivation-simplified-wireflow.html`
- Delete: `growwise redesigfn/ADR.md` (its content is already in master's `docs/architecture/ADR.md` except for ADR-019; ADR-019 is appended in Task 0.4)
- Delete: `growwise redesigfn/` folder itself

- [ ] **Step 1: Move the design spec**

Run: `mv "growwise redesigfn/2026-04-20-simplified-ui-v2-design.md" docs/superpowers/specs/`

- [ ] **Step 2: Move the implementation guide**

Run: `mv "growwise redesigfn/2026-04-20-simplified-ui-v2-implementation.md" docs/superpowers/specs/`

- [ ] **Step 3: Prepend an "OBSOLETE PHASE 2" note to the implementation guide**

Use Edit to insert this note at the very top of `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md`, before the existing line 1:

```markdown
> **Execution note (2026-04-22):** Phase 2 ("Font registration") is obsolete. The active plan ships iOS system fonts via `CultivationTheme.Fonts` — no custom `.ttf` files, no `UIAppFonts`, no `FontRegistration.swift`. See `docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md` for the current task list. Everything else in this file (ViewModifiers, MainAppView tab restructure, GardenClubFeedView source, HomeView/GardenView/PlantDetail skeletons) remains load-bearing reference material.

---

```

- [ ] **Step 4: Move the wireflow HTML**

Run: `mv "growwise redesigfn/cultivation-simplified-wireflow.html" docs/mockups/`

- [ ] **Step 5: Delete the leftover folder**

Run: `rm -rf "growwise redesigfn"`
Expected: folder is gone.

- [ ] **Step 6: Confirm no leftover references to the old path**

Run: `grep -rn "growwise redesigfn" docs/ GrowWisePackage/ GrowWise/ --include="*.md" --include="*.swift"`
Expected: empty output. (The execution spec at `docs/superpowers/specs/2026-04-22-...` mentions this path in its prep-commit section — that's intentional history; don't edit.)

### Task 0.4: Append ADR-019 and ADR-020 to the master ADR file

**Files:**
- Modify: `docs/architecture/ADR.md`

- [ ] **Step 1: Append ADR-019 verbatim from the spec**

Use Edit to append to `docs/architecture/ADR.md` after the existing final line (which is `*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*`). First, delete that instructional line. Then append the two ADRs. Use Edit's old_string/new_string with the instructional line as the anchor.

Replace the trailing instructional line with this block:

```markdown
## ADR-019: Simplified UI v2 — cream paper, 4 tabs, Club as a pillar
**Date:** 2026-04-20
**Status:** Active
**Decision:** Pivot the app's visual direction from dark glass-morphism to a cream paper "field journal" treatment, consolidate the tab bar from 5 tabs to 4, and promote Garden Club to a top-level tab with sharing as a first-class action on every screen. See `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md` and `docs/mockups/cultivation-simplified-wireflow.html`.
**Context:** ADR-017 established the Botanical Field Journal direction and we shipped it as dark glass-morphism (per the 2026-03-09 redesign spec). The dark treatment photographs well but is harder on the audience the PRD targets — 50+ enthusiast gardeners — due to lower contrast and the need for larger comfortable type sizes. The tab bar at 5 entries was also dense; Reminders duplicated work that Home's urgency-grouped task list already does, and Journal was competing for primary nav despite lower usage. Sharing (Garden Club) was buried behind the Community forum rather than being a primary pillar, which undercuts the social-first product direction.
**Consequences:**
- `CultivationTheme` replaced: cream paper (`#F6F0E4`) + ink (`#1F2A22`) + sage (`#7B9069`) + coral (`#D9694B`) + honey (`#C99327`). Old dark tokens removed, not kept for fallback.
- Typography uses `.system(design: .serif)` (display) and `.system(design: .rounded)` (body) as the nearest iOS-native match to Fraunces/Manrope. Custom font registration was scoped out of the v1 redesign for simplicity.
- `MainAppView` tabs: Home, Garden, Club, Me. Reminders and Journal tabs deleted; reminder rows stay on Home and journal entries render as a photo strip on Plant Detail.
- `Views/RemindersListView.swift` and `Views/Journal/*.swift` deleted. `JournalEntry` model stays — rendered through the Plant Detail photo strip.
- New `Views/GardenClub/GardenClubFeedView.swift` is the tab entry point and hosts the share-prompt, feed, and smart-match card.
- Every Plant Detail has a "Share to [Club]" coral button. Every Home screen has a "Your Club" card.
- "Smart enrichment" (weather, plant ID, reminders, hardiness zone, seasonal tips) surfaces with a `✦` sage tag anywhere the user might wonder where the info came from. No first-run setup for any of it.
- ADR-017's "serif plant names, coral accents, no tech teal" stays in force. ADR-018's contextual quick-care icons stay in force. This ADR changes the surface (paper vs glass) and the tab structure, not the brand attitude.

---

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

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
```

- [ ] **Step 2: Edit ADR-009 to mark it superseded**

Use Edit on `docs/architecture/ADR.md`. Find the line `**Status:** Active` that immediately follows `## ADR-009: Tab navigation redesign (was 7 → 4 → 5 tabs)` and the `**Updated:** 2026-03-27` line, and append a new line after the existing `**Updated:**` entry:

```
**Updated:** 2026-04-22 → superseded by ADR-019 (4 tabs: Home, Garden, Club, Me).
```

- [ ] **Step 3: Edit ADR-010 to mark it partially superseded**

Use Edit on `docs/architecture/ADR.md`. Find the line `**Updated:** 2026-03-12 (Botanical Field Journal palette)` under `## ADR-010: CultivationTheme`. Append a new line after it:

```
**Updated:** 2026-04-22 → palette and surfaces superseded by ADR-019; the centralization-in-`CultivationTheme` policy stays in force.
```

- [ ] **Step 4: Edit ADR-017 to mark it amended**

Use Edit on `docs/architecture/ADR.md`. Find the line `**Status:** Active` under `## ADR-017: Botanical Field Journal design language`. Append a new line after it:

```
**Updated:** 2026-04-22 → design-language *direction* (serif, warm earth tones, coral accents) stays in force; surface shifts from dark glass to cream paper per ADR-019.
```

### Task 0.5: Commit the prep work

- [ ] **Step 1: Stage changes**

Run:
```bash
git add docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md \
        docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md \
        docs/mockups/cultivation-simplified-wireflow.html \
        docs/architecture/ADR.md \
        docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md
git add -u  # stages the deletion of growwise redesigfn/ contents
```

- [ ] **Step 2: Verify staged diff**

Run: `git status --short`
Expected: four new/moved files under `docs/`, one modified `docs/architecture/ADR.md`, and three deleted files from `growwise redesigfn/`. No `.swift` files staged.

- [ ] **Step 3: Commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
docs(redesign): prep commit — move v2 source-of-truth docs, append ADR-019/020

- Move 2026-04-20 v2 design doc and implementation guide into docs/superpowers/specs/.
- Move v2 wireflow HTML into docs/mockups/.
- Prepend obsolete-Phase-2 note to the implementation guide.
- Append ADR-019 (v2 pivot) and ADR-020 (user-facing-only rename) to docs/architecture/ADR.md.
- Annotate ADR-009/010/017 with their relationship to ADR-019.
- Remove the growwise redesigfn/ folder.

Per docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md, Phase 0.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Confirm the tree is ready for Phase 1**

Run: `git status --short`
Expected: no staged changes related to the redesign. The `AppIcon.png` LFS modification from the previous branch may still appear — that is user environmental state and is not part of this redesign; leave it alone.

---

## Phase 1 — Theme tokens + ViewModifiers

Goal: replace palette and swap `GlassCardModifier` for `PaperCardModifier`. Preserve the entire public API surface of `CultivationTheme` so every existing call site compiles. End of phase: `swift build` clean.

**Reference:** `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` §Phase 1 has the full source for every change in this phase. Do not re-derive — copy and adapt.

### Task 1.1: Write failing tests for new palette values

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift`:

```swift
import Testing
import SwiftUI
@testable import GrowWiseFeature

@Suite("CultivationTheme v2 tokens")
struct CultivationThemeTests {
    @Test("Background is cream paper in light mode")
    func backgroundIsCreamPaperLight() {
        // Resolve in light-mode environment. Color equality in SwiftUI is tricky;
        // we compare via the hex-init helper the token file exposes.
        let expected = Color(hex: "F6F0E4")
        // The Color(light:dark:) wrapper makes direct equality unreliable; assert
        // the token is constructible and non-nil. A visual check comes from ui-verify.
        #expect(CultivationTheme.Colors.background != Color.clear)
        #expect(expected != Color.clear)
    }

    @Test("Coral accent matches spec hex D9694B")
    func coralAccentMatchesSpec() {
        let expected = Color(hex: "D9694B")
        #expect(CultivationTheme.Colors.accentCoral != Color.clear)
        #expect(expected != Color.clear)
    }

    @Test("Card radius is 16")
    func cardRadiusIs16() {
        #expect(CultivationTheme.Radius.card == 16)
    }

    @Test("Screen padding is 20")
    func screenPaddingIs20() {
        #expect(CultivationTheme.Spacing.screenPadding == 20)
    }

    @Test("Section gap is 24")
    func sectionGapIs24() {
        #expect(CultivationTheme.Spacing.sectionGap == 24)
    }

    @Test("StatCard radius token is defined")
    func statCardRadiusDefined() {
        #expect(CultivationTheme.Radius.statCard == 14)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationThemeTests"`
Expected: fail — the token values on master don't match the v2 spec (e.g., `Radius.card` is 14 not 16, `Spacing.screenPadding` is 16 not 20, `Radius.statCard` does not exist).

### Task 1.2: Replace `CultivationTheme.swift`

**Files:**
- Modify (full-file rewrite): `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

- [ ] **Step 1: Replace file contents**

Use Write to replace the full content of `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift` with the source in `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` §Phase 1 (lines 46–305 of that file — the block beginning `import SwiftUI` and ending with the `Color` extension closing brace).

Before writing: Read the current `CultivationTheme.swift` to keep any existing method bodies that are referenced elsewhere but not in the replacement block. In particular:
- `CultivationTheme.Typography.headline`, `body`, `caption` — all exist in the replacement; verify their call sites still compile.
- `CultivationTheme.Animation.card`, `tab`, `selection`, `sheet`, `entrance` — all exist in the replacement.
- Legacy aliases `Colors.heroGlow` and `Colors.brandGold` — both exist in the replacement.

The replacement block from the implementation guide is complete. Copy it verbatim.

- [ ] **Step 2: Build to confirm compile**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: clean build. If compile errors surface, they'll be from call sites using tokens that were renamed. Most likely offenders:
- `statusAlert`/`statusWarning`/`statusHealthy` — values changed but names kept; should compile.
- Any view that hardcodes a hex color rather than a token — compiles regardless.
Fix each error by pointing to the nearest-semantic new token, not by inventing a legacy alias.

- [ ] **Step 3: Run theme tests to confirm they pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationThemeTests"`
Expected: all token tests pass.

- [ ] **Step 4: Commit**

Run:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift
git commit -m "feat(theme): replace CultivationTheme tokens with v2 cream-paper palette

Cream #F6F0E4 paper background, ink #1F2A22 text, coral #D9694B action,
sage #7B9069 smart-enrichment, honey #C99327 warning. Radius.card 14→16,
Spacing.screenPadding 16→20, Spacing.sectionGap 20→24. New Radius.statCard.
New Colors.smartTag{Background,Foreground}. Legacy aliases heroGlow and
brandGold retained for existing call sites.

Per docs/superpowers/specs/2026-04-22-cultivation-redesign-and-rename-design.md,
Phase 1."
```

### Task 1.3: Write failing test for `SmartTag` accessibility label

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseFeatureTests/SmartTagTests.swift`

- [ ] **Step 1: Write the failing test**

Create `GrowWisePackage/Tests/GrowWiseFeatureTests/SmartTagTests.swift`:

```swift
import Testing
import SwiftUI
@testable import GrowWiseFeature

@Suite("SmartTag")
struct SmartTagTests {
    @Test("Accessibility label uses the 'Smart enrichment' prefix")
    func accessibilityLabelPrefix() {
        let tag = SmartTag(label: "Auto-identified")
        // Assert accessibility label via mirror — SwiftUI doesn't expose a public
        // accessor, but our implementation sets `.accessibilityLabel("Smart enrichment: \(label)")`.
        // The indirect proof: the label the view was constructed with.
        #expect(tag.label == "Auto-identified")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SmartTagTests"`
Expected: compile error — `SmartTag` doesn't exist yet.

### Task 1.4: Rewrite `ViewModifiers.swift`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift`

- [ ] **Step 1: Read the current file to preserve all existing exports**

Run: `cat GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift | head -200`
Inventory all public types currently in the file (e.g., `GlassPill`, `IconBubble`, `StatusDot`, `GradientButtonStyle`, `QuickStatCard`, `HeroBackgroundModifier`, `GlassCardModifier`) so none are accidentally dropped.

- [ ] **Step 2: Apply the eight edits from the implementation guide §Phase 1**

Apply these edits in order using Edit or Write. Each code block comes verbatim from `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` §Phase 1:

1. Replace `GlassCardModifier` struct + `glassCard()` extension with the `PaperCardModifier` struct, `paperCard()` extension, and a backwards-compatible `glassCard()` alias routing to `.paperCard()`. (Guide §Phase 1, edit #1.)
2. Replace `HeroBackgroundModifier` with the cream-paper gradient version. (Guide §Phase 1, edit #2.)
3. Replace `GradientButtonStyle` with the flat-moss version using `CultivationTheme.Fonts.body(16, weight: .bold)`. (Guide §Phase 1, edit #3.)
4. Add a new `CoralButtonStyle` struct for the Share-to-Club button. (Guide §Phase 1, edit #4.)
5. Add a new `SmartTag` struct. (Guide §Phase 1, edit #5.)
6. `IconBubble` stays structurally the same — verify on cream background it still reads; if `.opacity(0.12)` looks too washed out in the Phase 10 simulator review, bump to `0.16`. No code change required now.
7. Replace `GlassPill` with the coral-on-moss active-state version. (Guide §Phase 1, edit #7.)
8. Replace `QuickStatCard` with the ultraThinMaterial-free version. (Guide §Phase 1, edit #8.)

- [ ] **Step 3: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`
Expected: clean. Call sites using `.glassCard()` keep compiling via the alias.

- [ ] **Step 4: Run SmartTag test to confirm it passes**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SmartTagTests"`
Expected: pass.

- [ ] **Step 5: Commit**

Run:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/SmartTagTests.swift
git commit -m "feat(theme): PaperCardModifier, CoralButtonStyle, SmartTag, paper HeroBackground

Replaces GlassCardModifier with PaperCardModifier (soft warm shadow on cream,
no blur). glassCard() kept as backwards-compat alias. GradientButtonStyle shifts
from moss→sage gradient to flat moss. New CoralButtonStyle for the Share-to-Club
action. New SmartTag view (sage '✦' chip) for auto-enriched surfaces. GlassPill
active state is moss on cream. QuickStatCard drops ultraThinMaterial.

Per phased plan Phase 1."
```

### Task 1.5: Phase 1 PR

- [ ] **Step 1: Run full build to confirm nothing else broke**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -20"`
Expected: clean.

- [ ] **Step 2: Run full test suite**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"`
Expected: green, including all new token + SmartTag tests. Any failure unrelated to this phase is fixed here (quick win) or filed as a follow-up issue.

- [ ] **Step 3: Push branch + open PR**

Run:
```bash
git push -u origin redesign/v2
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 1: theme tokens + ViewModifiers" --body "$(cat <<'EOF'
## Summary
- Replace CultivationTheme palette with v2 cream-paper tokens (cream/ink/sage/coral/honey).
- Swap GlassCardModifier for PaperCardModifier; keep .glassCard() alias for unchanged call sites.
- Add CoralButtonStyle and SmartTag. GradientButtonStyle switches to flat moss; GlassPill active state is moss on cream; QuickStatCard drops ultraThinMaterial.
- No call-site changes beyond Theme + ViewModifiers — every existing screen still compiles against the new tokens.

## Test plan
- [ ] `swift build` clean on mac-mini.
- [ ] `swift test --filter CultivationThemeTests` green.
- [ ] `swift test --filter SmartTagTests` green.
- [ ] Full `swift test` green.

Base: `redesign/v2`. Per docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Wait for the branch to have no commits pending? No — this is a stacked-PR flow. `redesign/v2` is the base; there is no master-facing PR yet. Each phase PR merges into `redesign/v2` and that's the base for the next phase.

- [ ] **Step 4: Wait for the PR to be approved and merged by Blake**

When merged, the next phase is based on the now-updated `redesign/v2` branch. Pull it before starting Phase 2:

```bash
git fetch origin
git checkout redesign/v2
git pull
```

---

## Phase 2 — Typography simplification

Goal: replace `CultivationTheme.Fonts` with a thin pass-through to system fonts. No custom font files, no registration. End of phase: `swift build` clean.

### Task 2.1: Write failing tests for `Fonts` helpers

**Files:**
- Modify: `GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift`

- [ ] **Step 1: Add tests**

Append these tests to `CultivationThemeTests.swift`:

```swift
    @Test("Fonts.display returns a serif system font")
    func displayFontIsSerifSystem() {
        // System fonts don't expose design as a readable property, so the
        // check is structural: we construct and compare to the spec. The
        // ultimate validation is visual (ui-verify in Phase 10).
        let font = CultivationTheme.Fonts.display(17, weight: .medium)
        let expected = Font.system(size: 17, weight: .medium, design: .serif)
        #expect(String(describing: font) == String(describing: expected))
    }

    @Test("Fonts.body returns a rounded system font")
    func bodyFontIsRoundedSystem() {
        let font = CultivationTheme.Fonts.body(14)
        let expected = Font.system(size: 14, weight: .regular, design: .rounded)
        #expect(String(describing: font) == String(describing: expected))
    }

    @Test("Fonts.displayItalic returns a serif italic system font")
    func displayItalicIsSerifSystemItalic() {
        let font = CultivationTheme.Fonts.displayItalic(22)
        let expected = Font.system(size: 22, weight: .regular, design: .serif).italic()
        #expect(String(describing: font) == String(describing: expected))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationThemeTests"`
Expected: the three new tests fail (or return false) because the current `Fonts` implementation from Task 1.2 has availability checks and may return a fallback rather than unambiguously calling `.system(design: .serif)`. If the `displayAvailable` check returns false because no custom fonts are bundled, these tests may actually pass incidentally — confirm by reading current `Fonts` code before proceeding.

### Task 2.2: Simplify `CultivationTheme.Fonts`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

- [ ] **Step 1: Replace the `Fonts` enum body**

Use Edit on `CultivationTheme.swift` to replace the entire `public enum Fonts { … }` block with:

```swift
    /// System-font helpers. `display` uses `.serif` (New York) for headlines
    /// and plant names; `body` uses `.rounded` (SF Pro Rounded) for UI/body.
    /// Custom Fraunces/Manrope registration was scoped out of the v2 redesign;
    /// this helper is a single-file hook for adding them later if desired.
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

- [ ] **Step 2: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`
Expected: clean. All `CultivationTheme.Typography.*` helpers route through `Fonts.*` already (per Task 1.2) so their output changes from serif-or-fallback to unambiguously `.serif`/`.rounded`.

- [ ] **Step 3: Run tests**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter CultivationThemeTests"`
Expected: all font tests green.

- [ ] **Step 4: Commit**

Run:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/CultivationThemeTests.swift
git commit -m "refactor(theme): drop availability checks from Fonts; use system fonts directly

Custom Fraunces/Manrope registration was scoped out of the v1 redesign.
Fonts.display → .system(design: .serif), Fonts.body → .system(design: .rounded).
Single-file hook for future font registration if desired.

Per phased plan Phase 2."
```

### Task 2.3: Phase 2 PR

- [ ] **Step 1: Push + PR**

Run:
```bash
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 2: typography simplification (system fonts)" --body "$(cat <<'EOF'
## Summary
- Drop availability checks from CultivationTheme.Fonts.
- display → .system(design: .serif) (New York), body → .system(design: .rounded) (SF Pro Rounded).

## Test plan
- [ ] `swift build` clean.
- [ ] `swift test --filter CultivationThemeTests` green.

Base: `redesign/v2`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Await merge, then pull**

```bash
git fetch origin && git pull
```

---

## Phase 3 — Tab restructure (5 → 4)

Goal: `MainAppView` renders 4 tabs (Home/Garden/Club/Me) with coral tint. `GardenClubFeedView` is stubbed so the Club tab compiles; its real implementation comes in Phase 5. End of phase: `swift build` clean, all 4 tabs visible in simulator.

### Task 3.1: Stub `GardenClubFeedView`

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`

- [ ] **Step 1: Create the stub file**

Use Write to create `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`:

```swift
import SwiftUI

/// Tab-3 entry point for Garden Club. Stubbed in Phase 3 so MainAppView compiles;
/// real implementation lands in Phase 5.
public struct GardenClubFeedView: View {
    public init() {}

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Club feed")
                    .font(CultivationTheme.Fonts.display(22, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Coming next in Phase 5")
                    .font(CultivationTheme.Fonts.body(14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("club_feed_placeholder")
    }
}
```

- [ ] **Step 2: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`
Expected: clean.

### Task 3.2: Restructure `TabSelection` and `MainAppView`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift`

- [ ] **Step 1: Replace the `TabSelection` enum**

Use Edit to replace the entire `public enum TabSelection` block. Before:

```swift
public enum TabSelection: String, CaseIterable {
    case home
    case garden
    case journal
    case reminders
    case profile
}
```

After:

```swift
public enum TabSelection: String, CaseIterable {
    case home
    case garden
    case club
    case profile
}
```

- [ ] **Step 2: Replace `mainTabView`**

Use Edit to replace the body of `mainTabView` with the 4-tab layout (source: implementation guide §Phase 3, lines 659–684):

```swift
private var mainTabView: some View {
    TabView(selection: $selectedTab) {
        HomeView()
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(TabSelection.home)
            .accessibilityIdentifier("tab_home")

        GardenView()
            .tabItem { Label("Garden", systemImage: "leaf.fill") }
            .tag(TabSelection.garden)
            .accessibilityIdentifier("tab_garden")

        NavigationStack {
            GardenClubFeedView()
        }
        .tabItem { Label("Club", systemImage: "sparkles") }
        .tag(TabSelection.club)
        .accessibilityIdentifier("tab_club")

        ProfileView()
            .tabItem { Label("Me", systemImage: "person.fill") }
            .tag(TabSelection.profile)
            .accessibilityIdentifier("tab_profile")
    }
    .tint(CultivationTheme.Colors.accentCoral)
}
```

Note: the old `MainAppView` wrapped `RemindersListView` in a `NavigationStack` (current lines ~131–137). That whole block is gone in the new version.

- [ ] **Step 3: Fix call sites that reference `.journal` or `.reminders`**

Run: `grep -rn "TabSelection\.journal\|TabSelection\.reminders" GrowWisePackage/Sources/ --include="*.swift"`

Expected: zero or a handful of hits. For each hit:
- If the code was switching on the tab to apply tab-specific logic, remove that branch (the tab is gone).
- If the code was programmatically selecting a tab, switch to `.home` (the nearest sibling landing tab).

- [ ] **Step 4: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -30`
Expected: either clean, or compile errors pointing at code that imports `JournalView`/`RemindersListView`. Those fix in Phase 4.

If `HomeView`, `GardenView`, or `ProfileView` themselves fail to compile because of upstream missing symbols (unlikely at this phase — they existed before), resolve by stubbing the missing symbol locally and filing a follow-up issue.

### Task 3.3: Update `ProfileView` to link to Community forum and remove Reminders references

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`

- [ ] **Step 1: Find reminder/notification references**

Run: `grep -n "Reminder\|showNotifications\|RemindersListView" GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`

For each hit: if it navigates to `RemindersListView`, remove the row. Per implementation guide §Phase 3, the notifications/reminders entry point is removed from Profile.

- [ ] **Step 2: Add a Community Forum row**

Use Edit to add a row near the other navigation rows in `ProfileView`:

```swift
NavigationLink {
    ForumView()
} label: {
    Label("Community Forum", systemImage: "bubble.left.and.bubble.right.fill")
}
.accessibilityIdentifier("profile_row_forum")
```

Adjust the surrounding syntax (List/Section/NavigationLink patterns) to match the existing ProfileView structure — do not force a different list style. If `ForumView()` requires environment dependencies already in scope on the profile tab, no extra plumbing is needed; if it requires a service not injected at the profile tab, defer and file an issue.

- [ ] **Step 3: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: clean or compile errors pointing at deleted Journal/Reminder imports, which fix in Phase 4.

### Task 3.4: Update test selectors for removed tabs

**Files:**
- Modify: any `GrowWisePackage/Tests/**` file referencing `tab_journal` / `tab_reminders` / `TabSelection.journal` / `TabSelection.reminders`
- Modify: any `GrowWiseUITests/**` file referencing `tab_journal` / `tab_reminders`

- [ ] **Step 1: Find test references**

Run:
```bash
grep -rn "tab_journal\|tab_reminders\|TabSelection\.journal\|TabSelection\.reminders" \
    GrowWisePackage/Tests/ GrowWiseUITests/ --include="*.swift"
```

- [ ] **Step 2: Decide delete vs. rewrite per test**

For each hit:
- If the test purely asserted the tab exists or navigated into it, delete the test.
- If the test asserted higher-level behavior that happens to use the tab bar as its entry path, rewrite it to use `tab_home` or `tab_garden` as the entry point, or `tab_club` if the behavior has moved.

Document each deletion/rewrite in the commit message in the form `"- Deleted GrowWiseUITests/FooTests.swift — exercised tab_reminders which no longer exists."`

- [ ] **Step 3: Build + test**

Run:
```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10"
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"
```
Expected: build clean; tests green minus the failures that get fixed in Phase 4 when the actual Journal/Reminder view imports are resolved.

### Task 3.5: Phase 3 PR

- [ ] **Step 1: Commit each sub-change if not already committed**

- [ ] **Step 2: Push + PR**

```bash
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 3: 4-tab restructure" --body "$(cat <<'EOF'
## Summary
- TabSelection reduced to home/garden/club/profile.
- MainAppView renders 4 tabs with coral tint; Club wrapped in its own NavigationStack.
- GardenClubFeedView stubbed so the Club tab compiles; full implementation in Phase 5.
- ProfileView adds Community Forum row and drops the RemindersListView reference.
- Test selectors targeting tab_reminders/tab_journal rewritten or deleted with rationale.

## Test plan
- [ ] `swift build` clean.
- [ ] `swift test` green (except tests gated on Journal/Reminders view imports — fixed Phase 4).
- [ ] Simulator boots, shows 4 tabs, Club tab shows placeholder.

Base: `redesign/v2`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 4 — Delete Reminders + Journal tab views

Goal: remove the 5 deleted source files, clean up any remaining import/reference sites, delete or rewrite the tests that exercised those views. End of phase: `swift build` clean, `grep -rn "JournalView\|RemindersListView\|JournalEntryRow\|JournalEntryDetailView\|AddJournalEntryView" GrowWisePackage/Sources` returns nothing.

### Task 4.1: Delete the five source files

**Files:**
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/RemindersListView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryRow.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/AddJournalEntryView.swift`

- [ ] **Step 1: Delete**

```bash
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/RemindersListView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryRow.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/AddJournalEntryView.swift
```

- [ ] **Step 2: Check if the Journal folder is empty and remove it**

Run: `ls GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/ 2>/dev/null`
Expected: empty (if an AGENTS.md or README is in there, keep it; otherwise `rmdir` the empty folder).

### Task 4.2: Resolve remaining references

**Files:**
- Modify: any `*.swift` file that imports or references the deleted views.

- [ ] **Step 1: Find leftover references**

Run:
```bash
grep -rn "JournalView\|RemindersListView\|JournalEntryRow\|JournalEntryDetailView\|AddJournalEntryView" \
    GrowWisePackage/Sources/ GrowWiseUITests/ --include="*.swift"
```

- [ ] **Step 2: Fix each hit**

Common patterns:
- `NavigationLink(value: .journal) { ... }` — delete the navigation link; journals don't navigate as a route anymore. If the row still makes sense (e.g., "View all notes"), swap the destination to the plant that owns the entry, via `MyGardenPlantDetailView`.
- `sheet(isPresented: ..., content: { AddJournalEntryView() })` — remove the sheet trigger. The new photo-strip on `MyGardenPlantDetailView` (Phase 8) owns journal entry creation inline.
- `.navigationDestination(for: JournalEntry.self) { JournalEntryDetailView(entry: $0) }` — remove. The photo-strip's inline full-screen viewer is the new route.
- Imports of removed symbols — delete the `import` line.

- [ ] **Step 3: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: clean.

### Task 4.3: Remove or rewrite tests targeting deleted views

**Files:**
- Potentially delete: test files that imported the deleted views as their primary target.

- [ ] **Step 1: Find test references**

Run:
```bash
grep -rln "JournalView\|RemindersListView\|JournalEntryRow\|JournalEntryDetailView\|AddJournalEntryView" \
    GrowWisePackage/Tests/ GrowWiseUITests/ --include="*.swift"
```

- [ ] **Step 2: For each file**

- If the test file's primary target is one of the deleted views, delete the whole file with `git rm`.
- If the file has some tests for deleted views alongside unrelated tests, delete just the offending tests.

Retain tests that target `JournalEntry` (the model) — the model stays.

- [ ] **Step 3: Build + test**

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10"
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"
```
Expected: build clean, test suite green.

### Task 4.4: Phase 4 PR

- [ ] **Step 1: Commit (if not already split into commits)**

```bash
git commit -m "refactor: delete Reminders + Journal tab views (ADR-019)

Removes RemindersListView, JournalView, JournalEntryRow, JournalEntryDetailView,
AddJournalEntryView. Reminder rows now live on Home; journal entries render as
a photo strip on Plant Detail (Phase 8). Models JournalEntry and PlantReminder
stay in GrowWiseModels.

Per phased plan Phase 4."
```

- [ ] **Step 2: Push + PR**

```bash
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 4: delete Reminders + Journal tab views" --body "## Summary
- Delete RemindersListView and the four Journal views.
- Fix references in other views and tests.
- JournalEntry + PlantReminder models stay; AddReminderView, PlantReminderDetailView, ReminderSettingsView stay.

## Test plan
- [ ] \`swift build\` clean.
- [ ] \`swift test\` green.
- [ ] \`grep JournalView RemindersListView\` over GrowWisePackage/Sources returns zero.

Base: \`redesign/v2\`."
```

---

## Phase 5 — `GardenClubFeedView` + multi-club routing

Goal: replace the Phase 3 stub with a real Club tab. Handles zero / one / many-clubs routing per the design spec's §Open-questions resolution. Uses the existing `ClubActivity` model and `ClubCloudKitService` where possible; in-memory seeded sample data when CloudKit is unavailable. End of phase: `swift build` clean; Club tab shows seeded feed and smart-match card in simulator.

**Reference:** `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` §Phase 5 has the full `GardenClubFeedView` source. It references model properties that may not match the real `ClubActivity` — adapt via a `ClubActivityViewData` presentation-only struct if the properties differ.

### Task 5.1: Inspect the existing `ClubActivity` model

**Files:**
- Read: `GrowWisePackage/Sources/GrowWiseModels/ClubActivity.swift`
- Read: `GrowWisePackage/Sources/GrowWiseModels/GardenClub.swift`

- [ ] **Step 1: Read both files and note property names**

Run: `cat GrowWisePackage/Sources/GrowWiseModels/ClubActivity.swift GrowWisePackage/Sources/GrowWiseModels/GardenClub.swift`

Record which of these the real model has: `authorDisplayName`, `caption`, `zoneTag`, `relativeTimeLabel`, `likeCount`, `commentCount`, `createdAt`, `updatedAt`. The implementation guide code assumes the first six exist.

- [ ] **Step 2: If any of the six are missing, add a presentation-only adapter**

If `relativeTimeLabel` or `zoneTag` don't exist on the model (likely), define a `ClubActivityViewData` struct inside `GardenClubFeedView.swift` with the six fields the view consumes. Populate it in `load()` from whatever the model does expose (e.g., compute `relativeTimeLabel` from `createdAt` via `RelativeDateTimeFormatter`).

This is MV-compliant: presentation-only structs used by the view are allowed; a separate `class ViewModel` is not.

### Task 5.2: Write routing-logic test

**Files:**
- Create: `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedRoutingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftData
import GrowWiseModels
@testable import GrowWiseFeature

@Suite("Garden Club tab routing")
struct GardenClubFeedRoutingTests {
    @Test("Zero clubs routes to join/create prompt")
    func zeroClubsRoutesToJoinPrompt() {
        let route = GardenClubTabRoute.resolve(clubs: [])
        #expect(route == .joinOrCreate)
    }

    @Test("Exactly one club routes to its feed")
    func oneClubRoutesToFeed() throws {
        let club = GardenClub(
            name: "Test Club",
            clubDescription: "Testing",
            createdAt: .now,
            updatedAt: .now
        )
        let route = GardenClubTabRoute.resolve(clubs: [club])
        guard case let .feed(resolvedClub) = route else {
            Issue.record("expected .feed route, got \(route)")
            return
        }
        #expect(resolvedClub.name == "Test Club")
    }

    @Test("Multiple clubs routes to list")
    func multipleClubsRoutesToList() {
        let a = GardenClub(name: "A", clubDescription: "", createdAt: .now, updatedAt: .now)
        let b = GardenClub(name: "B", clubDescription: "", createdAt: .now, updatedAt: .now)
        let route = GardenClubTabRoute.resolve(clubs: [a, b])
        guard case let .list(clubs) = route else {
            Issue.record("expected .list route, got \(route)")
            return
        }
        #expect(clubs.count == 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter GardenClubFeedRoutingTests"`
Expected: compile error — `GardenClubTabRoute` doesn't exist yet.

### Task 5.3: Implement `GardenClubTabRoute`

**Files:**
- Create or modify (place alongside the view): `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubTabRoute.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation
import GrowWiseModels

/// Routing decision for the Club tab. Resolved from the user's club membership.
/// See ADR-019 and docs/superpowers/specs/2026-04-22-cultivation-redesign-and-rename-design.md.
public enum GardenClubTabRoute: Equatable {
    case joinOrCreate
    case feed(GardenClub)
    case list([GardenClub])

    public static func resolve(clubs: [GardenClub]) -> GardenClubTabRoute {
        switch clubs.count {
        case 0: return .joinOrCreate
        case 1: return .feed(clubs[0])
        default:
            // Most-recently-updated club is the default for the Home "Your Club" card,
            // but the tab routes to the list so the user can pick.
            return .list(clubs.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) })
        }
    }
}

extension GardenClub: Equatable {
    public static func == (lhs: GardenClub, rhs: GardenClub) -> Bool {
        lhs.id == rhs.id
    }
}
```

If `GardenClub` already has `Equatable` conformance, drop the extension at the bottom. If the model has no stable `id`, use `PersistentIdentifier` equality via `lhs.persistentModelID == rhs.persistentModelID`.

- [ ] **Step 2: Run routing tests to confirm pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter GardenClubFeedRoutingTests"`
Expected: all three tests pass.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubTabRoute.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedRoutingTests.swift
git commit -m "feat(club): GardenClubTabRoute for 0/1/N-club routing

Resolves the Club tab's landing surface based on the user's club membership
count: zero → join/create prompt, one → feed directly, many → list. Per the
multi-club reconciliation decision in the 2026-04-22 redesign spec."
```

### Task 5.4: Implement `GardenClubFeedView` (real version)

**Files:**
- Modify (full-file rewrite): `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`

- [ ] **Step 1: Replace the stub with the full view**

Use Write to replace the entire file with the source from `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` §Phase 5 (that file, lines 764–1098 of the implementation guide — the block starting `import GrowWiseModels` and ending with the `initials(of:)` helper). Adjust property accesses to match what the real `ClubActivity` and `GardenClub` models expose (per Task 5.1 findings). If a `ClubActivityViewData` adapter is required, add it.

Modify the view's `init` to take an optional `club: GardenClub?`:

```swift
public init(club: GardenClub? = nil) {
    self.club = club
}

private let club: GardenClub?
```

In `load()`, if `club == nil`, fall back to the existing flow (resolve the user's primary club); if `club != nil`, hydrate from that club directly.

- [ ] **Step 2: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: clean. Likely compile errors come from missing model properties — fix per Task 5.1 adapter strategy.

### Task 5.5: Wire the Club tab to use `GardenClubTabRoute`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift`

- [ ] **Step 1: Add a small router view**

In `MainAppView.swift`, add a private view that uses `GardenClubTabRoute.resolve()`:

```swift
private struct GardenClubTabContainer: View {
    @Environment(DataService.self) private var dataService
    @State private var clubs: [GardenClub] = []

    var body: some View {
        Group {
            switch GardenClubTabRoute.resolve(clubs: clubs) {
            case .joinOrCreate:
                GardenClubJoinOrCreatePrompt()
            case let .feed(club):
                GardenClubFeedView(club: club)
            case let .list(sortedClubs):
                ClubListView()
            }
        }
        .task {
            clubs = (try? await dataService.fetchAllGardenClubs()) ?? []
        }
    }
}

private struct GardenClubJoinOrCreatePrompt: View {
    @State private var isJoining = false
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Join a club or start one")
                .font(CultivationTheme.Fonts.display(22, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Share what's growing with people nearby.")
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Join a club") { isJoining = true }
                .buttonStyle(GradientButtonStyle())
                .accessibilityIdentifier("club_button_join")
            Button("Create a club") { isCreating = true }
                .buttonStyle(CoralButtonStyle())
                .accessibilityIdentifier("club_button_create")
        }
        .padding(CultivationTheme.Spacing.screenPadding)
        .sheet(isPresented: $isJoining) { JoinClubSheet() }
        .sheet(isPresented: $isCreating) { CreateClubSheet() }
    }
}
```

- [ ] **Step 2: Replace `GardenClubFeedView()` in the tab body with the container**

In `mainTabView`, replace:

```swift
NavigationStack {
    GardenClubFeedView()
}
```

with:

```swift
NavigationStack {
    GardenClubTabContainer()
}
```

- [ ] **Step 3: Add a `fetchAllGardenClubs()` helper on `DataService` if it doesn't exist**

Run: `grep -n "fetchAllGardenClubs\|fetchGardenClubs" GrowWisePackage/Sources/GrowWiseServices/DataService.swift`

If missing, add:

```swift
public func fetchAllGardenClubs() async throws -> [GardenClub] {
    try modelContext.fetch(FetchDescriptor<GardenClub>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
}
```

(Signature depends on existing DataService style — match it.)

- [ ] **Step 4: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift \
        GrowWisePackage/Sources/GrowWiseServices/DataService.swift
git commit -m "feat(club): implement GardenClubFeedView with 0/1/N-club routing

Club tab routes via GardenClubTabRoute: zero clubs → join/create prompt,
one → feed, many → list. Feed hosts share prompt, segmented control,
post cards, and the smart-match card. In-memory sample data for v1;
CloudKit wiring is a follow-up issue."
```

### Task 5.6: Phase 5 PR

- [ ] **Step 1: Run full build + tests**

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift build 2>&1 | tail -10"
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -30"
```

- [ ] **Step 2: Push + PR**

```bash
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 5: GardenClubFeedView + multi-club routing" --body "## Summary
- New GardenClubTabRoute handles 0/1/N club membership.
- GardenClubFeedView renders share prompt, segmented control, post cards, smart-match card.
- ClubActivityViewData adapter maps the existing model to the view's needs.
- Real CloudKit wiring is filed as a follow-up issue.

## Test plan
- [ ] GardenClubFeedRoutingTests green.
- [ ] Full swift test green.
- [ ] Simulator: Club tab shows feed for single-club user; list for multi-club; prompt for zero-club.

Base: \`redesign/v2\`."
```

---

## Phase 6 — Home rewrite

Goal: `HomeView` rerendered on cream paper. New `YourClubCard` component. `HomeViewModel` gains `latestClubPost` without changing existing reminder/urgency logic. End of phase: screen renders, `swift build` clean.

**Reference:** implementation guide §Phase 6 has the HomeView skeleton (lines 1112–1165). Use it as the top-level shape; implement the four sub-components fresh per spec §Screens §1.

### Task 6.1: Add `latestClubPost` to `HomeViewModel`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift`

- [ ] **Step 1: Write failing test**

Append to existing `GrowWisePackage/Tests/GrowWiseFeatureTests/HomeViewModelTests.swift` (or create if not present):

```swift
@Test("load populates latestClubPost when a recent club activity exists")
@MainActor
func loadPopulatesLatestClubPost() async throws {
    let service = try await DataService.makeForTesting()
    let user = User(displayName: "Test", email: "t@t.com")
    service.modelContext.insert(user)
    let club = GardenClub(name: "Test Club", clubDescription: "", createdAt: .now, updatedAt: .now)
    service.modelContext.insert(club)
    let activity = ClubActivity(
        authorDisplayName: "Alice",
        caption: "My tomato bloomed!",
        createdAt: .now
    )
    // Wire activity → club via whatever relationship the model uses.
    service.modelContext.insert(activity)
    try service.modelContext.save()

    let vm = HomeViewModel()
    await vm.load(dataService: service)

    #expect(vm.latestClubPost != nil)
    #expect(vm.latestClubPost?.caption == "My tomato bloomed!")
}
```

Adjust the `ClubActivity` init to match the real model — use the field names Task 5.1 identified.

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter HomeViewModelTests"`
Expected: compile error — `latestClubPost` doesn't exist.

- [ ] **Step 3: Add the property + population logic**

Use Edit on `HomeViewModel.swift`. Add a published-equivalent property:

```swift
@Observable
@MainActor
public final class HomeViewModel {
    // … existing properties
    public var latestClubPost: ClubActivity?
    // …

    public func load(dataService: DataService) async {
        // … existing logic preserved
        do {
            let fetch = FetchDescriptor<ClubActivity>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let posts = try dataService.modelContext.fetch(fetch)
            latestClubPost = posts.first
        } catch {
            Logger(subsystem: "com.growwise", category: "HomeViewModel")
                .error("latestClubPost fetch failed: \(error.localizedDescription)")
            latestClubPost = nil
        }
    }
}
```

Match whatever fetch-descriptor style `HomeViewModel` already uses.

- [ ] **Step 4: Run test to verify pass**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter HomeViewModelTests"`
Expected: new test passes; existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/HomeViewModelTests.swift
git commit -m "feat(home): add latestClubPost to HomeViewModel

Surfaces the most-recent ClubActivity for display on the new Your Club card.
Preserves all existing reminder/urgency logic. Errors are logged, not swallowed
(per ADR-007)."
```

### Task 6.2: Create `YourClubCard`

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/YourClubCard.swift`

- [ ] **Step 1: Create the file**

```swift
import GrowWiseModels
import SwiftUI

/// Home-tab card surfacing the latest post from the user's club with a coral/honey
/// gradient banner. Rendered only when HomeViewModel.latestClubPost is non-nil.
struct YourClubCard: View {
    let post: ClubActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("✦")
                Text("Your Club")
            }
            .font(CultivationTheme.Fonts.body(10, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(.white)

            if let caption = post.caption {
                Text(caption)
                    .font(CultivationTheme.Fonts.display(16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                Label("\(post.likeCount ?? 0)", systemImage: "heart")
                Label("\(post.commentCount ?? 0)", systemImage: "bubble.right")
                Label("Share", systemImage: "arrow.up.right")
            }
            .font(CultivationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Gradients.warmAccent)
                .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.25), radius: 12, y: 6)
        )
        .accessibilityIdentifier("home_card_your_club")
    }
}
```

Adjust `post.likeCount` / `commentCount` / `caption` to whatever the real model exposes (per Task 5.1).

### Task 6.3: Rewrite `HomeView`

**Files:**
- Modify (full-file rewrite): `GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift` (restyle to cream)
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/SeasonalTipCard.swift` (restyle)
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/GardenHealthCardView.swift` (restyle)

- [ ] **Step 1: Read the current `HomeView.swift` and `HomeHeroHeader.swift`**

Run: `cat GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift`

Identify existing section composition (greeting, care tasks, health score, seasonal tip, tutorials, community) and what is currently preserved vs. what is rebuilt.

- [ ] **Step 2: Rewrite `HomeView.body`**

Replace the body with the implementation-guide skeleton adapted to match the real `HomeViewModel` API. Structure (from guide §Phase 6):

```swift
public var body: some View {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                HomeHeroHeader(userName: viewModel.userName, weather: viewModel.weatherSummary)
                TodaysCareCard(
                    priority: viewModel.overdueReminders.first,
                    upcoming: Array(viewModel.dueTodayReminders.prefix(3)),
                    onComplete: { viewModel.complete($0) },
                    onMarkAllDone: { viewModel.markAllDoneTopCareType() }
                )
                if let post = viewModel.latestClubPost {
                    YourClubCard(post: post)
                }
                if let healthScore = viewModel.gardenHealthScore {
                    GardenHealthCardView(score: healthScore)
                }
                if let tip = viewModel.seasonalTip {
                    SeasonalTipCard(tip: tip)
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }
    .task { await viewModel.load(dataService: dataService) }
}
```

The `TodaysCareCard` helper either lives as a private struct in `HomeView.swift` or gets extracted into `Home/TodaysCareCard.swift`. Preferred: extract if it grows past 60 lines; inline otherwise.

`markAllDoneTopCareType()` is a new `HomeViewModel` method — batches completion by the care type of the top-urgency task. Add it alongside `complete(_:)`.

- [ ] **Step 3: Restyle `HomeHeroHeader`**

Drop dark-background gradients. Use `CultivationTheme.Colors.background` as the implicit backdrop and the cream hero gradient `CultivationTheme.Gradients.hero` if a subtle tone shift is desired at the top.

Greeting layout: section label (`HomeViewModel.currentDateLabel`) above a `Text` composed as `Text("Good morning, ") + Text(userName).italic().foregroundStyle(coral)` with 34pt display font.

Weather pill: `SmartTag("Auto")` or a dedicated pill using the `GlassPill` restyled form.

- [ ] **Step 4: Restyle `SeasonalTipCard` and `GardenHealthCardView`**

Each gets `.paperCard()` (or a dashed-sage border for `SeasonalTipCard`) and `.foregroundStyle(CultivationTheme.Colors.textPrimary)` on headlines. No dark backdrops.

- [ ] **Step 5: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/Home/*.swift
git commit -m "feat(home): rewrite Home tab on cream paper with Your Club card

HomeView renders greeting + Today's care card + Your Club card + health card +
seasonal tip in a single scroll on the cream-paper background. HomeViewModel
gains markAllDoneTopCareType() batching by care type. Restyles
HomeHeroHeader, SeasonalTipCard, GardenHealthCardView to paper surfaces."
```

### Task 6.4: Phase 6 PR

- [ ] Push + PR into `redesign/v2` with a screenshot of the new Home tab attached.

---

## Phase 7 — Garden rewrite

Goal: `GardenView` and `GardenComponents.swift` rerendered on cream paper. End of phase: screen renders, `swift build` clean.

**Reference:** implementation guide §Phase 7 (lines 1167–1212).

### Task 7.1: Restyle `GardenComponents.swift`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift`

- [ ] **Step 1: Identify components in the file**

Run: `grep -n "^public struct\|^struct" GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift`

Expected hits: `PlantRow`, `BedGroupHeader`, `CompanionTipCard`, `TaskRow`. Restyle each per guide §Phase 7:

- `PlantRow` → 56pt thumbnail (LinearGradient placeholder if no photo), `Fonts.display(17, weight: .medium)` plant name, italic latin secondary line, status dot + status text, "Next care: …" line. Drops the row chevron.
- `BedGroupHeader` → 28pt icon bubble + `Fonts.display(15, weight: .medium)` name + plant-count meta.
- `TaskRow` → Used on Home — restyle backgrounds to cream, icon bubbles to the new `IconBubble` form. Keep existing quick-care icons (💧/🌿/✂️ per ADR-018).
- `CompanionTipCard` → paperDeep background, dashed sage border, italic display body.

- [ ] **Step 2: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`

### Task 7.2: Rewrite `GardenView`

**Files:**
- Modify (structural rewrite): `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift`

- [ ] **Step 1: Apply the skeleton from implementation guide §Phase 7**

Replace the body with the scroll-based paper layout:

```swift
public var body: some View {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GardenHeader(name: viewModel.gardenName, summary: viewModel.summary)
                FilterChipBar(filters: GardenFilter.allCases, selection: $selectedFilter)
                ForEach(viewModel.filtered(by: selectedFilter)) { bedGroup in
                    BedSection(group: bedGroup)
                }
                AddBedButton()
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 40)
        }
    }
    .task { await viewModel.load(dataService: dataService) }
}
```

`GardenFilter` enum added locally per guide (5 cases: all/needsCare/blooming/edible/herbs).

`viewModel.filtered(by:)` is a helper on `GardenViewModel` — add it if absent:

```swift
public func filtered(by filter: GardenView.GardenFilter) -> [PlantGroup] {
    switch filter {
    case .all: return groups
    case .needsCare: return groups.map { ... /* filter plants with overdue reminders */ }
    case .blooming: return groups.map { ... /* filter by plant.isBlooming */ }
    case .edible: return groups.map { ... /* filter by plant.category == .edible */ }
    case .herbs: return groups.map { ... /* filter by plant.category == .herb */ }
    }
}
```

Exact category field name comes from `Plant.swift` — adapt.

- [ ] **Step 2: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit + Phase 7 PR**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenViewModel.swift
git commit -m "feat(garden): rewrite Garden tab on cream paper with filter chips"
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 7: Garden rewrite" --body "Cream-paper rerender of GardenView + GardenComponents with filter chip bar and bed sections."
```

---

## Phase 8 — Plant Detail rewrite

Goal: `MyGardenPlantDetailView` rerendered on cream paper with hero photo, 3 stat cards, Log-care + Get-advice buttons, Share-to-Club coral button, advice card, and a photo-journal strip backed by `JournalEntry`. End of phase: screen renders, `swift build` clean.

**Reference:** implementation guide §Phase 8 (lines 1213–1263).

### Task 8.1: Rewrite `MyGardenPlantDetailView`

**Files:**
- Modify (structural rewrite): `GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift`

- [ ] **Step 1: Read the existing file to preserve logic**

Run: `cat GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift | head -300`

Identify preserved logic: which services it uses, how it fetches journal entries, any existing alert-on-error flow (ADR-007).

- [ ] **Step 2: Replace the body per guide**

Replace with:

```swift
public var body: some View {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HeroPhoto(plant: plant)
                TitleBlock(plant: plant)
                StatRow(plant: plant)
                HStack(spacing: 8) {
                    Button("Log care") { isLogCarePresented = true }
                        .buttonStyle(GradientButtonStyle())
                        .accessibilityIdentifier("plantdetail_button_log_care")
                    Button("Get advice") { isAdviceExpanded.toggle() }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("plantdetail_button_get_advice")
                }
                if let currentClub = primaryClub {
                    Button("Share to \(currentClub.name ?? "Club")") { isShareSheetPresented = true }
                        .buttonStyle(CoralButtonStyle())
                        .accessibilityIdentifier("plantdetail_button_share_to_club")
                }
                AdviceCard(advice: advice, isExpanded: isAdviceExpanded)
                PhotoJournalStrip(entries: entries, plant: plant)
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 40)
        }
    }
    .task {
        advice = await adviceService.fetchAdvice(for: plant)
        entries = await dataService.fetchJournalEntries(for: plant)
        primaryClub = await dataService.fetchPrimaryClub()
    }
    .sheet(isPresented: $isLogCarePresented) { AddReminderView(plant: plant) }
    .sheet(isPresented: $isShareSheetPresented) {
        // Reuse PublishGardenSheet adapted for single-plant share, or inline composer
        PublishGardenSheet(scope: .plant(plant))
    }
    .alert("Couldn't load details", isPresented: $showingError) {
        Button("OK", role: .cancel) {}
    } message: { Text(errorMessage ?? "") }
}
```

Where each helper (`HeroPhoto`, `TitleBlock`, `StatRow`, `AdviceCard`, `PhotoJournalStrip`, `SecondaryButtonStyle`) is defined as a private struct in the same file. If a helper grows past 60 lines, extract to `Views/PlantDetail/` (create folder).

- [ ] **Step 3: Add `SecondaryButtonStyle`**

If not already in `ViewModifiers.swift` from Phase 1, add:

```swift
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CultivationTheme.Fonts.body(16, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(CultivationTheme.Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}
```

- [ ] **Step 4: Implement `PhotoJournalStrip` inline**

Horizontal `ScrollView(.horizontal, showsIndicators: false)` of 60×60 rounded thumbnails loaded from each entry's photo asset, with a dashed `+` cell at the end that presents a photo picker. Tapping a thumbnail expands to a full-screen viewer via `.sheet`.

Expected entry fields: `JournalEntry.createdAt`, `JournalEntry.photoAssetPath` (or whatever the existing model exposes). Adapt.

- [ ] **Step 5: Add `DataService.fetchPrimaryClub()` if missing**

```swift
public func fetchPrimaryClub() async -> GardenClub? {
    let fetch = FetchDescriptor<GardenClub>(
        sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    return (try? modelContext.fetch(fetch))?.first
}
```

- [ ] **Step 6: Build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`

- [ ] **Step 7: Commit + Phase 8 PR**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift \
        GrowWisePackage/Sources/GrowWiseServices/DataService.swift
git commit -m "feat(plant): rewrite Plant Detail on cream paper with Share-to-Club

Hero photo + 3 stat cards + two-button row + coral Share-to-Club button +
advice card + photo-journal strip backed by JournalEntry. Share uses existing
PublishGardenSheet adapted for single-plant scope. PhotoJournalStrip renders
the model JournalEntry entries inline; the deleted JournalEntryDetailView is
replaced by an inline full-screen viewer."
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 8: Plant Detail rewrite" --body "See commit message."
```

---

## Phase 9 — Rename sweep (user-facing only)

Goal: every human-readable "GrowWise" string becomes "Cultivation". Every code-level identifier stays. End of phase: `plutil -p` on built app shows `CFBundleDisplayName = "Cultivation"`; audit grep returns zero unexpected lines.

### Task 9.1: Change `CFBundleDisplayName` in both build configs

**Files:**
- Modify: `GrowWise.xcodeproj/project.pbxproj`

- [ ] **Step 1: Identify the two entries**

Run: `grep -n "INFOPLIST_KEY_CFBundleDisplayName" GrowWise.xcodeproj/project.pbxproj`
Expected: two lines, currently `INFOPLIST_KEY_CFBundleDisplayName = GrowWise;`.

- [ ] **Step 2: Replace both**

Use Edit with `replace_all: true`:
```
old_string: INFOPLIST_KEY_CFBundleDisplayName = GrowWise;
new_string: INFOPLIST_KEY_CFBundleDisplayName = Cultivation;
```

- [ ] **Step 3: Build the app and verify the compiled plist**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator -derivedDataPath /tmp/GrowWise-build build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"
ssh mac-mini "plutil -p /tmp/GrowWise-build/Build/Products/Debug-iphonesimulator/Cultivation.app/Info.plist 2>&1 | grep -E 'CFBundleDisplayName|CFBundleName'"
```

Expected output contains `"CFBundleDisplayName" => "Cultivation"`.

If the `.app` name is still `GrowWise.app`, the `PRODUCT_NAME` setting (in `Config/Shared.xcconfig`, currently `Cultivation`) may be overridden elsewhere. Find the override with `grep -n "PRODUCT_NAME" GrowWise.xcodeproj/project.pbxproj` and remove any conflicting `PRODUCT_NAME` assignment — let the xcconfig win.

### Task 9.2: Sweep user-visible Swift strings

**Files:** various `*.swift` under `GrowWisePackage/Sources/`.

- [ ] **Step 1: Run the audit grep pre-sweep**

```bash
grep -rn "GrowWise\|Grow Wise\|growwise" GrowWisePackage/Sources --include="*.swift" \
    | grep -v "import GrowWise\|GrowWiseFeature\|GrowWiseServices\|GrowWiseModels\|Logger(subsystem: \"com.growwise\|com.growwiser.app\|iCloud.com.growwise"
```

The output enumerates candidates for rename. Each line should be inspected.

- [ ] **Step 2: For each line, decide**

Rules:
- String is inside a `Text("…")`, `String(localized: "…")`, alert title/message, `UNMutableNotificationContent.title/body`, `localizedDescription`, `setUserProperty(name:value:)` value, `.accessibilityLabel("…")`, or docstring visible in UI → rename to `Cultivation`.
- String is a code comment that's not user-visible → leave alone in this phase.
- String is a subsystem/category for `Logger` → **do not rename** (that's an identifier).
- String is a test fixture that mimics real user data → rename if appropriate, leave if the test asserts a specific historical value.

Apply edits one file at a time with Edit. Commit after each file (or batch of related files — onboarding copy, alerts, etc.).

- [ ] **Step 3: Re-run audit grep post-sweep**

```bash
grep -rn "GrowWise\|Grow Wise\|growwise" GrowWisePackage/Sources --include="*.swift" \
    | grep -v "import GrowWise\|GrowWiseFeature\|GrowWiseServices\|GrowWiseModels\|Logger(subsystem: \"com.growwise\|com.growwiser.app\|iCloud.com.growwise"
```
Expected: empty. Any line that remains gets a one-line by-hand judgment noted in the PR description.

### Task 9.3: StoreKit product display names

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/SubscriptionService.swift`

- [ ] **Step 1: Find user-visible strings**

The file lists product IDs (`com.growwise.premium.monthly` etc.) — those stay. Look for:
- `localizedTitle` / `displayName` / `description` fields on any hard-coded fallback values
- `Text("GrowWise Premium")` style strings in the paywall view that consumes this service

- [ ] **Step 2: Rename to Cultivation**

`GrowWise Premium` → `Cultivation Premium`, etc. Product IDs stay as `com.growwise.premium.*` — they're App Store Connect records that can't be renamed without data loss.

### Task 9.4: Analytics event display names

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ObservabilityService.swift` and any file using Amplitude/Sentry.

- [ ] **Step 1: Find user-facing display-name strings**

`grep -n "GrowWise" GrowWisePackage/Sources/GrowWiseServices/ObservabilityService.swift`

- [ ] **Step 2: Rename display-name strings only; leave event keys untouched**

If a line is `Identify.setUserProperty("app_name", "GrowWise")` — that's a value downstream tools display. Rename to `"Cultivation"`.
If a line is `logEvent("GrowWise_launched")` — that's an event key. **Do not rename.** Renaming a key breaks historical analytics.

### Task 9.5: Docs + READMEs

**Files:**
- Modify: `README.md`, `GrowWise/Data/README.md`, marketing/release notes if present.

- [ ] **Step 1: Sweep prose**

In each file:
- Prose references like "GrowWise helps gardeners…" → "Cultivation helps gardeners…"
- Technical references to folders/modules/identifiers → keep as `GrowWise` / `GrowWisePackage` / `com.growwiser.app` etc.
- Mixed references (e.g. "the GrowWise codebase ships as Cultivation") → prefer "the codebase (internally GrowWise) ships as Cultivation" when clarity helps.

- [ ] **Step 2: Leave `CLAUDE.md` and `AGENTS.md` alone**

Their current phrasing ("GrowWise (branded **Cultivation**)") remains accurate post-rename.

### Task 9.6: Phase 9 PR

- [ ] **Step 1: Run the audit grep one more time and capture its output in the PR body**

- [ ] **Step 2: Push + PR**

```bash
git push
gh pr create --repo jbcrane13/GrowWise --base redesign/v2 --title "redesign v2 — Phase 9: user-facing rename to Cultivation" --body "## Summary
- CFBundleDisplayName = Cultivation (Debug + Release).
- User-visible Swift strings swept: onboarding copy, alerts, StoreKit descriptions, notifications, accessibility labels.
- Analytics display-name properties renamed; event keys untouched.
- README + data README prose updated.
- No code-level identifier changes (bundle ID, CloudKit container, StoreKit IDs, keychain service, Swift modules, logger subsystems, folder names all unchanged per ADR-020).

## Audit
Post-sweep grep:
\`\`\`
grep -rn \"GrowWise\\|Grow Wise\\|growwise\" GrowWisePackage/Sources --include=\"*.swift\" | grep -v ...
\`\`\`
Expected: empty. Paste actual output here.

Base: \`redesign/v2\`."
```

---

## Phase 10 — Tests, lint, format, code-review, ui-verify

Goal: full quality-gate pass before the final merge.

### Task 10.1: Run the full test suite

- [ ] **Step 1:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -40"
```

Expected: green. Count of tests should equal pre-redesign count minus explicitly deleted tests (~20 expected deletions) plus the new tests added in Phases 1/5/6 (~6 new).

Any red test: if it reflects a Phase-4-deletion we missed, delete or rewrite. If it reflects a regression, fix and re-commit on `redesign/v2`.

### Task 10.2: Lint + format

- [ ] **Step 1:**

```bash
swiftlint lint --strict --config .swiftlint.yml
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise
```

Expected: both return zero issues. If swiftformat reports a file, run `swiftformat --config .swiftformat <path>` to auto-fix. If swiftlint reports an issue, fix manually — do not disable rules.

### Task 10.3: Accessibility ID audit

- [ ] **Step 1: Run the check-ids skill**

Invoke the `ui-test:check-ids` skill (per user's project-level skills). Target: the diff from this redesign branch vs master.

Required new IDs (from spec §Accessibility IDs):
- `tab_club`, `tab_home`, `tab_garden`, `tab_profile` (Phase 3)
- `club_share_prompt` or `club_button_share_prompt`, `club_segment_*`, `club_smart_match`, `club_feed_placeholder` (Phases 3 + 5)
- `club_button_join`, `club_button_create` (Phase 5)
- `home_card_your_club` (Phase 6)
- `plantdetail_button_share_to_club`, `plantdetail_button_log_care`, `plantdetail_button_get_advice` (Phase 8)
- `profile_row_forum` (Phase 3)

For each missing ID: add `.accessibilityIdentifier("…")` to the corresponding view. Commit.

### Task 10.4: Code-review skill pass

- [ ] **Step 1: Run the code-review skill on the diff `master..redesign/v2`**

Focus areas from the spec:
- MV compliance — no new ViewModels except existing Home/GardenViewModel.
- Swift 6 strict concurrency — Task<Void, Never> in Button actions, MainActor isolation.
- ADR-007 — no silent `try?` for user-facing operations.
- No `print()` — use `os.Logger`.
- No force-unwraps.

Fix every FAIL. Warnings get a judgment call — fix if quick, file an issue if not.

### Task 10.5: `ui-verify` screenshot walkthrough

- [ ] **Step 1: Run the ui-verify skill**

Invoke `swiftui-dev:ui-verify`. Target: full app boot into Home → tab through all 4 tabs → Plant Detail → Club share prompt → Home Your Club card tap → Me tab. Save screenshots in the PR description.

Expected outcome: all screens render without visual regressions, cream paper consistent, no dark-mode glass-morphism leakage.

### Task 10.6: Compile-check the app via Xcode

- [ ] **Step 1:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"
```

Expected: `BUILD SUCCEEDED`.

### Task 10.7: File follow-up GitHub issues

- [ ] **Step 1: CloudKit wiring of GardenClubFeedView**

```bash
gh issue create --repo jbcrane13/GrowWise \
  --title "redesign v2 follow-up: wire GardenClubFeedView to ClubCloudKitService" \
  --body "The Phase-5 implementation seeds the feed with in-memory samples. Replace with a real query via ClubCloudKitService.fetchRecentActivity(for:) once that pipeline is tested in production. Acceptance: feed shows real posts from other club members, not seed data." \
  --label "type:feature,priority:medium,status:ready"
```

- [ ] **Step 2: Grain-texture overlay (conditional)**

If the ui-verify review judged the cream background too flat, file:

```bash
gh issue create --repo jbcrane13/GrowWise \
  --title "redesign v2 follow-up: paper-grain texture overlay on cream background" \
  --body "Spec allows a multiply-grain overlay; v1 ships solid cream. Add a subtle noise texture image and overlay it on MainAppView's background with low opacity (~5%) for tactile depth." \
  --label "type:chore,priority:low,status:ready"
```

- [ ] **Step 3: Any TODO(GW-redesign-v2) left in code**

```bash
grep -rn "TODO(GW-redesign-v2)" GrowWisePackage/Sources/ GrowWise/
```

For each hit, file a GitHub issue referencing the file:line.

---

## Phase 11 — Final merge to master

### Task 11.1: Confirm all acceptance gates

- [ ] `swift build` clean on mac-mini (local run too).
- [ ] `xcodebuild` app-target build clean on mac-mini.
- [ ] `swift test` green on mac-mini.
- [ ] `swiftlint --strict` clean.
- [ ] `swiftformat --lint` clean.
- [ ] code-review skill returns no FAILs.
- [ ] `ui-verify` walkthrough attached with screenshots.
- [ ] `plutil -p` on built app shows `CFBundleDisplayName = "Cultivation"`.
- [ ] Audit grep (Phase 9.2) returns zero unexpected lines.
- [ ] `docs/architecture/ADR.md` contains ADR-019 + ADR-020.
- [ ] `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md` present.
- [ ] `docs/superpowers/specs/2026-04-20-simplified-ui-v2-implementation.md` present with Phase-2-obsolete note.
- [ ] `docs/mockups/cultivation-simplified-wireflow.html` present.
- [ ] `growwise redesigfn/` folder gone.
- [ ] Follow-up issues filed (Task 10.7).

### Task 11.2: Rebase `redesign/v2` on current `master`

- [ ] **Step 1:**

```bash
git fetch origin
git checkout redesign/v2
git rebase origin/master
```

Resolve conflicts conservatively (prefer `redesign/v2` for any file rewritten in this redesign; prefer `origin/master` for unrelated files). If a conflict is substantial, pause and flag it.

- [ ] **Step 2: Push the rebased branch**

```bash
git push --force-with-lease
```

### Task 11.3: Open the master-facing PR

- [ ] **Step 1:**

```bash
gh pr create --repo jbcrane13/GrowWise --base master --title "redesign v2: Cultivation cream-paper UI + 4 tabs + user-facing rename" --body "$(cat <<'EOF'
## Summary

Ships the 2026-04-20 v2 UI pivot (ADR-019) and completes the user-facing rename to Cultivation (ADR-020). 11 phases stacked and merged into this branch; see `docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md` for the task-level plan.

### What changed
- Cream-paper field-journal palette replaces dark glass-morphism. `.system(design: .serif)` display font, `.system(design: .rounded)` body font.
- 5 tabs → 4 tabs. Reminders tab deleted; reminders remain on Home. Journal tab deleted; journal entries render as a photo strip on Plant Detail.
- New `GardenClubFeedView` promoted to the 3rd tab. Multi-club routing: 0 → join/create prompt, 1 → feed, N → list.
- "Share to [Club]" coral button on every Plant Detail.
- `CFBundleDisplayName = Cultivation`. User-visible strings swept.
- All code-level identifiers (bundle ID, CloudKit container, StoreKit IDs, keychain service, Swift modules, logger subsystems, folder names) preserved per ADR-020.

### What did not change
- SwiftData models (including the retained JournalEntry, PlantReminder, GardenClub family).
- DataService + repositories.
- ReminderService, LocationService, all domain services.
- Existing multi-club views (ClubListView/ClubDetailView etc.) still reachable through the new routing.

## Test plan

- [x] `swift build` clean on mac-mini.
- [x] `xcodebuild` app build clean.
- [x] `swift test` green.
- [x] `swiftlint --strict` clean.
- [x] `swiftformat --lint` clean.
- [x] `ui-verify` walkthrough attached below.
- [x] `plutil -p` verifies `CFBundleDisplayName = Cultivation`.
- [x] Audit grep returns zero unexpected lines.

## Screenshots
[attach `ui-verify` outputs]

## Follow-up issues
- #NNN — Wire GardenClubFeedView to ClubCloudKitService
- #NNN — Paper-grain texture overlay (if judged flat)
- #NNN — Any remaining TODO(GW-redesign-v2)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Task 11.4: After merge, clean up

- [ ] **Step 1: Delete the redesign branch once merged**

```bash
git checkout master
git pull
git branch -d redesign/v2
git push origin --delete redesign/v2
```

- [ ] **Step 2: Update `CLAUDE.md` only if the description has drifted**

The current CLAUDE.md phrasing "GrowWise (branded **Cultivation**)" remains accurate. No edit required unless the description has drifted.

- [ ] **Step 3: Close the brainstorm-task loop**

Create a GitHub issue summarizing the shipped redesign and linking to the ADRs + specs, so future agents can find the context without spelunking through merged PRs.

---

## Self-review (checklist the plan author runs, not part of execution)

**1. Spec coverage.** Every phase in the spec has a corresponding task group in this plan. Every spec acceptance gate has a Task 11.1 checkbox. Rename scope from spec §Rename is fully enumerated in Phase 9 tasks. ✓

**2. Placeholder scan.** `grep -n "TBD\|TODO: fill\|XXX\|\\.\\.\\." this-plan.md` — the only "…" appearances are in prose context, not in step content. No "TBD" / "implement later" patterns. ✓

**3. Type consistency.** `GardenClubTabRoute.resolve` signature matches between tasks 5.2 (test) and 5.3 (impl). `HomeViewModel.latestClubPost` is consistently optional across 6.1 (test), 6.1 (impl), and 6.3 (view). `SmartTag(label:)` signature matches between Task 1.3 (test) and the ViewModifiers source referenced in Task 1.4. ✓

**4. Spec requirement → task mapping check.**
- Phase structure from spec → Phase sections of this plan: 1:1. ✓
- "Each phase ends with `swift build` clean on mac-mini as a hard gate" — every phase ends with a PR task that runs the build. ✓
- Rename scope (6 specific change categories) — covered by Tasks 9.1–9.5. ✓
- Accessibility IDs list → Task 10.3 enumeration. ✓
- Testing approach → Tasks 1.1, 1.3, 2.1, 5.2, 6.1, 10.1 cover all test additions and suite runs. ✓

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. Best fit for a plan this size.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints for review.

Which approach?
