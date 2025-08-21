import SwiftUI
import GrowWiseFeature

@main
struct GrowWiseApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView()
        }
    }
}

struct SimpleTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🌱 GrowWise")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your Personal Gardening Companion")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("Track your plants")
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Set care reminders")
                }
                
                HStack {
                    Image(systemName: "book.pages")
                        .foregroundColor(.orange)
                    Text("Keep a garden journal")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button("Continue to Onboarding") {
                // Placeholder for onboarding
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}
