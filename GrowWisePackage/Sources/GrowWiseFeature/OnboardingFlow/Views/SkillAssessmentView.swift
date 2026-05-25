import GrowWiseModels
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

struct SkillAssessmentView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "graduationcap.fill",
                iconColor: CultivationTheme.Colors.brandLeaf,
                title: "Your experience level?",
                subtitle: "We'll tailor guides to match your skill."
            )

            // Cards fill remaining space between header and CTA
            VStack(spacing: 10) {
                ForEach(GardeningSkillLevel.allCases, id: \.self) { level in
                    SkillLevelCard(
                        level: level,
                        isSelected: userProfile.skillLevel == level
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            userProfile.skillLevel = level
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Skill Level Card (Dark Glass)

private struct SkillLevelCard: View {
    let level: GardeningSkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon bubble
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? CultivationTheme.Colors.brandForest.opacity(0.15) : CultivationTheme.Colors.accentCoral.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: level.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : CultivationTheme.Colors.accentCoral)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text(level.description)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? CultivationTheme.Colors.textSecondary : CultivationTheme.Colors.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection ring
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? CultivationTheme.Colors.brandLeaf : CultivationTheme.Colors.divider,
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(CultivationTheme.Colors.brandLeaf)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [CultivationTheme.Colors.brandForest, CultivationTheme.Colors.brandLeaf.opacity(0.85)],
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
                                isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.20) : CultivationTheme.Colors.cardBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? CultivationTheme.Colors.brandForest.opacity(0.4) : .clear,
                        radius: 12,
                        y: 4
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.displayName)
        .accessibilityIdentifier("onboarding_skill_\(level.rawValue)")
    }
}

extension GardeningSkillLevel {
    var iconName: String {
        switch self {
        case .beginner: "sprout.fill"
        case .intermediate: "leaf.fill"
        case .advanced: "tree"
        case .expert: "tree.fill"
        }
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack {
            SkillAssessmentView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}

// swiftlint:enable line_length
