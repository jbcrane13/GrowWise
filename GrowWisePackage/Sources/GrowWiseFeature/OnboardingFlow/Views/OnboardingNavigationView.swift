import SwiftUI
import GrowWiseModels
import GrowWiseServices

struct OnboardingNavigationView: View {
    @Binding var currentStep: OnboardingStep
    @Binding var userProfile: UserProfile
    @Binding var isCompleted: Bool
    
    private var isFirstStep: Bool {
        currentStep == OnboardingStep.allCases.first
    }
    
    private var isLastStep: Bool {
        currentStep == OnboardingStep.allCases.last
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .skillAssessment:
            return true // Skill level has a default
        case .goals:
            return !userProfile.goals.isEmpty
        case .location:
            return true // Optional step
        case .notifications:
            return true // Optional step
        case .completion:
            return true
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            if !isFirstStep {
                Button("Back") {
                    withAnimation(.easeInOut) {
                        moveToStep(direction: .previous)
                    }
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
            
            Spacer()
            
            // Next/Finish button
            Button(isLastStep ? "Get Started" : "Continue") {
                withAnimation(.easeInOut) {
                    if isLastStep {
                        completeOnboarding()
                    } else {
                        moveToStep(direction: .next)
                    }
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(!canProceed)
        }
        .padding(.horizontal)
    }
    
    private func moveToStep(direction: StepDirection) {
        let allCases = OnboardingStep.allCases
        guard let currentIndex = allCases.firstIndex(of: currentStep) else { return }
        
        let newIndex: Int
        switch direction {
        case .next:
            newIndex = min(currentIndex + 1, allCases.count - 1)
        case .previous:
            newIndex = max(currentIndex - 1, 0)
        }
        
        currentStep = allCases[newIndex]
    }
    
    private func completeOnboarding() {
        Task {
            do {
                // Create user in database
                let dataService: DataService
                do {
                    dataService = try DataService()
                } catch {
                    print("Primary DataService failed, using fallback: \(error)")
                    dataService = DataService.createFallback()
                }
                
                // For now, use a placeholder email - in a real app this would come from authentication
                let user = try dataService.createUser(
                    email: "user@example.com",
                    displayName: "Gardener",
                    skillLevel: userProfile.skillLevel
                )
                
                // Save additional preferences
                await saveUserPreferences(user: user)
                
                // Mark onboarding as completed
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                await MainActor.run {
                    isCompleted = true
                }
            } catch {
                print("Failed to complete onboarding: \(error)")
                // In a real app, show error to user
            }
        }
    }
    
    private func saveUserPreferences(user: User) async {
        // Save goals and interests as JSON in user defaults for now
        // In a more complex app, these might be separate entities
        let goalsData = try? JSONEncoder().encode(userProfile.goals.map(\.rawValue))
        let interestsData = try? JSONEncoder().encode(userProfile.interests.map(\.rawValue))
        
        UserDefaults.standard.set(goalsData, forKey: "userGardeningGoals")
        UserDefaults.standard.set(interestsData, forKey: "userPlantInterests")
        UserDefaults.standard.set(userProfile.gardenType.rawValue, forKey: "userGardenType")
        UserDefaults.standard.set(userProfile.spaceSize.rawValue, forKey: "userSpaceSize")
        UserDefaults.standard.set(userProfile.preferredNotificationTime, forKey: "userPreferredNotificationTime")
        
        // Set up notifications if permission granted
        if userProfile.hasNotificationPermission {
            let notificationService = NotificationService.shared
            notificationService.setupNotificationCategories()
        }
    }
}

enum StepDirection {
    case next
    case previous
}

// MARK: - Button Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(minWidth: 120, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.adaptiveSelectionBackground)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.adaptiveGreen)
            .frame(minWidth: 80, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.adaptiveGreen, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingNavigationView(
        currentStep: .constant(.skillAssessment),
        userProfile: .constant(UserProfile()),
        isCompleted: .constant(false)
    )
    .padding()
}