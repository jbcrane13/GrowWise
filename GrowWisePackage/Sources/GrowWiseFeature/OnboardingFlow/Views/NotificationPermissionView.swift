import SwiftUI
import GrowWiseServices

struct NotificationPermissionView: View {
    @Binding var userProfile: UserProfile
    @StateObject private var notificationService = NotificationService.shared
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.adaptiveGreen)
                
                Text("Stay connected to your garden")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Enable notifications to get timely reminders and important updates about your plants.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Notification benefits
            VStack(spacing: 16) {
                NotificationBenefitRow(
                    icon: "drop.fill",
                    title: "Watering Reminders",
                    description: "Never forget to water your plants again"
                )
                
                NotificationBenefitRow(
                    icon: "scissors",
                    title: "Care Alerts",
                    description: "Get reminded when it's time to prune, fertilize, or repot"
                )
                
                NotificationBenefitRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Weather Warnings",
                    description: "Protect your plants from frost, heat waves, and storms"
                )
                
                NotificationBenefitRow(
                    icon: "calendar.badge.plus",
                    title: "Seasonal Tips",
                    description: "Learn about seasonal gardening tasks and opportunities"
                )
                
                NotificationBenefitRow(
                    icon: "heart.text.square.fill",
                    title: "Plant Health Updates",
                    description: "Get notified if we detect potential issues with your plants"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Notification time preference
            if notificationService.isAuthorized {
                VStack(spacing: 12) {
                    Text("When would you like to receive reminders?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    DatePicker(
                        "Preferred Time",
                        selection: $userProfile.preferredNotificationTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxHeight: 120)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Permission button
            VStack(spacing: 16) {
                if notificationService.isAuthorized {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.adaptiveGreen)
                            Text("Notifications enabled")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("You can adjust notification settings anytime in the app settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.adaptiveGreenBackground)
                    )
                } else {
                    VStack(spacing: 12) {
                        Button(action: requestNotifications) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "bell.circle.fill")
                                        .font(.title3)
                                }
                                
                                Text(isRequesting ? "Requesting..." : "Enable Notifications")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.adaptiveSelectionBackground)
                            )
                        }
                        .disabled(isRequesting)
                        
                        Button("Maybe Later") {
                            userProfile.hasNotificationPermission = false
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Quiet hours info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.adaptiveGreen)
                    
                    Text("Respect your schedule")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Text("You can set quiet hours to avoid notifications during sleep or work time.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            userProfile.hasNotificationPermission = notificationService.isAuthorized
        }
        .onChange(of: notificationService.isAuthorized) { _, isAuthorized in
            userProfile.hasNotificationPermission = isAuthorized
            isRequesting = false
        }
    }
    
    private func requestNotifications() {
        isRequesting = true
        Task {
            let granted = await notificationService.requestNotificationPermissions()
            await MainActor.run {
                userProfile.hasNotificationPermission = granted
                isRequesting = false
            }
        }
    }
}

struct NotificationBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.adaptiveGreen)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NotificationPermissionView(userProfile: .constant(UserProfile()))
        .padding()
}