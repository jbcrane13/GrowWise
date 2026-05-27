# Tutorials and Education Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a practical education hub with beginner tutorials, timely planting guidance, real tutorial detail screens, and Home/Profile access.

**Architecture:** Keep tutorial content and progress in `TutorialService`, add deterministic planting-guide recommendations to `SeasonalPlannerService`, and reuse those service contracts in SwiftUI. The UI remains sheet-based per ADR-012 and uses the existing Cultivation paper-card theme.

**Tech Stack:** Swift 6, SwiftUI, SwiftData-backed services, Swift Testing, JSON resources.

---

### Task 1: Planting Guide Service Contract

**Files:**
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/SeasonalPlannerServiceTests.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/SeasonalPlannerService.swift`

- [ ] **Step 1: Write failing tests**

Add tests asserting that zone 7 spring guidance includes beginner direct-sow crops, zone 9 shifts that guidance earlier than zone 4, indoor-start items link to `seed-starting-indoors`, and item ids are unique.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SeasonalPlannerServiceTests 2>&1 | tail -40"`

Expected: compile failure or missing symbol for `getPlantingGuide`.

- [ ] **Step 3: Implement service types and method**

Add `PlantingGuideAction`, `PlantingGuideItem`, and `getPlantingGuide(for:zone:)` to `SeasonalPlannerService`. Use a small static crop table and the existing zone-offset convention.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter SeasonalPlannerServiceTests 2>&1 | tail -40"`

Expected: planting-guide tests pass.

### Task 2: Beginner Curriculum and Tutorial Corpus

**Files:**
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/TutorialServiceTests.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/TutorialServicePersonalizationTests.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/TutorialService.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseServices/Resources/tutorials.json`

- [ ] **Step 1: Write failing tests**

Add tests for required outdoor tutorial ids and ordered beginner learning path ids.

- [ ] **Step 2: Run focused tests and verify RED**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter Tutorial 2>&1 | tail -60"`

Expected: missing ids and missing `getBeginnerLearningPath`.

- [ ] **Step 3: Implement tutorial helpers and expand JSON**

Add `getBeginnerLearningPath()` and `getPlantingGuide(for:zone:)` to `TutorialService`. Add the new outdoor tutorials to `tutorials.json` with beginner-focused steps.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter Tutorial 2>&1 | tail -60"`

Expected: tutorial tests pass.

### Task 3: Tutorial Detail Experience

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialDetailView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialView.swift`

- [ ] **Step 1: Add static feature-label tests**

Add static constants on `TutorialView` for the learning hub title and Home learning-card title, then assert them from `GrowWiseFeatureTests`.

- [ ] **Step 2: Implement detail view**

Create `TutorialDetailView` with header, progress, step cards, tips, mistake callouts, and mark-complete buttons using `tutorialService.markStepComplete`.

- [ ] **Step 3: Wire navigation destination**

Add `.navigationDestination(for: TutorialTopic.self)` in `TutorialView` and route rows/featured cards into `TutorialDetailView`.

- [ ] **Step 4: Build-check feature target through package tests**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test --filter GrowWiseFeatureTests 2>&1 | tail -40"`

Expected: feature target compiles.

### Task 4: Learning Hub Surface

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`

- [ ] **Step 1: Redesign TutorialView around hub sections**

Add the planting-guide rail and beginner path rail above the existing category browser. Keep search and progress.

- [ ] **Step 2: Add Home entry point**

Add a `showTutorials` state, `learningCard`, and a sheet for `TutorialsView`. Give the button `home_button_learning_hub`.

- [ ] **Step 3: Update Profile row copy**

Rename the row to `Guides & Tutorials` while preserving `profile_row_tutorials`.

- [ ] **Step 4: Run lint on touched Swift files**

Run: `swiftlint lint --strict --config .swiftlint.yml GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialView.swift GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialDetailView.swift GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift GrowWisePackage/Sources/GrowWiseServices/TutorialService.swift GrowWisePackage/Sources/GrowWiseServices/SeasonalPlannerService.swift`

Expected: no strict lint violations in touched files.

### Task 5: Final Verification and Handoff

**Files:**
- All modified files

- [ ] **Step 1: Run service and feature tests**

Run: `ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -40"`

Expected: package tests pass or any unrelated pre-existing failure is identified with evidence.

- [ ] **Step 2: Run strict lint**

Run: `swiftlint lint --strict --config .swiftlint.yml`

Expected: lint exits 0.

- [ ] **Step 3: Run app build**

Run: `ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5"`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit and push**

Run:

```bash
git status --short
git add docs/superpowers/specs/2026-05-27-tutorials-education-design.md docs/superpowers/plans/2026-05-27-tutorials-education.md GrowWisePackage
git commit -m "feat: expand tutorials and planting education"
git push -u origin codex/tutorials-education
```
