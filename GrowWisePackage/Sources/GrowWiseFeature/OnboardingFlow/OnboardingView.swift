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
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator (hidden on welcome)
                    if currentStep != .welcome {
                        OnboardingProgressView(currentStep: currentStep)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Main content
                    TabView(selection: $currentStep) {
                        WelcomeStepView()
                            .tag(OnboardingStep.welcome)

                        SkillAssessmentView(userProfile: $userProfile)
                            .tag(OnboardingStep.skillAssessment)

                        GardeningGoalsView(userProfile: $userProfile)
                            .tag(OnboardingStep.goals)

                        GardenSetupView(userProfile: $userProfile)
                            .tag(OnboardingStep.gardenSetup)

                        LocationSetupView(userProfile: $userProfile)
                            .tag(OnboardingStep.location)

                        NotificationPermissionView(userProfile: $userProfile)
                            .tag(OnboardingStep.notifications)

                        CompletionView(userProfile: $userProfile)
                            .tag(OnboardingStep.completion)
                    }
                    .gwPagingTabStyle(indexDisplayMode: .never)
                    .animation(.spring(duration: 0.45, bounce: 0.05), value: currentStep)

                    // Navigation buttons
                    OnboardingNavigationView(
                        currentStep: $currentStep,
                        userProfile: $userProfile,
                        isCompleted: $isCompleted
                    )
                    .padding(.bottom, 16)
                }
            }
        }
        .accessibilityIdentifier("OnboardingView")
        .gwNavigationBarHidden(true)
        .onChange(of: isCompleted) { _, completed in
            if completed {
                onCompleted?()
                dismiss()
            }
        }
    }

    private var welcomeBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.botanicalForest,
                    Color(red: 0.118, green: 0.306, blue: 0.235),
                    Color(red: 0.094, green: 0.235, blue: 0.188),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Organic decorative orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.botanicalLeaf.opacity(0.25))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -60, y: -80)

                Circle()
                    .fill(Color.botanicalMint.opacity(0.15))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: geo.size.width - 100, y: 120)

                Circle()
                    .fill(Color.botanicalGold.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: 60, y: geo.size.height - 200)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Supporting Types

public enum OnboardingStep: String, CaseIterable {
    case welcome
    case skillAssessment
    case goals
    case gardenSetup
    case location
    case notifications
    case completion

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .skillAssessment: "Experience"
        case .goals: "Goals"
        case .gardenSetup: "Setup"
        case .location: "Location"
        case .notifications: "Reminders"
        case .completion: "All Set"
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
        case .learnSkills: "Learn Gardening"
        case .relaxation: "Relaxation & Therapy"
        case .sustainability: "Sustainable Living"
        case .healingGarden: "Healing Garden"
        }
    }

    var description: String {
        switch self {
        case .growFood: "Fresh vegetables, herbs & fruits"
        case .beautifySpace: "Flowers and decorative plants"
        case .learnSkills: "Master gardening techniques"
        case .relaxation: "Peaceful gardening activities"
        case .sustainability: "Eco-friendly practices"
        case .healingGarden: "Plants for wellness & meditation"
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

    var accentColor: Color {
        switch self {
        case .growFood: Color(red: 0.922, green: 0.596, blue: 0.200)
        case .beautifySpace: Color(red: 0.780, green: 0.420, blue: 0.820)
        case .learnSkills: Color(red: 0.275, green: 0.565, blue: 0.898)
        case .relaxation: Color.botanicalForest
        case .sustainability: Color.botanicalLeaf
        case .healingGarden: Color(red: 0.882, green: 0.380, blue: 0.459)
        }
    }
}

#Preview {
    OnboardingView()
}
