# Tutorials and Education Expansion Design

**Date:** 2026-05-27
**Status:** Approved for implementation

## Purpose

Cultivation should feel dependable for a beginner who wants to know what to do next, not like a settings screen with a few articles. The education experience will become a practical learning hub that is easy to reach from Home and Me, teaches outdoor gardening fundamentals, and surfaces timely planting guidance based on the user's zone and season.

## Scope

- Keep education inside the existing `TutorialsView` sheet per ADR-012.
- Add a Home entry point for “what to plant now” and beginner lessons.
- Rename the Me row from “Tutorials” to “Guides & Tutorials” while preserving the existing route.
- Expand the tutorial corpus from mostly houseplant basics into a beginner outdoor-gardening path.
- Add a deterministic planting-guide service API for current-month recommendations.
- Add a tutorial detail screen so tutorial rows actually open usable step-by-step content.

Out of scope:

- A new top-level Learn tab.
- Personalized push notifications for lessons.
- Perenual-backed live educational content.
- A full frost-date calendar replacement.

## References

- University of Maryland Extension vegetable planting calendar: `https://extension.umd.edu/resource/vegetable-planting-calendar/`
- University of Minnesota Extension seed-starting guidance: `https://extension.umn.edu/planting-and-growing-guides/starting-seeds-indoors`
- Penn State Extension seed starting and vegetable-garden guidance: `https://extension.psu.edu/seed-starting-demystified`

These references inform the app copy at a high level. App content remains original, short, and action-oriented.

## Architecture

`TutorialService` stays the public education facade. It continues loading tutorial content from `tutorials.json`, tracking progress through Keychain-backed step completion, and filtering by skill level. It gains small query helpers for the beginner learning path and current planting guidance.

`SeasonalPlannerService` gains a value-type planting guide API:

- `PlantingGuideAction`: start indoors, direct sow, transplant.
- `PlantingGuideItem`: plant name, type, action, beginner flag, timing summary, why-now copy, next-step copy, and an optional tutorial id.
- `getPlantingGuide(for month:zone:)`: deterministic monthly recommendations using the existing zone-offset convention.

This keeps time/zone logic near the existing seasonal planner while letting Tutorials and Home reuse it without duplicating planting calendars.

## UI Design

`TutorialView` becomes a learning hub:

- Header: “Learn & Grow” with compact progress.
- What to plant now rail: current zone/month guide cards with action chips and next steps.
- Beginner path rail: ordered curriculum for first-time gardeners.
- Category selector: existing categories remain for browsing.
- Tutorial list: existing search and progress metadata remain.

`TutorialDetailView` shows the tutorial title, description, progress, and step cards. Each step has tips, mistakes to avoid, and a mark-complete button with accessibility identifiers.

`HomeView` gets a paper-card button that opens the same Tutorials sheet. It should read like a practical next action, not a marketing panel.

## Data

`tutorials.json` will be expanded with outdoor beginner topics:

- First Outdoor Garden
- What to Plant This Month
- Seed Starting Indoors
- Direct Sowing Basics
- Transplanting and Hardening Off
- Succession Planting
- Harvesting Basics

Existing tutorials remain valid and searchable. New tutorials are beginner-level unless the concept requires intermediate framing.

## Testing

Service tests will cover:

- Planting-guide recommendations for spring direct sowing in zone 7.
- Warmer and colder zones shifting the same planting window.
- Indoor-start recommendations linking to the seed-starting tutorial.
- Unique planting-guide ids.
- Beginner curriculum ids resolving to tutorials in order.
- Tutorial corpus containing the new outdoor beginner path.

Feature tests will cover static learning entry labels where useful. Full SwiftUI navigation behavior is covered by build verification because current feature tests do not use a UI introspection framework.

## Error Handling

Tutorial content remains bundle-backed and fails fast if malformed, matching the existing service behavior. Planting-guide recommendations do not perform I/O and should return an empty array only when a month has no matching recommendations. User-facing fetch errors are not introduced.

## Accessibility

New interactive controls must use the existing snake-case identifier style:

- `home_button_learning_hub`
- `tutorials_button_progress`
- `tutorials_card_planting_<id>`
- `tutorials_row_<tutorial-id>`
- `tutorialdetail_button_step_<index>`

## Verification

Run:

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"
swiftlint lint --strict --config .swiftlint.yml
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"
```
