import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep

    /// Welcome and completion are full-screen moments — no dots shown
    private let visibleSteps: [OnboardingStep] = [
        .skillAssessment, .goals, .gardenSetup, .location, .notifications,
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, step in
                StepDot(state: dotState(for: step))
                    .accessibilityIdentifier("onboarding_step_\(step.rawValue)")

                if index < visibleSteps.count - 1 {
                    Capsule()
                        .fill(
                            step.stepNumber < currentStep.stepNumber
                                ? CultivationTheme.Colors.brandLeaf
                                : Color.white.opacity(0.20)
                        )
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .animation(.spring(duration: 0.4), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }

    private func dotState(for step: OnboardingStep) -> StepDotState {
        if step.stepNumber < currentStep.stepNumber { return .completed }
        if step == currentStep { return .active }
        return .upcoming
    }
}

// MARK: - Supporting Types

enum StepDotState { case completed, active, upcoming }

private struct StepDot: View {
    let state: StepDotState

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(border, lineWidth: 1.5))
                .frame(width: 24, height: 24)

            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else if state == .active {
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
            }
        }
        .scaleEffect(state == .active ? 1.1 : 1.0)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: state)
    }

    private var fill: Color {
        switch state {
        case .completed: CultivationTheme.Colors.brandLeaf
        case .active: CultivationTheme.Colors.accentCoral
        case .upcoming: .clear
        }
    }

    private var border: Color {
        switch state {
        case .completed: CultivationTheme.Colors.brandLeaf
        case .active: CultivationTheme.Colors.accentCoral
        case .upcoming: CultivationTheme.Colors.divider
        }
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack(spacing: 24) {
            ForEach([OnboardingStep.skillAssessment, .goals, .gardenSetup, .location], id: \.self) { step in
                OnboardingProgressView(currentStep: step)
            }
        }
    }
}
