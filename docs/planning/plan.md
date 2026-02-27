# GrowWise UI Test Coverage Plan

## 1. Executive Summary
Currently, GrowWise has basic UI tests for App Launch and the Onboarding flow. However, the core gardening features (managing gardens, plants, reminders, and journals) lack UI test coverage. This plan outlines a comprehensive suite of XCUITest targets to verify all critical user interactions.

## 2. Current Coverage Analysis
**Covered:**
- **App Launch:** `GrowWiseUITests.swift` checks basic app initialization.
- **Onboarding:** `OnboardingFlowUITests.swift` exhaustively covers the welcome, skill assessment, goals, location, and notification setups, including back navigation and skip logic.

**Missing Coverage (The Gap):**
- **My Garden:** Creating gardens, adding plants, filtering plants.
- **Journal:** Adding entries, attaching photos, sorting/filtering entries.
- **Reminders:** Creating custom reminders, marking them complete.
- **Plant Guide:** Searching the database, adding from the database to a garden.
- **Tutorials:** Tracking reading progress, finishing a tutorial.

## 3. Implementation Plan

### Phase 1: Core Gardening Tests (`MyGardenUITests.swift`)
- **Test 1:** Create a new Garden (Verify Empty State -> Tap Create -> Fill Form -> Verify Appearance)
- **Test 2:** Add a Plant to Garden (Tap Add -> Fill Plant Form -> Verify Appearance)
- **Test 3:** Filter Plants (Open Sheet -> Select Filter -> Verify Grid Updates)

### Phase 2: Journal & Photo Tests (`JournalUITests.swift`)
- **Test 1:** Add Journal Entry (Tap Plus -> Enter Text/Measurements -> Save -> Verify in List)
- **Test 2:** Journal Filtering (Tap Plant Filter Chip -> Verify List Updates)

### Phase 3: Reminders & Alerts (`RemindersUITests.swift`)
- **Test 1:** Create Reminder (Select Plant -> Set Frequency -> Save -> Verify in Home/List)
- **Test 2:** Complete Reminder (Tap Checkmark -> Verify State Change)

### Phase 4: Discovery Tests (`DiscoveryUITests.swift`)
- **Test 1:** Search Plant Database (Type in search -> Verify Results -> Add to Garden)
- **Test 2:** Complete Tutorial (Open Tutorial -> Tap through steps -> Verify Progress updates)

## 4. Architecture for UI Tests
- Utilize the `--uitesting` launch argument to inject mock data or clear existing databases on startup.
- Add specific `.accessibilityIdentifier()` tags to any ambiguous UI elements discovered during test writing.
