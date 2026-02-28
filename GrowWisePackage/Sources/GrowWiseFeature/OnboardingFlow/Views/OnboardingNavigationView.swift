import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct OnboardingNavigationView: View {
    @Binding var currentStep: OnboardingStep
    @Binding var userProfile: UserProfile
    @Binding var isCompleted: Bool

    @Environment(DataService.self) private var dataService
    @Environment(NotificationService.self) private var notificationService

    @State private var showingError = false
    @State private var errorMessage = ""

    private var isFirstStep: Bool {
        currentStep == OnboardingStep.allCases.first
    }

    private var isLastStep: Bool {
        currentStep == OnboardingStep.allCases.last
    }

    private var canProceed: Bool {
        switch currentStep {
        case .welcome:
            true

        case .skillAssessment:
            true // Skill level has a default

        case .goals:
            !userProfile.goals.isEmpty

        case .location:
            true // Optional step

        case .notifications:
            true // Optional step

        case .completion:
            true
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
        .alert("Setup Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func moveToStep(direction: StepDirection) {
        let allCases = OnboardingStep.allCases
        guard let currentIndex = allCases.firstIndex(of: currentStep) else { return }

        let newIndex: Int = switch direction {
        case .next:
            min(currentIndex + 1, allCases.count - 1)

        case .previous:
            max(currentIndex - 1, 0)
        }

        currentStep = allCases[newIndex]
    }

    private func completeOnboarding() {
        Task {
            do {
                // Email and display name validation will be added when user authentication is implemented
                // For now, we use placeholder values
                let email = "user@example.com"
                let displayName = "Gardener"

                // Validate email for future use
                let emailValidation = ValidationService.shared.validateEmail(email)

                guard emailValidation.isValid else {
                    errorMessage = emailValidation.errorMessage ?? "Invalid email address"
                    showingError = true
                    return
                }

                // Validate display name for future use
                let nameValidation = ValidationService.shared.validateName(displayName)

                guard nameValidation.isValid else {
                    errorMessage = nameValidation.errorMessage ?? "Invalid display name"
                    showingError = true
                    return
                }

                let user = try dataService.createUser(
                    email: email,
                    displayName: displayName,
                    skillLevel: userProfile.skillLevel
                )

                // Save additional preferences (non-critical — log failures but don't block onboarding)
                await saveUserPreferences(user: user)

                // Mark onboarding as completed (persist for presentation logic)
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                await MainActor.run {
                    isCompleted = true
                }
            } catch {
                errorMessage = "Failed to complete setup: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func saveUserPreferences(user: User) async {
        // Save supplementary preferences to UserDefaults.
        // These are non-critical — the User record is already persisted in SwiftData.
        if let goalsData = try? JSONEncoder().encode(userProfile.goals.map(\.rawValue)) {
            UserDefaults.standard.set(goalsData, forKey: "userGardeningGoals")
        }

        if let interestsData = try? JSONEncoder().encode(userProfile.interests.map(\.rawValue)) {
            UserDefaults.standard.set(interestsData, forKey: "userPlantInterests")
        }

        UserDefaults.standard.set(userProfile.gardenType.rawValue, forKey: "userGardenType")
        UserDefaults.standard.set(userProfile.spaceSize.rawValue, forKey: "userSpaceSize")

        if let timeData = try? JSONEncoder().encode(userProfile.preferredNotificationTime) {
            UserDefaults.standard.set(timeData, forKey: "userPreferredNotificationTime")
        }

        // Set up notifications if permission granted
        if userProfile.hasNotificationPermission {
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
