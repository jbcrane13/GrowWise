import GrowWiseModels
import SwiftUI

struct GardeningGoalsView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                OnboardingStepHeader(
                    icon: "scope",
                    iconColor: Color.botanicalForest,
                    title: "What brings you\nto gardening?",
                    subtitle: "Select everything that resonates. We'll tailor your experience to match your vision."
                )

                // Goal cards grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(GardeningGoal.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: userProfile.goals.contains(goal),
                            action: {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    if userProfile.goals.contains(goal) {
                                        userProfile.goals.remove(goal)
                                    } else {
                                        userProfile.goals.insert(goal)
                                    }
                                }
                            }
                        )
                        .accessibilityIdentifier("onboarding_goal_\(goal.rawValue)")
                    }
                }
                .padding(.horizontal, 24)

                // Garden type selection
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "What type of garden?")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(GardenType.allCases, id: \.self) { gardenType in
                                GardenTypeChip(
                                    gardenType: gardenType,
                                    isSelected: userProfile.gardenType == gardenType,
                                    action: {
                                        withAnimation(.spring(duration: 0.25)) {
                                            userProfile.gardenType = gardenType
                                        }
                                    }
                                )
                                .accessibilityIdentifier("onboarding_gardentype_\(gardenType.rawValue)")
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Space size
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "How much space do you have?")

                    VStack(spacing: 8) {
                        ForEach(SpaceSize.allCases, id: \.self) { size in
                            SpaceSizeRow(
                                size: size,
                                isSelected: userProfile.spaceSize == size,
                                action: {
                                    withAnimation(.spring(duration: 0.25)) {
                                        userProfile.spaceSize = size
                                    }
                                }
                            )
                            .padding(.horizontal, 24)
                            .accessibilityIdentifier("onboarding_space_\(size.rawValue)")
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Section Label

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color.botanicalForest)
            .padding(.horizontal, 24)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: GardeningGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.22) : goal.accentColor.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: goal.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? .white : goal.accentColor)
                }

                VStack(spacing: 4) {
                    Text(goal.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : Color.botanicalForest)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(goal.description)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.80) : Color.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [goal.accentColor, goal.accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white, Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? goal.accentColor.opacity(0.35)
                            : Color.black.opacity(0.06),
                        radius: isSelected ? 10 : 6,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : Color.botanicalSage.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.displayName)
    }
}

// MARK: - Garden Type Chip

struct GardenTypeChip: View {
    let gardenType: GardenType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: gardenType.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.botanicalForest)

                Text(gardenType.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color.botanicalForest)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.botanicalForest : Color.white)
                    .shadow(color: Color.black.opacity(0.07), radius: 4, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.botanicalSage.opacity(0.30),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gardenType.displayName)
    }
}

// MARK: - Space Size Row

struct SpaceSizeRow: View {
    let size: SpaceSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon box
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.botanicalForest : Color.botanicalMint.opacity(0.30))
                        .frame(width: 40, height: 40)

                    Image(systemName: size.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.botanicalForest)
                }

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(size.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.botanicalForest)

                        Text("·")
                            .foregroundColor(Color.secondary)

                        Text(size.subtitle)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color.secondary)
                    }
                }

                Spacer()

                // Check indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.botanicalLeaf)
                } else {
                    Circle()
                        .stroke(Color.botanicalSage.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.botanicalMint.opacity(0.25) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.botanicalLeaf.opacity(0.5) : Color.botanicalSage.opacity(0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.displayName), \(size.subtitle)")
    }
}

// MARK: - GardenType Extensions

extension GardenType {
    var iconName: String {
        switch self {
        case .outdoor: "sun.max.fill"
        case .indoor: "house.fill"
        case .container: "rectangle.3.offgrid.fill"
        case .raised: "rectangle.stack.fill"
        case .hydroponic: "drop.circle.fill"
        case .greenhouse: "leaf.fill"
        case .balcony: "building.2.fill"
        case .windowsill: "window.horizontal"
        }
    }
}

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        GardeningGoalsView(userProfile: .constant(UserProfile()))
    }
}
