import Foundation
import GrowWiseModels
import os
@preconcurrency import UserNotifications

private let logger = Logger(subsystem: "com.growwise", category: "NotificationService")

/// Notification management service using @Observable pattern
/// Access via @Environment(NotificationService.self) in views
/// Singleton pattern removed - injected via environment
@MainActor
@Observable
public final class NotificationService: NSObject {
    public var isAuthorized = false
    public var badgeCount = 0
    public var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter: UNUserNotificationCenter?

    /// Alias for isAuthorized to maintain backward compatibility
    public var isEnabled: Bool {
        isAuthorized
    }

    override public init() {
        notificationCenter = UNUserNotificationCenter.current()
        super.init()

        notificationCenter?.delegate = self
        if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
            checkNotificationPermissions()
        }
    }

    /// Internal initializer for unit and integration testing.
    /// Passing `notificationCenter: nil` prevents the service from touching
    /// `UNUserNotificationCenter.current()`, which requires app entitlements and
    /// crashes in the swift test runner.
    init(notificationCenter: UNUserNotificationCenter?) {
        self.notificationCenter = notificationCenter
        super.init()
        // Do not set delegate or check permissions in test mode.
    }

    // MARK: - Permission Management

    public func requestNotificationPermissions() async -> Bool {
        guard let notificationCenter else { return false }
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
            return granted
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func checkNotificationPermissions() {
        guard let notificationCenter else { return }
        Task<Void, Never> {
            let settings = await notificationCenter.notificationSettings()
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    public func checkAuthorizationStatus() async {
        guard let notificationCenter else { return }
        let settings = await notificationCenter.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        self.isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling Notifications

    public func scheduleReminderNotification(for reminder: PlantReminder) async throws {
        guard isAuthorized, let notificationCenter else { return }

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
        notificationCenter?.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAllNotifications() async {
        notificationCenter?.removeAllPendingNotificationRequests()
    }

    // MARK: - Helper Functions

    private func updateBadgeCount() async {
        let pendingCount = await getPendingNotificationsCount()
        self.badgeCount = pendingCount
        try? await notificationCenter?.setBadgeCount(pendingCount)
    }

    private func createReminderNotificationContent(for reminder: PlantReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let plantName = reminder.plant?.name ?? reminder.plantName
        content.title = "Time to care for \(plantName)"
        content.body = reminder.reminderType.displayName
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)

        // Add custom user info for handling actions
        var userInfo: [String: Any] = [
            "reminderId": reminder.id.uuidString,
            "reminderType": reminder.reminderType.rawValue,
        ]

        if let plantId = reminder.plant?.id {
            userInfo["plantId"] = plantId.uuidString
        }

        content.userInfo = userInfo
        return content
    }

    /// Returns the notification title and body that would be used for the given reminder.
    /// Exposed for unit-testing notification content without scheduling a real notification.
    public func notificationContent(for reminder: PlantReminder) -> (title: String, body: String) {
        let plantName = reminder.plant?.name ?? reminder.plantName
        return (
            title: "Time to care for \(plantName)",
            body: reminder.reminderType.displayName
        )
    }

    private func createNotificationTrigger(for date: Date, repeats: Bool) -> UNNotificationTrigger {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }

    private func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter?.pendingNotificationRequests() ?? []
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
        await requestNotificationPermissions()
    }

    public func setupNotificationCategories() {
        // Setup notification categories for reminder actions
        // This would be implementation-specific for garden care categories
    }

    // MARK: - Additional Methods for View Compatibility

    public func scheduleSeasonalReminder(title: String, body: String, date: Date, identifier: String) async throws {
        guard isAuthorized, let notificationCenter else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)

        let trigger = createNotificationTrigger(for: date, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await notificationCenter.add(request)
    }

    public func getPendingNotifications() async -> [PendingNotificationInfo] {
        let requests = await notificationCenter?.pendingNotificationRequests() ?? []
        return requests.map {
            PendingNotificationInfo(
                identifier: $0.identifier,
                title: $0.content.title,
                body: $0.content.body
            )
        }
    }

    public func clearAllNotifications() {
        Task<Void, Never> {
            await cancelAllNotifications()
        }
    }
}

// MARK: - Supporting Types

public struct PendingNotificationInfo: Sendable {
    public let identifier: String
    public let title: String
    public let body: String
}

public struct NotificationStatistics: Sendable {
    public let pendingCount: Int
    public let deliveredCount: Int
    public let isAuthorized: Bool
    public let badgeEnabled: Bool
    public let soundEnabled: Bool
    public let alertEnabled: Bool

    public init(
        pendingCount: Int,
        deliveredCount: Int,
        isAuthorized: Bool,
        badgeEnabled: Bool,
        soundEnabled: Bool,
        alertEnabled: Bool
    ) {
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
        _ = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // Handle default tap action
            break

        default:
            break
        }

        Task<Void, Never> { @MainActor in
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
