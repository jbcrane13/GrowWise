# Cultivation — App Store Screenshots Plan

## Overview
Generate 10 screenshots per device size (iPhone, iPad) covering core flows and features.

## Device Sizes Required
| Device | Display | Size | Notes |
|--------|---------|------|-------|
| iPhone 17 Pro Max | 6.9" | 1320 x 2868 px | Required |
| iPhone 17 Pro | 6.3" | 1206 x 2622 px | Required |
| iPad Pro 13" | 13" | 2048 x 2732 px | Recommended |

---

## Current App Structure (4 Tabs)
- **Home** — Care task dashboard, weather, seasonal tips, club card
- **Garden** — Plant list grouped by bed, add plant/garden FAB
- **Club** — Garden Club feed, create/join, chat, share
- **Me** — Profile, stats, settings, subscription

---

## Screenshot List (10 per device)

### 1. Home Dashboard — Care Tasks
**Feature**: Overdue and due-today reminders with one-tap completion
**Frame**: Home screen showing:
- Hero greeting with stat cards (plants, alerts)
- Overdue task section with inline complete buttons
- Due today section
- Seasonal tip card
- Your Club card
**Caption**: "Never miss a watering or fertilizing task"

### 2. Garden Tab — Plant List
**Feature**: Plants grouped by bed/area with hero header
**Frame**: Garden screen showing:
- Hero header with garden selector and plant count
- Plants grouped by bed/area
- Plant rows with health status indicators
- Floating add button (coral FAB)
**Caption**: "All your plants, organized by garden bed"

### 3. Add Plant — Quick Entry
**Feature**: Streamlined plant addition
**Frame**: AddPlantSheet showing:
- Plant name field
- Plant type picker
- Garden and location assignment
- Save button
**Caption**: "Add plants in seconds"

### 4. Plant Detail — Growth Journey
**Feature**: Detailed plant care with photo timeline
**Frame**: Plant detail view showing:
- Plant hero image
- Health status
- Last care dates (watered, fertilized, pruned)
- Quick action buttons
- Photo journal strip
**Caption**: "Track every plant's journey from seed to harvest"

### 5. Club Tab — Garden Club Feed
**Feature**: Share what's growing with nearby gardeners
**Frame**: Club feed showing:
- Club name and member count
- Activity posts with photos
- Share button
- Member avatars
**Caption**: "Share what's growing with your garden club"

### 6. Club — Create or Join
**Feature**: Club creation and invite code flow
**Frame**: Create Club sheet or Join Club sheet showing:
- Club name field
- Invite code display/copy
- Join via invite code
**Caption**: "Start a garden club or join one nearby"

### 7. Plant Health Guidance
**Feature**: Common plant issues and treatments
**Frame**: CommonPlantIssuesView showing:
- Issue categories
- Symptom descriptions
- Treatment recommendations
- Plant Health check access
**Caption**: "Identify common plant issues and find treatments"

### 8. Seasonal Planner — Month View
**Feature**: Zone-aware planting calendar
**Frame**: Seasonal planner showing:
- Month selector strip
- Activity cards: "Start tomatoes indoors", "Transplant peppers"
- Zone indicator
**Caption**: "Know exactly what to plant each month"

### 9. Compost Tracker
**Feature**: Compost batch management
**Frame**: Compost tracker showing:
- Batch list with status
- Temperature/moisture logs
- Readiness estimation
**Caption**: "Track your compost from scraps to garden gold"

### 10. Profile — Your Garden Stats
**Feature**: Garden statistics and subscription
**Frame**: Profile screen showing:
- Plant and journal count
- Streak days
- Subscription status
- Settings access
**Caption**: "See your garden stats at a glance"

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

---

## Test Data Setup
Create a `--demo-data` launch argument that populates:
- 1 garden with 2 beds
- 5 plants across beds (tomato, pepper, basil, lettuce, carrot)
- 3 overdue reminders
- 2 due-today reminders
- 1 garden club with 2 posts
- 2 journal entries with photos
- Hardiness zone: 7a
