# Cultivation — Full UI Redesign

**Date:** 2026-03-09
**Status:** Approved

## Vision

Reimagine the entire Cultivation (GrowWise) app with a premium, garden-centric design. The Garden tab is the hero — a grouped list of plants organized by bed/area with care status surfaced inline. Every screen follows a "Clean Minimal + Premium" design language: dark surfaces, glass-morphism cards, Apple system colors, botanical green accents, and SF Pro Rounded headlines.

## Design Language

### Foundation: Clean Minimal + 6 Premium Elevations

1. **Botanical accent gradient** — CTAs and selected states use a forest→leaf green gradient (`#2d6a4f` → `#52b788`), not flat green.
2. **Elevated card surfaces** — Dark mode cards use `rgba(255,255,255,0.04)` with `backdrop-filter: blur(12px)` and `1px solid rgba(255,255,255,0.08)` border. Light mode: white with subtle shadow.
3. **SF Pro Rounded headlines** — `.fontDesign(.rounded)` on all headlines and stat numbers. Body text stays default SF Pro.
4. **Signature hero moments** — Home and Garden headers use a near-black background (`#0c0c0c`) with a subtle green glow orb, not a green gradient wash.
5. **Spring animations** — Custom `.spring(duration:bounce:)` on card taps, tab switches, selection changes. No stock linear animations.
6. **Tinted icon backgrounds** — Key icons sit inside rounded-rect containers with 10-12% opacity tint of their semantic color.

### Color Palette

| Token | Hex | Usage |
|---|---|---|
| `background` | `#0c0c0c` | App background (dark) |
| `cardSurface` | `rgba(255,255,255,0.04)` + blur | Card/row backgrounds |
| `cardBorder` | `rgba(255,255,255,0.08)` | Card borders |
| `textPrimary` | `#E5E5E5` | Primary text |
| `textSecondary` | `rgba(255,255,255,0.4)` | Secondary/subtitle text |
| `sectionLabel` | `#666666` | Section headers (uppercase) |
| `accentGreen` | `#30D158` | Healthy status, positive states (Apple system green) |
| `accentYellow` | `#FFD60A` | Warning/due-soon states (Apple system yellow) |
| `accentRed` | `#FF453A` | Overdue/alert states (Apple system red) |
| `brandForest` | `#2d6a4f` | Gradient start for CTAs |
| `brandLeaf` | `#52b788` | Gradient end for CTAs |
| `heroGlow` | `rgba(76,175,80,0.08)` | Subtle green glow orb in hero sections |
| `botanicalMint` | `#B7E4C7` | Light accents (onboarding, light mode) |
| `botanicalCream` | `#F5F0E8` | Light mode backgrounds |
| `botanicalGold` | `#E9C46A` | Warm accent (achievements, seasonal tips) |

Light mode inverts: `background` → `#FAFAF8`, `cardSurface` → white + `shadow(0 1px 3px rgba(0,0,0,0.06))`, text colors flip to dark equivalents.

### Typography

- Headlines: SF Pro Rounded (`.fontDesign(.rounded)`), bold weight
- Body: SF Pro (system default)
- Stats/numbers: SF Pro Rounded, bold
- Section labels: system font, 11pt, uppercase, `letterSpacing: 1`, color `#666`

### Corner Radii

- Cards/rows: 14px
- Icon containers: 10-12px
- Pill/chips: capsule (full round)
- Stat cards: 14px
- Buttons: 14-16px

## Navigation — 4 Tabs

Consolidated from 7 tabs down to 4. Each has one clear job.

### Tab Bar

| Tab | Icon | Job | Absorbed From |
|---|---|---|---|
| Home | `house.fill` | "What needs doing today?" | Weather, Quick Actions |
| Garden | `leaf.fill` | "Where is everything, how do I care for it?" | My Garden, Plant Guide, Garden Layout, Scanner |
| Journal | `book.fill` | "What happened, how is it growing?" | — |
| Profile | `person.fill` | "Settings, learning, account" | Learn/Tutorials, Reminder Settings, Subscription |

## Screen Designs

### 1. Home Tab

**Purpose:** Task-focused morning check-in across ALL gardens.

**Layout:**
- **Hero header** (signature dark bg + green glow orb):
  - Greeting ("Good morning") + user name
  - Glass weather pill (top-right): icon, temp, suitability note
- **Summary counters** (3 glass stat cards in a row):
  - Overdue count (red `#FF453A`)
  - Due Today count (yellow `#FFD60A`)
  - All Good count (green `#30D158`)
- **Task list** (scrollable, grouped by urgency):
  - "OVERDUE" section label (red) → task rows with red tint
  - "DUE TODAY" section label (yellow) → task rows
  - Each row: plant icon bubble + task description + garden/bed location + one-tap complete button (gradient on overdue, outline on others)
- **Seasonal tip card** (bottom, shown when no urgent tasks or always):
  - Tinted icon bubble + "Seasonal Tip" label + contextual advice based on zone/date
- **Empty state** (all tasks done): Celebration message, "Your garden is thriving" + next upcoming task preview

**Interactions:**
- Tap complete button → marks task done with spring animation, row slides away
- Tap task row → navigates to that plant in the Garden tab
- Pull to refresh

### 2. Garden Tab (Hero Screen)

**Purpose:** Visual overview of everything planted, organized by physical location, with care status inline.

**Layout:**
- **Hero header** (signature dark bg + green glow orb):
  - "My Garden" label + current garden name (large, rounded bold)
  - Search button + Add button (gradient)
  - Garden switcher pills (horizontal scroll)
  - Quick summary strip: plant count, needs-water count, alert count
- **Grouped plant list** (primary view, scrollable):
  - **Group header**: icon bubble + bed/area name + dimensions/location + plant count + `⋯` overflow menu
  - **Plant rows** (glass cards): icon bubble (tinted by status) + name + next care action + sun requirement + status dot (green/yellow/red)
  - Overdue plants surface to top of their group with red tint and inline action button
  - **Companion tip** (inline under relevant group): `💡` icon + contextual planting advice
  - **"+ Add Bed or Area"** button at bottom (dashed border)
- **Layout mode** (optional, accessible from toolbar or group `⋯` menu):
  - Spatial grid view for garden bed planning
  - Not in the primary flow — used for planning sessions

**Plant Quick Card (bottom sheet on tap):**
- Drag handle
- Plant header: icon bubble + name + location + planted date + status dot
- Quick stats row (3 glass cards): Water countdown, Sun requirement, Health rating
- Quick action buttons row: Water (gradient), Prune, Log, Guide
- "View Full Details →" link

**Plant Detail View (full push):**
- Hero section with photo (or gradient placeholder)
- Care requirements section
- Photo gallery
- Journal entries for this plant
- Reminders list
- Care history timeline
- Edit/delete actions

**Add Plant flow:**
- Sheet with built-in plant database search
- Contextual suggestions: "What grows well in Zone 7b", "Good companions for Tomato"
- Garden/bed selector
- Customization fields (location, planting date, notes)

**Intelligence features (contextual, not separate screens):**
- Companion planting tips appear inline under bed groups
- "What to plant" suggestions appear in Add Plant flow based on zone, season, existing plants
- Plant scanner accessible from Add Plant or plant detail

### 3. Journal Tab

**Purpose:** Timeline of garden activity — what happened and growth progress.

**Layout:**
- **Header**: "Journal" title (large rounded bold) + search button + add button (gradient)
- **Filter pills** (horizontal scroll): All, Watering, Photos, Notes, Harvested
- **Timeline** (grouped by date):
  - Date headers: "TODAY", "YESTERDAY", "MAR 7" etc.
  - Entry cards (glass):
    - Plant icon bubble + plant name + time + action type
    - Optional photo (rounded, inline)
    - Optional notes text
  - Simple log entries (no photo/notes): compact single-line format

**Add Entry (sheet):**
- Photo-first: camera/gallery picker prominent
- Plant selector
- Entry type selector
- Notes field
- Weather auto-captured

### 4. Profile Tab

**Purpose:** User identity, learning, settings, subscription.

**Layout:**
- **User card**: Avatar circle (initial + gradient) + name + skill level + zone
- **Stats row**: Plants count, Day streak, Journal entries
- **Learning section**: Tutorials (with progress), Achievements
- **Settings section**: Notifications, Subscription, App Settings
- Grouped menu rows with tinted icon bubbles

### 5. Onboarding (Already Redesigned)

Keep the botanical biophilic onboarding from the earlier commit. Update its color tokens to use the refined palette (Apple system colors for status, darker backgrounds where applicable). The onboarding's warm cream/forest-green aesthetic serves as the "first impression" that transitions into the darker app chrome.

## Component Library

### Shared Components to Build

| Component | Usage | Notes |
|---|---|---|
| `GlassCard` | Every card/row surface | Modifier that applies glass bg + border + corner radius |
| `HeroHeader` | Home, Garden tab headers | Dark bg + glow orb + content slot |
| `IconBubble` | Plant icons, action icons | Rounded rect with tinted bg, accepts SF Symbol + color |
| `StatusDot` | Plant health indicators | 6px circle, color from status enum |
| `GradientButton` | Primary CTAs | Forest→leaf gradient, white text |
| `GlassPill` | Garden switcher, filter pills | Glass bg for active, outline for inactive |
| `TaskRow` | Home tab task items | Icon bubble + text + location + complete button |
| `PlantRow` | Garden tab plant items | Icon bubble + name + care info + status dot |
| `GroupHeader` | Garden bed/area headers | Icon bubble + title + subtitle + overflow menu |
| `SectionLabel` | "OVERDUE", "DUE TODAY" etc. | 11pt, uppercase, colored, letter-spaced |
| `CompanionTip` | Inline planting advice | Small card with 💡 icon + tip text |
| `QuickStatCard` | Summary counters | Glass card with large number + label |

### Existing Components to Restyle

All existing components get the new design language applied:
- `PlantCardView` → becomes `PlantRow` (simplified)
- `WelcomeSection` → absorbed into `HeroHeader`
- `StatsSection` → becomes `QuickStatCard` row
- `WeatherSection` → becomes glass pill in hero header
- `QuickActionsSection` → removed (actions are contextual now)
- `ReminderRowView` → becomes `TaskRow`
- `CompactReminderRow` → becomes `TaskRow` compact variant
- `SearchBarView` → restyled with glass treatment
- `ErrorView` → restyled

## Data Model Impact

No model changes required. The redesign is purely UI — same `Garden`, `Plant`, `PlantReminder`, `JournalEntry` models. The grouped list uses existing `Garden` → `Plant` relationships. Bed/area grouping uses existing `GardenBed` data.

## Files to Create/Modify

### New Files
- `Design/CultivationTheme.swift` — Design tokens, glass modifiers, shared styles
- `Components/GlassCard.swift` — Glass surface modifier
- `Components/HeroHeader.swift` — Signature hero header
- `Components/IconBubble.swift` — Tinted icon container
- `Components/StatusDot.swift` — Health status indicator
- `Components/GradientButton.swift` — Primary CTA button style
- `Components/GlassPill.swift` — Filter/switcher pill
- `Components/TaskRow.swift` — Home tab task row
- `Components/PlantRow.swift` — Garden tab plant row
- `Components/GroupHeader.swift` — Bed/area section header
- `Components/SectionLabel.swift` — Uppercase section label
- `Components/CompanionTip.swift` — Inline planting tip
- `Components/QuickStatCard.swift` — Summary stat card

### Major Rewrites
- `MainAppView.swift` — 4-tab navigation, remove 3 tabs
- `HomeView.swift` — Complete rewrite as task-focused dashboard
- `MyGardenView.swift` — Complete rewrite as grouped plant list
- `PlantDetailView.swift` (was `MyGardenPlantDetailView.swift`) — Restyle with new design language
- `ProfileView.swift` — Rewrite with grouped settings menu

### Restyle Only
- `JournalView.swift` — Apply glass cards, new typography, filter pills
- `JournalEntryRow.swift` — Glass card treatment
- `JournalEntryDetailView.swift` — Restyle
- `AddJournalEntryView.swift` — Restyle form
- `AddPlantSheet.swift` — Restyle, add plant database search inline
- `AddReminderView.swift` — Restyle
- `ReminderSettingsView.swift` — Moves to Profile sub-view, restyle
- `PlantReminderDetailView.swift` — Restyle
- `RemindersListView.swift` — Likely absorbed into Home tab, restyle if kept
- `ErrorView.swift` — Restyle

### Remove/Deprecate
- `TutorialsView.swift` — Absorbed into Profile
- `PlantDatabaseView.swift` — Absorbed into Garden's Add Plant flow
- `PlantScannerView.swift` — Absorbed into Garden (toolbar action or plant detail)
- `GardenLayoutView.swift` — Kept but demoted to optional planning mode
- `QuickActionsSection.swift` — Actions are contextual now
- `WelcomeSection.swift` — Absorbed into HeroHeader
- `WeatherSection.swift` — Absorbed into HeroHeader glass pill
- `DatabasePlantRowView.swift` — Replaced by PlantRow
- `DatabasePlantCustomizationSheet.swift` — Merged into AddPlantSheet
- `PlantDatabaseAddToGardenSheet.swift` — Merged into AddPlantSheet
- `ReminderManagementView.swift` — Absorbed into Home tab

### Update
- `Color+Theme.swift` — Add new design tokens, keep backward compat during migration
- `OnboardingFlow/*` — Minor token updates to align alert colors

## Implementation Phases

### Phase 1: Design Foundation
Build the component library and theme system. No visible app changes yet.
- `CultivationTheme.swift` (all tokens)
- All shared components (GlassCard, HeroHeader, IconBubble, etc.)
- Updated `Color+Theme.swift`

### Phase 2: Navigation Restructure
Switch to 4-tab navigation. Stub out new screen structures.
- `MainAppView.swift` rewrite (4 tabs)
- Stub Home, Garden, Journal, Profile views

### Phase 3: Garden Tab (Hero Screen)
Build the most important screen first.
- Grouped plant list with bed sections
- Plant rows with care status
- Group headers with overflow menu
- Plant quick card (bottom sheet)
- Garden switcher
- Companion tips inline

### Phase 4: Home Tab
Task-focused dashboard.
- Hero header with weather pill
- Summary stat counters
- Task list grouped by urgency
- One-tap complete actions
- Seasonal tips

### Phase 5: Journal & Profile
Restyle existing screens.
- Journal timeline with glass cards and filter pills
- Profile with user card, stats, grouped settings menu
- Tutorials moved into Profile

### Phase 6: Detail Views & Sheets
Restyle all secondary screens.
- Plant detail view
- Add plant sheet (with inline database search)
- Add reminder sheet
- Journal entry detail
- Reminder settings (in Profile)

### Phase 7: Polish & Cleanup
- Remove deprecated files
- Animation polish pass
- Light mode verification
- Accessibility audit
- Clean up old color tokens
