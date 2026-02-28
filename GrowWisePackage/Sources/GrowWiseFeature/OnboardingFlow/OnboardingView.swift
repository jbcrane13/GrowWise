import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var userProfile = UserProfile()
    @State private var isCompleted = false
    @Environment(\.dismiss) private var dismiss

    /// Called when the user finishes onboarding. Used when OnboardingView is
    /// embedded in an if/else branch (not a sheet) so dismiss() has no effect.
    var onCompleted: (() -> Void)?

    public init(onCompleted: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient that adapts to appearance mode
                LinearGradient(
                    colors: [
                        Color.adaptiveGreenBackground,
                        Color(light: Color.blue.opacity(0.1), dark: Color.blue.opacity(0.15)),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    OnboardingProgressView(currentStep: currentStep)
                        .padding(.top)

                    // Main content
                    TabView(selection: $currentStep) {
                        WelcomeStepView()
                            .tag(OnboardingStep.welcome)

                        SkillAssessmentView(userProfile: $userProfile)
                            .tag(OnboardingStep.skillAssessment)

                        GardeningGoalsView(userProfile: $userProfile)
                            .tag(OnboardingStep.goals)

                        LocationSetupView(userProfile: $userProfile)
                            .tag(OnboardingStep.location)

                        NotificationPermissionView(userProfile: $userProfile)
                            .tag(OnboardingStep.notifications)

                        CompletionView(userProfile: $userProfile)
                            .tag(OnboardingStep.completion)
                    }
                    .gwPagingTabStyle(indexDisplayMode: .never)
                    .animation(.easeInOut, value: currentStep)

                    // Navigation buttons
                    OnboardingNavigationView(
                        currentStep: $currentStep,
                        userProfile: $userProfile,
                        isCompleted: $isCompleted
                    )
                    .padding(.bottom)
                }
            }
        }
        .accessibilityIdentifier("OnboardingView")
        .gwNavigationBarHidden(true)
        .onChange(of: isCompleted) { _, completed in
            if completed {
                onCompleted?() // Update parent state when embedded in a branch
                dismiss() // Also works when presented as a sheet
            }
        }
    }
}

// MARK: - Supporting Types

public enum OnboardingStep: String, CaseIterable {
    case welcome
    case skillAssessment
    case goals
    case location
    case notifications
    case completion

    var title: String {
        switch self {
        case .welcome: "Welcome to GrowWise"
        case .skillAssessment: "Your Gardening Experience"
        case .goals: "Your Gardening Goals"
        case .location: "Your Location"
        case .notifications: "Stay Connected"
        case .completion: "You're All Set!"
        }
    }

    var stepNumber: Int {
        OnboardingStep.allCases.firstIndex(of: self) ?? 0
    }

    var totalSteps: Int {
        OnboardingStep.allCases.count
    }
}

public struct UserProfile {
    var skillLevel: GardeningSkillLevel = .beginner
    var goals: Set<GardeningGoal> = []
    var gardenType: GardenType = .outdoor
    var spaceSize: SpaceSize = .small
    var interests: Set<PlantType> = []
    var hasLocationPermission: Bool = false
    var hasNotificationPermission: Bool = false
    var preferredNotificationTime: Date = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
}

public enum GardeningGoal: String, CaseIterable, Identifiable {
    case growFood = "grow_food"
    case beautifySpace = "beautify_space"
    case learnSkills = "learn_skills"
    case relaxation
    case sustainability
    case healingGarden = "healing_garden"

    public var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .growFood: "Grow My Own Food"
        case .beautifySpace: "Beautify My Space"
        case .learnSkills: "Learn Gardening Skills"
        case .relaxation: "Relaxation & Therapy"
        case .sustainability: "Sustainable Living"
        case .healingGarden: "Create a Healing Garden"
        }
    }

    var description: String {
        switch self {
        case .growFood: "Fresh vegetables, herbs, and fruits"
        case .beautifySpace: "Flowers and decorative plants"
        case .learnSkills: "Master gardening techniques"
        case .relaxation: "Peaceful gardening activities"
        case .sustainability: "Eco-friendly practices"
        case .healingGarden: "Plants for wellness and meditation"
        }
    }

    var icon: String {
        switch self {
        case .growFood: "carrot.fill"
        case .beautifySpace: "sparkles"
        case .learnSkills: "book.fill"
        case .relaxation: "leaf.fill"
        case .sustainability: "globe.americas.fill"
        case .healingGarden: "heart.fill"
        }
    }
}

public enum SpaceSize: String, CaseIterable {
    case tiny // Windowsill, small containers
    case small // Balcony, small patio
    case medium // Small yard, large patio
    case large // Large yard, multiple beds
    case acreage // Farm or large property

    var displayName: String {
        switch self {
        case .tiny: "Tiny (Windowsill/Indoor)"
        case .small: "Small (Balcony/Patio)"
        case .medium: "Medium (Small Yard)"
        case .large: "Large (Large Yard)"
        case .acreage: "Acreage (Farm/Estate)"
        }
    }

    var description: String {
        switch self {
        case .tiny: "Perfect for herbs and small houseplants"
        case .small: "Container gardening and small plants"
        case .medium: "Raised beds and medium-sized gardens"
        case .large: "Multiple garden areas and diverse plantings"
        case .acreage: "Large-scale gardening and farming"
        }
    }
}

#Preview {
    OnboardingView()
}
