# Cultivation 1.0 Blockers Design

## Goal

Make first-run setup and plant creation credible for a 1.0 release: onboarding should create a usable garden structure, core Add Plant flows should persist through the service layer, and the plant database story should be honest when online enrichment is unavailable.

## Blocker Tickets

- #300: Inline garden and container creation must save through the service layer.
- #301: Add Plant and onboarding must use unified local plus Perenual plant search.
- #302: Onboarding must persist a complete garden, container, and first plant flow.
- #303: Configure Perenual for TestFlight and show online database availability.
- #304: Expand the bundled on-device plant database beyond starter scale.

## Recommended 1.0 Scope

The 1.0 release should prefer a dependable, visible first-run result over ambitious personalization. The first onboarding pass should:

1. Capture level and goals.
2. Offer a skippable first garden.
3. Offer a skippable first container when a garden is being created.
4. Offer a skippable first plant.
5. Persist garden, container, starter plant, and starter watering reminder through `DataService`.
6. Show the result in Garden immediately after onboarding.

This means the selected level/goals remain useful but lightweight: they influence beginner recommendations and persisted user preferences. Deeper custom plans, adaptive lessons, garden layouts, and multi-week coaching stay out of 1.0 and should be queued for a quick 1.1 iteration under #287.

## Architecture

- Keep persistence behind `DataService` and repositories. Views should not directly insert core `Garden`, `GardenBed`, or `Plant` models for user-facing creation flows.
- Add `DataService.createGardenBed(...)` as the service-layer path for containers.
- Extend user-plant creation with an optional `GardenBed` parameter so onboarding and Add Plant can place a plant in a container atomically.
- Keep SwiftUI state local to onboarding views per ADR-002. Do not add a new ViewModel for this flow.
- Seed the local plant database before first-plant onboarding recommendations load, because the UI-test fast path can show onboarding before background seeding completes.
- Keep online plant database integration graceful. Perenual should enrich Add Plant/search when configured, while local results remain usable offline.

## 1.1 Fast-Follow Scope Left Out of the Recommended 1.0 Cut

- Multi-garden onboarding.
- Layout planning and container geometry.
- Deep goal-based coaching plans.
- Seasonal grow plans generated from location and hardiness zone.
- Full offline catalog parity with Perenual.
- Rich recommendation ranking across goals, climate, companion planting, and available space.
- Bulk import/backfill of a large curated plant taxonomy beyond the 1.0 offline baseline.

Those are valuable, but they are not required to make the 1.0 first-run promise honest.
