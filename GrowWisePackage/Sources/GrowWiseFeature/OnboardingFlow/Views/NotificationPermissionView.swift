import GrowWiseServices
import SwiftUI

struct NotificationPermissionView: View {
    @Binding var userProfile: UserProfile
    @Environment(NotificationService.self) private var notificationService
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                OnboardingStepHeader(
                    icon: "bell.badge.fill",
                    iconColor: Color(red: 0.922, green: 0.596, blue: 0.200),
                    title: "Never miss a\ncare moment",
                    subtitle: "Timely reminders keep your plants thriving\nand your garden on schedule."
                )

                // Permission state
                VStack(spacing: 16) {
                    if notificationService.isAuthorized {
                        PermissionGrantedBadge(message: "Notifications enabled")
                            .padding(.horizontal, 24)

                        // Time preference picker
                        VStack(spacing: 10) {
                            Text("Best time for reminders?")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.botanicalForest)

                            DatePicker(
                                "Preferred Time",
                                selection: $userProfile.preferredNotificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .gwWheelDatePickerStyle()
                            .labelsHidden()
                            .frame(maxHeight: 120)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                        )
                        .padding(.horizontal, 24)

                    } else {
                        // CTA button
                        Button(action: requestNotifications) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }

                                Text(isRequesting ? "Requesting Access…" : "Enable Notifications")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.botanicalForest, Color.botanicalLeaf],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color.botanicalForest.opacity(0.30), radius: 10, y: 4)
                            )
                        }
                        .disabled(isRequesting)
                        .padding(.horizontal, 24)
                        .accessibilityLabel("Enable Notifications")
                        .accessibilityIdentifier("onboarding_notifications_enable")

                        Button("Maybe Later") {
                            userProfile.hasNotificationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.secondary)
                        .accessibilityIdentifier("onboarding_notifications_skip")
                    }
                }

                // Benefits
                VStack(spacing: 14) {
                    BenefitRow(
                        icon: "drop.fill",
                        iconColor: Color(red: 0.275, green: 0.565, blue: 0.898),
                        title: "Watering Reminders",
                        description: "Smart schedules tailored to each plant's needs"
                    )
                    BenefitRow(
                        icon: "scissors",
                        iconColor: Color.botanicalLeaf,
                        title: "Care Alerts",
                        description: "Timely reminders to prune, fertilize, or repot"
                    )
                    BenefitRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Color(red: 0.922, green: 0.420, blue: 0.310),
                        title: "Weather Warnings",
                        description: "Protect plants from frost, heat waves, and storms"
                    )
                    BenefitRow(
                        icon: "calendar.badge.plus",
                        iconColor: Color.botanicalGold,
                        title: "Seasonal Tips",
                        description: "Learn what to plant, harvest, and prepare each season"
                    )
                }
                .padding(.horizontal, 24)

                // Quiet hours note
                PrivacyNote(
                    icon: "moon.fill",
                    text: "You can set quiet hours so reminders never interrupt your sleep or work."
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
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

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        NotificationPermissionView(userProfile: .constant(UserProfile()))
    }
}
