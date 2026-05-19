import GrowWiseModels
import SwiftUI

/// Environment-specific setup screen that branches based on the garden type
/// selected in GardenSetupView. Shows different questions for Indoor, Outdoor,
/// and Hydroponic environments.
struct EnvironmentSetupView: View {
    @Binding var userProfile: UserProfile

    @ViewBuilder private var environmentView: some View {
        switch userProfile.gardenType {
        case .indoor, .windowsill:
            indoorEnvironmentView

        case .outdoor, .raised, .balcony, .greenhouse:
            outdoorEnvironmentView

        case .hydroponic:
            hydroponicEnvironmentView

        case .container:
            // Container gardens use outdoor-style questions
            outdoorEnvironmentView
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                OnboardingStepHeader(
                    icon: environmentIcon,
                    iconColor: CultivationTheme.Colors.brandLeaf,
                    title: environmentTitle,
                    subtitle: environmentSubtitle
                )

                environmentView
                    .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Environment Info

    private var environmentIcon: String {
        switch userProfile.gardenType {
        case .indoor, .windowsill: "house.fill"
        case .outdoor, .raised, .balcony, .greenhouse: "sun.max.fill"
        case .hydroponic: "drop.triangle.fill"
        case .container: "square.grid.2x2.fill"
        }
    }

    private var environmentTitle: String {
        switch userProfile.gardenType {
        case .indoor, .windowsill: "Indoor\nenvironment"
        case .outdoor, .raised, .balcony, .greenhouse: "Outdoor\nconditions"
        case .hydroponic: "Hydroponic\nsystem"
        case .container: "Container\nsetup"
        }
    }

    private var environmentSubtitle: String {
        switch userProfile.gardenType {
        case .indoor, .windowsill:
            "Helps us recommend the right plants and care routine."

        case .outdoor, .raised, .balcony, .greenhouse:
            "Your climate and location help us plan seasonal activities."

        case .hydroponic:
            "Your system setup helps us calibrate nutrient delivery."

        case .container:
            "Container placement affects light and water needs."
        }
    }

    // MARK: - Indoor View

    private var indoorEnvironmentView: some View {
        VStack(spacing: 16) {
            // Light availability
            VStack(alignment: .leading, spacing: 10) {
                Text("LIGHT AVAILABILITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .tracking(1.0)
                    .padding(.horizontal, 4)

                ForEach(LightAvailability.allCases, id: \.self) { level in
                    IndoorOptionRow(
                        title: level.displayName,
                        isSelected: userProfile.indoorLightAvailability == level
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            userProfile.indoorLightAvailability = level
                        }
                    }
                    .accessibilityIdentifier("onboarding_light_\(level.rawValue)")
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // Room temperature toggle
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $userProfile.indoorRoomTemp) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Consistent room temperature")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text("Stable temps between 65-75°F year-round")
                            .font(.system(size: 12))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
                .tint(CultivationTheme.Colors.brandLeaf)
                .accessibilityIdentifier("onboarding_toggle_room_temp")
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // Pets toggle
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $userProfile.hasPetsInHome) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pets in the home")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text("We'll flag plants that may be toxic to pets")
                            .font(.system(size: 12))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
                .tint(CultivationTheme.Colors.brandLeaf)
                .accessibilityIdentifier("onboarding_toggle_pets")
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    // MARK: - Outdoor View

    private var outdoorEnvironmentView: some View {
        VStack(spacing: 16) {
            // Hardiness zone
            VStack(alignment: .leading, spacing: 10) {
                Text("HARDINESS ZONE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .tracking(1.0)
                    .padding(.horizontal, 4)

                ZStack {
                    TextField("e.g. 7a, 9b", text: $userProfile.hardinessZone)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .padding(12)
                        .autocorrectionDisabled()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CultivationTheme.Colors.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("onboarding_textfield_zone")
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // Sun exposure
            VStack(alignment: .leading, spacing: 10) {
                Text("SUN EXPOSURE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .tracking(1.0)
                    .padding(.horizontal, 4)

                ForEach(SunExposure.allCases, id: \.self) { exposure in
                    OutdoorOptionRow(
                        title: exposure.displayName,
                        isSelected: userProfile.sunExposure == exposure
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            userProfile.sunExposure = exposure
                        }
                    }
                    .accessibilityIdentifier("onboarding_sun_\\(exposure.rawValue)")
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // Frost protection toggle
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $userProfile.hasFrostProtection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frost protection available")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text("Cover, cold frame, or bring plants inside")
                            .font(.system(size: 12))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
                .tint(CultivationTheme.Colors.brandLeaf)
                .accessibilityIdentifier("onboarding_toggle_frost")
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    // MARK: - Hydroponic View

    private var hydroponicEnvironmentView: some View {
        VStack(spacing: 16) {
            // System type
            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM TYPE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .tracking(1.0)
                    .padding(.horizontal, 4)

                ForEach(HydroponicSystemType.allCases, id: \.self) { type in
                    IndoorOptionRow(
                        title: type.displayName,
                        isSelected: userProfile.hydroponicSystemType == type
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            userProfile.hydroponicSystemType = type
                        }
                    }
                    .accessibilityIdentifier("onboarding_hydro_type_\\(type.rawValue)")
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // Nutrient schedule slider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("NUTRIENT SCHEDULE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .tracking(1.0)
                    Spacer()
                    Text("\(Int(userProfile.nutrientSchedule * 100))% strength")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }

                Slider(value: $userProfile.nutrientSchedule, in: 0.1 ... 1.0, step: 0.1)
                    .tint(CultivationTheme.Colors.brandLeaf)
                    .accessibilityIdentifier("onboarding_slider_nutrients")

                HStack {
                    Text("Low")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Spacer()
                    Text("High")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()

            // pH range slider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TARGET PH RANGE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .tracking(1.0)
                    Spacer()
                    Text(String(format: "%.1f - %.1f", userProfile.phRange.lowerBound, userProfile.phRange.upperBound))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }

                HStack(spacing: 12) {
                    Text("5.0")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(CultivationTheme.Colors.backgroundSecondary)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(CultivationTheme.Gradients.warmAccent)
                                .frame(width: phRangeWidth(in: geometry.size), height: 8)
                                .offset(x: geometry.size.width * (userProfile.phRange.lowerBound - 5.0) / 5.0)
                        }
                    }
                    .frame(height: 8)

                    Text("8.0")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }

                HStack(spacing: 8) {
                    Text("Acidic")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Spacer()
                    Text("Neutral")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Spacer()
                    Text("Alkaline")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    private func phRangeWidth(in size: CGSize) -> CGFloat {
        size.width * (userProfile.phRange.upperBound - userProfile.phRange.lowerBound) / 5.0
    }
}

// MARK: - Indoor Option Row

private struct IndoorOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf.opacity(0.20)
                                : CultivationTheme.Colors.backgroundSecondary
                        )
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    }
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

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
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.10)
                            : CultivationTheme.Colors.cardSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.35) : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Outdoor Option Row

private struct OutdoorOptionRow: View {
    let title: String
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
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    }
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

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
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.10)
                            : CultivationTheme.Colors.cardSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? CultivationTheme.Colors.brandLeaf.opacity(0.35) : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack {
            EnvironmentSetupView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
