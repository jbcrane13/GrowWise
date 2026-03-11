import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenView

/// Garden tab — hero screen with grouped plant list by bed/location.
/// Full redesign implementation (Task 6).
public struct GardenView: View {
    @Environment(DataService.self) private var dataService

    @State private var viewModel = GardenViewModel()
    @State private var selectedPlant: Plant?
    @State private var showAddPlant = false
    @State private var showCreateBed = false
    @State private var showSearch = false
    @State private var plantToNavigate: Plant?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.filteredGroups.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.filteredGroups) { group in
                            GardenBedSection(
                                group: group,
                                onPlantTap: { plant in selectedPlant = plant },
                                onQuickAction: { _ in
                                    // Phase 6: mark care complete
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
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    GardenHeroHeader(
                        gardens: viewModel.gardens,
                        selectedGarden: viewModel.selectedGarden,
                        totalPlants: viewModel.totalPlantCount,
                        alertCount: viewModel.alertCount,
                        onSelectGarden: { garden in
                            Task { await viewModel.selectGarden(garden, dataService: dataService) }
                        },
                        onAdd: { showAddPlant = true },
                        onSearch: { withAnimation(.easeInOut(duration: 0.2)) { showSearch.toggle() } }
                    )
                    if showSearch {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            TextField("Search plants\u{2026}", text: $viewModel.searchText)
                                .font(.system(.body, design: .rounded))
                                .accessibilityIdentifier("garden_search_field")
                            if !viewModel.searchText.isEmpty {
                                Button {
                                    viewModel.searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                }
                                .accessibilityIdentifier("garden_button_clearsearch")
                            }
                        }
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .padding(.vertical, 10)
                        .background(CultivationTheme.Colors.background)
                    }
                }
            }
            .toolbarBackground(.hidden)
            .task {
                await viewModel.load(dataService: dataService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService)
            }
            .navigationDestination(item: $plantToNavigate) { plant in
                PlantDetailView(plant: plant)
            }
            .sheet(isPresented: $showAddPlant, onDismiss: {
                Task { await viewModel.load(dataService: dataService) }
            }) {
                AddPlantSheet()
            }
            .sheet(item: $selectedPlant) { plant in
                PlantQuickCard(
                    plant: plant,
                    onWater: {
                        selectedPlant = nil
                    },
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
            .sheet(isPresented: $showCreateBed) {
                if let garden = viewModel.selectedGarden {
                    CreateBedSheet(garden: garden) { _ in
                        Task { await viewModel.load(dataService: dataService) }
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                }
            }
        }
        .accessibilityIdentifier("screen_garden")
    }

    // MARK: - Sub-views

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CultivationTheme.Colors.brandLeaf)
            Text("Loading garden…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityIdentifier("garden_loading_indicator")
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
            Text("Add your first plant to get started")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Button("Add Plant") { showAddPlant = true }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, 40)
                .accessibilityIdentifier("garden_button_addplant_empty")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
        .accessibilityIdentifier("garden_button_addbed")
    }
}
