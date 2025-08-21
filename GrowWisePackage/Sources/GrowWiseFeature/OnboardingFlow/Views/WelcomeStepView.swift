import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon and branding
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.adaptiveGreen, Color(light: .blue, dark: Color(red: 0.3, green: 0.6, blue: 1.0))],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("GrowWise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Your Personal Gardening Companion")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Feature highlights
            VStack(spacing: 20) {
                WelcomeFeatureRow(
                    icon: "calendar.badge.clock",
                    title: "Smart Reminders",
                    description: "Never forget to water your plants again"
                )
                
                WelcomeFeatureRow(
                    icon: "book.pages",
                    title: "Expert Guidance",
                    description: "Learn from comprehensive plant care guides"
                )
                
                WelcomeFeatureRow(
                    icon: "camera.fill",
                    title: "Garden Journal",
                    description: "Track your garden's progress with photos"
                )
                
                WelcomeFeatureRow(
                    icon: "cloud.sun.fill",
                    title: "Weather Integration",
                    description: "Get personalized care tips based on your climate"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Getting started message
            VStack(spacing: 8) {
                Text("Let's get your garden started!")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("We'll help you set up your profile and preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct WelcomeFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.adaptiveGreen)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveCardBackground)
        )
    }
}

#Preview {
    WelcomeStepView()
        .padding()
}