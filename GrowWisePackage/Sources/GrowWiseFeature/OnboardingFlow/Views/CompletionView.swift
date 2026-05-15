import SwiftUI

struct CompletionView: View {
    @Binding var userProfile: UserProfile
    @State private var heroVisible = false
    @State private var summaryVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero checkmark
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.14))
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CultivationTheme.Colors.brandForest, CultivationTheme.Colors.brandLeaf],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: CultivationTheme.Colors.brandForest.opacity(0.45), radius: 20, y: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.75)

                VStack(spacing: 8) {
                    Text("Your garden awaits!")
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Everything's set up. Let's grow.")
                        .font(.system(size: 16))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 12)
            }

            Spacer().frame(height: 32)

            // Profile summary card — glass, setup rows
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Text("Your Profile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                CompletionSummaryRow(
                    icon: "graduationcap.fill",
                    iconColor: CultivationTheme.Colors.brandLeaf,
                    label: "Experience",
                    value: userProfile.skillLevel.displayName
                )

                Divider().padding(.leading, 48)
                CompletionSummaryRow(
                    icon: "scope",
                    iconColor: CultivationTheme.Colors.brandLeaf.opacity(0.80),
                    label: "Goals",
                    value: Self.goalsSummary(for: userProfile)
                )

                Divider().padding(.leading, 48)
                CompletionSummaryRow(
                    icon: "leaf.fill",
                    iconColor: CultivationTheme.Colors.brandLeaf.opacity(0.70),
                    label: "First Garden",
                    value: Self.gardenSummary(for: userProfile)
                )

                if userProfile.shouldCreateFirstGarden {
                    Divider().padding(.leading, 48)
                    CompletionSummaryRow(
                        icon: userProfile.firstContainerType.iconName,
                        iconColor: CultivationTheme.Colors.accentCoral,
                        label: "First Container",
                        value: Self.containerSummary(for: userProfile)
                    )

                    Divider().padding(.leading, 48)
                    CompletionSummaryRow(
                        icon: "square.grid.2x2.fill",
                        iconColor: CultivationTheme.Colors.textTertiary,
                        label: "Space",
                        value: userProfile.spaceSize.displayName
                    )
                }

                Divider().padding(.leading, 48)
                CompletionSummaryRow(
                    icon: "sprout.fill",
                    iconColor: CultivationTheme.Colors.brandLeaf.opacity(0.80),
                    label: "First Plant",
                    value: Self.firstPlantSummary(for: userProfile)
                )

                if let nextCare = Self.nextCareSummary(for: userProfile) {
                    Divider().padding(.leading, 48)
                    CompletionSummaryRow(
                        icon: "drop.fill",
                        iconColor: CultivationTheme.Colors.accentSky,
                        label: "Next Care",
                        value: nextCare
                    )
                }
            }
            .paperCard()
            .padding(.horizontal, 24)
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65, bounce: 0.2).delay(0.1)) { heroVisible = true }
            withAnimation(.spring(duration: 0.55).delay(0.55)) { summaryVisible = true }
        }
    }

    static func gardenSummary(for profile: UserProfile) -> String {
        guard profile.shouldCreateFirstGarden else { return "Skipped" }
        let trimmedName = profile.firstGardenName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "My First Garden" : trimmedName
    }

    static func containerSummary(for profile: UserProfile) -> String {
        guard profile.shouldCreateFirstGarden, profile.shouldCreateFirstContainer else { return "Skipped" }
        let trimmedName = profile.firstContainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Starter Container" : trimmedName
    }

    static func firstPlantSummary(for profile: UserProfile) -> String {
        let trimmedName = profile.selectedFirstPlantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Skipped" : trimmedName
    }

    static func nextCareSummary(for profile: UserProfile) -> String? {
        firstPlantSummary(for: profile) == "Skipped" ? nil : "Watering reminder"
    }

    static func goalsSummary(for profile: UserProfile) -> String {
        let selectedGoals = GardeningGoal.allCases.filter { profile.goals.contains($0) }
        guard !selectedGoals.isEmpty else { return "None selected" }

        let visibleGoals = selectedGoals.prefix(2).map(\.displayName).joined(separator: ", ")
        let remainingCount = selectedGoals.count - 2
        guard remainingCount > 0 else { return visibleGoals }
        return "\(visibleGoals) +\(remainingCount)"
    }
}

// MARK: - Summary Row

private struct CompletionSummaryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        VStack {
            CompletionView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
