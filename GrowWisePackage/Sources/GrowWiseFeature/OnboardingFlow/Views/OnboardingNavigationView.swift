import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

struct OnboardingNavigationView: View {
    @Binding var currentStep: OnboardingStep
    @Binding var userProfile: UserProfile
    @Binding var isCompleted: Bool

    let analyticsTracker: OnboardingAnalyticsTracker

    @Environment(DataService.self)
    private var dataService
    @Environment(NotificationService.self)
    private var notificationService

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    private var isFirstStep: Bool {
        currentStep == OnboardingStep.allCases.first
    }

    private var isLastStep: Bool {
        currentStep == OnboardingStep.allCases.last
    }

    private var canProceed: Bool {
        switch currentStep {
        case .welcome, .skillAssessment, .gardenSetup, .environmentSetup, .location, .notifications, .firstPlant, .completion:
            true

        case .goals:
            !userProfile.goals.isEmpty
        }
    }

    private var nextLabel: String {
        switch currentStep {
        case .welcome: "Get Started"
        case .completion: "Start Growing"
        default: "Continue"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Separator line
            Divider()

            HStack(spacing: 12) {
                // Back button
                if !isFirstStep {
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.05)) {
                            moveToStep(direction: .previous)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(CultivationTheme.Colors.cardSurface)
                                    .shadow(
                                        color: Color(red: 0.12, green: 0.16, blue: 0.13, opacity: 0.06),
                                        radius: 6,
                                        y: 2
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        CultivationTheme.Colors.cardBorder,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("onboarding_nav_back")
                }

                // Next / Finish button
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.05)) {
                        if isLastStep {
                            completeOnboarding()
                        } else {
                            moveToStep(direction: .next)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.85)
                                .tint(.white)
                        }

                        Text(isSaving ? "Setting up…" : nextLabel)
                            .font(.system(size: 16, weight: .semibold))

                        if !isSaving, !isLastStep, currentStep != .welcome {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                canProceed
                                    ? CultivationTheme.Gradients.warmAccent
                                    : LinearGradient(
                                        colors: [CultivationTheme.Colors.textTertiary, CultivationTheme.Colors.textTertiary.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                            )
                            .shadow(
                                color: canProceed ? CultivationTheme.Colors.accentCoral.opacity(0.25) : .clear,
                                radius: 8,
                                y: 3
                            )
                    )
                }
                .disabled(!canProceed || isSaving)
                .accessibilityLabel(nextLabel)
                .accessibilityIdentifier("onboarding_nav_next")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
        .alert("Setup Error", isPresented: $showingError) {
            Button("OK") {}
                .accessibilityIdentifier("onboarding_nav_button_error_dismiss")
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
        isSaving = true
        Task {
            do {
                let email = "user@example.com"
                let displayName = "Gardener"

                let emailValidation = ValidationService.shared.validateEmail(email)
                guard emailValidation.isValid else {
                    await showError(emailValidation.errorMessage ?? "Invalid email address")
                    return
                }

                let nameValidation = ValidationService.shared.validateName(displayName)
                guard nameValidation.isValid else {
                    await showError(nameValidation.errorMessage ?? "Invalid display name")
                    return
                }

                let user = try dataService.createUser(
                    email: email,
                    displayName: displayName,
                    skillLevel: userProfile.skillLevel
                )

                try await saveUserPreferences(user: user)
                let firstGarden = try await createFirstGardenIfRequested()
                let firstContainer = try await createFirstContainerIfRequested(garden: firstGarden)
                try await createFirstPlantIfSelected(garden: firstGarden, gardenBed: firstContainer)
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                await MainActor.run {
                    analyticsTracker.trackOnboardingCompleted()
                    isSaving = false
                    isCompleted = true
                }
            } catch {
                await showError("Failed to complete setup: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showError(_ message: String) {
        isSaving = false
        errorMessage = message
        showingError = true
    }

    @MainActor
    private func createFirstGardenIfRequested() async throws -> Garden? {
        guard userProfile.shouldCreateFirstGarden else { return nil }
        let trimmedName = userProfile.firstGardenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let gardenName = trimmedName.isEmpty ? "My First Garden" : trimmedName

        return try dataService.createGarden(
            name: gardenName,
            type: userProfile.gardenType,
            isIndoor: OnboardingPersonalization.defaultIsIndoor(for: userProfile.gardenType),
            spaceSize: userProfile.spaceSize
        )
    }

    @MainActor
    private func createFirstContainerIfRequested(garden: Garden?) async throws -> GardenBed? {
        guard userProfile.shouldCreateFirstGarden, userProfile.shouldCreateFirstContainer else { return nil }
        guard let garden else { return nil }
        let trimmedName = userProfile.firstContainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let containerName = trimmedName.isEmpty ? "Starter Container" : trimmedName

        return try dataService.createGardenBed(
            name: containerName,
            bedType: userProfile.firstContainerType,
            in: garden
        )
    }

    @MainActor
    private func createFirstPlantIfSelected(garden: Garden?, gardenBed: GardenBed?) async throws {
        guard let plantName = userProfile.selectedFirstPlantName, !plantName.isEmpty else { return }
        guard let garden else {
            throw OnboardingSaveError.firstPlantNeedsGarden
        }
        guard let template = selectedFirstPlantTemplate(named: plantName) else {
            throw OnboardingSaveError.firstPlantTemplateMissing(plantName)
        }

        _ = try dataService.createStarterPlant(from: template, in: garden, gardenBed: gardenBed)
    }

    private func selectedFirstPlantTemplate(named plantName: String) -> Plant? {
        let templates = dataService.fetchPlantDatabase()
        if let selectedFirstPlantID = userProfile.selectedFirstPlantID,
           let match = templates.first(where: { $0.id == selectedFirstPlantID })
        {
            return match
        }
        return templates.first { $0.name == plantName }
    }

    @MainActor
    private func saveUserPreferences(user: User) async throws {
        let goalsData = try JSONEncoder().encode(userProfile.goals.map(\.rawValue))
        UserDefaults.standard.set(goalsData, forKey: "userGardeningGoals")
        let interestsData = try JSONEncoder().encode(userProfile.interests.map(\.rawValue))
        UserDefaults.standard.set(interestsData, forKey: "userPlantInterests")
        UserDefaults.standard.set(userProfile.gardenType.rawValue, forKey: "userGardenType")
        UserDefaults.standard.set(userProfile.spaceSize.rawValue, forKey: "userSpaceSize")
        let timeData = try JSONEncoder().encode(userProfile.preferredNotificationTime)
        UserDefaults.standard.set(timeData, forKey: "userPreferredNotificationTime")
        if userProfile.hasNotificationPermission {
            notificationService.setupNotificationCategories()
        }

        try dataService.updateOnboardingProfile(
            for: user,
            gardeningGoals: OnboardingPersonalization.modelGoals(from: userProfile.goals),
            preferredPlantTypes: OnboardingPersonalization.preferredPlantTypes(
                goals: userProfile.goals,
                interests: userProfile.interests
            )
        )
    }
}

enum StepDirection {
    case next
    case previous
}

private enum OnboardingSaveError: LocalizedError {
    case firstPlantNeedsGarden
    case firstPlantTemplateMissing(String)

    var errorDescription: String? {
        switch self {
        case .firstPlantNeedsGarden:
            "Create a first garden before adding a first plant, or skip the first plant for now."

        case .firstPlantTemplateMissing(let name):
            "Could not find \(name) in the plant database. Please pick a plant again or skip for now."
        }
    }
}

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        VStack {
            Spacer()
            OnboardingNavigationView(
                currentStep: .constant(.goals),
                userProfile: .constant(UserProfile()),
                isCompleted: .constant(false),
                analyticsTracker: .shared
            )
        }
    }
}

// swiftlint:enable line_length
