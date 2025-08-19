import Foundation
import CoreData
import CloudKit

/// Core Data manager with CloudKit synchronization
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "GrowWiseDataModel")
        
        // Configure for CloudKit
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // CloudKit configuration
        storeDescription?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.growwise.gardening"
        )
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - CloudKit Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    func delete<T: NSManagedObject>(_ object: T) {
        context.delete(object)
        save()
    }
    
    // MARK: - Data Validation
    
    func validatePlantData(_ plant: Plant) -> [String] {
        var errors: [String] = []
        
        if plant.name?.isEmpty ?? true {
            errors.append("Plant name is required")
        }
        
        if plant.wateringFrequencyDays <= 0 {
            errors.append("Watering frequency must be positive")
        }
        
        if !["beginner", "intermediate", "advanced"].contains(plant.difficultyLevel) {
            errors.append("Invalid difficulty level")
        }
        
        if !["low", "medium", "high"].contains(plant.maintenanceLevel) {
            errors.append("Invalid maintenance level")
        }
        
        return errors
    }
    
    func validateUserPlant(_ userPlant: UserPlant) -> [String] {
        var errors: [String] = []
        
        if userPlant.plantingDate > Date() {
            errors.append("Planting date cannot be in the future")
        }
        
        if let lastWatered = userPlant.lastWateredDate,
           lastWatered > Date() {
            errors.append("Last watered date cannot be in the future")
        }
        
        if !["healthy", "stressed", "diseased", "dormant"].contains(userPlant.healthStatus) {
            errors.append("Invalid health status")
        }
        
        return errors
    }
    
    // MARK: - CloudKit Integration
    
    func checkCloudKitAccountStatus() async -> CKAccountStatus {
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        do {
            return try await container.accountStatus()
        } catch {
            print("CloudKit account status error: \(error)")
            return .noAccount
        }
    }
    
    func requestCloudKitPermissions() async -> Bool {
        let container = CKContainer(identifier: "iCloud.com.growwise.gardening")
        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            return status == .granted
        } catch {
            print("CloudKit permissions error: \(error)")
            return false
        }
    }
    
    // MARK: - Sample Data Loading
    
    func loadSampleDataIfNeeded() {
        let request: NSFetchRequest<Plant> = Plant.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                PlantDatabase.loadSamplePlants(into: context)
                print("Loaded sample plant data")
            }
        } catch {
            print("Error checking for existing plants: \(error)")
        }
    }
    
    // MARK: - Fetch Request Helpers
    
    func fetchPlants(category: String? = nil, difficultyLevel: String? = nil) -> NSFetchRequest<Plant> {
        let request: NSFetchRequest<Plant> = Plant.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        if let difficultyLevel = difficultyLevel {
            predicates.append(NSPredicate(format: "difficultyLevel == %@", difficultyLevel))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Plant.name, ascending: true)]
        return request
    }
    
    func fetchUserPlants(for garden: Garden) -> NSFetchRequest<UserPlant> {
        let request: NSFetchRequest<UserPlant> = UserPlant.fetchRequest()
        request.predicate = NSPredicate(format: "garden == %@ AND isActive == YES", garden)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserPlant.plantingDate, ascending: false)]
        return request
    }
    
    func fetchActiveReminders() -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.nextDueDate, ascending: true)]
        return request
    }
    
    func fetchOverdueReminders() -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        let now = Date()
        request.predicate = NSPredicate(format: "isActive == YES AND isCompleted == NO AND nextDueDate < %@", now as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.nextDueDate, ascending: true)]
        return request
    }
    
    func fetchJournalEntries(for userPlant: UserPlant? = nil, limit: Int = 20) -> NSFetchRequest<JournalEntry> {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        if let userPlant = userPlant {
            request.predicate = NSPredicate(format: "userPlant == %@", userPlant)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.entryDate, ascending: false)]
        request.fetchLimit = limit
        return request
    }
}

// MARK: - Core Data Extensions

extension NSManagedObjectContext {
    func saveIfChanged() {
        if hasChanges {
            do {
                try save()
            } catch {
                print("Context save error: \(error)")
            }
        }
    }
}