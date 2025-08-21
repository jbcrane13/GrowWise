import SwiftUI
import GrowWiseServices
import UserNotifications

public struct ReminderSettingsView: View {
    let reminderService: ReminderService
    @Binding var reminderSettings: ReminderSettings
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var showingQuietHoursStart = false
    @State private var showingQuietHoursEnd = false
    @State private var showingDefaultTime = false
    @State private var tempQuietStart = Date()
    @State private var tempQuietEnd = Date()
    @State private var tempDefaultTime = Date()
    
    public init(reminderService: ReminderService, reminderSettings: Binding<ReminderSettings>) {
        self.reminderService = reminderService
        self._reminderSettings = reminderSettings
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // Notification permissions
                notificationPermissionsSection
                
                // Reminder types
                reminderTypesSection
                
                // Default timing
                defaultTimingSection
                
                // Quiet hours
                quietHoursSection
                
                // Advanced features
                advancedFeaturesSection
                
                // Notification management
                notificationManagementSection
            }
            .navigationTitle("Reminder Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupTempValues()
                Task {
                    await notificationService.checkAuthorizationStatus()
                }
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var notificationPermissionsSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.headline)
                    
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                notificationStatusIndicator
            }
            .padding(.vertical, 4)
            
            if !notificationService.isEnabled {
                Button("Enable Notifications") {
                    openNotificationSettings()
                }
                .foregroundColor(.blue)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Notifications are required to receive plant care reminders. You can manage notification permissions in Settings.")
        }
    }
    
    private var reminderTypesSection: some View {
        Section(content: {
            Toggle("Watering Reminders", isOn: $reminderSettings.enableWateringReminders)
            Toggle("Fertilizing Reminders", isOn: $reminderSettings.enableFertilizingReminders)
            Toggle("Pest Control Reminders", isOn: $reminderSettings.enablePestControlReminders)
        }, header: {
            Text("Reminder Types")
        }, footer: {
            Text("Choose which types of plant care reminders you want to receive.")
        })
    }
    
    private var defaultTimingSection: some View {
        Section(content: {
            HStack {
                Text("Default Notification Time")
                Spacer()
                
                Button(action: { showingDefaultTime = true }) {
                    Text(formatTime(reminderSettings.defaultNotificationTime ?? Date()))
                        .foregroundColor(.blue)
                }
            }
        }, header: {
            Text("Default Timing")
        }, footer: {
            Text("New reminders will use this time by default. You can customize individual reminder times when creating them.")
        })
        .sheet(isPresented: $showingDefaultTime) {
            TimePickerSheet(
                title: "Default Notification Time",
                selectedTime: $tempDefaultTime,
                onSave: {
                    reminderSettings.defaultNotificationTime = tempDefaultTime
                    showingDefaultTime = false
                },
                onCancel: { showingDefaultTime = false }
            )
        }
    }
    
    private var quietHoursSection: some View {
        Section(content: {
            HStack {
                Text("Start Time")
                Spacer()
                
                if let quietStart = reminderSettings.quietHoursStart {
                    Button(action: { showingQuietHoursStart = true }) {
                        Text(formatTime(quietStart))
                            .foregroundColor(.blue)
                    }
                } else {
                    Button("Set Time") {
                        showingQuietHoursStart = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            HStack {
                Text("End Time")
                Spacer()
                
                if let quietEnd = reminderSettings.quietHoursEnd {
                    Button(action: { showingQuietHoursEnd = true }) {
                        Text(formatTime(quietEnd))
                            .foregroundColor(.blue)
                    }
                } else {
                    Button("Set Time") {
                        showingQuietHoursEnd = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if reminderSettings.quietHoursStart != nil || reminderSettings.quietHoursEnd != nil {
                Button("Clear Quiet Hours") {
                    reminderSettings.quietHoursStart = nil
                    reminderSettings.quietHoursEnd = nil
                }
                .foregroundColor(.red)
            }
        }, header: {
            Text("Quiet Hours")
        }, footer: {
            Text("During quiet hours, notifications will be delayed until the next appropriate time.")
        })
        .sheet(isPresented: $showingQuietHoursStart) {
            TimePickerSheet(
                title: "Quiet Hours Start",
                selectedTime: $tempQuietStart,
                onSave: {
                    reminderSettings.quietHoursStart = tempQuietStart
                    showingQuietHoursStart = false
                },
                onCancel: { showingQuietHoursStart = false }
            )
        }
        .sheet(isPresented: $showingQuietHoursEnd) {
            TimePickerSheet(
                title: "Quiet Hours End",
                selectedTime: $tempQuietEnd,
                onSave: {
                    reminderSettings.quietHoursEnd = tempQuietEnd
                    showingQuietHoursEnd = false
                },
                onCancel: { showingQuietHoursEnd = false }
            )
        }
    }
    
    private var advancedFeaturesSection: some View {
        Section {
            Toggle("Weather-Based Adjustments", isOn: $reminderSettings.enableWeatherBasedAdjustments)
        } header: {
            Text("Smart Features")
        } footer: {
            Text("When enabled, watering reminders will automatically adjust based on weather conditions.")
        }
    }
    
    private var notificationManagementSection: some View {
        Section {
            NavigationLink("Pending Notifications") {
                PendingNotificationsView()
            }
            
            Button("Test Notification") {
                sendTestNotification()
            }
            .foregroundColor(.blue)
            
            Button("Clear All Notifications") {
                clearAllNotifications()
            }
            .foregroundColor(.red)
        } header: {
            Text("Notification Management")
        } footer: {
            Text("Manage and test your notification settings.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var notificationStatusText: String {
        switch notificationService.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Denied - Enable in Settings"
        case .notDetermined:
            return "Not requested"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var notificationStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(notificationService.isEnabled ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(notificationService.isEnabled ? "ON" : "OFF")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(notificationService.isEnabled ? .green : .red)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupTempValues() {
        tempDefaultTime = reminderSettings.defaultNotificationTime ?? Date()
        tempQuietStart = reminderSettings.quietHoursStart ?? Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        tempQuietEnd = reminderSettings.quietHoursEnd ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveSettings() {
        reminderService.updateReminderSettings(reminderSettings)
    }
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func sendTestNotification() {
        Task {
            do {
                try await notificationService.scheduleSeasonalReminder(
                    title: "Test Notification",
                    body: "This is a test notification from GrowWise. Your reminder settings are working correctly!",
                    date: Date().addingTimeInterval(5), // 5 seconds from now
                    identifier: "test_notification_\(UUID().uuidString)"
                )
                
                // Provide feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
            } catch {
                print("Failed to send test notification: \(error)")
            }
        }
    }
    
    private func clearAllNotifications() {
        notificationService.clearAllNotifications()
        
        // Provide feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    let title: String
    @Binding var selectedTime: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Pending Notifications View

struct PendingNotificationsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var pendingNotifications: [UNNotificationRequest] = []
    
    var body: some View {
        List {
            if pendingNotifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No Pending Notifications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Your scheduled notifications will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(pendingNotifications, id: \.identifier) { notification in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notification.content.title)
                            .font(.headline)
                        
                        Text(notification.content.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let trigger = notification.trigger as? UNCalendarNotificationTrigger,
                           let nextDate = trigger.nextTriggerDate() {
                            Text("Scheduled: \(nextDate, style: .date) at \(nextDate, style: .time)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Pending Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPendingNotifications()
        }
        .refreshable {
            loadPendingNotifications()
        }
    }
    
    private func loadPendingNotifications() {
        Task {
            let requests = await notificationService.getPendingNotifications()
            await MainActor.run {
                pendingNotifications = requests
            }
        }
    }
}

#Preview {
    let dataService = try! DataService()
    let notificationService = NotificationService.shared
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
    let settings = ReminderSettings()
    
    ReminderSettingsView(
        reminderService: reminderService,
        reminderSettings: .constant(settings)
    )
}