import GrowWiseServices
import SwiftUI

struct LocationSetupView: View {
    @Binding var userProfile: UserProfile
    @Environment(LocationService.self)
    private var locationService
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Central permission content
            VStack(spacing: 28) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.12))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle().stroke(CultivationTheme.Colors.accentCoral.opacity(0.20), lineWidth: 1)
                        )
                    Circle()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.18))
                        .frame(width: 80, height: 80)
                    Image(systemName: "location.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }

                VStack(spacing: 10) {
                    Text("Know your climate")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Get weather-aware care tips and\nseasonal planting guidance.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Granted vs. request state
                if locationService.hasLocationPermission {
                    VStack(spacing: 12) {
                        PermissionGrantedBadge(message: "Location access granted")
                        if let zone = locationService.hardinessZone {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                Text("Hardiness Zone: \(zone)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 14) {
                        Button(action: requestLocation) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView().scaleEffect(0.85).tint(.white)
                                } else {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isRequesting ? "Requesting…" : "Enable Location")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        CultivationTheme.Gradients.warmAccent
                                    )
                                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.40), radius: 12, y: 4)
                            )
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding_location_enable")

                        Button("Skip for Now") {
                            userProfile.hasLocationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.40))
                        .accessibilityIdentifier("onboarding_location_skip")
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            PrivacyNote(
                icon: "lock.shield.fill",
                text: "Location is only used for gardening features and never shared."
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .onAppear { userProfile.hasLocationPermission = locationService.hasLocationPermission }
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
        Color.black.ignoresSafeArea()
        LocationSetupView(userProfile: .constant(UserProfile()))
    }
}
