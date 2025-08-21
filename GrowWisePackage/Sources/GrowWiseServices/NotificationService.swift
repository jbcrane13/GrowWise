import Foundation
import UserNotifications
import GrowWiseModels

@MainActor
public final class NotificationService: NSObject, ObservableObject {
    public static let shared = NotificationService()
    
    @Published public var isAuthorized = false
    @Published public var badgeCount = 0
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let notificationCenter: UNUserNotificationCenter
    
    /// Alias for isAuthorized to maintain backward compatibility
    public var isEnabled: Bool {
        return isAuthorized
    }
    
    override init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        super.init()
        
        notificationCenter.delegate = self
        checkNotificationPermissions()
    }
    
    // MARK: - Permission Management
    
    public func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    private func checkNotificationPermissions() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    public func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Scheduling Notifications
    
    public func scheduleReminderNotification(for reminder: PlantReminder) async throws {
        guard isAuthorized else { return }
        
        let content = createReminderNotificationContent(for: reminder)
        let trigger = createNotificationTrigger(for: reminder.nextDueDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    public func cancelNotification(with identifier: String) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    public func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Helper Functions
    
    private func updateBadgeCount() async {
        let pendingCount = await getPendingNotificationsCount()
        await MainActor.run {
            self.badgeCount = pendingCount
        }
        
        try? await notificationCenter.setBadgeCount(pendingCount)
    }
    
    private func createReminderNotificationContent(for reminder: PlantReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        
        // Add custom user info for handling actions
        var userInfo: [String: Any] = [
            "reminderId": reminder.id.uuidString,
            "reminderType": reminder.reminderType.rawValue
        ]
        
        if let plantId = reminder.plant?.id {
            userInfo["plantId"] = plantId.uuidString
        }
        
        content.userInfo = userInfo
        return content
    }
    
    private func createNotificationTrigger(for date: Date, repeats: Bool) -> UNNotificationTrigger {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }
    
    private func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
    
    // MARK: - Additional Helper Methods
    
    public func isInQuietHours() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 8 || hour > 21 // Quiet hours are before 8 AM and after 9 PM
    }
    
    public func cancelReminderNotification(for reminderId: UUID) async {
        await cancelNotification(with: reminderId.uuidString)
    }
    
    public func requestPermission() async -> Bool {
        return await requestNotificationPermissions()
    }
    
    public func setupNotificationCategories() {
        // Setup notification categories for reminder actions
        // This would be implementation-specific for garden care categories
    }
    
    // MARK: - Additional Methods for View Compatibility
    
    public func scheduleSeasonalReminder(title: String, body: String, date: Date, identifier: String) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        
        let trigger = createNotificationTrigger(for: date, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try await notificationCenter.add(request)
    }
    
    public func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    public func clearAllNotifications() {
        Task {
            await cancelAllNotifications()
        }
    }
}

// MARK: - Supporting Types

public struct NotificationStatistics: Sendable {
    public let pendingCount: Int
    public let deliveredCount: Int
    public let isAuthorized: Bool
    public let badgeEnabled: Bool
    public let soundEnabled: Bool
    public let alertEnabled: Bool
    
    public init(pendingCount: Int, deliveredCount: Int, isAuthorized: Bool, badgeEnabled: Bool, soundEnabled: Bool, alertEnabled: Bool) {
        self.pendingCount = pendingCount
        self.deliveredCount = deliveredCount
        self.isAuthorized = isAuthorized
        self.badgeEnabled = badgeEnabled
        self.soundEnabled = soundEnabled
        self.alertEnabled = alertEnabled
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let _ = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // Handle default tap action
            break
        default:
            break
        }
        
        Task {
            await updateBadgeCount()
        }
        
        completionHandler()
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}