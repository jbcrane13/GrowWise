import GrowWiseServices
import SwiftUI

struct LocationSetupView: View {
    @Binding var userProfile: UserProfile
    @Environment(LocationService.self) private var locationService
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                OnboardingStepHeader(
                    icon: "location.fill",
                    iconColor: Color.botanicalLeaf,
                    title: "Know your\ngarden's climate",
                    subtitle: "Location lets us give you weather-aware care\ntips and seasonal planting guidance."
                )

                // Permission state
                VStack(spacing: 16) {
                    if locationService.hasLocationPermission {
                        PermissionGrantedBadge(message: "Location access granted")
                            .padding(.horizontal, 24)

                        if let zone = locationService.hardinessZone {
                            HStack(spacing: 10) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.botanicalForest)

                                Text("Hardiness Zone: \(zone)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.botanicalForest)
                            }
                            .padding(.horizontal, 24)
                        }
                    } else {
                        // CTA button
                        Button(action: requestLocation) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }

                                Text(isRequesting ? "Requesting Access…" : "Enable Location Services")
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
                        .accessibilityLabel("Enable Location Services")
                        .accessibilityIdentifier("onboarding_location_enable")

                        Button("Skip for Now") {
                            userProfile.hasLocationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.secondary)
                        .accessibilityIdentifier("onboarding_location_skip")
                    }
                }

                // Privacy note
                PrivacyNote(
                    icon: "lock.shield.fill",
                    text: "Location is used only for gardening features and is never shared with third parties."
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .onAppear {
            userProfile.hasLocationPermission = locationService.hasLocationPermission
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            #if os(iOS)
            userProfile.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
            #elseif os(macOS)
            userProfile.hasLocationPermission = status == .authorizedAlways
            #else
            userProfile.hasLocationPermission = false
            #endif
            isRequesting = false
        }
    }

    private func requestLocation() {
        isRequesting = true
        locationService.requestLocationPermission()
    }
}

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        LocationSetupView(userProfile: .constant(UserProfile()))
    }
}
