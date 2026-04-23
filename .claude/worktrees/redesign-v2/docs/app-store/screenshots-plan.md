# GrowWise — App Store Screenshots Plan

## Overview
Generate 10 screenshots per device size (iPhone, iPad) covering core flows and features.

## Device Sizes Required
| Device | Display | Size | Notes |
|--------|---------|------|-------|
| iPhone 17 Pro Max | 6.9" | 1320 x 2868 px | Required |
| iPhone 17 Pro | 6.3" | 1206 x 2622 px | Required |
| iPad Pro 13" | 13" | 2048 x 2732 px | Recommended |

---

## Screenshot List (10 per device)

### 1. Home Dashboard — Care Tasks
**Feature**: Overdue and due-today reminders with one-tap completion
**Frame**: Home screen showing:
- Hero greeting with stat cards (plants, alerts)
- Overdue task section (red accent)
- Due today section (orange accent)
- Seasonal tip card
- "Ready to Plant" seed inventory card (if applicable)
**Caption**: "Never miss a watering or fertilizing task"

### 2. Plant Detail — Growth Journey
**Feature**: Detailed plant care with photo timeline
**Frame**: Plant detail view showing:
- Plant hero image
- Health status badge
- Last care dates (watered, fertilized, pruned)
- Journal entries with photos
- Quick action buttons (Water, Fertilize, Prune, Log)
**Caption**: "Track every plant's journey from seed to harvest"

### 3. Add Plant — Quick Entry
**Feature**: Streamlined plant addition with suggestions
**Frame**: Add plant sheet showing:
- Search bar with plant name
- Plant type picker (vegetable, herb, fruit, flower)
- Garden assignment dropdown
- Quick-add suggestions based on seasonal timing
**Caption**: "Add plants in seconds"

### 4. Garden Overview — Bed Management
**Feature**: Visual garden layout with beds
**Frame**: Garden detail view showing:
- Bed sections with plant counts
- Companion planting tips between rows
- Suggested seeds for each bed (SuggestedSeedsCard)
- Stats strip (plants, beds, alerts)
**Caption**: "Organize beds and see compatible plants"

### 5. Seed Inventory — Packet Scanner
**Feature**: OCR seed packet scanning
**Frame**: Seed scanner camera view showing:
- Camera viewfinder framing a seed packet
- Detected variety name overlay
- "Capture" button
- Alternative: Seed inventory list with search
**Caption**: "Scan seed packets to auto-fill details"

### 6. Seed Detail — Growing Requirements
**Feature**: Complete seed packet info
**Frame**: Seed detail view showing:
- Packet photo thumbnail
- Variety name and brand
- Days to germination, maturity
- Depth, spacing, sun requirements
- Indoor start weeks and quantity
**Caption**: "All your seed info in one place"

### 7. Seasonal Planner — Month View
**Feature**: Zone-aware planting calendar
**Frame**: Seasonal planner showing:
- Month selector strip (current month highlighted)
- Activity cards: "Start tomatoes indoors", "Transplant peppers", "Harvest lettuce"
- Zone indicator (e.g., "Zone 7a — Last frost: April 15")
**Caption**: "Know exactly what to plant each month"

### 8. Plant Database — Browse & Learn
**Feature**: 50+ plants with care guides
**Frame**: Plant database view showing:
- Search bar
- Category tabs (Vegetables, Herbs, Fruits, Flowers)
- Plant cards with image, name, difficulty
- Filter for "Good for beginners"
**Caption**: "Explore 50+ plants with growing guides"

### 9. Journal — Photo Timeline
**Feature**: Visual plant history
**Frame**: Journal tab showing:
- Most recent entry with photo
- Entry cards with date, plant, and thumbnail
- Filter by plant or date range
**Caption**: "Capture your garden's progress"

### 10. Shopping List — Supply Tracker
**Feature**: Track what you need to buy
**Frame**: Shopping list showing:
- Unchecked items (seeds, soil, tools)
- Checked items (completed purchases)
- Category chips (Seeds, Soil Amendments, Tools)
- Add item button
**Caption**: "Never forget what you need at the garden store"

---

## Screenshot Generation Process

### Option A: Simulator Screenshots
1. Set simulator to correct device size
2. Launch app with test data: `--uitesting --demo-data`
3. Navigate to each screen
4. Capture with: `xcrun simctl io booted screenshot`
5. Add device frame using `screenshoter` or Figma

### Option B: Device Frame Overlay (Recommended)
1. Run app on physical device or simulator
2. Capture raw screenshots (no frame)
3. Use Apple's Media Manager or `ios-screenshot` tool
4. Export with device bezels

### Option C: Design Tool Export
1. Use Figma/Sketch with device templates
2. Paste app screenshots into device frames
3. Export at required resolutions

---

## Accessibility Requirements
- All screenshots must have meaningful captions
- Captions should describe the feature, not just the screen name
- Avoid tiny text that becomes unreadable at small sizes
- Use demo data that reflects real gardening scenarios

---

## Localization Note
Screenshots should be generated for primary market languages:
- English (US) — Required
- Spanish (ES) — Recommended
- French (FR) — Optional
- German (DE) — Optional

---

## Deliverables
1. `screenshots/iphone-17-pro-max/` — 10 PNG files (1320 x 2868)
2. `screenshots/iphone-17-pro/` — 10 PNG files (1206 x 2622)
3. `screenshots/ipad-pro-13/` — 10 PNG files (2048 x 2732)
4. `docs/app-store/app-store-copy.md` — This file

---

## Test Data Setup
Create a `--demo-data` launch argument that populates:
- 1 garden with 3 beds
- 5 plants across beds (tomato, pepper, basil, lettuce, carrot)
- 3 overdue reminders
- 2 due-today reminders
- 2 seed packets (1 with indoorStartWeeks set)
- 1 journal entry with photo
- 4 shopping list items (2 checked, 2 unchecked)
- Hardiness zone: 7a