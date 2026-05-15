import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Onboarding step showing curated beginner plants for one-tap selection.
/// Allows users to pick their first plant before completing onboarding.
struct FirstPlantStepView: View {
    @Binding var userProfile: UserProfile
    @Environment(PlantDatabaseService.self)
    private var plantDatabaseService

    @State private var beginnerPlants: [Plant] = []
    @State private var selectedPlant: Plant?
    @State private var loadErrorMessage: String?

    /// Curated plant names for onboarding — diverse, beginner-friendly, common.
    private static let curatedNames: Set<String> = [
        "Basil", "Tomato", "Mint", "Lettuce",
        "Snake Plant", "Pothos", "Sunflower", "Marigold",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.10))
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(CultivationTheme.Colors.brandLeaf.opacity(0.18), lineWidth: 1))
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Pick your first plant")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding_firstplant_title")

                    Text("Choose a beginner-friendly plant\nto get started with.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Plant grid
                if let loadErrorMessage, beginnerPlants.isEmpty {
                    Text(loadErrorMessage)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("onboarding_firstplant_error")
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 12) {
                        ForEach(beginnerPlants.prefix(8)) { plant in
                            PlantPickerCard(
                                plant: plant,
                                isSelected: selectedPlant?.id == plant.id
                            ) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    if selectedPlant?.id == plant.id {
                                        selectedPlant = nil
                                        userProfile.selectedFirstPlantName = nil
                                        userProfile.selectedFirstPlantID = nil
                                    } else {
                                        selectedPlant = plant
                                        userProfile.selectedFirstPlantName = plant.name
                                        userProfile.selectedFirstPlantID = plant.id
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Skip option
                Button {
                    selectedPlant = nil
                    userProfile.selectedFirstPlantName = nil
                    userProfile.selectedFirstPlantID = nil
                } label: {
                    Text("Skip — I'll add plants later")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityIdentifier("onboarding_firstplant_skip")
            }
            .padding(.horizontal, 4)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .task {
            await loadPlants()
        }
    }

    private func loadPlants() async {
        let allBeginner: [Plant]
        do {
            allBeginner = try await plantDatabaseService.getSeededBeginnerFriendlyPlants()
            loadErrorMessage = nil
        } catch {
            allBeginner = plantDatabaseService.getBeginnerFriendlyPlants()
            loadErrorMessage = "Starter plants are unavailable right now. You can skip and add plants later."
        }

        // Prefer curated list for consistent onboarding experience
        let curated = allBeginner.filter { plant in
            guard let name = plant.name else { return false }
            return Self.curatedNames.contains(name)
        }

        if curated.count >= 6 {
            beginnerPlants = curated
        } else {
            // Fall back to first 8 beginner plants
            beginnerPlants = Array(allBeginner.prefix(8))
        }
    }
}

// MARK: - Plant Picker Card

private struct PlantPickerCard: View {
    let plant: Plant
    let isSelected: Bool
    let onTap: () -> Void

    private var accessibilityID: String {
        let rawName = plant.name ?? "unknown"
        let sanitized = rawName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return "onboarding_firstplant_card_\(sanitized)"
    }

    private var plantIcon: String {
        plant.plantType?.iconName ?? "leaf.fill"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf.opacity(0.25)
                                : CultivationTheme.Colors.backgroundSecondary
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: plantIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf
                                : CultivationTheme.Colors.textSecondary
                        )
                }

                Text(plant.name ?? "Plant")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(plant.difficultyLevel?.displayName ?? "Easy")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.12)
                            : CultivationTheme.Colors.cardSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.4)
                            : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}

#Preview {
    ZStack {
        CultivationTheme.Colors.background.ignoresSafeArea()
        FirstPlantStepView(userProfile: .constant(UserProfile()))
    }
}
