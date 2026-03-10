import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep

    /// Exclude welcome and completion from the visible step dots
    private let visibleSteps: [OnboardingStep] = [
        .skillAssessment, .goals, .location, .notifications,
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Step dots + connectors
            HStack(spacing: 0) {
                ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, step in
                    StepIndicatorDot(
                        label: step.title,
                        state: dotState(for: step)
                    )
                    .accessibilityIdentifier("onboarding_step_\(step.rawValue)")

                    if index < visibleSteps.count - 1 {
                        Capsule()
                            .fill(
                                step.stepNumber < currentStep.stepNumber
                                    ? Color.botanicalLeaf
                                    : Color.botanicalSage.opacity(0.35)
                            )
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .animation(.spring(duration: 0.4), value: currentStep)
                    }
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.vertical, 4)
    }

    private func dotState(for step: OnboardingStep) -> StepDotState {
        if step.stepNumber < currentStep.stepNumber { return .completed }
        if step == currentStep { return .active }
        return .upcoming
    }
}

enum StepDotState {
    case completed, active, upcoming
}

struct StepIndicatorDot: View {
    let label: String
    let state: StepDotState

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Track circle
                Circle()
                    .fill(circleFill)
                    .overlay(
                        Circle()
                            .stroke(circleBorder, lineWidth: 1.5)
                    )
                    .frame(width: 28, height: 28)
                    .shadow(
                        color: state == .active ? Color.botanicalForest.opacity(0.3) : .clear,
                        radius: 6,
                        y: 2
                    )

                // Inner content
                Group {
                    if state == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else if state == .active {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .scaleEffect(state == .active ? 1.1 : 1.0)
            .animation(.spring(duration: 0.35, bounce: 0.3), value: state)

            Text(label)
                .font(.system(size: 10, weight: state == .active ? .semibold : .regular, design: .rounded))
                .foregroundColor(
                    state == .upcoming
                        ? Color.botanicalSage.opacity(0.6)
                        : Color.botanicalForest
                )
                .lineLimit(1)
        }
    }

    private var circleFill: Color {
        switch state {
        case .completed: Color.botanicalLeaf
        case .active: Color.botanicalForest
        case .upcoming: Color.clear
        }
    }

    private var circleBorder: Color {
        switch state {
        case .completed: Color.botanicalLeaf
        case .active: Color.botanicalForest
        case .upcoming: Color.botanicalSage.opacity(0.4)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach([OnboardingStep.skillAssessment, .goals, .location, .notifications], id: \.self) { step in
            OnboardingProgressView(currentStep: step)
                .padding(.horizontal)
        }
    }
    .background(Color.botanicalCream)
}
