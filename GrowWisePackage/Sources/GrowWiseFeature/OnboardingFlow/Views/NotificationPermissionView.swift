import GrowWiseServices
import SwiftUI

struct NotificationPermissionView: View {
    @Binding var userProfile: UserProfile
    @Environment(NotificationService.self)
    private var notificationService
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Colors.accentAmber.opacity(0.10))
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(CultivationTheme.Colors.accentAmber.opacity(0.18), lineWidth: 1))
                    Circle()
                        .fill(CultivationTheme.Colors.accentAmber.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.accentAmber)
                }

                VStack(spacing: 10) {
                    Text("Never miss a care moment")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Smart reminders keep your plants\nthriving and on schedule.")
                        .font(.system(size: 16))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                if notificationService.isAuthorized {
                    VStack(spacing: 14) {
                        PermissionGrantedBadge(message: "Notifications enabled")

                        // Time picker in glass card
                        VStack(spacing: 8) {
                            Text("Best time for reminders?")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)

                            DatePicker(
                                "Time",
                                selection: $userProfile.preferredNotificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .gwWheelDatePickerStyle()
                            .labelsHidden()
                            .frame(maxHeight: 120)
                            .accessibilityIdentifier("onboarding_datepicker_notification_time")
                        }
                        .padding(16)
                        .paperCard()
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 14) {
                        Button(action: requestNotifications) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView().scaleEffect(0.85).tint(.white)
                                } else {
                                    Image(systemName: "bell.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isRequesting ? "Requesting…" : "Enable Notifications")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(CultivationTheme.Gradients.warmAccent)
                                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.40), radius: 12, y: 4)
                            )
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding_notifications_enable")

                        Button("Maybe Later") {
                            userProfile.hasNotificationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .accessibilityIdentifier("onboarding_notifications_skip")
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            PrivacyNote(
                icon: "moon.fill",
                text: "You can set quiet hours so reminders never interrupt your sleep."
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .onAppear { userProfile.hasNotificationPermission = notificationService.isAuthorized }
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

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        NotificationPermissionView(userProfile: .constant(UserProfile()))
    }
}
