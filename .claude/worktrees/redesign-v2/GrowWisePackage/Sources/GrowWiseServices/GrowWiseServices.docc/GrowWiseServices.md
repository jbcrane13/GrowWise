# ``GrowWiseServices``

Business logic and service layer for the GrowWise gardening app.

## Overview

GrowWiseServices contains all non-UI logic for the GrowWise (Cultivation) iOS app. Services follow the `@Observable` pattern and are injected into SwiftUI views via `@Environment`. The module integrates with CloudKit for sync, Sentry for error tracking, and Amplitude for analytics.

All services are `@MainActor`-isolated for UI-bound work, with dedicated actors for concurrent operations.

## Topics

### Data Persistence

- ``DataService``
- ``DataServiceError``
- ``ModelContainerFactory``
- ``DataTransformationService``
- ``SwiftDataCache``

### Cloud & Sync

- ``CloudSyncService``
- ``CloudKitError``
- ``CloudSyncStatus``

### Plant Intelligence

- ``CompanionPlantingService``
- ``CompanionPlantingInfo``
- ``PlantCompatibilityProfile``
- ``GardenCompatibilityAnalysis``
- ``PlantCompatibility``
- ``PlantDatabaseService``
- ``PlantDiagnosticService``

### Location & Weather

- ``LocationService``
- ``LocationError``
- ``PlantingWindow``
- ``WeatherAlertType``
- ``AlertSeverity``

### Notifications

- ``NotificationService``
- ``ReminderService``

### Subscriptions & Features

- ``SubscriptionService``
- ``FeatureFlagService``
- ``FeatureFlag``

### Security

- ``KeychainService``
- ``BiometricService``

### Observability

- ``ObservabilityService``
- ``AnalyticsService``
- ``AnalyticsEvent``

### Tutorials

- ``TutorialService``
- ``TutorialContent``
- ``TutorialTopic``
- ``TutorialStep``

### Validation

- ``ValidationService``
