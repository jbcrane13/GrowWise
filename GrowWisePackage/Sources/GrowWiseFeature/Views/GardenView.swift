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
    @State private var showAddBed = false
    @State private var newBedName = ""
    @State private var bedLocationPreset = ""
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
                GardenHeroHeader(
                    gardens: viewModel.gardens,
                    selectedGarden: viewModel.selectedGarden,
                    totalPlants: viewModel.totalPlantCount,
                    alertCount: viewModel.alertCount,
                    onSelectGarden: { garden in
                        Task { await viewModel.selectGarden(garden, dataService: dataService) }
                    },
                    onAdd: { showAddPlant = true },
                    onSearch: {
                        // Phase 6: toggle search bar / sheet
                    }
                )
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.load(dataService: dataService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService)
            }
            .navigationDestination(item: $plantToNavigate) { plant in
                PlantDetailView(plant: plant)
            }
            .sheet(isPresented: $showAddPlant) {
                AddPlantSheet(locationPreset: bedLocationPreset)
                    .onDisappear { bedLocationPreset = "" }
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
            .alert("New Bed or Area", isPresented: $showAddBed) {
                TextField("e.g. South Bed, Back Patio", text: $newBedName)
                    .accessibilityIdentifier("garden_alert_textfield_bedname")
                Button("Add Plant") {
                    bedLocationPreset = newBedName
                    newBedName = ""
                    showAddPlant = true
                }
                Button("Cancel", role: .cancel) { newBedName = "" }
            } message: {
                Text("Name this bed or area, then add your first plant to it.")
            }
        }
        .accessibilityIdentifier("garden_view")
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
            showAddBed = true
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
