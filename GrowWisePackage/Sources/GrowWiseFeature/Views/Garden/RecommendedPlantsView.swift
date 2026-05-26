import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable identifier_name

// MARK: - RecommendedPlantsView

/// Shows smart plant recommendations based on garden conditions and user profile.
/// Presented as a sheet after garden creation, or as a section in GardenDetailView.
struct RecommendedPlantsView: View {
    let garden: Garden

    @Environment(DataService.self)
    private var dataService
    @Environment(PlantDatabaseService.self)
    private var plantDatabaseService
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    @State private var recommendations: [PlantRecommendation] = []
    @State private var companionSuggestions: [Plant] = []
    @State private var isLoading = true
    @State private var addedPlantIDs: Set<UUID> = []
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                        if isLoading {
                            loadingState
                        } else if recommendations.isEmpty, companionSuggestions.isEmpty {
                            emptyState
                        } else {
                            if !recommendations.isEmpty {
                                recommendationsSection
                            }
                            if !companionSuggestions.isEmpty {
                                companionSection
                            }
                        }
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Suggested Plants")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("recommended_button_done")
                }
            }
            .task { await loadRecommendations() }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
                    .accessibilityIdentifier("recommended_button_error_ok")
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sections

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommended for You")
                .sectionLabelStyle()

            ForEach(recommendations) { rec in
                RecommendationCard(
                    recommendation: rec,
                    isAdded: addedPlantIDs.contains(rec.plant.id ?? UUID()),
                    onAdd: { addPlantToGarden(rec.plant) }
                )
            }
        }
    }

    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Companion Suggestions")
                .sectionLabelStyle()

            Text("Plants that grow well with what\u{2019}s already in your garden")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)

            ForEach(companionSuggestions, id: \.id) { plant in
                CompanionSuggestionCard(
                    plant: plant,
                    isAdded: addedPlantIDs.contains(plant.id ?? UUID()),
                    onAdd: { addPlantToGarden(plant) }
                )
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CultivationTheme.Colors.brandLeaf)
            Text("Finding the best plants for your garden\u{2026}")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBubble(
                systemName: "sparkles",
                color: CultivationTheme.Colors.brandLeaf,
                size: 64,
                iconSize: 28
            )
            Text("No suggestions available")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Add more details to your garden to get personalized recommendations")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data

    private func loadRecommendations() async {
        let user = dataService.getCurrentUser()

        let profile = UserGardenProfile(
            skillLevel: user?.skillLevel ?? .beginner,
            availableSpace: spaceRequirementFromGarden(),
            timeCommitment: user?.timeCommitment ?? .moderate,
            gardenType: garden.gardenType?.rawValue ?? "outdoor",
            preferredPlantTypes: user?.preferredPlantTypes ?? [],
            gardeningGoals: user?.gardeningGoals ?? []
        )

        recommendations = plantDatabaseService.getRecommendedPlants(for: profile, limit: 8)

        // Companion suggestions from existing plants
        let existingPlants = garden.plants ?? []
        if !existingPlants.isEmpty {
            var seen = Set<String>()
            var companions: [Plant] = []
            for plant in existingPlants {
                let suggested = plantDatabaseService.getCompanionPlants(for: plant)
                for s in suggested {
                    let name = s.name ?? ""
                    if !name.isEmpty, !seen.contains(name),
                       !existingPlants.contains(where: { $0.name == name })
                    {
                        seen.insert(name)
                        companions.append(s)
                    }
                }
            }
            companionSuggestions = Array(companions.prefix(6))
        }

        isLoading = false
    }

    private func spaceRequirementFromGarden() -> SpaceRequirement {
        switch garden.spaceAvailable {
        case .tiny, .small: .small
        case .medium: .medium
        case .large, .extraLarge: .large
        case .none: .medium
        }
    }

    private func addPlantToGarden(_ plant: Plant) {
        do {
            try dataService.createUserPlant(from: plant, in: garden)

            if let plantID = plant.id {
                addedPlantIDs.insert(plantID)
            }
        } catch {
            errorMessage = "Failed to add plant: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - RecommendationCard

private struct RecommendationCard: View {
    let recommendation: PlantRecommendation
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconBubble(
                    systemName: recommendation.plant.plantType?.iconName ?? "leaf.fill",
                    color: CultivationTheme.Colors.brandLeaf,
                    size: CultivationTheme.Spacing.iconSize,
                    iconSize: 20
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.plant.name ?? "Unknown")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    if let difficulty = recommendation.plant.difficultyLevel {
                        Text(difficulty.displayName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                }

                Spacer()

                Text("\(Int(recommendation.compatibilityScore * 100))% match")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                    }
            }

            if !recommendation.recommendationReasons.isEmpty {
                HStack(spacing: 6) {
                    ForEach(recommendation.recommendationReasons, id: \.self) { reason in
                        ReasonChip(reason: reason)
                    }
                }
            }

            Button {
                onAdd()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdded ? "checkmark" : "plus.circle.fill")
                    Text(isAdded ? "Added" : "Add to Garden")
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(isAdded ? CultivationTheme.Colors.statusHealthy : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                        .fill(
                            isAdded
                                ? CultivationTheme.Colors.statusHealthy.opacity(0.12)
                                : CultivationTheme.Colors.brandLeaf
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityIdentifier("recommended_button_add_\(recommendation.plant.name ?? "")")
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }
}

// MARK: - CompanionSuggestionCard

private struct CompanionSuggestionCard: View {
    let plant: Plant
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: plant.plantType?.iconName ?? "leaf.fill",
                color: CultivationTheme.Colors.brandSage,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 14
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name ?? "Unknown")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text(plant.plantType?.displayName ?? "")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        isAdded
                            ? CultivationTheme.Colors.statusHealthy
                            : CultivationTheme.Colors.brandLeaf
                    )
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityIdentifier("companion_button_add_\(plant.name ?? "")")
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }
}

// MARK: - ReasonChip

private struct ReasonChip: View {
    let reason: RecommendationReason

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reason.icon)
                .font(.system(size: 10, weight: .medium))
            Text(reason.displayText)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
        }
        .accessibilityIdentifier("reason_chip_\(reason.rawValue)")
    }
}

// MARK: - Inline Suggested Plants Section (for GardenDetailView)

struct SuggestedPlantsSection: View {
    let garden: Garden

    @Environment(DataService.self)
    private var dataService
    @Environment(PlantDatabaseService.self)
    private var plantDatabaseService

    @State private var suggestions: [PlantRecommendation] = []
    @State private var showFullRecommendations = false

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Suggested Plants")
                        .sectionLabelStyle()

                    Spacer()

                    Button("See All") {
                        showFullRecommendations = true
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    .accessibilityIdentifier("gardendetail_button_seeallsuggestions")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions.prefix(4)) { rec in
                            SuggestionChip(recommendation: rec)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFullRecommendations) {
                RecommendedPlantsView(garden: garden)
            }
            .task { await loadSuggestions() }
        }
    }

    private func loadSuggestions() async {
        let user = dataService.getCurrentUser()

        let profile = UserGardenProfile(
            skillLevel: user?.skillLevel ?? .beginner,
            availableSpace: spaceRequirement(),
            timeCommitment: user?.timeCommitment ?? .moderate,
            gardenType: garden.gardenType?.rawValue ?? "outdoor",
            preferredPlantTypes: user?.preferredPlantTypes ?? [],
            gardeningGoals: user?.gardeningGoals ?? []
        )

        suggestions = plantDatabaseService.getRecommendedPlants(for: profile, limit: 4)
    }

    private func spaceRequirement() -> SpaceRequirement {
        switch garden.spaceAvailable {
        case .tiny, .small: .small
        case .medium: .medium
        case .large, .extraLarge: .large
        case .none: .medium
        }
    }
}

// MARK: - SuggestionChip

private struct SuggestionChip: View {
    let recommendation: PlantRecommendation

    var body: some View {
        VStack(spacing: 6) {
            IconBubble(
                systemName: recommendation.plant.plantType?.iconName ?? "leaf.fill",
                color: CultivationTheme.Colors.brandLeaf,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 14
            )

            Text(recommendation.plant.name ?? "Unknown")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(1)

            Text("\(Int(recommendation.compatibilityScore * 100))%")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        }
        .frame(width: 80)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .glassCard()
        .accessibilityIdentifier("suggestion_chip_\(recommendation.plant.name ?? "")")
    }
}

// swiftlint:enable identifier_name
