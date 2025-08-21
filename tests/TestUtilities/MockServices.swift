import Foundation
import SwiftData
import UserNotifications
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - Mock DataService

@MainActor
public final class MockDataService: ObservableObject {
    
    // In-memory storage for testing
    private var users: [User] = []
    private var gardens: [Garden] = []
    private var plants: [Plant] = []
    private var reminders: [PlantReminder] = []
    private var journalEntries: [JournalEntry] = []
    
    public var shouldFailOperations = false
    public var operationDelay: TimeInterval = 0
    
    public init() {}
    
    // MARK: - User Management
    
    public func createUser(email: String, displayName: String, skillLevel: GardeningSkillLevel) throws -> User {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        
        let user = User(email: email, displayName: displayName, skillLevel: skillLevel)
        users.append(user)
        return user
    }
    
    public func getCurrentUser() -> User? {
        return users.last // Return most recently created user
    }
    
    public func updateUser(_ user: User) throws {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        user.lastModified = Date()
    }
    
    // MARK: - Garden Management
    
    public func createGarden(name: String, type: GardenType, isIndoor: Bool) throws -> Garden {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        
        let garden = Garden(name: name, gardenType: type, isIndoor: isIndoor)
        if let currentUser = getCurrentUser() {
            garden.user = currentUser
            currentUser.gardens.append(garden)
        }
        gardens.append(garden)
        return garden
    }
    
    public func fetchGardens() -> [Garden] {
        return gardens.sorted { $0.name < $1.name }
    }
    
    public func deleteGarden(_ garden: Garden) throws {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        gardens.removeAll { $0.id == garden.id }
    }
    
    // MARK: - Plant Management
    
    public func createPlant(
        name: String,
        type: PlantType,
        difficultyLevel: DifficultyLevel = .beginner,
        garden: Garden? = nil
    ) throws -> Plant {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        
        let plant = Plant(name: name, plantType: type, difficultyLevel: difficultyLevel)
        if let garden = garden {
            plant.garden = garden
            garden.plants.append(plant)
        }
        plants.append(plant)
        return plant
    }
    
    public func fetchPlants(for garden: Garden? = nil) -> [Plant] {
        if let garden = garden {
            return plants.filter { $0.garden?.id == garden.id }
        }
        return plants.filter { $0.isUserPlant }
    }
    
    public func fetchPlantDatabase() -> [Plant] {
        return plants.filter { !$0.isUserPlant }
    }
    
    public func updatePlant(_ plant: Plant) throws {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        // No-op for mock
    }
    
    public func deletePlant(_ plant: Plant) throws {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        plants.removeAll { $0.id == plant.id }
    }
    
    // MARK: - Reminder Management
    
    public func createReminder(
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        dueDate: Date,
        plant: Plant
    ) throws -> PlantReminder {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        
        let reminder = PlantReminder(
            title: title,
            message: message,
            reminderType: type,
            frequency: frequency,
            nextDueDate: dueDate,
            plant: plant
        )
        
        if let currentUser = getCurrentUser() {
            reminder.user = currentUser
            currentUser.reminders.append(reminder)
        }
        
        plant.reminders.append(reminder)
        reminders.append(reminder)
        return reminder
    }
    
    public func fetchActiveReminders() -> [PlantReminder] {
        let now = Date()
        return reminders.filter { $0.isEnabled && $0.nextDueDate <= now }
    }
    
    public func fetchUpcomingReminders(days: Int = 7) -> [PlantReminder] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        return reminders.filter {
            $0.isEnabled && $0.nextDueDate > now && $0.nextDueDate <= futureDate
        }
    }
    
    public func completeReminder(_ reminder: PlantReminder) throws {
        if shouldFailOperations {
            throw MockDataServiceError.operationFailed
        }
        reminder.markCompleted()
    }
    
    // MARK: - Search and Filter
    
    public func searchPlants(query: String) -> [Plant] {
        let lowercaseQuery = query.lowercased()
        return plants.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            ($0.scientificName?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    public func filterPlants(
        by type: PlantType? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        sunlightRequirement: SunlightLevel? = nil
    ) -> [Plant] {
        return plants.filter { plant in
            (type == nil || plant.plantType == type) &&
            (difficultyLevel == nil || plant.difficultyLevel == difficultyLevel) &&
            (sunlightRequirement == nil || plant.sunlightRequirement == sunlightRequirement)
        }
    }
    
    // MARK: - Statistics
    
    public func getGardeningStats() -> GardeningStats {
        let totalPlants = plants.filter { $0.isUserPlant }.count
        let healthyPlants = plants.filter { $0.isUserPlant && $0.healthStatus == .healthy }.count
        let activeReminders = fetchActiveReminders().count
        let totalJournalEntries = journalEntries.count
        
        return GardeningStats(
            totalPlants: totalPlants,
            healthyPlants: healthyPlants,
            activeReminders: activeReminders,
            totalJournalEntries: totalJournalEntries
        )
    }
    
    // MARK: - Test Utilities
    
    public func reset() {
        users.removeAll()
        gardens.removeAll()
        plants.removeAll()
        reminders.removeAll()
        journalEntries.removeAll()
        shouldFailOperations = false
        operationDelay = 0
    }
    
    public func seedTestData() {
        // Create test user
        let user = try! createUser(email: "test@example.com", displayName: "Test User", skillLevel: .intermediate)
        
        // Create test gardens
        let vegetableGarden = try! createGarden(name: "Vegetable Garden", type: .vegetable, isIndoor: false)
        let herbGarden = try! createGarden(name: "Herb Garden", type: .herb, isIndoor: true)
        
        // Create test plants
        let tomato = try! createPlant(name: "Cherry Tomato", type: .vegetable, difficultyLevel: .beginner, garden: vegetableGarden)
        let basil = try! createPlant(name: "Sweet Basil", type: .herb, difficultyLevel: .beginner, garden: herbGarden)
        let pepper = try! createPlant(name: "Bell Pepper", type: .vegetable, difficultyLevel: .intermediate, garden: vegetableGarden)
        
        // Create test reminders
        let waterTomato = try! createReminder(
            title: "Water Tomato",
            message: "Time to water your cherry tomato",
            type: .watering,
            frequency: .daily,
            dueDate: Date().addingTimeInterval(-3600), // 1 hour ago
            plant: tomato
        )
        
        let fertilizeBasil = try! createReminder(
            title: "Fertilize Basil",
            message: "Feed your basil plant",
            type: .fertilizing,
            frequency: .weekly,
            dueDate: Date().addingTimeInterval(86400), // Tomorrow
            plant: basil
        )
    }
}

// MARK: - Mock NotificationService

@MainActor
public final class MockNotificationService: ObservableObject {
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var isEnabled: Bool = false
    
    public var shouldFailPermissionRequest = false
    public var shouldFailScheduling = false
    public var scheduledNotifications: [MockNotificationRequest] = []
    public var deliveredNotifications: [MockNotificationRequest] = []
    
    public init() {}
    
    // MARK: - Permission Management
    
    public func requestPermission() async throws {
        if shouldFailPermissionRequest {
            throw MockNotificationError.permissionDenied
        }
        authorizationStatus = .authorized
        isEnabled = true
    }
    
    public func checkAuthorizationStatus() async {
        // Simulate async check
        try? await Task.sleep(for: .milliseconds(10))
    }
    
    // MARK: - Reminder Notifications
    
    public func scheduleReminderNotification(for reminder: PlantReminder) async throws {
        if shouldFailScheduling {
            throw MockNotificationError.schedulingFailed
        }
        
        guard isEnabled else { return }
        
        let notification = MockNotificationRequest(
            identifier: "reminder_\(reminder.id.uuidString)",
            title: reminder.title,
            body: reminder.message,
            date: reminder.nextDueDate,
            userInfo: [
                "reminderId": reminder.id.uuidString,
                "plantId": reminder.plant?.id.uuidString ?? "",
                "reminderType": reminder.reminderType.rawValue
            ]
        )
        
        scheduledNotifications.append(notification)
        reminder.notificationIdentifier = notification.identifier
    }
    
    public func cancelReminderNotification(for reminder: PlantReminder) {
        if let identifier = reminder.notificationIdentifier {
            scheduledNotifications.removeAll { $0.identifier == identifier }
            reminder.notificationIdentifier = nil
        }
    }
    
    // MARK: - Batch Operations
    
    public func scheduleAllActiveReminders(_ reminders: [PlantReminder]) async {
        for reminder in reminders where reminder.isEnabled {
            try? await scheduleReminderNotification(for: reminder)
        }
    }
    
    public func cancelAllNotifications() {
        scheduledNotifications.removeAll()
        deliveredNotifications.removeAll()
    }
    
    // MARK: - Statistics
    
    public func getPendingNotificationsCount() async -> Int {
        return scheduledNotifications.count
    }
    
    public func getDeliveredNotificationsCount() async -> Int {
        return deliveredNotifications.count
    }
    
    // MARK: - Test Utilities
    
    public func reset() {
        authorizationStatus = .notDetermined
        isEnabled = false
        shouldFailPermissionRequest = false
        shouldFailScheduling = false
        scheduledNotifications.removeAll()
        deliveredNotifications.removeAll()
    }
    
    public func simulateNotificationDelivery(_ identifier: String) {
        if let index = scheduledNotifications.firstIndex(where: { $0.identifier == identifier }) {
            let notification = scheduledNotifications.remove(at: index)
            deliveredNotifications.append(notification)
        }
    }
    
    public func simulatePermissionGranted() {
        authorizationStatus = .authorized
        isEnabled = true
    }
    
    public func simulatePermissionDenied() {
        authorizationStatus = .denied
        isEnabled = false
    }
}

// MARK: - Supporting Types

public struct MockNotificationRequest {
    public let identifier: String
    public let title: String
    public let body: String
    public let date: Date
    public let userInfo: [String: Any]
    
    public init(identifier: String, title: String, body: String, date: Date, userInfo: [String: Any]) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.date = date
        self.userInfo = userInfo
    }
}

public enum MockDataServiceError: Error {
    case operationFailed
    case userNotFound
    case invalidData
    
    public var localizedDescription: String {
        switch self {
        case .operationFailed:
            return "Mock operation failed"
        case .userNotFound:
            return "User not found"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}

public enum MockNotificationError: Error {
    case permissionDenied
    case schedulingFailed
    case notificationNotFound
    
    public var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .notificationNotFound:
            return "Notification not found"
        }
    }
}