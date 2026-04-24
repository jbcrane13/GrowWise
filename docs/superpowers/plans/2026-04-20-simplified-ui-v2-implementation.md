# Cultivation — Simplified UI v2 · Implementation Plan

**Date:** 2026-04-20 (regenerated 2026-04-23 for the finish-the-conversion pass)
**Status:** Living plan — update as phases close.
**Target branch:** `redesign/v2-simplified-ui` (worktree at `.claude/worktrees/redesign-v2`), or a fresh worktree off `master`.
**Source of truth for intent:** `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md`
**Visual reference:** `docs/mockups/cultivation-simplified-wireflow.html`
**Decision record:** ADR-019 in `docs/architecture/ADR.md`

## How to use this document

This is an **audit-and-close** plan, not a greenfield rewrite. The v1 pass of the redesign already landed on master: the theme tokens are cream paper, `PaperCardModifier` is the surface, the tab bar is down to four, and `GardenClubFeedView` is wired up. What v1 didn't finish is the *sweep* — many downstream views still have leftovers from the dark era.

The phases below each start with an audit (a grep or a read), call out the likely gaps, and finish with a verification command. Skip any phase whose audit comes back clean.

## Operator ground rules

These are load-bearing — violating them wastes time or breaks things:

- **Never run `xcodebuild test` locally.** It crashes this machine. Tests run on mac-mini via SSH.
- Use **`swift build`** in `GrowWisePackage/` for fast local compile checks between phases.
- **Strict MV only.** No new ViewModel classes except `GardenViewModel` / `HomeViewModel` (ADR-002, ADR-015). Services go through `@Environment`.
- `@Observable`, never `@Published` or `@StateObject`.
- SwiftData `@Model` props are all optional (CloudKit constraint).
- Every new interactive element: `.accessibilityIdentifier("screen_element_descriptor")`.
- Errors surface via alerts in views. No silent `try?` (ADR-007).
- `.sheet` over `navigationDestination` for views that own a NavigationStack (ADR-012).
- `os.Logger` with `.private` for user data. No `print()` in production code.
- Issues tracked in GitHub via `gh` CLI. `beads (bd)` is deprecated.

## Phase 0 — Pre-flight audit

Runs before any code change. Produces a punch list that tells the rest of the plan what to do.

```bash
cd ~/Projects/GrowWise

# 1. Confirm branch
git status

# 2. Find residual dark-era surfaces
grep -rn "Color\\.black\\|\\.foregroundColor(\\.white)\\|\\.background(Color\\.black" \
  GrowWisePackage/Sources/GrowWiseFeature/ --include="*.swift"

# 3. Find residual dark hex literals
grep -rn "0C0C0C\\|#0c0c0c\\|hex: \"0C\\|hex: \"0c" \
  GrowWisePackage/Sources/GrowWiseFeature/ --include="*.swift"

# 4. System-default typography that should probably be display/body tokens
grep -rn "font(\\.system(size:\\|font(\\.title\\|font(\\.largeTitle" \
  GrowWisePackage/Sources/GrowWiseFeature/ --include="*.swift" | head -40

# 5. Old blur + material usage
grep -rn "ultraThinMaterial\\|thinMaterial\\|regularMaterial\\|\\.blur(" \
  GrowWisePackage/Sources/GrowWiseFeature/ --include="*.swift"

# 6. Stale tab-related symbols (should be zero hits)
grep -rn "RemindersListView\\|JournalView\\|JournalEntryRow\\|JournalEntryDetailView\\|AddJournalEntryView\\|TabSelection\\.journal\\|TabSelection\\.reminders" \
  GrowWisePackage/Sources/GrowWiseFeature/ --include="*.swift"

# 7. Sheets that might not have been swept (common offenders)
ls GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/
ls GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/
ls GrowWisePackage/Sources/GrowWiseFeature/Views/Settings/
ls GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/
```

Write the findings into a scratch file (`scratch/v2-audit.md`, gitignored). Treat it as the to-do list for phases 3–8.

**Verification.** `swift build` clean at the start. If it is not, stop and fix compile errors before touching anything else.

## Phase 1 — Confirm theme and modifiers are v2

**Files:** `Design/CultivationTheme.swift`, `Design/ViewModifiers.swift`, `Design/GardenComponents.swift`.

**Expected on master.** Paper tokens (`#F6F0E4`, `#FFFDF7`, `#1F2A22`, coral, sage, moss, honey). `PaperCardModifier`. `.glassCard()` back-compat aliased to `.paperCard()`. `HeroBackgroundModifier` rendering cream gradient + soft coral/sage glows.

**Audit.**
```bash
grep -n "PaperCardModifier\\|paperCard\\|HeroBackgroundModifier" \
  GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift
grep -n "brandCream\\|cardSurface\\|accentCoral\\|statusHealthy" \
  GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift
```

**If anything is missing,** restore the v2 implementation. The `HeroBackgroundModifier` is the most common regression — in v1 it still held dark-era coral/sage *orbs* on a dark bg until swapped. The current implementation should read roughly:

```swift
struct HeroBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            CultivationTheme.Gradients.hero          // cream → cream-deep
                .overlay(alignment: .topTrailing) { /* soft coral glow */ }
                .overlay(alignment: .bottomLeading) { /* soft sage glow */ }
        }
    }
}
```

**Verification.** `swift build` clean.

## Phase 2 — Register custom fonts (Fraunces + Manrope)

**Status:** Required. ADR-019 scoped this out of the v1 pass for simplicity. In the finish-the-conversion pass, Blake decided to pull it back in — the system fallbacks (`.system(design: .serif)` / `.rounded`) are close, but not the field-journal character the spec intends. Fraunces and Manrope are now canon.

**Files:**
- `GrowWisePackage/Sources/GrowWiseFeature/Resources/Fonts/Fraunces[opsz,wght].ttf`
- `GrowWisePackage/Sources/GrowWiseFeature/Resources/Fonts/Fraunces-Italic[opsz,wght].ttf`
- `GrowWisePackage/Sources/GrowWiseFeature/Resources/Fonts/Manrope[wght].ttf`
- `GrowWisePackage/Sources/GrowWiseFeature/Resources/FontRegistration.swift` (new)
- `GrowWise/Info.plist` (add `UIAppFonts`)
- `GrowWisePackage/Package.swift` (add `.process("Resources")` or keep default bundle behavior — check existing convention)

**Registration bootstrap.** Because these ship via SPM's `Bundle.module`, Info.plist alone is not sufficient — we need to register with CoreText at app launch:

```swift
// Resources/FontRegistration.swift
import CoreText
import Foundation
import os

@MainActor
public enum FontRegistration {
    private static let logger = Logger(subsystem: "com.growwise", category: "FontRegistration")
    private static var registered = false

    public static func registerIfNeeded() {
        guard !registered else { return }
        let names = [
            "Fraunces[opsz,wght]",
            "Fraunces-Italic[opsz,wght]",
            "Manrope[wght]",
        ]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                logger.error("Font missing from bundle: \(name, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                logger.error("Font register failed: \(name, privacy: .public) — \(String(describing: error), privacy: .public)")
            }
        }
        registered = true
    }
}
```

Call `FontRegistration.registerIfNeeded()` as the first line of `GrowWiseApp.init()` (or equivalent root entry).

**Theme consumption.** Add a `Fonts` namespace to `CultivationTheme`:

```swift
public enum Fonts {
    public static var displayAvailable: Bool {
        UIFont(name: "Fraunces-Regular", size: 12) != nil ||
        UIFont(name: "Fraunces_opsz_wght-Regular", size: 12) != nil
    }

    public static func display(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        if displayAvailable {
            let base = italic ? "Fraunces-Italic" : "Fraunces"
            return .custom(base, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif).italic(italic)
    }

    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if UIFont(name: "Manrope-Regular", size: 12) != nil {
            return .custom("Manrope", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}
```

(`.italic(_:)` is a small helper — SwiftUI's `Font.italic()` returns non-italic on custom fonts unless the italic face is registered, so we select the italic PostScript name explicitly when available.)

**Sweep call sites.** Replace `.font(.system(size: N, design: .serif))` with `.font(CultivationTheme.Fonts.display(N))` and the `.rounded` equivalents with `CultivationTheme.Fonts.body(N)`. A fast grep for `design: .serif` and `design: .rounded` finds the call sites.

**Verification.** `swift build`, then run the app; confirm plant names and greeting render in Fraunces, body in Manrope. If the fonts don't appear, the registration failed silently (check the logger output).

## Phase 3 — Sweep dark-era surfaces

From Phase 0's grep output, visit each offender and make a minimal, targeted edit:

| Pattern | Fix |
|---|---|
| `.background(Color.black)` | `.background(CultivationTheme.Colors.background)` (that resolves to paper) |
| `.foregroundColor(.white)` on body text | `.foregroundColor(CultivationTheme.Colors.textPrimary)` (ink) |
| `.foregroundColor(.white)` inside a coral or moss button | keep — it's correct on saturated backgrounds |
| Color literals `Color(hex: "0C0C0C")` | delete; fall through to paper |
| `.ultraThinMaterial` backdrops | remove; use `.paperCard()` |

**Do not globally replace.** Materials inside a coral/moss pill, on the club-card gradient, or on a hero photo overlay *are* correct. The sweep is: every call site, decide visually.

**Verification per file.** `swift build` after each batch of edits. Then visual spot-check in the simulator.

## Phase 4 — Sweep typography

From Phase 0's Audit #4: find views using raw `.font(.system(size:))`, `.font(.title)`, `.font(.largeTitle)`. Each one should either:

1. Use a design-system token (`.system(size: N, weight: W, design: .serif)` or `.rounded` if Phase 2 was skipped; `CultivationTheme.Fonts.display(N)` or `.body(N)` if Phase 2 ran), **or**
2. Be an intentional deviation (rare — flag in the PR).

Greetings, plant names, club names, and screen titles should all be serif / display. Body copy, button labels, meta lines should all be rounded / body.

**Verification.** Simulator screenshot pass. Typography should feel consistent across tabs.

## Phase 5 — Onboarding sweep

**Files:** `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/`

Onboarding is the single highest-visibility screen and is frequently missed in broad sweeps. Expected state:

- Paper background, not dark.
- Serif headings. Rounded body.
- Coral primary CTA, moss "continue" / outlined "skip".
- No `.ultraThinMaterial`, no `.heroBackground()` with dark orbs.
- Accessibility identifiers present on every button.

**Method.** Open each step-view, run through the seven onboarding screens in the simulator, note any visual leftovers, fix.

**Verification.** `--reset-onboarding` launch argument in the scheme to replay onboarding. Confirms the flow renders in v2 tokens end-to-end.

## Phase 6 — Sheets and detail views

**Files:** `Views/Garden/*.swift`, `Views/Community/*.swift`, `Views/PlantDatabase/*.swift`, `Views/Tutorials/*.swift`, `Views/Settings/*.swift`, `Views/AddReminderView.swift`, `Views/AddPlantSheet.swift`.

These are the most-likely untouched surface area. For each file:

1. Confirm it uses `.paperCard()` (or the aliased `.glassCard()`) rather than a hand-rolled background.
2. Confirm text colors come from `CultivationTheme.Colors.*`, not `.white` / `.black`.
3. Confirm headline text uses serif, body uses rounded / Manrope.
4. If the file renders a hero image or colored band, confirm the overlay treatment is cream-compatible (no dark-only assumptions).
5. Every interactive element: `.accessibilityIdentifier(...)`.

**Common offenders to double-check.**

- `AddPlantSheet.swift`, `AddReminderView.swift` — modal sheets that often had a dark backdrop assumption.
- `CreateGardenSheet.swift`, `CreateBedSheet.swift`, `AddSeedSheet.swift` — same.
- `GardenCardView.swift`, `PlantQuickCard.swift` — card surfaces that could have residual gradients.
- `PaywallView.swift` — paywalls often have their own lavish treatment that wasn't the focus of v1.
- `GardenHeroHeader.swift` and `HomeHeroHeader.swift` — heroes were touched in v1 but confirm no stray dark gradient remains.
- `ProfileView.swift` — became the "Me" tab; ensure it reads as v2.

**Verification.** Navigate into each sheet once in the simulator. Take a screenshot. Compare to the wireflow.

## Phase 7 — Plant Detail Share button tone-down

Per the 2026-04-23 spec update.

**File:** `GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift`

**Current state.** Likely a filled coral button with a strong shadow.

**Target state.** An outlined coral button on a faint coral-tinted fill — same weight as "Get advice", sitting below "Log care".

```swift
// Within MyGardenPlantDetailView, replace the Share-to-Club button:
Button {
    presentShareSheet()
} label: {
    HStack(spacing: 8) {
        Text("✦")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(CultivationTheme.Colors.accentCoral)
        Text("Share to \(primaryClubName ?? "your club")")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(CultivationTheme.Colors.accentCoralDeep)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background {
        RoundedRectangle(cornerRadius: 13)
            .fill(CultivationTheme.Colors.accentCoral.opacity(0.06))
    }
    .overlay {
        RoundedRectangle(cornerRadius: 13)
            .stroke(CultivationTheme.Colors.accentCoral, lineWidth: 1.5)
    }
}
.buttonStyle(.plain)
.accessibilityIdentifier("plant_detail_share_to_club_button")
```

If `accentCoralDeep` isn't a theme token yet, add it: `Color(hex: "B14F33")` with a light/dark mode variant if desired.

**Verification.** Screenshot Plant Detail. The Share button should be clearly recognizable as coral/share without overpowering "Log care".

## Phase 8 — Remove stale files

If Phase 0's Audit #6 or #7 found any of these, delete them:

```bash
rm -f GrowWisePackage/Sources/GrowWiseFeature/Views/RemindersListView.swift
rm -rf GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/
```

Then grep once more to confirm no references remain:

```bash
grep -rn "RemindersListView\\|JournalEntryRow\\|JournalEntryDetailView\\|AddJournalEntryView" \
  GrowWisePackage --include="*.swift"
```

If the grep returns anything, fix the caller (likely a navigation destination or a preview) before proceeding.

**Verification.** `swift build` clean. `swift test` (via SSH) — expect failures from previously-existing Reminders/Journal tab tests; note them in the PR.

## Phase 9 — Smart-enrichment tag consistency

**Files:** anywhere the UI shows derived data.

**Goal.** Wherever the app shows something the user didn't enter, render a `✦` sage tag with an uppercase 9pt label. Expected call sites:

- Plant Detail: next to the italic latin name (`Auto-identified`).
- Home's seasonal-tip card (`Seasonal tip · Zone 9b`).
- Plant Detail care-advice card (`Smart suggestion`).
- Club feed smart-match card (`Smart match`).
- Any "auto-scheduled" reminder rows.

**If `SmartTag` doesn't yet exist** as a view, add it to `Design/ViewModifiers.swift`:

```swift
struct SmartTag: View {
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text("✦")
            Text(label)
                .tracking(0.22 * 9)          // 22% letter-spacing
        }
        .font(.system(size: 9, weight: .bold))
        .textCase(.uppercase)
        .foregroundStyle(CultivationTheme.Colors.brandSage)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(CultivationTheme.Colors.brandSage.opacity(0.14))
        }
        .accessibilityLabel("Smart enrichment: \(label)")
    }
}
```

**Verification.** Screenshot sweep. Every derived value reads as "the app is helping" and never as magic.

## Phase 10 — Full verification

```bash
# Fast local compile
cd ~/Projects/GrowWise/GrowWisePackage && swift build

# Lint + format
swiftlint lint --strict --config .swiftlint.yml
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise

# Full app build (on mac-mini)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"

# Package tests
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -30"

# UI tests (requires GUI session on mac-mini)
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -40"
```

**Visual pass (manual, in the simulator).**

1. Launch with `--reset-onboarding --skip-onboarding`. Four tabs render. Coral tint.
2. Home — greeting, weather pill, three tasks, club card, seasonal tip card. Nothing dark.
3. Garden — stats strip, filter chips, bed groups, plant cards. Dashed "+ add bed" footer.
4. Plant Detail — hero photo, healthy badge, 3 stats, Log care + Get advice, toned-down Share button, smart suggestion, journal strip.
5. Club — share prompt, segmented control, post with plant-id pill, smart match card.
6. Me — settings, tutorials, account. Nothing dark.
7. Launch with `--reset-onboarding` (no skip). Onboarding flow is paper, serif, coral CTA.

**Screenshot set.** Drop the 5 canonical screenshots (Home, Garden, Plant Detail, Club, Me) into the PR description so a reviewer can compare to the wireflow at a glance.

## Commit and PR

```bash
git add -A
git commit -m "feat(ui): finish v2 conversion — sweep sheets, typography, Share button"
git push -u origin redesign/v2-simplified-ui
gh pr create --repo jbcrane13/GrowWise --title "Finish v2 UI conversion" --body "$(cat <<'EOF'
## Summary
- Sweeps every downstream view to cream paper (sheets, details, onboarding)
- Tones down the Plant Detail Share-to-Club button to an outlined coral treatment
- Adds SmartTag to every derived-value surface
- Removes stale Reminders/Journal tab files (if any remained)
- (Optional) Registers Fraunces + Manrope via CoreText at launch

## Test plan
- [ ] swift build clean
- [ ] swiftlint --strict clean
- [ ] swift test passes (ignoring deleted Reminders/Journal tab tests)
- [ ] Screenshot pass across all four tabs, onboarding, and major sheets
- [ ] xcodebuild clean on mac-mini
EOF
)"
```

## Open questions — confirm with Blake before starting

1. **"Mark all done" batching.** All visible tasks in one shot, or grouped by care type? Affects `HomeViewModel.markAllDone()` behavior (if it exists) and the copy on the button.
2. **Community/ForumView destination.** Keep as a row inside Me, or retire? Affects Phase 6 scope.
3. **Share button final weight.** The tone-down in Phase 7 is outlined coral on a faint fill. If it reads too quiet in the simulator, the fallback is a filled coral with a softer shadow (half the original). Needs a visual decision in the simulator.

**Decided:**
- **Custom fonts:** yes — Phase 2 is in. Fraunces + Manrope registered via CoreText at launch, selected through `CultivationTheme.Fonts.*` with `.serif` / `.rounded` fallbacks that remain live in case a TTF fails to load.

## Appendix — likely-outdated files to check first

Based on the Phase 0 audit signal, these are the most-likely-missed views in order of visibility:

1. `Views/OnboardingFlow/*.swift` — seven screens, high visibility.
2. `Views/AddPlantSheet.swift`, `Views/AddReminderView.swift`.
3. `Views/Garden/CreateGardenSheet.swift`, `CreateBedSheet.swift`, `AddSeedSheet.swift`, `MovePlantSheet.swift`.
4. `Views/Garden/SeedInventoryView.swift`, `ShoppingListView.swift`, `CompostTrackerView.swift`.
5. `Views/PaywallView.swift`.
6. `Views/Tutorials/*.swift`.
7. `Views/Settings/AppSettingsView.swift`.
8. `Views/PlantDatabase/*.swift`.
9. `Views/Community/*.swift`.
10. `Components/PerenualEnrichmentCard.swift`, `SuggestedSeedsCard.swift`, `ReadyToPlantCard.swift`.

Hit this list in order and the screenshot pass at Phase 10 should come back clean.
