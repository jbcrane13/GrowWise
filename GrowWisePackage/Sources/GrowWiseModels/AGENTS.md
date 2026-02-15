# GrowWiseModels - Agent Instructions

## Purpose

Pure data layer containing SwiftData `@Model` persistence classes and supporting types. This target has **no dependencies** beyond `Foundation` and `SwiftData`.

## Files

| File | Contents |
|------|----------|
| `Plant.swift` | `Plant` @Model + enums: PlantType, DifficultyLevel, SunlightLevel, WateringFrequency, SpaceRequirement, GrowthStage, HealthStatus, ContainerType |
| `Garden.swift` | `Garden` @Model + enums: GardenType, SunExposure, SoilType, DrainageLevel, SpaceSize |
| `User.swift` | `User` @Model + `ReminderSettings` @Model + enums: GardeningSkillLevel, GardeningGoal, TimeCommitment, MeasurementSystem, SubscriptionTier |
| `PlantReminder.swift` | `PlantReminder` @Model + enums: ReminderType, ReminderFrequency, SnoozeDuration, ReminderPriority |
| `JournalEntry.swift` | `JournalEntry` @Model + enums: JournalEntryType, SoilMoisture, WeatherCondition, PlantMood |
| `GardeningStats.swift` | `GardeningStats` Sendable struct for dashboard aggregation |
| `SecureCredentials.swift` | `SecureCredentials` Codable struct + `SecureTokenEncryption` (AES-256-GCM) + `TokenRefreshResponse` |

## Critical Rules

1. **All `@Model` properties MUST be optional or have default values** for CloudKit compatibility. This is annotated with `// CloudKit: made optional or with default value` throughout.

2. **Enums MUST conform to `String, CaseIterable, Codable, Sendable`** for SwiftData serialization and thread safety.

3. **Relationships are optional arrays** (e.g., `var plants: [Plant]? = []`). Initialize to empty arrays in `init()`.

4. **Do not import GrowWiseServices or GrowWiseFeature** - this is the leaf dependency.

5. **`@Model` classes must be `public final class`** for SwiftData.

## Relationship Map

```
User 1--* Garden 1--* Plant
User 1--* PlantReminder *--1 Plant
User 1--* JournalEntry *--1 Plant
User 1--1 ReminderSettings
Plant *--* Plant (companionPlants, self-referential)
```

## Adding a New Model

1. Create `NewModel.swift` in this directory
2. Annotate with `@Model public final class`
3. Make all properties optional or provide defaults
4. Add `public init(...)` with explicit initialization of all properties
5. Register the type in `DataService`'s `Schema([...])` array
6. Add a CloudKit record type in `CloudKitSchema.swift`
7. Add CRUD methods to `DataService`

## Duplicate Files

Files with " 2" suffix (`Plant 2.swift`, `User 2.swift`, etc.) are duplicates that should be removed.
