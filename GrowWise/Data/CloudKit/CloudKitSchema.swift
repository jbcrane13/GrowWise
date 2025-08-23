import Foundation
import CloudKit
import GrowWiseModels

/// CloudKit schema definitions and record types for GrowWise
struct CloudKitSchema {
    
    // MARK: - Record Types
    
    static let userRecordType = "User"
    static let plantRecordType = "Plant"
    static let gardenRecordType = "Garden"
    static let plantReminderRecordType = "PlantReminder"
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
        case plantType = "plantType"
        case difficultyLevel = "difficultyLevel"
        case isUserPlant = "isUserPlant"
        case plantingDate = "plantingDate"
        case harvestDate = "harvestDate"
        case sunlightRequirement = "sunlightRequirement"
        case wateringFrequency = "wateringFrequency"
        case spaceRequirement = "spaceRequirement"
        case growthStage = "growthStage"
        case lastWatered = "lastWatered"
        case lastFertilized = "lastFertilized"
        case lastPruned = "lastPruned"
        case healthStatus = "healthStatus"
        case notes = "notes"
        case photoURLs = "photoURLs"
        case gardenLocation = "gardenLocation"
        case containerType = "containerType"
        case gardenReference = "gardenReference"
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
    
    enum PlantReminderFields: String, CaseIterable {
        case title = "title"
        case message = "message"
        case reminderType = "reminderType"
        case frequency = "frequency"
        case nextDueDate = "nextDueDate"
        case lastCompletedDate = "lastCompletedDate"
        case isEnabled = "isEnabled"
        case isRecurring = "isRecurring"
        case notificationIdentifier = "notificationIdentifier"
        case snoozeCount = "snoozeCount"
        case maxSnoozeCount = "maxSnoozeCount"
        case createdDate = "createdDate"
        case lastModified = "lastModified"
        case plantReference = "plantReference"
        case userReference = "userReference"
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
            plantReminderRecordType,
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
        
        record[UserFields.skillLevel.rawValue] = user.skillLevel.rawValue
        record[UserFields.hardinessZone.rawValue] = user.hardinessZone
        
        // Combine location fields
        let locationComponents = [user.city, user.state, user.country].compactMap { $0 }
        if !locationComponents.isEmpty {
            record[UserFields.location.rawValue] = locationComponents.joined(separator: ", ")
        }
        
        record[UserFields.createdDate.rawValue] = user.createdDate
        record[UserFields.lastActiveDate.rawValue] = user.lastLoginDate
        
        // Note: These fields don't exist in the current User model
        // record[UserFields.gardenType.rawValue] = user.gardenType
        // record[UserFields.profileImageData.rawValue] = user.profileImageData
        // record[UserFields.preferences.rawValue] = user.preferences
        // record[UserFields.notificationSettings.rawValue] = user.notificationSettings
        
        return record
    }
    
    static func createPlantRecord(from plant: Plant) -> CKRecord {
        let record = CKRecord(recordType: plantRecordType)
        
        record[PlantFields.name.rawValue] = plant.name
        record[PlantFields.scientificName.rawValue] = plant.scientificName
        record[PlantFields.plantType.rawValue] = plant.plantType?.rawValue
        record[PlantFields.difficultyLevel.rawValue] = plant.difficultyLevel?.rawValue
        record[PlantFields.isUserPlant.rawValue] = plant.isUserPlant
        record[PlantFields.plantingDate.rawValue] = plant.plantingDate
        record[PlantFields.harvestDate.rawValue] = plant.harvestDate
        record[PlantFields.sunlightRequirement.rawValue] = plant.sunlightRequirement?.rawValue
        record[PlantFields.wateringFrequency.rawValue] = plant.wateringFrequency?.rawValue
        record[PlantFields.spaceRequirement.rawValue] = plant.spaceRequirement?.rawValue
        record[PlantFields.growthStage.rawValue] = plant.growthStage?.rawValue
        record[PlantFields.lastWatered.rawValue] = plant.lastWatered
        record[PlantFields.lastFertilized.rawValue] = plant.lastFertilized
        record[PlantFields.lastPruned.rawValue] = plant.lastPruned
        record[PlantFields.healthStatus.rawValue] = plant.healthStatus?.rawValue
        record[PlantFields.notes.rawValue] = plant.notes
        record[PlantFields.photoURLs.rawValue] = plant.photoURLs
        record[PlantFields.gardenLocation.rawValue] = plant.gardenLocation
        record[PlantFields.containerType.rawValue] = plant.containerType?.rawValue
        
        // Add garden reference if exists
        if let garden = plant.garden, let gardenId = garden.id {
            let gardenReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: gardenId.uuidString), action: .deleteSelf)
            record[PlantFields.gardenReference.rawValue] = gardenReference
        }
        
        return record
    }
    
    static func createGardenRecord(from garden: Garden) -> CKRecord {
        let record = CKRecord(recordType: gardenRecordType)
        
        record[GardenFields.name.rawValue] = garden.name
        record[GardenFields.sunExposure.rawValue] = garden.sunExposure?.rawValue
        record[GardenFields.gardenType.rawValue] = garden.gardenType?.rawValue
        record[GardenFields.soilType.rawValue] = garden.soilType?.rawValue
        record[GardenFields.hardinessZone.rawValue] = garden.hardinessZone
        record[GardenFields.createdDate.rawValue] = garden.createdDate
        record[GardenFields.lastModifiedDate.rawValue] = garden.lastModified
        record[GardenFields.layout.rawValue] = garden.layout
        
        // Combine location from lat/lng if available
        if let lat = garden.latitude, let lng = garden.longitude {
            record[GardenFields.location.rawValue] = "\(lat),\(lng)"
        }
        
        // Size from spaceAvailable
        record[GardenFields.size.rawValue] = garden.spaceAvailable?.rawValue
        
        // Add owner reference (user)
        if let user = garden.user {
            let userReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: user.id.uuidString), action: .deleteSelf)
            record[GardenFields.ownerReference.rawValue] = userReference
        }
        
        // Note: These fields don't exist in the current Garden model
        // record[GardenFields.gardenDescription.rawValue] = garden.gardenDescription
        // record[GardenFields.gardenImageData.rawValue] = garden.gardenImageData
        // record[GardenFields.notes.rawValue] = garden.notes
        
        return record
    }
    
    static func createPlantReminderRecord(from reminder: PlantReminder) -> CKRecord {
        let record = CKRecord(recordType: plantReminderRecordType)
        
        record[PlantReminderFields.title.rawValue] = reminder.title
        record[PlantReminderFields.message.rawValue] = reminder.message
        record[PlantReminderFields.reminderType.rawValue] = reminder.reminderType.rawValue
        record[PlantReminderFields.nextDueDate.rawValue] = reminder.nextDueDate
        record[PlantReminderFields.lastCompletedDate.rawValue] = reminder.lastCompletedDate
        record[PlantReminderFields.isEnabled.rawValue] = reminder.isEnabled
        record[PlantReminderFields.isRecurring.rawValue] = reminder.isRecurring
        record[PlantReminderFields.notificationIdentifier.rawValue] = reminder.notificationIdentifier
        record[PlantReminderFields.snoozeCount.rawValue] = reminder.snoozeCount
        record[PlantReminderFields.maxSnoozeCount.rawValue] = reminder.maxSnoozeCount
        record[PlantReminderFields.createdDate.rawValue] = reminder.createdDate
        record[PlantReminderFields.lastModified.rawValue] = reminder.lastModified
        
        // Encode the frequency enum using rawValue
        record[PlantReminderFields.frequency.rawValue] = reminder.frequency.rawValue
        
        // Add plant reference
        if let plant = reminder.plant, let plantId = plant.id {
            let plantReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: plantId.uuidString), action: .deleteSelf)
            record[PlantReminderFields.plantReference.rawValue] = plantReference
        }
        
        // Add user reference
        if let user = reminder.user {
            let userReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: user.id.uuidString), action: .deleteSelf)
            record[PlantReminderFields.userReference.rawValue] = userReference
        }
        
        return record
    }
    
    static func createJournalEntryRecord(from entry: JournalEntry) -> CKRecord {
        let record = CKRecord(recordType: journalEntryRecordType)
        
        record[JournalEntryFields.title.rawValue] = entry.title
        record[JournalEntryFields.content.rawValue] = entry.content
        record[JournalEntryFields.entryDate.rawValue] = entry.entryDate
        record[JournalEntryFields.createdDate.rawValue] = entry.entryDate // Using entryDate as created date
        record[JournalEntryFields.lastModifiedDate.rawValue] = entry.lastModified
        record[JournalEntryFields.entryType.rawValue] = entry.entryType.rawValue
        record[JournalEntryFields.mood.rawValue] = entry.mood?.rawValue
        record[JournalEntryFields.tags.rawValue] = entry.tags
        record[JournalEntryFields.photos.rawValue] = entry.photoURLs
        
        // Environmental data - encode as string if available
        if let temp = entry.temperature {
            record[JournalEntryFields.weather.rawValue] = "temp:\(temp)"
        }
        if let condition = entry.weatherConditions {
            record[JournalEntryFields.weather.rawValue] = condition.rawValue
        }
        
        // Measurements - encode as JSON string
        var measurements: [String: Any] = [:]
        if let height = entry.heightMeasurement {
            measurements["height"] = height
        }
        if let width = entry.widthMeasurement {
            measurements["width"] = width
        }
        if !measurements.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: measurements),
               let jsonString = String(data: data, encoding: .utf8) {
                record[JournalEntryFields.measurements.rawValue] = jsonString
            }
        }
        
        // Add user reference
        if let user = entry.user {
            let userReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: user.id.uuidString), action: .deleteSelf)
            record[JournalEntryFields.userReference.rawValue] = userReference
        }
        
        // Add plant reference (optional) - now references Plant directly, not UserPlant
        if let plant = entry.plant, let plantId = plant.id {
            let plantReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: plantId.uuidString), action: .deleteSelf)
            record[JournalEntryFields.userPlantReference.rawValue] = plantReference
        }
        
        return record
    }
    
    // MARK: - Subscription Setup
    
    static func setupCloudKitSubscriptions() async throws {
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        let database = container.privateCloudDatabase
        
        // User plants subscription (Plant records with isUserPlant = true)
        let userPlantsPredicate = NSPredicate(format: "isUserPlant == 1")
        let userPlantsSubscription = CKQuerySubscription(
            recordType: plantRecordType,
            predicate: userPlantsPredicate,
            subscriptionID: "user-plants-changes"
        )
        
        let userPlantsNotification = CKSubscription.NotificationInfo()
        userPlantsNotification.alertBody = "Your plant data has been updated"
        userPlantsNotification.shouldSendContentAvailable = true
        userPlantsSubscription.notificationInfo = userPlantsNotification
        
        // Plant reminders subscription
        let remindersPredicate = NSPredicate(format: "isEnabled == 1")
        let remindersSubscription = CKQuerySubscription(
            recordType: plantReminderRecordType,
            predicate: remindersPredicate,
            subscriptionID: "active-plant-reminders"
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
