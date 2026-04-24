import GrowWiseModels
import SwiftUI

struct GardeningGoalsView: View {
    @Binding var userProfile: UserProfile

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "scope",
                iconColor: CultivationTheme.Colors.brandLeaf,
                title: "What brings you\nto gardening?",
                subtitle: "Pick everything that resonates."
            )

            // Grid fills remaining space
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GardeningGoal.allCases) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: userProfile.goals.contains(goal)
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            if userProfile.goals.contains(goal) {
                                userProfile.goals.remove(goal)
                            } else {
                                userProfile.goals.insert(goal)
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding_goal_\(goal.rawValue)")
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Goal Card (Dark Glass)

private struct GoalCard: View {
    let goal: GardeningGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? goal.accentColor.opacity(0.20) : goal.accentColor.opacity(0.10))
                        .frame(width: 48, height: 48)
                    Image(systemName: goal.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : goal.accentColor)
                }

                Text(goal.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [goal.accentColor.opacity(0.60), goal.accentColor.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [CultivationTheme.Colors.cardSurface, CultivationTheme.Colors.cardSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? goal.accentColor.opacity(0.50) : CultivationTheme.Colors.cardBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? goal.accentColor.opacity(0.30) : .clear,
                        radius: 10,
                        y: 3
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.displayName)
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack {
            GardeningGoalsView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
