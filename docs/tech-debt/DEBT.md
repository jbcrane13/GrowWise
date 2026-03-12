# GrowWise Technical Debt Register

**Updated:** 2026-03-12
**Process:** Tech debt is tracked here and as beads issues (`bd show`).
All `// TODO` and `// FIXME` comments in Swift source **must** reference a beads issue number:
```swift
// TODO(GW-123): description of what needs doing
// FIXME(GW-456): description of the problem
```
Unlinked markers fail CI (`tech-debt` job) and SwiftLint (error severity).

To create a beads issue: `bd create "description"` → note the issue number → add to code.

---

## How to Use This Register

| Field | Meaning |
|-------|---------|
| ID | Beads issue ID (create with `bd create "..."`) |
| Severity | `high` = blocks features or causes bugs; `medium` = slows development; `low` = cleanup |
| Effort | S (<2h), M (half-day), L (1-2 days), XL (sprint) |
| Area | Which module/layer is affected |

---

## Active Debt

### Dead Code — GrowWiseFeature/Components

These components were built but are not referenced in any active view after the March 2026 UI redesign. They should either be adopted into views or deleted.

| File | Unused Item | Severity | Effort |
|------|------------|----------|--------|
| `Components/PlantCardView.swift` | Entire file: `PlantCardView`, `HealthStatusBadge`, `CareIndicator`, `QuickActionButton`, `PlantTypeBadge`, `DifficultyBadge` + `CareStatus` enum | medium | M |
| `Components/SearchBarView.swift` | `SearchBarView`, `PlantSearchBarView`, `PlantFilterSheet`, `SearchSuggestionsView` | medium | M |
| `Components/CompactReminderRow.swift` | `CompactReminderRow` struct | low | S |
| `Components/PlantReminderCard.swift` | `PlantReminderCard` struct | low | S |
| `Components/StatCard.swift` | `StatCard` struct | low | S |

**Action:** Audit each component. Delete if not planned for use; otherwise wire up or document the roadmap item.

---

### Dead Code — GrowWiseServices/ValidationService

`ValidationService` has a comprehensive validation API that is entirely unused by the app. The service was built speculatively but nothing calls it.

| Item | Severity | Effort |
|------|----------|--------|
| `ValidationService.shared` singleton | medium | S |
| `validateEmail(_:)` | medium | S |
| `validateText(_:fieldName:minLength:maxLength:)` | medium | S |
| `validateName(_:fieldName:)` | medium | S |
| `validateNumber(_:fieldName:min:max:allowDecimals:)` | medium | S |
| `validatePlantName(_:)` | medium | S |
| `validateTag(_:)` | medium | S |
| `validateHeight/Width/Temperature/Humidity/WaterAmount(_:)` | medium | S |
| `validateSearchQuery(_:)` | medium | S |
| `sanitizeInput(_:)` | medium | S |
| `validateFields(_:)` | medium | S |
| `ValidationModifier` ViewModifier | medium | S |

**Action:** Either wire `ValidationService` into `AddPlantSheet`/`AddReminderView` form fields (preferred), or delete the service if custom validation is not needed.

---

### Dead Code — GrowWiseServices/TutorialService

Tutorial tracking structs are defined but not used anywhere in the app.

| Item | Severity | Effort |
|------|----------|--------|
| `TutorialStep` struct + `steps` property | low | S |
| `TutorialProgress` struct (`tutorialId`, `completedSteps`, `totalSteps`, `isCompleted`, `progressPercentage`) | low | S |
| `TutorialAnalytics` struct | low | S |

**Action:** Delete these or connect them to the Profile tab tutorial screen once tutorials are implemented.

---

### Unused Parameters — GrowWiseServices

Function parameters that are accepted but never read inside the function body.

| File | Function | Unused Param | Severity |
|------|----------|-------------|----------|
| `PhotoService.swift` | private helper | `dataService` | low |
| `PlantDatabaseService.swift` | scoring fn | `score` | low |
| `ReminderService.swift` | multiple | `plant` (×2), `year` | low |
| `Repositories/PlantRepository.swift` | add | `plant` | medium |

**Action:** Either use the parameter or replace with `_` to silence warnings and signal intent.

---

### Duplicate Type — SpaceSize Enum

Two `SpaceSize` enums coexist, causing type ambiguity:
- `GrowWiseModels.SpaceSize` — the canonical model type (CloudKit-compatible, `Codable`)
- `GrowWiseFeature.SpaceSize` — defined in `OnboardingFlow/OnboardingView.swift`

The feature-level duplicate should be removed; `OnboardingView` should import and use `GrowWiseModels.SpaceSize`.

| Severity | Effort |
|----------|--------|
| high | S |

---

### Large Files Exceeding 500-Line Guideline

Files over 500 lines are harder for agents and reviewers to navigate. Each should be split into focused sub-files.

| File | Lines | Split Suggestion |
|------|-------|-----------------|
| `GrowWiseServices/ReminderService.swift` | 998 | Extract scheduling logic, repeat logic, notification building |
| `GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift` | 850 | Extract photo section, entry form, action toolbar |
| `GrowWiseServices/DataService.swift` | 789 | Already delegates to repositories; audit for removable code |
| `GrowWiseFeature/Views/PlantDatabaseView.swift` | 758 | Extract filter panel, plant row, detail sheet |
| `GrowWiseFeature/Views/AddPlantSheet.swift` | 748 | Extract per-tab subviews |
| `GrowWiseFeature/Views/GardenLayoutView.swift` | 728 | Extract grid cell, drag layer |
| `GrowWise/Data/Models/DataValidationRules.swift` | 576 | App-layer only; evaluate if still needed |
| `GrowWiseFeature/Views/MyGardenView.swift` | ~513 | Extract filter UI, sheets |

---

### Compiler Warnings — Concurrency

These warnings indicate real potential race conditions or unnecessary `await`/`try` usage.

| File | Warning | Severity |
|------|---------|----------|
| `AddPlantSheet.swift:303-304` | `@MainActor` property accessed from nonisolated context | high |
| `OnboardingNavigationView.swift:169,175,193` | `await` with no async work | low |
| `AddPlantSheet.swift:514-519` | Unreachable `catch` block + dead code | low |
| `AddReminderView.swift:512` | Optional debug description in string interpolation | low |
| `HomeViewModel.swift:62` | `withAnimation` return value unused | low |

---

## Resolved Debt

| Date | Item | Resolution |
|------|------|------------|
| 2026-03-12 | Duplicate `CreateGardenSheet` struct in `MyGardenView.swift` | Removed duplicate; canonical version in `Views/Garden/CreateGardenSheet.swift` |
| 2026-03-12 | SwiftFormat `redundantSendable` in `CompanionPlantingService`, `PlantDatabaseService`, `GardenLayoutView` | Auto-fixed with `swiftformat` |
