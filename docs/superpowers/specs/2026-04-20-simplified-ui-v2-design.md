# Cultivation — Simplified UI v2

**Date:** 2026-04-20
**Status:** In progress
**Supersedes (partially):** 2026-03-09 Full UI Redesign — Botanical Field Journal direction stays, dark glass-morphism does not.

## Vision

The current build does too much *asking*. The user is asked to identify a plant, configure reminders, set a hardiness zone, opt into weather, decide what counts as urgent. Each ask is a chance to drop off — especially for the 50+ enthusiast audience the app is meant to serve.

V2 reverses that. The app does the work in the background — identification, weather, scheduling, zone-aware tips — and surfaces results as plain language. The user only has to look, tap, or share. **Garden Club is promoted to the second pillar of the app**: every screen has one obvious way to share what they're growing.

The Botanical Field Journal *character* is preserved (serif headlines, warm earth tones, coral accents). The *medium* shifts from dark glass-morphism to cream paper — better for the audience's eyes, more literal to the field-journal metaphor, and considerably less "tech" in feel.

## Three principles

1. **Smart enrichment is invisible.** Weather, plant ID, zone, reminders — all derived. The user never sees a setup screen for any of it. Where derivation might surprise the user, mark with a small `✦` tag (`Auto-identified`, `Smart suggestion`).
2. **One screen, one job.** Each screen answers exactly one question. Detail is reachable, not in the way.
3. **Sharing is built in, not bolted on.** Activity card on Home, Share button on every plant, and the Club tab opens with a one-tap photo prompt at top.

## Navigation — 5 tabs → 4

| Tab | Job | Absorbed from |
|---|---|---|
| Home | "What needs doing today?" | Reminders (folded in) |
| Garden | "Where is everything?" | — |
| **Club** *(new)* | "What's the club up to?" | Community + GardenClub entry points |
| Me | "Settings, learning, account" | — |

**Removed as tabs:** Reminders (its rows already live on Home), Journal (becomes a photo strip on Plant Detail).

## Design language

### Foundation: Cream paper field journal

1. **Cream paper background** — `#F6F0E4` with a faint multiply grain. Replaces `#0C0C0C` dark.
2. **Card surfaces** — `#FFFDF7` with a 1px hairline border (`rgba(31,42,34,0.08)`) and a soft warm shadow. No glass-morphism.
3. **Fraunces + Manrope** — Fraunces (variable serif) for headlines and plant names; Manrope for body and UI. Falls back to SF Pro Rounded / SF Pro if registration fails.
4. **Coral as the action color** — `#D9694B` for primary CTAs and the Share button. Deep moss `#2E4631` for "Mark all done" / commit-style buttons.
5. **Sage as the auto-enrichment color** — Smart enrichment cards use a dashed sage border + sage label. Reads as "the app is helping" without being noisy.
6. **Tactile depth, not glass** — Soft shadows on cards (`0 8px 24px -12px rgba(31,42,34,0.18)`). Paper texture overlay on the app background.

### Color palette

| Token | Hex | Usage |
|---|---|---|
| `paper` | `#F6F0E4` | App background |
| `paperDeep` | `#EFE6D3` | Recessed surfaces, smart-enrichment cards |
| `card` | `#FFFDF7` | Card surfaces |
| `ink` | `#1F2A22` | Primary text |
| `inkSoft` | `#3F4A40` | Body text |
| `inkQuiet` | `#6E7368` | Secondary / meta text |
| `line` | `#D9CFB8` | Dividers, dashed borders |
| `lineSoft` | `rgba(31,42,34,0.08)` | Card hairlines |
| `sage` | `#7B9069` | Healthy status, smart enrichment |
| `sageDeep` | `#4F6B49` | Sage-on-cream label color |
| `moss` | `#2E4631` | Primary commit buttons, brand depth |
| `coral` | `#D9694B` | Primary action color, Share CTA |
| `coralDeep` | `#B14F33` | Coral on cream label color |
| `honey` | `#C99327` | Warning/due-soon states |
| `sky` | `#6F94A6` | Watering icon tint |

**Dark mode** (system-driven only, no setting): `paper → #181816`, `card → #232220`, `ink → #EAE2D2`. Coral, sage, honey, sky retain saturation. Dark mode is a courtesy, not the primary direction.

### Typography

- **Display / headlines:** Fraunces (variable, opt-size aware). Italic available for emphasis. 28–68pt depending on context.
- **UI / body:** Manrope. 14pt body, 16pt comfortable body, 18pt buttons.
- **Section labels:** Manrope, 10–11pt, uppercase, `letter-spacing: 0.16em`, color `inkQuiet`.
- **Stat numbers:** Fraunces 600.

Rationale: Fraunces is warm, opt-size-aware, and feels like a real letterpress field journal. Manrope is clean and humanist (warmer than Inter), and reads well at body sizes for older eyes.

### Corner radii

| Element | Radius |
|---|---|
| Cards | 16px |
| Plant cards / phone screens | 14px |
| Icon containers | 10–12px |
| Pills / chips | 999px (capsule) |
| Primary buttons | 14px |

## Screens

### 1. Home — "What needs doing today?"

- Greeting block: section label (date), large Fraunces "Good morning, **Blake.**" with the name italicized + coral
- Auto weather pill (`72° · Good day to water`) — derived from CLLocation + WeatherKit
- **Today's care card** — max 3 visible tasks, with a coral check on the top-priority overdue row, and a "Mark all done" moss button at the bottom
- **Your Club card** — coral/honey gradient banner with club name, latest member post (avatar + photo + caption + ♥/💬/↗ actions)
- **Seasonal tip card** — paperDeep background, dashed sage border, "✦ Seasonal tip · Zone 9b" label, italic Fraunces body

### 2. Garden — "Where is everything?"

- Section label "My Garden", large Fraunces garden name
- Summary strip: plant count / needs care / blooming
- Filter chips: All (active = moss), Needs care (coral dot), Blooming, Edible, Herbs
- Bed group headers (icon bubble + name + plant count)
- Plant cards — 56px thumbnail (gradient placeholder until photo is added), Fraunces plant name, latin italic, status dot + status text, "Next care: ___" line
- Dashed "+ Add a bed or area" footer

### 3. Plant Detail — "How is this plant?"

- Hero photo block (180pt) with "Healthy" badge top-right
- Fraunces plant name, italic latin name with `Auto-identified` sage tag
- 3 stat cards in a row: Sun · Water · Soil
- Two-button row: **Log care** (moss) + **Get advice** (paper outlined)
- **Share to [Club name]** — full-width coral button with `✦` prefix
- "Care advice for today" sage-bordered smart suggestion card with italic quote
- Photo journal strip — 4 dated thumbnails + dashed `+` add cell

### 4. Garden Club — "What's the club up to?"

- "Your club" eyebrow + large Fraunces club name (italic accent on second word)
- Member count top-right
- **Coral share prompt** — `[avatar] Share what's growing, Blake. [📷]` — one tap to camera
- Feed segmented control: Club feed · Nearby · Following
- Post cards — avatar + name + zone tag (`Zone 9b · 2 mi away`) + caption with a Fraunces italic emphasis, photo with a meta pill (plant ID/size auto-tagged), ♥/💬/↗ action row
- **Smart match card** — dashed sage border: "3 people in **your zone** are growing Cherokee Purple too. Want to see their tips?"

## Implementation plan

### Files to rewrite

- `Design/CultivationTheme.swift` — replace token set
- `Design/ViewModifiers.swift` — `.glassCard()` becomes `.paperCard()`; remove blur backdrops
- `Design/GardenComponents.swift` — restyle PlantRow, BedGroupHeader, TaskRow, CompanionTipCard
- `Main/MainAppView.swift` — 5 → 4 tabs; new Club tab; coral tint
- `Views/HomeView.swift` + `Views/Home/HomeHeroHeader.swift` + `Views/Home/SeasonalTipCard.swift` + `Views/Home/GardenHealthCardView.swift` — rebuild as cream-paper, club card inserted
- `Views/Home/HomeViewModel.swift` — add latest-club-post assembly, no other behavior change
- `Views/GardenView.swift` — rebuild; remove glass background
- `Views/Garden/GardenViewModel.swift` — keep, possibly add bloom-state filter helper
- `Views/MyGardenPlantDetailView.swift` — rebuild around the 3-stat + smart advice + journal-strip pattern; add Share button
- *New:* `Views/GardenClub/GardenClubFeedView.swift` — entry point for the Club tab

### Files to delete

- `Views/RemindersListView.swift`
- `Views/Journal/JournalView.swift`, `JournalEntryRow.swift`, `JournalEntryDetailView.swift`, `AddJournalEntryView.swift`

(Models stay: `JournalEntry` is still attached to plants and rendered as a photo strip on Plant Detail.)

### Font registration

- Add `Fraunces[opsz,wght].ttf` and `Manrope[wght].ttf` (variable fonts) to `GrowWise/Resources/Fonts/`
- Register in `Info.plist` `UIAppFonts`
- `CultivationTheme.Fonts.display(_ size: CGFloat)` returns Fraunces with system fallback
- `CultivationTheme.Fonts.body(_ size: CGFloat)` returns Manrope with system fallback

### Smart enrichment markers

A reusable `SmartTag` view: rounded sage chip with `✦` prefix and uppercase 9pt label. Used wherever the app derived a value the user didn't enter (`Auto-identified`, `Smart suggestion`, `Smart match`).

## What "done" looks like

- `swift build` clean
- `xcodebuild` clean on mac-mini
- `swift test` passes (with deliberate deletions of Reminders/Journal tab tests, documented)
- `swiftlint --strict` and `swiftformat --lint` clean
- Code-review skill returns no FAILs on MV / Swift 6 / SwiftData / force-unwrap / print
- The app boots into Home, all four tabs render, plant detail renders, Club tab renders with at least seeded sample data
- An `ADR-019` entry committed describing the pivot

## Open questions

- Does Fraunces variable include all the opsz weights we want at iOS sizes? If file size is an issue, fall back to two static weights.
- Where does the existing `Community/ForumView.swift` flow go? Proposed: keep accessible from "Me" but no longer surfaced via a tab — Club replaces it as the social entry point.
- Should "Mark all done" trigger reminders for all visible tasks, or only the ones a single tap can sensibly batch (e.g. all watering tasks)? Proposed: batch by care type to avoid logging "fed" when the user only watered.
