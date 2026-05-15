# 1.0 Blocker Burn-Down Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to execute this plan task-by-task. Track progress with the checkbox list below.

**Goal:** Resolve or verify every open `[1.0 blocker]` GitHub issue (#300-#310) so Cultivation can reach a credible 1.0 release candidate.

**Architecture:** Treat already-implemented blockers as verification work and close them only with evidence. For remaining code blockers, use narrow service/view changes backed by Swift Testing or XCUITest coverage, preserving SwiftUI + SwiftData + service injection patterns. Release-copy readiness is documented in repo because App Store Connect assets cannot be fully verified from source.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, StoreKit 2, CloudKit, Swift Testing, XCUITest, SwiftLint, mac-mini SSH build/test verification, GitHub Issues.

## Task 1: Verify Existing 1.0 Blocker Fixes (#300-#304)

**Files to inspect:** `AddPlantSheet.swift`, `CreateBedSheet.swift`, onboarding flow views, `PerenualBrowseView.swift`, `PlantDatabaseService.swift`, `plant_database.json`.

- [x] Verify Add Plant and Create Container route through `DataService` rather than direct view-level SwiftData inserts.
- [x] Verify onboarding persists a first garden, first container, and selected first plant.
- [x] Verify Add Plant combines local and Perenual results and handles missing Perenual API configuration gracefully.
- [x] Verify offline plant catalog meets the 1.0 breadth target.
- [x] Run focused onboarding, Perenual, and database tests on mac-mini.
- [ ] Close #300-#304 with command evidence after final branch verification.

## Task 2: Fix Lint And Pricing Drift (#306, #310)

**Files:** `PaywallView.swift`, `User.swift`, `UserTests.swift`, `PaywallPresentationTests.swift`.

- [ ] Write failing tests for launch Premium pricing: `$2.99/mo` and `$34.99/yr`.
- [ ] Update `SubscriptionTier.premium.monthlyPrice` and Paywall display constants.
- [ ] Fix the Paywall SwiftLint trailing-comma violation.
- [ ] Run focused pricing tests and strict SwiftLint.

## Task 3: Enforce Plant Health Scanner Limits (#307)

**Files:** `PlantScannerView.swift`, `PlantDiagnosticService.swift`, Plant Diagnostic and scanner presentation tests.

- [ ] Write a failing feature test proving the scanner no longer exposes sample/debug guidance in release UI and no longer calls the legacy unmetered `diagnose(image:)` path.
- [ ] Add or verify service tests for allowed usage and limit-reached behavior.
- [ ] Inject `DataService` into `PlantScannerView` and route photo analysis through the tier-aware diagnostic call.
- [ ] Run focused scanner and diagnostic tests.

## Task 4: Preserve Club Share Garden Context And CloudKit Mapping (#308)

**Files:** `DataService+GardenClub.swift`, `ClubShareComposerSheet.swift`, `ClubCloudKitService.swift`, Garden Club service tests.

- [ ] Write a failing service test for `createClubPost(... gardenName:)`.
- [ ] Write pure CloudKit mapping/scope tests that require `gardenName` to be mapped and owner/member scope to be deterministic.
- [ ] Propagate garden context from Plant Detail share composer into the persisted club post.
- [ ] Use the tested CloudKit mapping/scope helpers from publish/fetch paths.
- [ ] Run focused Garden Club and ClubCloudKit tests.

## Task 5: Add Missing Critical UI Coverage (#309)

**Files:** `OnboardingFlowUITests.swift`, `GardenClubUITests.swift`, possibly `FirstPlantStepView.swift`.

- [ ] Add stable accessibility identifiers for starter plant cards if missing.
- [ ] Extend onboarding UI coverage to create garden, container, and first plant.
- [ ] Add Club composer coverage from the Club tab.
- [ ] Add Plant Detail share-to-club composer coverage if the existing UI hooks make it reliable.
- [ ] Run focused UI tests on mac-mini or document any simulator blocker.

## Task 6: Document App Store Readiness (#305)

**Files:** `docs/release/1.0-app-store-readiness.md`.

- [ ] Add release copy focused on outdoor gardens, beds/areas, timely care, and private clubs.
- [ ] Document subscription copy: Premium annual around `$34.99/year`, monthly available, Pro future-facing only.
- [ ] Document screenshot storyboard and privacy/subscription checklist.
- [ ] Add repository-side copy guardrails for Plant Health Guidance language.

## Task 7: Final Verification And Issue Updates

- [ ] Run `swiftlint lint --strict --config .swiftlint.yml`.
- [ ] Run `ssh mac-mini "cd ~/Projects/GrowWise/.worktrees/1-0-blockers/GrowWisePackage && swift test"`.
- [ ] Run `ssh mac-mini "cd ~/Projects/GrowWise/.worktrees/1-0-blockers && xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -sdk iphonesimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"`.
- [ ] Update or close #300-#310 with evidence and any residual risk.
- [ ] Commit and push `codex/1.0-blockers`.
