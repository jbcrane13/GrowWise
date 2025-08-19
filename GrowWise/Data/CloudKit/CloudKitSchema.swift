import Foundation
import CloudKit

/// CloudKit schema definitions and record types for GrowWise
struct CloudKitSchema {
    
    // MARK: - Record Types
    
    static let userRecordType = "User"
    static let plantRecordType = "Plant"
    static let gardenRecordType = "Garden"
    static let userPlantRecordType = "UserPlant"
    static let reminderRecordType = "Reminder"
    static let journalEntryRecordType = "JournalEntry"
    
    // MARK: - Field Names
    
    enum UserFields: String, CaseIterable {
        case skillLevel = "skillLevel"
        case hardinessZone = "hardinessZone"
        case location = "location"
        case gardenType = "gardenType"
        case preferences = "preferences"
        case createdDate = "createdDate"
        case lastActiveDate = "lastActiveDate"
        case profileImageData = "profileImageData"
        case notificationSettings = "notificationSettings"
    }
    
    enum PlantFields: String, CaseIterable {
        case name = "name"
        case scientificName = "scientificName"
        case plantDescription = "plantDescription"
        case category = "category"
        case difficultyLevel = "difficultyLevel"
        case maintenanceLevel = "maintenanceLevel"
        case wateringFrequencyDays = "wateringFrequencyDays"
        case sunRequirement = "sunRequirement"
        case soilType = "soilType"
        case temperatureMin = "temperatureMin"
        case temperatureMax = "temperatureMax"
        case hardinessZones = "hardinessZones"
        case growthStages = "growthStages"
        case harvestTimeWeeks = "harvestTimeWeeks"
        case commonProblems = "commonProblems"
        case careTips = "careTips"
        case plantImageURL = "plantImageURL"
        case seasonalCare = "seasonalCare"
        case companionPlants = "companionPlants"
        case fertilizingFrequencyWeeks = "fertilizingFrequencyWeeks"
        case pruningFrequencyWeeks = "pruningFrequencyWeeks"
    }
    
    enum GardenFields: String, CaseIterable {
        case name = "name"
        case gardenDescription = "gardenDescription"
        case size = "size"
        case sunExposure = "sunExposure"
        case gardenType = "gardenType"
        case location = "location"
        case soilType = "soilType"
        case hardinessZone = "hardinessZone"
        case createdDate = "createdDate"
        case lastModifiedDate = "lastModifiedDate"
        case gardenImageData = "gardenImageData"
        case layout = "layout"
        case notes = "notes"
        case ownerReference = "ownerReference"
    }
    
    enum UserPlantFields: String, CaseIterable {
        case customName = "customName"
        case plantingDate = "plantingDate"
        case lastWateredDate = "lastWateredDate"
        case lastFertilizedDate = "lastFertilizedDate"
        case lastPrunedDate = "lastPrunedDate"
        case healthStatus = "healthStatus"
        case currentGrowthStage = "currentGrowthStage"
        case notes = "notes"
        case location = "location"
        case plantImageData = "plantImageData"
        case isActive = "isActive"
        case harvestLog = "harvestLog"
        case customWateringFrequency = "customWateringFrequency"
        case customFertilizingFrequency = "customFertilizingFrequency"
        case tags = "tags"
        case plantReference = "plantReference"
        case gardenReference = "gardenReference"
    }
    
    enum ReminderFields: String, CaseIterable {
        case type = "type"
        case title = "title"
        case reminderDescription = "reminderDescription"
        case frequencyDays = "frequencyDays"
        case nextDueDate = "nextDueDate"
        case lastCompletedDate = "lastCompletedDate"
        case isCompleted = "isCompleted"
        case isActive = "isActive"
        case priority = "priority"
        case notes = "notes"
        case createdDate = "createdDate"
        case notificationEnabled = "notificationEnabled"
        case customInstructions = "customInstructions"
        case userPlantReference = "userPlantReference"
    }
    
    enum JournalEntryFields: String, CaseIterable {
        case title = "title"
        case content = "content"
        case entryDate = "entryDate"
        case createdDate = "createdDate"
        case lastModifiedDate = "lastModifiedDate"
        case entryType = "entryType"
        case tags = "tags"
        case weather = "weather"
        case mood = "mood"
        case photos = "photos"
        case measurements = "measurements"
        case userReference = "userReference"
        case userPlantReference = "userPlantReference"
    }
    
    // MARK: - Schema Validation
    
    static func validateCloudKitSchema() async throws {
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        let database = container.privateCloudDatabase
        
        // Validate that all required record types exist
        let recordTypes = [
            userRecordType,
            plantRecordType,
            gardenRecordType,
            userPlantRecordType,
            reminderRecordType,
            journalEntryRecordType
        ]
        
        for recordType in recordTypes {
            do {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: false))
                _ = try await database.records(matching: query)
                print("✅ Record type '\(recordType)' exists")
            } catch {
                print("❌ Record type '\(recordType)' validation failed: \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Record Creation Helpers
    
    static func createUserRecord(from user: User) -> CKRecord {
        let record = CKRecord(recordType: userRecordType)
        
        record[UserFields.skillLevel.rawValue] = user.skillLevel
        record[UserFields.hardinessZone.rawValue] = user.hardinessZone
        record[UserFields.location.rawValue] = user.location
        record[UserFields.gardenType.rawValue] = user.gardenType
        record[UserFields.createdDate.rawValue] = user.createdDate
        record[UserFields.lastActiveDate.rawValue] = user.lastActiveDate
        record[UserFields.profileImageData.rawValue] = user.profileImageData
        
        return record
    }
    
    static func createPlantRecord(from plant: Plant) -> CKRecord {
        let record = CKRecord(recordType: plantRecordType)
        
        record[PlantFields.name.rawValue] = plant.name
        record[PlantFields.scientificName.rawValue] = plant.scientificName
        record[PlantFields.plantDescription.rawValue] = plant.plantDescription
        record[PlantFields.category.rawValue] = plant.category
        record[PlantFields.difficultyLevel.rawValue] = plant.difficultyLevel
        record[PlantFields.maintenanceLevel.rawValue] = plant.maintenanceLevel
        record[PlantFields.wateringFrequencyDays.rawValue] = plant.wateringFrequencyDays
        record[PlantFields.sunRequirement.rawValue] = plant.sunRequirement
        record[PlantFields.soilType.rawValue] = plant.soilType
        record[PlantFields.temperatureMin.rawValue] = plant.temperatureMin
        record[PlantFields.temperatureMax.rawValue] = plant.temperatureMax
        record[PlantFields.hardinessZones.rawValue] = plant.hardinessZones
        record[PlantFields.harvestTimeWeeks.rawValue] = plant.harvestTimeWeeks
        record[PlantFields.plantImageURL.rawValue] = plant.plantImageURL
        record[PlantFields.fertilizingFrequencyWeeks.rawValue] = plant.fertilizingFrequencyWeeks
        record[PlantFields.pruningFrequencyWeeks.rawValue] = plant.pruningFrequencyWeeks
        
        return record
    }
    
    static func createGardenRecord(from garden: Garden) -> CKRecord {
        let record = CKRecord(recordType: gardenRecordType)
        
        record[GardenFields.name.rawValue] = garden.name
        record[GardenFields.gardenDescription.rawValue] = garden.gardenDescription
        record[GardenFields.size.rawValue] = garden.size
        record[GardenFields.sunExposure.rawValue] = garden.sunExposure
        record[GardenFields.gardenType.rawValue] = garden.gardenType
        record[GardenFields.location.rawValue] = garden.location
        record[GardenFields.soilType.rawValue] = garden.soilType
        record[GardenFields.hardinessZone.rawValue] = garden.hardinessZone
        record[GardenFields.createdDate.rawValue] = garden.createdDate
        record[GardenFields.lastModifiedDate.rawValue] = garden.lastModifiedDate
        record[GardenFields.gardenImageData.rawValue] = garden.gardenImageData
        record[GardenFields.notes.rawValue] = garden.notes
        
        // Add owner reference
        if let owner = garden.owner {
            let ownerReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: owner.id?.uuidString ?? ""), action: .deleteSelf)
            record[GardenFields.ownerReference.rawValue] = ownerReference
        }
        
        return record
    }
    
    static func createUserPlantRecord(from userPlant: UserPlant) -> CKRecord {
        let record = CKRecord(recordType: userPlantRecordType)
        
        record[UserPlantFields.customName.rawValue] = userPlant.customName
        record[UserPlantFields.plantingDate.rawValue] = userPlant.plantingDate
        record[UserPlantFields.lastWateredDate.rawValue] = userPlant.lastWateredDate
        record[UserPlantFields.lastFertilizedDate.rawValue] = userPlant.lastFertilizedDate
        record[UserPlantFields.lastPrunedDate.rawValue] = userPlant.lastPrunedDate
        record[UserPlantFields.healthStatus.rawValue] = userPlant.healthStatus
        record[UserPlantFields.currentGrowthStage.rawValue] = userPlant.currentGrowthStage
        record[UserPlantFields.notes.rawValue] = userPlant.notes
        record[UserPlantFields.location.rawValue] = userPlant.location
        record[UserPlantFields.plantImageData.rawValue] = userPlant.plantImageData
        record[UserPlantFields.isActive.rawValue] = userPlant.isActive
        record[UserPlantFields.customWateringFrequency.rawValue] = userPlant.customWateringFrequency
        record[UserPlantFields.customFertilizingFrequency.rawValue] = userPlant.customFertilizingFrequency
        
        // Add plant reference
        if let plant = userPlant.plant {
            let plantReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: plant.id?.uuidString ?? ""), action: .deleteSelf)
            record[UserPlantFields.plantReference.rawValue] = plantReference
        }
        
        // Add garden reference
        if let garden = userPlant.garden {
            let gardenReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: garden.id?.uuidString ?? ""), action: .deleteSelf)
            record[UserPlantFields.gardenReference.rawValue] = gardenReference
        }
        
        return record
    }
    
    static func createReminderRecord(from reminder: Reminder) -> CKRecord {
        let record = CKRecord(recordType: reminderRecordType)
        
        record[ReminderFields.type.rawValue] = reminder.type
        record[ReminderFields.title.rawValue] = reminder.title
        record[ReminderFields.reminderDescription.rawValue] = reminder.reminderDescription
        record[ReminderFields.frequencyDays.rawValue] = reminder.frequencyDays
        record[ReminderFields.nextDueDate.rawValue] = reminder.nextDueDate
        record[ReminderFields.lastCompletedDate.rawValue] = reminder.lastCompletedDate
        record[ReminderFields.isCompleted.rawValue] = reminder.isCompleted
        record[ReminderFields.isActive.rawValue] = reminder.isActive
        record[ReminderFields.priority.rawValue] = reminder.priority
        record[ReminderFields.notes.rawValue] = reminder.notes
        record[ReminderFields.createdDate.rawValue] = reminder.createdDate
        record[ReminderFields.notificationEnabled.rawValue] = reminder.notificationEnabled
        record[ReminderFields.customInstructions.rawValue] = reminder.customInstructions
        
        // Add user plant reference
        if let userPlant = reminder.userPlant {
            let userPlantReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: userPlant.id?.uuidString ?? ""), action: .deleteSelf)
            record[ReminderFields.userPlantReference.rawValue] = userPlantReference
        }
        
        return record
    }
    
    static func createJournalEntryRecord(from entry: JournalEntry) -> CKRecord {
        let record = CKRecord(recordType: journalEntryRecordType)
        
        record[JournalEntryFields.title.rawValue] = entry.title
        record[JournalEntryFields.content.rawValue] = entry.content
        record[JournalEntryFields.entryDate.rawValue] = entry.entryDate
        record[JournalEntryFields.createdDate.rawValue] = entry.createdDate
        record[JournalEntryFields.lastModifiedDate.rawValue] = entry.lastModifiedDate
        record[JournalEntryFields.entryType.rawValue] = entry.entryType
        record[JournalEntryFields.weather.rawValue] = entry.weather
        record[JournalEntryFields.mood.rawValue] = entry.mood
        
        // Add user reference
        if let user = entry.user {
            let userReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: user.id?.uuidString ?? ""), action: .deleteSelf)
            record[JournalEntryFields.userReference.rawValue] = userReference
        }
        
        // Add user plant reference (optional)
        if let userPlant = entry.userPlant {
            let userPlantReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: userPlant.id?.uuidString ?? ""), action: .deleteSelf)
            record[JournalEntryFields.userPlantReference.rawValue] = userPlantReference
        }
        
        return record
    }
    
    // MARK: - Subscription Setup
    
    static func setupCloudKitSubscriptions() async throws {
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        let database = container.privateCloudDatabase
        
        // User plants subscription
        let userPlantsPredicate = NSPredicate(value: true)
        let userPlantsSubscription = CKQuerySubscription(
            recordType: userPlantRecordType,
            predicate: userPlantsPredicate,
            subscriptionID: "user-plants-changes"
        )
        
        let userPlantsNotification = CKSubscription.NotificationInfo()
        userPlantsNotification.alertBody = "Your plant data has been updated"
        userPlantsNotification.shouldSendContentAvailable = true
        userPlantsSubscription.notificationInfo = userPlantsNotification
        
        // Reminders subscription
        let remindersPredicate = NSPredicate(format: "isActive == 1")
        let remindersSubscription = CKQuerySubscription(
            recordType: reminderRecordType,
            predicate: remindersPredicate,
            subscriptionID: "active-reminders"
        )
        
        let remindersNotification = CKSubscription.NotificationInfo()
        remindersNotification.alertBody = "You have garden reminders due"
        remindersNotification.shouldSendContentAvailable = true
        remindersSubscription.notificationInfo = remindersNotification
        
        do {
            _ = try await database.save(userPlantsSubscription)
            _ = try await database.save(remindersSubscription)
            print("✅ CloudKit subscriptions created successfully")
        } catch {
            print("❌ Failed to create CloudKit subscriptions: \(error)")
            throw error
        }
    }
}