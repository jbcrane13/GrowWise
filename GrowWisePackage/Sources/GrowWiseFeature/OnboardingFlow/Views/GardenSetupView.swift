import GrowWiseModels
import SwiftUI

struct GardenSetupView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                OnboardingStepHeader(
                    icon: "square.split.2x1.fill",
                    iconColor: CultivationTheme.Colors.brandLeaf,
                    title: "Tell us about\nyour garden",
                    subtitle: "Helps us give you the right plant advice."
                )

                VStack(spacing: 16) {
                    gardenCreationSection

                    // Garden type — horizontal chip row
                    if userProfile.shouldCreateFirstGarden {
                        containerCreationSection

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
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private var gardenCreationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $userProfile.shouldCreateFirstGarden) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create your first garden")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Text(userProfile.shouldCreateFirstGarden ? "Ready for plants after setup" : "Skipped for now")
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .tint(CultivationTheme.Colors.brandLeaf)
            .accessibilityIdentifier("onboarding_toggle_create_garden")

            if userProfile.shouldCreateFirstGarden {
                TextField("Garden name", text: $userProfile.firstGardenName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(CultivationTheme.Colors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                    )
                    .accessibilityIdentifier("onboarding_textfield_garden_name")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .padding(.horizontal, 20)
    }

    private var containerCreationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $userProfile.shouldCreateFirstContainer) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a starter container")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Text(userProfile.shouldCreateFirstContainer ? "Your first plant has a home" : "Plants can be assigned later")
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .tint(CultivationTheme.Colors.brandLeaf)
            .accessibilityIdentifier("onboarding_toggle_create_container")

            if userProfile.shouldCreateFirstContainer {
                TextField("Container name", text: $userProfile.firstContainerName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(CultivationTheme.Colors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                    )
                    .accessibilityIdentifier("onboarding_textfield_container_name")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BedType.allCases, id: \.self) { type in
                            ContainerTypeChip(
                                type: type,
                                isSelected: userProfile.firstContainerType == type
                            ) {
                                withAnimation(.spring(duration: 0.25)) {
                                    userProfile.firstContainerType = type
                                    if userProfile.firstContainerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        userProfile.firstContainerName = type.displayName
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .padding(.horizontal, 20)
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
        .accessibilityIdentifier("onboarding_gardentype_\(type.rawValue)")
    }
}

// MARK: - Container Type Chip

private struct ContainerTypeChip: View {
    let type: BedType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 13, weight: .medium))
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : CultivationTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
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
        .accessibilityIdentifier("onboarding_containertype_\(type.rawValue)")
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
                        .fill(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf.opacity(0.20)
                                : CultivationTheme.Colors.backgroundSecondary
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: size.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? CultivationTheme.Colors.brandLeaf : CultivationTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(size.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
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
                                isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.35) : CultivationTheme.Colors.cardBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.displayName), \(size.subtitle)")
        .accessibilityIdentifier("onboarding_space_\(size.rawValue)")
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
