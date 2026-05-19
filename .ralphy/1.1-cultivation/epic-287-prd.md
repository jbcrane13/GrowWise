# PRD: Epic #287 — Onboarding & Personalization (1.1 fast-follow)

## Branch
`feature/1.1-cultivation`

## Scope
8 sub-issues, split into 3 parallel workstreams:

### Workstream A — Services (#341, #343, #345, #348)
Pure backend service extensions. No UI.

**#341** — Extend `StarterPlanService.build` to emit day-keyed `StarterPlan` (today through day 14), keyed off `User.gardeningGoals`, `Garden.type`, selected first plant template, and season.
**#343** — Extend `ShoppingListService` with `StarterShoppingSuggestionService` logic: derive soil type, container size, fertilizer, tools from `Garden.type` + plant type. Surface in onboarding completion.
**#345** — Extend `PerenualEnrichmentService`: background prefetch on first-plant-pick, persistent on-disk image cache (LRU, size-bounded), confidence indicator, duplicate resolution UI.
**#348** — Add `RecommendationReason` enum, surface up to 3 chips per recommendation card.

### Workstream B — Onboarding UI Flow (#346, #342, #347)
Onboarding flow modifications. Sequential within workstream.

**#346** — Branch `OnboardingFlow/OnboardingView.swift` by garden type:
  - Indoor: light availability, room temp, pets
  - Outdoor: hardiness zone, sun exposure, frost protection
  - Hydroponic: system type, nutrient schedule, pH range
**#342** — In final onboarding step, show `SeasonalPlannerService.getMonthlyActivities` as horizontal 12-month strip. "Add to calendar" button.
**#347** — Amplitude events at every onboarding step:
  - `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_step_skipped`, `onboarding_completed`
  - Activation: `activation_d1`, `activation_d7`, `activation_d30`

### Workstream C — Home UI (#344)
**#344** — Extend `TutorialService.recommendedTutorials(for:)` to filter by `User.skillLevel`, `User.gardeningGoals`, season, first plant type. New `TutorialRail` component on Home showing top 3 for first 7 days.

## Constraints
- Swift 6 strict concurrency
- @Observable only — never ObservableObject
- accessibilityIdentifier on every interactive element
- Do NOT re-build existing services — extend them
- Commit each issue separately with `feat(#XXX): ...` format

## Verification
- [ ] Build passes: `xcodebuild -scheme GrowWise -destination 'platform=iOS Simulator,name=iPhone 17' build`
- [ ] SwiftLint clean: `swiftlint --strict`
- [ ] Tests pass where applicable

## Anti-Stall
- Never wait for input. Keep moving.
- When done: commit, push to `feature/1.1-cultivation`, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"
