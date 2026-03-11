import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenDetailView

/// Drill-down view for a single garden showing its beds, plants, and stats.
/// Reached by tapping a garden card on the main Gardens dashboard.
struct GardenDetailView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext

    let garden: Garden

    @State private var groupedPlants: [PlantGroup] = []
    @State private var searchText: String = ""
    @State private var selectedPlant: Plant?
    @State private var showAddPlant = false
    @State private var showCreateBed = false
    @State private var plantToNavigate: Plant?
    @State private var isLoading = true

    private var filteredGroups: [PlantGroup] {
        guard !searchText.isEmpty else { return groupedPlants }
        let query = searchText.lowercased()
        return groupedPlants.compactMap { group in
            let matching = group.plants.filter { plant in
                (plant.name ?? "").lowercased().contains(query) ||
                    (plant.scientificName ?? "").lowercased().contains(query) ||
                    (plant.notes ?? "").lowercased().contains(query)
            }
            guard !matching.isEmpty else { return nil }
            return PlantGroup(id: group.id, bed: group.bed, plants: matching)
        }
    }

    private var plantCount: Int {
        groupedPlants.reduce(0) { $0 + $1.plants.count }
    }

    private var bedCount: Int {
        (garden.beds ?? []).count
    }

    private var alertCount: Int {
        let now = Date()
        return groupedPlants.flatMap(\.plants).count { plant in
            (plant.reminders ?? []).contains { $0.isEnabled && $0.nextDueDate < now }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                // Garden info header
                gardenHeader

                // Search bar
                searchBar

                if isLoading {
                    loadingState
                } else if filteredGroups.isEmpty && searchText.isEmpty {
                    emptyState
                } else if filteredGroups.isEmpty {
                    noResultsState
                } else {
                    ForEach(filteredGroups) { group in
                        GardenBedSection(
                            group: group,
                            onPlantTap: { plant in selectedPlant = plant },
                            onQuickAction: { _ in },
                            onDelete: { plant in
                                modelContext.delete(plant)
                                Task { await rebuildGroups() }
                            }
                        )
                    }

                    addBedButton
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 32)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(garden.name ?? "Garden")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPlant = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(CultivationTheme.Gradients.ctaVertical)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("gardendetail_button_add")
            }
        }
        .task { await rebuildGroups() }
        .refreshable { await rebuildGroups() }
        .navigationDestination(item: $plantToNavigate) { plant in
            PlantDetailView(plant: plant)
        }
        .sheet(isPresented: $showAddPlant, onDismiss: {
            Task { await rebuildGroups() }
        }) {
            AddPlantSheet()
        }
        .sheet(item: $selectedPlant) { plant in
            PlantQuickCard(
                plant: plant,
                onWater: { selectedPlant = nil },
                onPrune: { selectedPlant = nil },
                onLog: { selectedPlant = nil },
                onViewDetails: {
                    let captured = plant
                    selectedPlant = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        plantToNavigate = captured
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCreateBed, onDismiss: {
            Task { await rebuildGroups() }
        }) {
            CreateBedSheet(garden: garden) { _ in
                Task { await rebuildGroups() }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Sub-views

    private var gardenHeader: some View {
        VStack(spacing: 12) {
            // Stats strip
            HStack(spacing: 10) {
                QuickStatCard(
                    value: plantCount,
                    label: "Plants",
                    color: CultivationTheme.Colors.statusHealthy
                )
                QuickStatCard(
                    value: bedCount,
                    label: "Beds",
                    color: CultivationTheme.Colors.brandLeaf
                )
                QuickStatCard(
                    value: alertCount,
                    label: "Alerts",
                    color: alertCount > 0
                        ? CultivationTheme.Colors.statusAlert
                        : CultivationTheme.Colors.textTertiary
                )
            }

            // Garden info chips
            HStack(spacing: 8) {
                if let gardenType = garden.gardenType {
                    InfoChip(icon: gardenType.iconName, text: gardenType.displayName)
                }
                if let sun = garden.sunExposure {
                    InfoChip(icon: "sun.max.fill", text: sun.displayName)
                }
            }
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            TextField("Search plants\u{2026}", text: $searchText)
                .font(.system(.subheadline, design: .rounded))
                .accessibilityIdentifier("gardendetail_search_field")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
        }
        .padding(10)
        .glassCard()
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CultivationTheme.Colors.brandLeaf)
            Text("Loading plants\u{2026}")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBubble(
                systemName: "leaf",
                color: CultivationTheme.Colors.brandLeaf,
                size: 64,
                iconSize: 28
            )
            Text("No plants yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Start by adding beds and plants to this garden")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Add Bed") { showCreateBed = true }
                    .buttonStyle(OutlineButtonStyle())
                    .accessibilityIdentifier("gardendetail_button_addbed_empty")

                Button("Add Plant") { showAddPlant = true }
                    .buttonStyle(GradientButtonStyle())
                    .accessibilityIdentifier("gardendetail_button_addplant_empty")
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Text("No results")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Try a different search term")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var addBedButton: some View {
        Button {
            showCreateBed = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                Text("Add Bed or Area")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(
                        CultivationTheme.Colors.brandLeaf.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gardendetail_button_addbed")
    }

    // MARK: - Data

    private func rebuildGroups() async {
        let allPlants: [Plant]
        do {
            allPlants = try dataService.plants.fetchAll()
        } catch {
            allPlants = []
        }

        let gardenPlants = allPlants.filter { $0.garden?.id == garden.id }

        var bedMap: [String: (GardenBed, [Plant])] = [:]
        var unassigned: [Plant] = []

        for plant in gardenPlants {
            if let bed = plant.bed, let bedID = bed.id?.uuidString {
                if bedMap[bedID] == nil {
                    bedMap[bedID] = (bed, [])
                }
                bedMap[bedID]?.1.append(plant)
            } else {
                unassigned.append(plant)
            }
        }

        var groups: [PlantGroup] = bedMap.values
            .sorted { ($0.0.name ?? "") < ($1.0.name ?? "") }
            .map { bed, bedPlants in
                PlantGroup(
                    id: bed.id?.uuidString ?? UUID().uuidString,
                    bed: bed,
                    plants: bedPlants.sorted { ($0.name ?? "") < ($1.name ?? "") }
                )
            }

        if !unassigned.isEmpty {
            groups.append(PlantGroup(
                id: "__unassigned__",
                bed: nil,
                plants: unassigned.sorted { ($0.name ?? "") < ($1.name ?? "") }
            ))
        }

        // Also add empty beds (beds with no plants) so they appear in the layout
        let bedsWithPlants = Set(bedMap.keys)
        for bed in garden.beds ?? [] {
            if let bedID = bed.id?.uuidString, !bedsWithPlants.contains(bedID) {
                groups.insert(
                    PlantGroup(id: bedID, bed: bed, plants: []),
                    at: max(0, groups.count - (unassigned.isEmpty ? 0 : 1))
                )
            }
        }

        groupedPlants = groups
        isLoading = false
    }
}

// MARK: - InfoChip

private struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(CultivationTheme.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(CultivationTheme.Colors.cardSurface)
        }
        .overlay {
            Capsule()
                .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
        }
    }
}

// MARK: - OutlineButtonStyle

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.35), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}
