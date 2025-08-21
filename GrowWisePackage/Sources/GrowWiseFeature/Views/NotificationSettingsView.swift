import SwiftUI
import GrowWiseServices
import UserNotifications
import GrowWiseModels

public struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var reminderSettings = ReminderSettings()
    @State private var defaultNotificationTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var showingPermissionAlert = false
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                // Current Status
                notificationStatusSection
                
                // Permission Management
                if !notificationService.isAuthorized {
                    permissionSection
                }
                
                // Reminder Types (disabled if not authorized)
                reminderTypesSection
                
                // Timing Settings
                timingSection
                
                // Badge Management
                badgeSection
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    // MARK: - Sections
    
    private var notificationStatusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: notificationService.isAuthorized ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationService.isAuthorized ? .green : .orange)
                        
                        Text("Notifications")
                            .font(.headline)
                    }
                    
                    Text(notificationStatusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("Badge Count:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(notificationService.badgeCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                statusBadge
            }
            .padding(.vertical, 4)
        } footer: {
            if !notificationService.isAuthorized {
                Text("Enable notifications to receive plant care reminders")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var permissionSection: some View {
        Section("Enable Notifications") {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Notifications are disabled")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                Text("Enable notifications to receive timely plant care reminders, watering alerts, and seasonal gardening tips.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Enable Notifications") {
                    Task {
                        let granted = await notificationService.requestNotificationPermissions()
                        if granted {
                            showingTestResult = true
                            testResultMessage = "Notifications enabled successfully!"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical)
        }
    }
    
    private var reminderTypesSection: some View {
        Section("Reminder Types") {
            Toggle("Watering Reminders", isOn: $reminderSettings.enableWateringReminders)
            Toggle("Fertilizing Reminders", isOn: $reminderSettings.enableFertilizingReminders)
            Toggle("Pruning Reminders", isOn: $reminderSettings.enablePruningReminders)
            Toggle("Harvest Reminders", isOn: $reminderSettings.enableHarvestReminders)
            Toggle("Seasonal Care", isOn: $reminderSettings.enableSeasonalReminders)
        }
        .disabled(!notificationService.isAuthorized)
    }
    
    private var timingSection: some View {
        Section(content: {
            // Default notification time
            HStack {
                Label("Default Time", systemImage: "clock.fill")
                Spacer()
                
                DatePicker(
                    "Default Time",
                    selection: $defaultNotificationTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
            .disabled(!notificationService.isAuthorized)
            
            Toggle("Weekend Reminders", isOn: $reminderSettings.weekendReminders)
                .disabled(!notificationService.isAuthorized)
        }, header: {
            Text("Timing & Schedule")
        }, footer: {
            Text("Configure when you prefer to receive plant care reminders")
        })
    }
    
    private var badgeSection: some View {
        Section(content: {
            Button("Clear Badge Count") {
                // Reset badge count to 0
                Task {
                    // The badge count will be updated through the published property
                    try? await UNUserNotificationCenter.current().setBadgeCount(0)
                }
            }
            .disabled(!notificationService.isAuthorized)
            
            Button("Test Notification") {
                Task {
                    await testNotification()
                }
            }
            .disabled(!notificationService.isAuthorized)
        }, header: {
            Text("Badge Management")
        }, footer: {
            Text("Manage app badge and test notification delivery")
        })
        .alert("Notification Test", isPresented: $showingTestResult) {
            Button("OK") { }
        } message: {
            Text(testResultMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var notificationStatusDescription: String {
        if notificationService.isAuthorized {
            return "Notifications are enabled and working properly"
        } else {
            return "Notifications are disabled. Enable to receive plant care reminders"
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
            
            Text(badgeText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(badgeColor)
        }
    }
    
    private var badgeColor: Color {
        if notificationService.isAuthorized {
            return .green
        } else {
            return .red
        }
    }
    
    private var badgeText: String {
        if notificationService.isAuthorized {
            return "ENABLED"
        } else {
            return "DISABLED"
        }
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        // Settings are already initialized with defaults
        // In a real app, you might load from UserDefaults or a data service
    }
    
    private func testNotification() async {
        // Create a test notification using the available API
        let content = UNMutableNotificationContent()
        content.title = "GrowWise Test"
        content.body = "This is a test notification to verify your settings are working correctly!"
        content.sound = .default
        content.badge = NSNumber(value: notificationService.badgeCount + 1)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            testResultMessage = "Test notification scheduled successfully!"
            showingTestResult = true
        } catch {
            testResultMessage = "Failed to schedule test notification: \(error.localizedDescription)"
            showingTestResult = true
        }
    }
}

#Preview {
    NotificationSettingsView()
}