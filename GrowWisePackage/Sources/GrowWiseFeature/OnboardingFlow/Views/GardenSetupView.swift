import GrowWiseModels
import SwiftUI

struct GardenSetupView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "square.split.2x1.fill",
                iconColor: CultivationTheme.Colors.brandLeaf,
                title: "Tell us about\nyour garden",
                subtitle: "Helps us give you the right plant advice."
            )

            VStack(spacing: 16) {
                // Garden type — horizontal chip row
                VStack(alignment: .leading, spacing: 10) {
                    Text("GARDEN TYPE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .tracking(1.0)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GardenType.allCases, id: \.self) { type in
                                GardenTypeChip(
                                    type: type,
                                    isSelected: userProfile.gardenType == type
                                ) {
                                    withAnimation(.spring(duration: 0.25)) {
                                        userProfile.gardenType = type
                                    }
                                }
                                .accessibilityIdentifier("onboarding_gardentype_\(type.rawValue)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Space size — vertical list, fills remaining height
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR SPACE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .tracking(1.0)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        ForEach(SpaceSize.allCases, id: \.self) { size in
                            SpaceSizeRow(
                                size: size,
                                isSelected: userProfile.spaceSize == size
                            ) {
                                withAnimation(.spring(duration: 0.25)) {
                                    userProfile.spaceSize = size
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(maxHeight: .infinity)
                            .accessibilityIdentifier("onboarding_space_\(size.rawValue)")
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Garden Type Chip (Dark)

private struct GardenTypeChip: View {
    let type: GardenType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : CultivationTheme.Colors.brandLeaf)
                Text(type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : CultivationTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [CultivationTheme.Colors.brandForest, CultivationTheme.Colors.brandLeaf],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [CultivationTheme.Colors.cardSurface, CultivationTheme.Colors.cardSurface],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .overlay(
                        Capsule().stroke(
                            isSelected ? Color.clear : CultivationTheme.Colors.cardBorder,
                            lineWidth: 1
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
    }
}

// MARK: - Space Size Row (Dark)

private struct SpaceSizeRow: View {
    let size: SpaceSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.20) : CultivationTheme.Colors.backgroundSecondary)
                        .frame(width: 40, height: 40)
                    Image(systemName: size.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? CultivationTheme.Colors.brandLeaf : CultivationTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(size.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("·")
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        Text(size.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                } else {
                    Circle()
                        .stroke(CultivationTheme.Colors.divider, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.10)
                            : CultivationTheme.Colors.cardSurface
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.35) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.displayName), \(size.subtitle)")
    }
}

// GardenType icon extension moved to GardenComponents.swift

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack {
            GardenSetupView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
