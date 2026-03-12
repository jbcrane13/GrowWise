# ``GrowWiseModels``

SwiftData model layer for the GrowWise gardening app.

## Overview

GrowWiseModels defines all persistent data types used by the GrowWise (Cultivation) iOS app. Every model class uses SwiftData's `@Model` macro and is designed for CloudKit compatibility — all properties are optional or have defaults.

The module has no external dependencies, making it safe to import from any target.

## Topics

### Plants

- ``Plant``
- ``PlantType``
- ``DifficultyLevel``
- ``SunlightLevel``
- ``WateringFrequency``
- ``GrowthStage``
- ``HealthStatus``
- ``SpaceRequirement``
- ``ContainerType``

### Gardens

- ``Garden``
- ``GardenType``
- ``SunExposure``
- ``SoilType``
- ``DrainageLevel``
- ``SpaceSize``
- ``GardenBed``
- ``BedType``

### Journal

- ``JournalEntry``
- ``JournalEntryType``
- ``SoilMoisture``
- ``WeatherCondition``
- ``PlantMood``

### Reminders

- ``PlantReminder``
- ``ReminderType``
- ``ReminderFrequency``
- ``SnoozeDuration``
- ``ReminderPriority``

### Soil Tracking

- ``SoilLog``
- ``FertilizerType``
- ``SoilRecommendation``
- ``SoilNutrientStatus``
- ``SoilTestRanges``

### User Profile

- ``User``
- ``ReminderSettings``
- ``GardeningSkillLevel``
- ``GardeningGoal``
- ``TimeCommitment``
- ``MeasurementSystem``
- ``SubscriptionTier``

### Statistics

- ``GardeningStats``
