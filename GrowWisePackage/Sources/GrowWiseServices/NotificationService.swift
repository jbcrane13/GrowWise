import Foundation
import UserNotifications
import GrowWiseModels

@MainActor
public final class NotificationService: NSObject, ObservableObject, Sendable {
    public static let shared = NotificationService()
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var isEnabled: Bool = false
    
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Management
    
    public func requestPermission() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
        await checkAuthorizationStatus()
        isEnabled = granted
    }
    
    public func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    
    // MARK: - Reminder Notifications
    
    public func scheduleReminderNotification(for reminder: PlantReminder) async throws {
        guard isEnabled else { return }
        
        // Cancel existing notification if it exists
        if let identifier = reminder.notificationIdentifier {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.badge = 1
        
        // Add plant name and type to user info
        if let plant = reminder.plant {
            content.userInfo = [
                "reminderId": reminder.id.uuidString,
                "plantId": plant.id.uuidString,
                "plantName": plant.name,
                "reminderType": reminder.reminderType.rawValue
            ]
        }
        
        // Create trigger based on due date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.nextDueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "reminder_\(reminder.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try await center.add(request)
        
        // Store the notification identifier
        reminder.notificationIdentifier = identifier
    }
    
    public func cancelReminderNotification(for reminder: PlantReminder) {
        if let identifier = reminder.notificationIdentifier {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            reminder.notificationIdentifier = nil
        }
    }
    
    // MARK: - Batch Operations
    
    public func scheduleAllActiveReminders(_ reminders: [PlantReminder]) async {
        for reminder in reminders where reminder.isEnabled {
            do {
                try await scheduleReminderNotification(for: reminder)
            } catch {
                print("Failed to schedule notification for reminder \(reminder.id): \(error)")
            }
        }
    }
    
    public func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    // MARK: - Seasonal and Plant-Specific Notifications
    
    public func scheduleSeasonalReminder(
        title: String,
        body: String,
        date: Date,
        identifier: String
    ) async throws {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.userInfo = ["type": "seasonal", "identifier": identifier]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }
    
    public func scheduleWeatherAlert(
        title: String,
        body: String,
        category: WeatherAlertCategory = .general
    ) async throws {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = category.rawValue
        content.userInfo = ["type": "weather", "category": category.rawValue]
        
        // Immediate delivery for weather alerts
        let identifier = "weather_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        try await center.add(request)
    }
    
    // MARK: - Plant Health Notifications
    
    public func schedulePlantHealthAlert(
        for plant: Plant,
        issue: HealthIssue,
        severity: AlertSeverity = .medium
    ) async throws {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(plant.name) Needs Attention"
        content.body = issue.description
        content.sound = severity.sound
        content.badge = 1
        content.categoryIdentifier = "PLANT_HEALTH"
        
        content.userInfo = [
            "type": "health",
            "plantId": plant.id.uuidString,
            "plantName": plant.name,
            "issue": issue.rawValue,
            "severity": severity.rawValue
        ]
        
        let identifier = "health_\(plant.id.uuidString)_\(issue.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        try await center.add(request)
    }
    
    // MARK: - Notification Categories and Actions
    
    public func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 1 Hour",
            options: []
        )
        
        let viewPlantAction = UNNotificationAction(
            identifier: "VIEW_PLANT_ACTION",
            title: "View Plant",
            options: [.foreground]
        )
        
        // Reminder category
        let reminderCategory = UNNotificationCategory(
            identifier: "PLANT_REMINDER",
            actions: [completeAction, snoozeAction, viewPlantAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Health alert category
        let healthCategory = UNNotificationCategory(
            identifier: "PLANT_HEALTH",
            actions: [viewPlantAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Weather alert category
        let weatherCategory = UNNotificationCategory(
            identifier: "WEATHER_ALERT",
            actions: [viewPlantAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([reminderCategory, healthCategory, weatherCategory])
    }
    
    // MARK: - Statistics
    
    public func getPendingNotificationsCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }
    
    public func getDeliveredNotificationsCount() async -> Int {
        let notifications = await center.deliveredNotifications()
        return notifications.count
    }
    
    // MARK: - Settings Management
    
    public func updateQuietHours(start: Date?, end: Date?) {
        UserDefaults.standard.set(start, forKey: "quietHoursStart")
        UserDefaults.standard.set(end, forKey: "quietHoursEnd")
    }
    
    public func isInQuietHours() -> Bool {
        guard let start = UserDefaults.standard.object(forKey: "quietHoursStart") as? Date,
              let end = UserDefaults.standard.object(forKey: "quietHoursEnd") as? Date else {
            return false
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startTime = calendar.dateComponents([.hour, .minute], from: start)
        let endTime = calendar.dateComponents([.hour, .minute], from: end)
        
        let current = currentTime.hour! * 60 + currentTime.minute!
        let startMinutes = startTime.hour! * 60 + startTime.minute!
        let endMinutes = endTime.hour! * 60 + endTime.minute!
        
        if startMinutes <= endMinutes {
            return current >= startMinutes && current <= endMinutes
        } else {
            return current >= startMinutes || current <= endMinutes
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            handleCompleteAction(userInfo: userInfo)
        case "SNOOZE_ACTION":
            handleSnoozeAction(userInfo: userInfo)
        case "VIEW_PLANT_ACTION":
            handleViewPlantAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleCompleteAction(userInfo: [AnyHashable: Any]) {
        guard let reminderIdString = userInfo["reminderId"] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else { return }
        
        // Post notification for app to handle reminder completion
        NotificationCenter.default.post(
            name: .completeReminder,
            object: nil,
            userInfo: ["reminderId": reminderId]
        )
    }
    
    private func handleSnoozeAction(userInfo: [AnyHashable: Any]) {
        guard let reminderIdString = userInfo["reminderId"] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else { return }
        
        // Post notification for app to handle reminder snooze
        NotificationCenter.default.post(
            name: .snoozeReminder,
            object: nil,
            userInfo: ["reminderId": reminderId]
        )
    }
    
    private func handleViewPlantAction(userInfo: [AnyHashable: Any]) {
        guard let plantIdString = userInfo["plantId"] as? String,
              let plantId = UUID(uuidString: plantIdString) else { return }
        
        // Post notification for app to navigate to plant detail
        NotificationCenter.default.post(
            name: .viewPlant,
            object: nil,
            userInfo: ["plantId": plantId]
        )
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        // Handle tap on notification body
        handleViewPlantAction(userInfo: userInfo)
    }
}

// MARK: - Supporting Types

public enum WeatherAlertCategory: String, CaseIterable, Sendable {
    case frost = "frost"
    case heatwave = "heatwave"
    case heavyRain = "heavyRain"
    case drought = "drought"
    case wind = "wind"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .frost: return "Frost Warning"
        case .heatwave: return "Heat Warning"
        case .heavyRain: return "Heavy Rain Alert"
        case .drought: return "Drought Conditions"
        case .wind: return "High Wind Warning"
        case .general: return "Weather Alert"
        }
    }
}

public enum HealthIssue: String, CaseIterable, Sendable {
    case overwatering = "overwatering"
    case underwatering = "underwatering"
    case pestInfestation = "pestInfestation"
    case disease = "disease"
    case nutrientDeficiency = "nutrientDeficiency"
    case rootBound = "rootBound"
    case sunStress = "sunStress"
    case temperatureStress = "temperatureStress"
    
    public var description: String {
        switch self {
        case .overwatering: return "Signs of overwatering detected. Check soil drainage."
        case .underwatering: return "Plant appears dehydrated. Consider watering."
        case .pestInfestation: return "Possible pest activity observed."
        case .disease: return "Potential plant disease detected."
        case .nutrientDeficiency: return "Nutrient deficiency symptoms visible."
        case .rootBound: return "Plant may need repotting."
        case .sunStress: return "Plant showing signs of sun stress."
        case .temperatureStress: return "Temperature stress detected."
        }
    }
}

public enum AlertSeverity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var sound: UNNotificationSound {
        switch self {
        case .low: return .default
        case .medium: return .default
        case .high: return .defaultCritical
        case .critical: return .defaultCritical
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let completeReminder = Notification.Name("completeReminder")
    static let snoozeReminder = Notification.Name("snoozeReminder")
    static let viewPlant = Notification.Name("viewPlant")
}