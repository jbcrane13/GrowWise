# GrowWise Core Data Architecture

## Overview

The GrowWise iOS app uses a comprehensive Core Data model with CloudKit synchronization to provide a robust gardening management system. This architecture supports user profiles, plant databases, garden management, smart reminders, and plant journaling.

## Entity Relationship Diagram

```
User ──────┐
           │
           ├── Gardens ──── UserPlants ──┬── Reminders
           │                             │
           └── JournalEntries ────────────┤
                                         │
                              Plant ─────┘
```

## Core Entities

### User
- **Purpose**: Store user profiles with skill levels and gardening preferences
- **Key Features**: Skill level tracking, location/hardiness zone, notification settings
- **CloudKit**: ✅ Synced to private database

### Plant
- **Purpose**: Master database of 25+ common plants with detailed care information
- **Key Features**: Difficulty levels, care schedules, growth stages, companion planting
- **CloudKit**: ✅ Synced to private database
- **Sample Data**: Pre-loaded with herbs, vegetables, flowers, succulents, houseplants, fruits

### Garden
- **Purpose**: User's garden spaces with layout and environmental characteristics
- **Key Features**: Sun exposure mapping, soil types, garden layouts, size tracking
- **CloudKit**: ✅ Synced to private database

### UserPlant
- **Purpose**: Junction entity representing user's specific plant instances
- **Key Features**: Planting dates, health tracking, custom care schedules, harvest logs
- **CloudKit**: ✅ Synced to private database

### Reminder
- **Purpose**: Smart reminders for plant care tasks
- **Key Features**: Frequency-based scheduling, priority levels, notification integration
- **CloudKit**: ✅ Synced to private database

### JournalEntry
- **Purpose**: Plant journal with photos, notes, and progress tracking
- **Key Features**: Photo storage, measurement tracking, categorized entries
- **CloudKit**: ✅ Synced to private database

## Key Features

### CloudKit Integration
- **Container**: `iCloud.com.growwise.gardening`
- **Database**: Private database for user data
- **Sync**: Automatic bidirectional synchronization
- **Subscriptions**: Push notifications for data changes

### Data Validation
- Comprehensive validation rules for all entities
- Field-level constraints and business logic validation
- Warning system for unusual but valid data
- Batch validation capabilities

### Sample Plant Database
Pre-loaded with 25+ plants including:
- **Herbs**: Basil, Mint, Rosemary, Parsley, Oregano
- **Vegetables**: Tomato, Lettuce, Spinach, Carrot, Radish
- **Flowers**: Marigold, Sunflower, Zinnia, Cosmos, Nasturtium
- **Succulents**: Aloe Vera, Jade Plant, Echeveria
- **Houseplants**: Pothos, Snake Plant, Peace Lily, Rubber Tree, Philodendron
- **Fruits**: Strawberry, Blueberry, Lemon Tree

### Relationship Design
- **User → Gardens**: One-to-many with cascade delete
- **Garden → UserPlants**: One-to-many with cascade delete
- **Plant → UserPlants**: One-to-many with nullify delete
- **UserPlant → Reminders**: One-to-many with cascade delete
- **UserPlant → JournalEntries**: One-to-many with cascade delete

## File Structure

```
GrowWise/Data/
├── Models/
│   ├── GrowWiseDataModel.xcdatamodeld/
│   ├── CoreDataManager.swift
│   └── DataValidationRules.swift
├── Sample/
│   └── PlantDatabase.swift
└── CloudKit/
    └── CloudKitSchema.swift
```

## Implementation Details

### Core Data Manager
- Singleton pattern with `CoreDataManager.shared`
- NSPersistentCloudKitContainer for CloudKit integration
- Automatic change merging and conflict resolution
- Background context support for heavy operations

### Validation System
- Real-time validation during data entry
- Batch validation for data integrity checks
- Error and warning categorization
- Business rule enforcement

### CloudKit Schema
- Record type definitions for all entities
- Field mapping and relationship handling
- Subscription management for push notifications
- Schema validation utilities

## Usage Examples

### Creating a New Garden
```swift
let garden = Garden(context: CoreDataManager.shared.context)
garden.id = UUID()
garden.name = "Herb Garden"
garden.gardenType = "container"
garden.sunExposure = "full_sun"
garden.owner = currentUser
CoreDataManager.shared.save()
```

### Adding a Plant to Garden
```swift
let userPlant = UserPlant(context: CoreDataManager.shared.context)
userPlant.id = UUID()
userPlant.plant = selectedPlant
userPlant.garden = selectedGarden
userPlant.plantingDate = Date()
userPlant.healthStatus = "healthy"
userPlant.currentGrowthStage = "seedling"
CoreDataManager.shared.save()
```

### Creating Smart Reminders
```swift
let reminder = Reminder(context: CoreDataManager.shared.context)
reminder.id = UUID()
reminder.type = "watering"
reminder.frequencyDays = userPlant.plant?.wateringFrequencyDays ?? 7
reminder.nextDueDate = Calendar.current.date(byAdding: .day, value: Int(reminder.frequencyDays), to: Date())
reminder.userPlant = userPlant
CoreDataManager.shared.save()
```

## Data Migration Strategy

The Core Data model is designed with future extensibility in mind:
- Optional attributes for backward compatibility
- Transformable attributes for complex data types
- Versioning support for schema evolution
- CloudKit schema evolution best practices

## Performance Considerations

- Lazy loading relationships to minimize memory usage
- Batch operations for sample data loading
- Background context for CloudKit operations
- Fetch request optimization with predicates and sort descriptors

## Security & Privacy

- All user data stored in private CloudKit database
- No sensitive information in shared or public databases
- Local Core Data encryption via iOS data protection
- User consent required for CloudKit features

This architecture provides a solid foundation for the GrowWise gardening app, supporting both offline usage and seamless cloud synchronization across devices.