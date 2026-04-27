# Cultivation — Simplified UI v2 · Handoff Packet

**For:** a Claude Code session (or Blake) finishing the v2 UI redesign.
**Date:** 2026-04-23
**Branch:** `redesign/v2-simplified-ui` (worktree at `.claude/worktrees/redesign-v2`) or a fresh worktree off `master`.

## The situation in one paragraph

The v1 pass of this redesign landed on master (commits `a4bce27` through `a1c2596`). It converted the core theme, tab structure, Plant Detail, Garden, Home's hero, and added `GardenClubFeedView`. What it did not do is sweep every downstream view. Many sheets, cards, and detail screens still have leftover dark surfaces, `.foregroundColor(.white)`, untouched typography, or other artifacts from the pre-redesign treatment. This packet exists so the next session can **find and close those gaps** without starting over.

## What's already true on master

- `CultivationTheme.swift` uses cream paper tokens (`#F6F0E4` paper, `#1F2A22` ink, coral, sage, moss, honey).
- `PaperCardModifier` is the surface treatment. `.glassCard()` is aliased to `.paperCard()` so old call sites keep compiling.
- `HeroBackgroundModifier` now renders cream gradient + soft coral/sage glows (no dark orbs).
- `MainAppView` has four tabs: Home, Garden, Club, Me. Reminders and Journal tabs are gone.
- `Views/Journal/` directory is deleted. `JournalEntry` model remains and renders as a photo strip inside Plant Detail.
- `Views/GardenClub/GardenClubFeedView.swift` is the Club tab entry point, wired to `ClubCloudKitService`.
- ADR-017 (field journal), ADR-018 (contextual quick-care icons), and ADR-019 (this pivot) are committed.
- ADR-020 constrains the rename: user-facing "Cultivation" only, no code-level identifier changes.

## What's likely not done yet

Audit commands are in the plan, but these are the most probable gaps:

- **Force light appearance + remove Appearance toggle (Phase 1.5, run first).** The v2 spec was updated on 2026-04-23 to drop dark mode entirely — cream paper always. Dark mode was masking unconverted views in the second pass and making it hard to tell what was actually broken. Force `.preferredColorScheme(.light)` on `MainAppView`, delete the `AppStorage("app_appearance")` machinery, remove the Appearance Picker from `AppSettingsView`, and delete the `AppAppearance` enum. Do this before any visual audit — it's what lets you see what's genuinely wrong.
- Views that still set `.foregroundColor(.white)`, `.background(Color.black...)`, or similar dark-era tokens.
- Hero and header views in feature subfolders (Tutorials, PlantDatabase, Community, Settings, Onboarding) that never got swept in the v1 pass.
- Sheets in `Views/Garden/` (CreateGarden, CreateBed, AddSeed, MovePlant, etc.) that have their own backgrounds or custom styling.
- Places using `.font(.system(...))` without the display/body tokens — meaning they're rendering in SF Pro instead of the intended serif/rounded pairing.
- Photos/imagery that assume dark backgrounds (overlays, corner treatments).
- Onboarding flow, which is visually high-stakes (first impression) and often missed in broad sweeps.
- **Custom font registration for Fraunces + Manrope.** v1 deliberately scoped this out and used `.system(design: .serif)` / `.rounded`. v2 brings the real fonts back in — Phase 2 of the implementation plan owns the work (CoreText registration via `Bundle.module`, wired through `CultivationTheme.Fonts.*`, with system fallbacks still live for safety).

## The three documents in this packet

Read them in this order:

1. **`docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md`** — the design spec. Describes the *target* state. Use it to decide whether a given view matches the intent.
2. **`docs/architecture/ADR.md`** (on master) — already contains ADR-019 and ADR-020. No changes needed here.
3. **`docs/superpowers/plans/2026-04-20-simplified-ui-v2-implementation.md`** — the implementation plan. Drives the audit-and-close workflow. Start here when you're ready to write code.
4. **`docs/mockups/cultivation-simplified-wireflow.html`** — the visual reference. Toned-down Share button on Plant Detail is canon.

## Operator ground rules (from `CLAUDE.md`)

These are load-bearing — violating them wastes time or breaks things:

- **Never run `xcodebuild test` on this machine.** It crashes. Tests run on `mac-mini` via SSH. Use `swift build` in `GrowWisePackage/` locally for fast compile checks between phases.
- **No new ViewModel classes** except `GardenViewModel` / `HomeViewModel` (ADR-002, ADR-015). Services go through `@Environment`.
- **`@Observable`, not `@Published` or `@StateObject`.**
- **SwiftData `@Model` properties all optional** for CloudKit compatibility.
- **Every interactive element needs `.accessibilityIdentifier("screen_element_descriptor")`.**
- **Errors must surface via alerts** in views. No silent `try?` on user-facing operations (ADR-007).
- **`.sheet` over `navigationDestination`** for views that own a NavigationStack (ADR-012).
- **`os.Logger` with `.private` for user data.** No `print()` in production code.
- **Issue tracking is GitHub Issues via `gh` CLI.** `beads (bd)` is deprecated.

## Build and verify

```bash
# Fast local compile
cd ~/Projects/GrowWise/GrowWisePackage && swift build

# Full app build (needs to work before shipping)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"

# Package tests
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"

# Lint / format
swiftlint lint --strict --config .swiftlint.yml
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise
```

## Definition of done

1. `swift build` clean, locally.
2. `xcodebuild` clean on mac-mini.
3. `swift test` passes (note deliberately-deleted Reminders/Journal tab tests).
4. `swiftlint --strict` and `swiftformat --lint` clean.
5. A manual screenshot sweep through all four tabs, the major sheets (Add Plant, Create Garden, Create Bed), onboarding, and settings confirms no residual dark surfaces, white text on cream, or untouched typography.
6. The wireflow HTML and the simulator's rendered screens tell the same visual story.
7. Final commit on the branch; open a PR.

## A note on scope

If, while auditing, you find a view whose copy or interaction pattern doesn't match the spec (not just the surface treatment), **flag it rather than silently rewriting it**. The goal of this phase is to finish the visual and structural conversion, not re-scope features. Open questions should land in the spec's "Open questions" section rather than get answered unilaterally in code.
