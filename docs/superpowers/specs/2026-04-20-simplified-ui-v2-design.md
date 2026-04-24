# Cultivation — Simplified UI v2 · Design Spec

**Date:** 2026-04-20 (updated 2026-04-23 — Plant Detail Share button toned down)
**Status:** Active. See `ADR-019` for the decision record.
**Supersedes (partially):** `2026-03-09-full-ui-redesign-design.md` — the Botanical Field Journal *direction* (serif, warm earth tones, coral accents) stays. The *surface* — dark glass-morphism — does not.
**Visual reference:** `docs/mockups/cultivation-simplified-wireflow.html`

## Vision

The current build does too much asking. The user is asked to identify a plant, configure reminders, set a hardiness zone, opt into weather, decide what counts as urgent. Each ask is a chance to drop off — especially for the 50+ enthusiast audience the app serves.

V2 reverses that. The app does the work in the background — identification, weather, scheduling, zone-aware tips — and surfaces results as plain language. The user only has to look, tap, or share. **Garden Club is promoted to the second pillar of the app**: every screen has one obvious way to share what they're growing.

The field journal *character* is preserved (serif headlines, warm earth tones, coral accents). The *medium* shifts from dark glass-morphism to cream paper — better for the audience's eyes, more literal to the field-journal metaphor, and considerably less "tech" in feel.

## Three principles

1. **Smart enrichment is invisible.** Weather, plant ID, zone, reminders — all derived. The user never sees a setup screen for any of it. Where derivation might surprise the user, mark with a small `✦` tag (`Auto-identified`, `Smart suggestion`, `Smart match`, `Seasonal tip · Zone 9b`).
2. **One screen, one job.** Each screen answers exactly one question. Detail is reachable, not in the way.
3. **Sharing is built in, not bolted on.** A club activity card on Home, a Share action on every Plant Detail, and a Club tab that opens with a one-tap photo prompt at the top.

## Navigation — 5 tabs to 4

| Tab | Job | Absorbed from |
|---|---|---|
| Home | "What needs doing today?" | Reminders (folded in) |
| Garden | "Where is everything?" | — |
| **Club** *(new)* | "What's the club up to?" | Community + GardenClub entry points |
| Me | Settings, learning, account | Profile |

**Removed as tabs:** Reminders (its rows already live on Home), Journal (becomes a photo strip on Plant Detail).

## Design language

### Foundation — cream paper field journal

1. **Cream paper background.** `#F6F0E4` with a faint multiply grain. Replaces the dark `#0C0C0C` surface.
2. **Card surfaces.** `#FFFDF7` with a 1px hairline border (`rgba(31, 42, 34, 0.08)`) and a soft warm shadow. No glass-morphism.
3. **Tactile depth, not glass.** `0 8px 24px -12px rgba(31, 42, 34, 0.18)` shadows on cards. Paper grain overlay on the app background.
4. **Coral as the commit color.** `#D9694B` for primary CTAs and the Share action. Deep moss `#2E4631` for "Mark all done" / "Log care" buttons.
5. **Sage as the auto-enrichment color.** Smart enrichment cards use a dashed sage border + a sage `✦` label. Reads as "the app is helping" without being noisy.
6. **No heavy materials.** `.ultraThinMaterial`, opaque blur backdrops, and dark-over-dark stacks should not appear in any new view.

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
| `sage` | `#7B9069` | Healthy status, smart-enrichment accents |
| `sageDeep` | `#4F6B49` | Sage-on-cream label color |
| `moss` | `#2E4631` | Primary commit buttons |
| `coral` | `#D9694B` | Primary action color |
| `coralDeep` | `#B14F33` | Coral-on-cream label color |
| `honey` | `#C99327` | Warning / due-soon states |
| `sky` | `#6F94A6` | Watering icon tint |

**Dark mode** (system-driven only, no in-app setting): `paper → #181816`, `card → #232220`, `ink → #EAE2D2`. Coral, sage, honey, sky retain saturation. Dark mode is a courtesy, not the primary direction.

### Typography

- **Display / headlines:** Fraunces (variable, opt-size aware). Italic available for emphasis. 28–68pt depending on context.
- **UI / body:** Manrope. 14pt body, 16pt comfortable body, 18pt buttons.
- **Section labels:** 10–11pt, uppercase, `letter-spacing: 0.16em–0.22em`, color `inkQuiet` (or `sageDeep` above smart-enrichment).
- **Stat numbers:** Fraunces 600.

**Registration.** Fraunces and Manrope ship as variable TTFs inside the SPM resources bundle, registered with CoreText at launch (see implementation plan, Phase 2). `.system(design: .serif)` and `.system(design: .rounded)` stay wired as fallbacks in case a TTF fails to load on-device, but the intent is the real fonts.

*Rationale.* Fraunces is warm, opt-size-aware, and reads as a field journal rather than a dashboard. Manrope is humanist and warmer than Inter, and stays legible at body sizes for older eyes. v1 of the redesign deliberately used the system serif/rounded fallbacks to keep scope tight; v2 brings the real fonts back in.

### Corner radii

| Element | Radius |
|---|---|
| Cards | 16pt |
| Plant cards | 14pt |
| Icon containers | 10–12pt |
| Pills / chips | 999pt (capsule) |
| Primary buttons | 14pt |

## Screens

### 1. Home — "What needs doing today?"

- Greeting block: section label with today's date; large serif "Good morning, **Blake.**" with the name italicized in coral.
- Auto weather pill (`☀ 72° · Good day to water`) — derived from `LocationService` + `WeatherKit`. Sage-tinted capsule.
- **Today's care card** — max 3 visible tasks. Coral check on the top-priority overdue row. "Mark all done" moss button at the bottom.
- **Your Club card** — coral/honey gradient banner with club name, latest member post (avatar, photo, caption, `♥`/`💬`/`↗` row). Navigates to the Club tab when tapped.
- **Seasonal tip card** — `paperDeep` background, dashed sage border, `✦ Seasonal tip · Zone 9b` label, italic serif body.

### 2. Garden — "Where is everything?"

- Section label "My Garden", large serif garden name (italic second word).
- Summary strip: plant count / needs care / blooming.
- Filter chips: All (active = moss), Needs care (coral dot), Blooming, Edible, Herbs.
- Bed group headers (icon bubble + name + plant count + part-sun / full-sun meta).
- Plant cards — 42–56pt thumbnail (gradient placeholder until photo is added), serif plant name, latin italic, status dot + status text, `Next care: ___` line.
- Dashed `+ Add a bed or area` footer.

### 3. Plant Detail — "How is this plant?"

- Hero photo block (180pt) with a "Healthy" badge top-right.
- Serif plant name, italic latin name with an `✦ Auto-identified` sage tag.
- Three stat cards in a row: Sun · Water · Soil.
- Two-button row: **Log care** (moss) + **Get advice** (paper outlined).
- **Share to [Club name]** — **outlined coral** button on a faint coral-tinted fill, with an `✦` prefix.

  *Note: earlier versions of this spec called for a solid coral button. Toned down on 2026-04-23 so it reads at roughly the same weight as "Get advice" and does not compete with the "Log care" commit button.*

- "Care advice for today" sage-bordered smart suggestion card with an italic serif quote.
- Photo journal strip — 4 dated thumbnails + a dashed `+` add cell.

### 4. Garden Club — "What's the club up to?"

- "Your club" eyebrow + large serif club name (italic accent on second word).
- Member count, top-right.
- **Coral share prompt** — `[avatar] Share what's growing, Blake. [📷]`. One tap to camera. This is the view's entry point — never a cold "create post" screen.
- Feed segmented control: Club feed · Nearby · Following.
- Post cards — avatar + name + zone tag (`Zone 9b · 2 mi away`), caption with a serif italic emphasis, photo with an auto-tagged meta pill (plant ID + size), `♥`/`💬`/`↗` row.
- **Smart match card** — dashed sage border: "`✦ Smart match` — **3 people in your zone** are growing Cherokee Purple too. Want to see their tips?"

## What is removed

### Tab bar
- **Reminders tab** — its rows already live on Home's Today's-care card.
- **Journal tab** — journal entries render as a photo strip on Plant Detail.

### Files (if still present after the v1 pass)
- `Views/RemindersListView.swift`
- `Views/Journal/JournalView.swift`, `JournalEntryRow.swift`, `JournalEntryDetailView.swift`, `AddJournalEntryView.swift`

### What stays
- `JournalEntry` model — attached to plants, rendered as thumbnails.
- `ReminderService` and `PlantReminder` — used by Home's task card.
- `Views/Community/ForumView.swift` — reachable from the Me tab, not surfaced via a tab of its own.
- `AddReminderView.swift`, `PlantReminderDetailView.swift` — reached from Plant Detail, not from a Reminders tab.

## Smart enrichment markers

A reusable `SmartTag` view: rounded sage chip with `✦` prefix and an uppercase 9pt label. Used wherever the app derived a value the user did not enter: `Auto-identified`, `Smart suggestion`, `Smart match`, `Seasonal tip · Zone 9b`, `Auto-scheduled`.

## What "done" looks like

- `swift build` clean.
- `xcodebuild` clean on mac-mini.
- `swift test` passes (Reminders/Journal tab tests are deliberately deleted; note in the PR).
- `swiftlint --strict` and `swiftformat --lint` clean.
- A screenshot sweep across all four tabs, the major sheets, onboarding, and settings returns no dark surfaces, no `.foregroundColor(.white)` on cream, and no untouched system-default typography.
- A screenshot pair (Home, Garden, Plant Detail, Club) that matches the wireflow.

## Open questions

1. **"Mark all done" batching.** Does it trigger completion for *all* visible tasks, or only those a single tap can sensibly batch (e.g. all watering tasks)? Proposed: batch by care type to avoid logging "fed" when the user only watered. Needs a product decision before we touch `HomeViewModel`.
2. **Community/ForumView destination.** Proposed: keep reachable from the Me tab as a list row. Alternative: retire it entirely and consider Club the only social surface. Blake's call.
3. **Plant Detail Share affordance.** Now outlined coral. If this reads as *too* quiet in the simulator after implementation, the fallback is a filled coral button with a softer shadow (halfway between the original and the current).

**Decided:**
- **Custom font registration.** Yes — Fraunces + Manrope ship inside the SPM resources bundle and register with CoreText at launch. System `.serif` / `.rounded` remain wired as fallbacks.
