# DataService Refactor Design (Domain Repositories)

**Date:** 2026-02-27
**Issue:** [GrowWise-bk9] Refactor DataService to extract domain-specific repositories

## Motivation
`DataService.swift` has grown into a "God object" (1,300+ lines), handling initialization, CloudKit sync fallbacks, and every single CRUD operation for `Plant`, `Garden`, `Reminder`, `Journal`, etc. 
While simplifying the app by removing CloudKit was initially considered, the decision was made to **keep CloudKit** (preserving sync and community features) but **refactor DataService** to reduce complexity.

## Architecture & Components
*   **DataService (Slimmed Down):** Acts purely as the `ModelContainer` owner. It retains the critical 6-level fallback initialization logic and CloudKit attachment, but delegates all data operations.
*   **Domain Repositories:** We will extract CRUD operations into distinct, focused classes:
    *   `PlantRepository`: All plant fetching, adding, and health status updates.
    *   `GardenRepository`: Garden management, community publishing logic.
    *   `ReminderRepository`: Scheduling, batching, and weather-aware logic for `PlantReminder`s.
    *   `JournalRepository`: `JournalEntry` and `SoilLog` CRUD.
    *   `UserRepository`: Profile management and skill assessments.
*   **Access Pattern:** `DataService` will vend these repositories as properties (e.g., `dataService.plants.fetchAll()`), so we don't need to change every `@Environment(DataService.self)` declaration in the app immediately.

## Data Flow
1.  A SwiftUI view calls `dataService.plants.add(newPlant)`.
2.  `PlantRepository` uses the shared `ModelContext` (passed from `DataService`) to insert the model and save.
3.  SwiftData (`NSPersistentCloudKitContainer`) seamlessly handles the background sync to iCloud exactly as it does now.

## Error Handling
*   We'll introduce domain-specific errors (e.g., `PlantError.notFound`, `GardenError.saveFailed`) rather than a giant list of generic `DataServiceError`s, making debugging much easier.
*   The critical 6-level fallback initialization (CloudKit -> in-memory -> stub) remains intact to ensure the app never crashes on startup.

## Testing
*   This makes testing *much* better. We can instantiate `ReminderRepository` in isolation with an in-memory test context (`DataService.makeForTesting()`) without loading the entire 1,300+ line God object.
