import Foundation
@testable import GrowWiseModels

// MARK: - Test Data Factory

public struct TestDataFactory {
    
    // MARK: - User Factory
    
    public static func createUser(
        email: String = "test@example.com",
        displayName: String = "Test User",
        skillLevel: GardeningSkillLevel = .beginner
    ) -> User {
        return User(email: email, displayName: displayName, skillLevel: skillLevel)
    }
    
    public static func createAdvancedUser() -> User {
        let user = createUser(
            email: "expert@example.com",
            displayName: "Expert Gardener",
            skillLevel: .expert
        )
        user.experienceYears = 10
        user.plantsGrown = 50
        user.plantsHarvested = 30
        user.streakDays = 100
        user.achievementPoints = 500
        user.completedTutorials = ["basic_watering", "soil_preparation", "pest_control"]
        user.gardeningGoals = [.growFood, .sustainability, .learnSkills]
        user.preferredPlantTypes = [.vegetable, .herb, .fruit]
        user.timeCommitment = .heavy
        return user
    }
    
    // MARK: - Garden Factory
    
    public static func createGarden(
        name: String = "Test Garden",
        type: GardenType = .vegetable,
        isIndoor: Bool = false
    ) -> Garden {
        return Garden(name: name, gardenType: type, isIndoor: isIndoor)
    }
    
    public static func createIndoorHerbGarden() -> Garden {
        let garden = createGarden(name: "Kitchen Herbs", type: .herb, isIndoor: true)
        garden.location = "Kitchen Windowsill"
        garden.lightConditions = .partialSun
        garden.size = .small
        return garden
    }
    
    public static func createOutdoorVegetableGarden() -> Garden {
        let garden = createGarden(name: "Backyard Vegetable Patch", type: .vegetable, isIndoor: false)
        garden.location = "Backyard"
        garden.lightConditions = .fullSun
        garden.size = .large
        return garden
    }
    
    // MARK: - Plant Factory
    
    public static func createPlant(
        name: String = "Test Plant",
        type: PlantType = .vegetable,
        difficulty: DifficultyLevel = .beginner,
        isUserPlant: Bool = true
    ) -> Plant {
        return Plant(name: name, plantType: type, difficultyLevel: difficulty, isUserPlant: isUserPlant)
    }
    
    public static func createTomatoPlant() -> Plant {
        let plant = createPlant(name: "Cherry Tomato", type: .vegetable, difficulty: .beginner)
        plant.scientificName = "Solanum lycopersicum"
        plant.sunlightRequirement = .fullSun
        plant.wateringFrequency = .daily
        plant.spaceRequirement = .medium
        plant.growthStage = .flowering
        plant.healthStatus = .healthy
        plant.plantingDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        plant.containerType = .container
        return plant
    }
    
    public static func createBasilPlant() -> Plant {
        let plant = createPlant(name: "Sweet Basil", type: .herb, difficulty: .beginner)
        plant.scientificName = "Ocimum basilicum"
        plant.sunlightRequirement = .partialSun
        plant.wateringFrequency = .everyOtherDay
        plant.spaceRequirement = .small
        plant.growthStage = .vegetative
        plant.healthStatus = .healthy
        plant.plantingDate = Calendar.current.date(byAdding: .week, value: -3, to: Date())
        plant.containerType = .indoor
        return plant
    }
    
    public static func createSickPlant() -> Plant {
        let plant = createPlant(name: "Wilting Lettuce", type: .vegetable, difficulty: .beginner)
        plant.healthStatus = .needsAttention
        plant.lastWatered = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        plant.notes = "Leaves are yellowing, possible overwatering"
        return plant
    }
    
    public static func createDatabasePlants() -> [Plant] {
        let plants = [
            createDatabasePlant(name: "Roma Tomato", type: .vegetable, difficulty: .intermediate),
            createDatabasePlant(name: "Thai Basil", type: .herb, difficulty: .beginner),
            createDatabasePlant(name: "Bell Pepper", type: .vegetable, difficulty: .intermediate),
            createDatabasePlant(name: "Mint", type: .herb, difficulty: .beginner),
            createDatabasePlant(name: "Lettuce", type: .vegetable, difficulty: .beginner),
            createDatabasePlant(name: "Cilantro", type: .herb, difficulty: .beginner),
            createDatabasePlant(name: "Cucumber", type: .vegetable, difficulty: .intermediate),
            createDatabasePlant(name: "Oregano", type: .herb, difficulty: .beginner),
            createDatabasePlant(name: "Spinach", type: .vegetable, difficulty: .beginner),
            createDatabasePlant(name: "Parsley", type: .herb, difficulty: .beginner)
        ]
        return plants
    }
    
    private static func createDatabasePlant(
        name: String,
        type: PlantType,
        difficulty: DifficultyLevel
    ) -> Plant {
        let plant = Plant(name: name, plantType: type, difficultyLevel: difficulty, isUserPlant: false)
        
        // Set common database plant properties
        switch type {
        case .vegetable:
            plant.sunlightRequirement = .fullSun
            plant.wateringFrequency = .daily
            plant.spaceRequirement = .medium
        case .herb:
            plant.sunlightRequirement = .partialSun
            plant.wateringFrequency = .everyOtherDay
            plant.spaceRequirement = .small
        default:
            plant.sunlightRequirement = .fullSun
            plant.wateringFrequency = .weekly
            plant.spaceRequirement = .medium
        }
        
        return plant
    }
    
    // MARK: - Reminder Factory
    
    public static func createReminder(
        title: String = "Test Reminder",
        message: String = "Test reminder message",
        type: ReminderType = .watering,
        frequency: ReminderFrequency = .daily,
        dueDate: Date = Date(),
        plant: Plant
    ) -> PlantReminder {
        return PlantReminder(
            title: title,
            message: message,
            reminderType: type,
            frequency: frequency,
            nextDueDate: dueDate,
            plant: plant
        )
    }
    
    public static func createWateringReminder(for plant: Plant, daysFromNow: Int = 0) -> PlantReminder {
        let dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return createReminder(
            title: "Water \(plant.name)",
            message: "Time to water your \(plant.name.lowercased())",
            type: .watering,
            frequency: .daily,
            dueDate: dueDate,
            plant: plant
        )
    }
    
    public static func createFertilizingReminder(for plant: Plant, daysFromNow: Int = 7) -> PlantReminder {
        let dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return createReminder(
            title: "Fertilize \(plant.name)",
            message: "Time to feed your \(plant.name.lowercased())",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: dueDate,
            plant: plant
        )
    }
    
    public static func createOverdueReminder(for plant: Plant) -> PlantReminder {
        let dueDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        let reminder = createWateringReminder(for: plant, daysFromNow: 0)
        reminder.nextDueDate = dueDate
        return reminder
    }
    
    // MARK: - Journal Entry Factory
    
    public static func createJournalEntry(
        title: String = "Test Entry",
        content: String = "Test journal content",
        type: JournalEntryType = .observation,
        plant: Plant
    ) -> JournalEntry {
        return JournalEntry(title: title, content: content, entryType: type, plant: plant)
    }
    
    public static func createProgressEntry(for plant: Plant) -> JournalEntry {
        return createJournalEntry(
            title: "Growth Progress",
            content: "Plant is showing healthy new growth with vibrant green leaves. No signs of pests or disease.",
            type: .progress,
            plant: plant
        )
    }
    
    public static func createPhotoEntry(for plant: Plant) -> JournalEntry {
        let entry = createJournalEntry(
            title: "Weekly Photo",
            content: "Weekly progress photo showing overall plant health.",
            type: .photo,
            plant: plant
        )
        entry.photoURLs = ["file://path/to/photo.jpg"]
        return entry
    }
    
    public static func createMaintenanceEntry(for plant: Plant) -> JournalEntry {
        return createJournalEntry(
            title: "Watering & Pruning",
            content: "Watered thoroughly and removed dead leaves. Added liquid fertilizer.",
            type: .maintenance,
            plant: plant
        )
    }
}

// MARK: - Test Scenarios

public struct TestScenarios {
    
    public static func createBeginnerUserWithFirstGarden() -> (User, Garden, [Plant]) {
        let user = TestDataFactory.createUser(skillLevel: .beginner)
        let garden = TestDataFactory.createIndoorHerbGarden()
        garden.user = user
        user.gardens.append(garden)
        
        let basil = TestDataFactory.createBasilPlant()
        let mint = TestDataFactory.createPlant(name: "Mint", type: .herb, difficulty: .beginner)
        
        basil.garden = garden
        mint.garden = garden
        garden.plants = [basil, mint]
        
        return (user, garden, [basil, mint])
    }
    
    public static func createExperiencedUserWithMultipleGardens() -> (User, [Garden], [Plant]) {
        let user = TestDataFactory.createAdvancedUser()
        
        let herbGarden = TestDataFactory.createIndoorHerbGarden()
        let vegetableGarden = TestDataFactory.createOutdoorVegetableGarden()
        
        herbGarden.user = user
        vegetableGarden.user = user
        user.gardens = [herbGarden, vegetableGarden]
        
        let basil = TestDataFactory.createBasilPlant()
        let tomato = TestDataFactory.createTomatoPlant()
        let sickPlant = TestDataFactory.createSickPlant()
        
        basil.garden = herbGarden
        tomato.garden = vegetableGarden
        sickPlant.garden = vegetableGarden
        
        herbGarden.plants = [basil]
        vegetableGarden.plants = [tomato, sickPlant]
        
        return (user, [herbGarden, vegetableGarden], [basil, tomato, sickPlant])
    }
    
    public static func createUserWithActiveReminders() -> (User, [Plant], [PlantReminder]) {
        let user = TestDataFactory.createUser()
        let garden = TestDataFactory.createGarden()
        garden.user = user
        user.gardens.append(garden)
        
        let tomato = TestDataFactory.createTomatoPlant()
        let basil = TestDataFactory.createBasilPlant()
        
        tomato.garden = garden
        basil.garden = garden
        garden.plants = [tomato, basil]
        
        let overdueReminder = TestDataFactory.createOverdueReminder(for: tomato)
        let upcomingReminder = TestDataFactory.createWateringReminder(for: basil, daysFromNow: 1)
        let fertilizeReminder = TestDataFactory.createFertilizingReminder(for: tomato, daysFromNow: 3)
        
        overdueReminder.user = user
        upcomingReminder.user = user
        fertilizeReminder.user = user
        
        user.reminders = [overdueReminder, upcomingReminder, fertilizeReminder]
        tomato.reminders = [overdueReminder, fertilizeReminder]
        basil.reminders = [upcomingReminder]
        
        return (user, [tomato, basil], [overdueReminder, upcomingReminder, fertilizeReminder])
    }
    
    public static func createUserWithJournalEntries() -> (User, Plant, [JournalEntry]) {
        let user = TestDataFactory.createUser()
        let garden = TestDataFactory.createGarden()
        garden.user = user
        user.gardens.append(garden)
        
        let tomato = TestDataFactory.createTomatoPlant()
        tomato.garden = garden
        garden.plants = [tomato]
        
        let progressEntry = TestDataFactory.createProgressEntry(for: tomato)
        let photoEntry = TestDataFactory.createPhotoEntry(for: tomato)
        let maintenanceEntry = TestDataFactory.createMaintenanceEntry(for: tomato)
        
        progressEntry.user = user
        photoEntry.user = user
        maintenanceEntry.user = user
        
        user.journalEntries = [progressEntry, photoEntry, maintenanceEntry]
        tomato.journalEntries = [progressEntry, photoEntry, maintenanceEntry]
        
        return (user, tomato, [progressEntry, photoEntry, maintenanceEntry])
    }
}

// MARK: - Test Constants

public struct TestConstants {
    
    public static let defaultEmail = "test@example.com"
    public static let defaultDisplayName = "Test User"
    public static let defaultGardenName = "Test Garden"
    public static let defaultPlantName = "Test Plant"
    
    public static let samplePlantNames = [
        "Cherry Tomato", "Sweet Basil", "Bell Pepper", "Lettuce",
        "Mint", "Cilantro", "Cucumber", "Oregano", "Spinach", "Parsley"
    ]
    
    public static let sampleGardenNames = [
        "Kitchen Herbs", "Backyard Vegetables", "Window Garden",
        "Greenhouse Collection", "Patio Container Garden"
    ]
    
    public static let sampleReminderTitles = [
        "Water Plants", "Check for Pests", "Fertilize Garden",
        "Prune Dead Leaves", "Harvest Ready Vegetables"
    ]
    
    public static let sampleJournalTitles = [
        "Weekly Progress Check", "Watering Schedule", "Growth Milestone",
        "Pest Treatment", "Harvest Day", "Seasonal Preparation"
    ]
}