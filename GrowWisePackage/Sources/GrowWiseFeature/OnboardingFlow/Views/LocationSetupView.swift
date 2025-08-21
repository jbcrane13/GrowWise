import SwiftUI
import GrowWiseServices

struct LocationSetupView: View {
    @Binding var userProfile: UserProfile
    @StateObject private var locationService = LocationService.shared
    @State private var isRequesting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.adaptiveGreen)
                    
                    Text("Help us know your location")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("We'll use this to provide weather updates, planting recommendations, and determine your hardiness zone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Location benefits
                VStack(spacing: 16) {
                    LocationBenefitRow(
                        icon: "thermometer.sun.fill",
                        title: "Weather-Based Care Tips",
                        description: "Get personalized watering and care advice based on your local weather"
                    )
                    
                    LocationBenefitRow(
                        icon: "map.fill",
                        title: "Hardiness Zone Detection",
                        description: "Know which plants will thrive in your climate"
                    )
                    
                    LocationBenefitRow(
                        icon: "calendar.badge.clock",
                        title: "Seasonal Reminders",
                        description: "Receive timely notifications for planting and harvesting"
                    )
                    
                    LocationBenefitRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Weather Alerts",
                        description: "Get warned about frost, heat waves, and storms"
                    )
                }
                .padding(.horizontal)
                
                // Current location status
                VStack(spacing: 16) {
                    if locationService.authorizationStatus == .authorizedWhenInUse || 
                       locationService.authorizationStatus == .authorizedAlways {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.adaptiveGreen)
                                Text("Location access granted")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            if let zone = locationService.hardinessZone {
                                Text("Hardiness Zone: \(zone)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    } else {
                        VStack(spacing: 12) {
                            Button(action: requestLocation) {
                                HStack {
                                    if isRequesting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "location.circle.fill")
                                            .font(.title3)
                                    }
                                    
                                    Text(isRequesting ? "Requesting..." : "Enable Location Services")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green)
                                )
                            }
                            .disabled(isRequesting)
                            
                            Button("Skip for Now") {
                                userProfile.hasLocationPermission = false
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Privacy note
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.adaptiveGreen)
                        
                        Text("Your privacy matters")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Location data is used only for gardening features and never shared with third parties.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Bottom spacer for navigation buttons
                Spacer(minLength: 80)
            }
            .padding()
        }
        .onAppear {
            userProfile.hasLocationPermission = locationService.authorizationStatus == .authorizedWhenInUse || 
                                              locationService.authorizationStatus == .authorizedAlways
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            userProfile.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
            isRequesting = false
        }
    }
    
    private func requestLocation() {
        isRequesting = true
        locationService.requestLocationPermission()
    }
}

struct LocationBenefitRow: View {
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
    LocationSetupView(userProfile: .constant(UserProfile()))
        .padding()
}