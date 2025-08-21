import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var userProfile = UserProfile()
    @State private var isCompleted = false
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient that adapts to appearance mode
                LinearGradient(
                    colors: [
                        Color.adaptiveGreenBackground,
                        Color(light: Color.blue.opacity(0.1), dark: Color.blue.opacity(0.15))
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
                    .tabViewStyle(.page(indexDisplayMode: .never))
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
        .navigationBarHidden(true)
        .onChange(of: isCompleted) { _, completed in
            if completed {
                dismiss()
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
        case .welcome: return "Welcome to GrowWise"
        case .skillAssessment: return "Your Gardening Experience"
        case .goals: return "Your Gardening Goals"
        case .location: return "Your Location"
        case .notifications: return "Stay Connected"
        case .completion: return "You're All Set!"
        }
    }
    
    var stepNumber: Int {
        return OnboardingStep.allCases.firstIndex(of: self) ?? 0
    }
    
    var totalSteps: Int {
        return OnboardingStep.allCases.count
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
    case relaxation = "relaxation"
    case sustainability = "sustainability"
    case healingGarden = "healing_garden"
    
    public var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .growFood: return "Grow My Own Food"
        case .beautifySpace: return "Beautify My Space"
        case .learnSkills: return "Learn Gardening Skills"
        case .relaxation: return "Relaxation & Therapy"
        case .sustainability: return "Sustainable Living"
        case .healingGarden: return "Create a Healing Garden"
        }
    }
    
    var description: String {
        switch self {
        case .growFood: return "Fresh vegetables, herbs, and fruits"
        case .beautifySpace: return "Flowers and decorative plants"
        case .learnSkills: return "Master gardening techniques"
        case .relaxation: return "Peaceful gardening activities"
        case .sustainability: return "Eco-friendly practices"
        case .healingGarden: return "Plants for wellness and meditation"
        }
    }
    
    var icon: String {
        switch self {
        case .growFood: return "carrot.fill"
        case .beautifySpace: return "sparkles"
        case .learnSkills: return "book.fill"
        case .relaxation: return "leaf.fill"
        case .sustainability: return "globe.americas.fill"
        case .healingGarden: return "heart.fill"
        }
    }
}

public enum SpaceSize: String, CaseIterable {
    case tiny = "tiny"           // Windowsill, small containers
    case small = "small"         // Balcony, small patio
    case medium = "medium"       // Small yard, large patio
    case large = "large"         // Large yard, multiple beds
    case acreage = "acreage"     // Farm or large property
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (Windowsill/Indoor)"
        case .small: return "Small (Balcony/Patio)"
        case .medium: return "Medium (Small Yard)"
        case .large: return "Large (Large Yard)"
        case .acreage: return "Acreage (Farm/Estate)"
        }
    }
    
    var description: String {
        switch self {
        case .tiny: return "Perfect for herbs and small houseplants"
        case .small: return "Container gardening and small plants"
        case .medium: return "Raised beds and medium-sized gardens"
        case .large: return "Multiple garden areas and diverse plantings"
        case .acreage: return "Large-scale gardening and farming"
        }
    }
}

#Preview {
    OnboardingView()
}