import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenFilter

/// Filter chips shown in the Garden tab plant list.
public enum GardenFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case needsCare = "Needs Care"
    case blooming = "Blooming"
    case edible = "Edible"
    case herbs = "Herbs"
    public var id: String {
        rawValue
    }
}

// MARK: - GardenView

/// Garden tab — shows plants grouped by bed for the selected garden.
/// Multi-garden users get a horizontal garden picker at the top.
public struct GardenView: View {
    @Environment(DataService.self)
    private var dataService

    @State private var viewModel = GardenViewModel()
    @State private var selectedFilter: GardenFilter = .all
    @State private var selectedPlant: Plant?
    @State private var plantToNavigate: Plant?
    @State private var showAddPlantSheet = false
    @State private var showCreateGarden = false
    @State private var showCreateBed = false
    @State private var gardenToDelete: Garden?
    @State private var showDeleteConfirmation = false
    @State private var showPlantDatabase = false

    public init() {}

    private var filteredGroups: [PlantGroup] {
        viewModel.filtered(by: selectedFilter)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        gardenHeader
                        if viewModel.gardens.count > 1 {
                            gardenPicker
                        }
                        filterChipBar
                        if viewModel.isLoading {
                            loadingState
                        } else if viewModel.groupedPlants.isEmpty {
                            emptyState
                        } else {
                            if filteredGroups.isEmpty {
                                filterEmptyState
                            } else {
                                ForEach(filteredGroups) { group in
                                    GardenBedSection(
                                        group: group,
                                        onPlantTap: { plant in selectedPlant = plant },
                                        onQuickAction: { _ in },
                                        onDelete: { plant in
                                            Task<Void, Never> {
                                                do {
                                                    try dataService.plants.delete(plant)
                                                } catch {
                                                    viewModel.error = error
                                                }
                                                await viewModel.load(dataService: dataService)
                                            }
                                        }
                                    )
                                    .accessibilityIdentifier(
                                        "garden_bed_\(group.displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
                                    )
                                }
                            }
                        }
                        addBedButton
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .task {
                await viewModel.load(dataService: dataService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService)
            }
            .navigationDestination(item: $plantToNavigate) { plant in
                PlantDetailView(plant: plant)
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
                        Task<Void, Never> { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            plantToNavigate = captured
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(
                isPresented: $showAddPlantSheet,
                onDismiss: {
                    Task<Void, Never> { await viewModel.load(dataService: dataService) }
                },
                content: {
                    AddPlantSheet()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                }
            )
            .sheet(
                isPresented: $showCreateGarden,
                onDismiss: {
                    Task<Void, Never> { await viewModel.load(dataService: dataService) }
                },
                content: {
                    CreateGardenSheet { _ in
                        Task<Void, Never> { await viewModel.load(dataService: dataService) }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
            )
            .sheet(
                isPresented: $showCreateBed,
                onDismiss: {
                    Task<Void, Never> { await viewModel.load(dataService: dataService) }
                },
                content: {
                    if let garden = viewModel.selectedGarden {
                        CreateBedSheet(garden: garden) { _ in
                            Task<Void, Never> { await viewModel.load(dataService: dataService) }
                        }
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.hidden)
                    }
                }
            )
            .sheet(isPresented: $showPlantDatabase) {
                PlantDatabaseView()
            }
            .alert("Delete Garden?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    gardenToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let garden = gardenToDelete {
                        Task<Void, Never> {
                            await viewModel.deleteGarden(garden, dataService: dataService)
                        }
                        gardenToDelete = nil
                    }
                }
            } message: {
                if let garden = gardenToDelete {
                    let plantCount = (garden.plants ?? []).count
                    let gardenName = garden.name ?? "this garden"
                    let suffix = plantCount == 1 ? "" : "s"
                    Text("This will permanently delete \"\(gardenName)\" and its \(plantCount) plant\(suffix).")
                }
            }
            .alert(
                "Couldn't delete plant",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
        .accessibilityIdentifier("screen_garden")
    }

    // MARK: - Garden Header

    private var gardenHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GARDEN")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                Text(viewModel.selectedGarden?.name ?? "My Garden")
                    .font(CultivationTheme.Fonts.display(28, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
            }

            Spacer()

            // Plant count badge
            if viewModel.totalPlantCount > 0 {
                VStack(spacing: 2) {
                    Text("\(viewModel.totalPlantCount)")
                        .font(CultivationTheme.Fonts.display(20, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    Text("plants")
                        .font(CultivationTheme.Fonts.body(11))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.pill)
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.08))
                }
            }

            Button {
                showPlantDatabase = true
            } label: {
                Image(systemName: "book.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(CultivationTheme.Colors.cardSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("garden_button_plantguide")
        }
        .padding(.top, 16)
        .accessibilityIdentifier("garden_header")
    }

    // MARK: - Garden Picker (multi-garden)

    private var gardenPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.gardens) { garden in
                    let isActive = viewModel.selectedGarden?.id == garden.id
                    Button {
                        Task<Void, Never> {
                            await viewModel.selectGarden(garden, dataService: dataService)
                        }
                    } label: {
                        Text(garden.name ?? "Garden")
                            .font(CultivationTheme.Fonts.body(13, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? Color.white : CultivationTheme.Colors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(
                                        isActive
                                            ? AnyShapeStyle(Color(CultivationTheme.Colors.brandForest))
                                            : AnyShapeStyle(CultivationTheme.Colors.cardSurface)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("garden_picker_\(garden.name?.lowercased().replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }

                Button {
                    showCreateGarden = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(CultivationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("garden_button_add")
            }
            .padding(.horizontal, 1) // prevent clip
        }
        .accessibilityIdentifier("garden_picker")
    }

    // MARK: - Filter Chip Bar

    private var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GardenFilter.allCases) { filter in
                    let isActive = selectedFilter == filter
                    Button {
                        withAnimation(CultivationTheme.Animation.selection) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(CultivationTheme.Fonts.body(13, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? Color.white : CultivationTheme.Colors.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(
                                        isActive
                                            ? AnyShapeStyle(Color(CultivationTheme.Colors.brandForest))
                                            : AnyShapeStyle(CultivationTheme.Colors.cardSurface)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("garden_filter_\(filter.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.6))
                        .offset(x: 20, y: -8)
                }
            }

            VStack(spacing: 6) {
                Text("No plants yet")
                    .font(CultivationTheme.Fonts.display(20, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("Add your first plant to get started.")
                    .font(CultivationTheme.Fonts.body(14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Plant") {
                showAddPlantSheet = true
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityIdentifier("garden_button_add_plant")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var filterEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            Text("No plants match \"\(selectedFilter.rawValue)\"")
                .font(CultivationTheme.Fonts.body(15))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Show All") {
                withAnimation(CultivationTheme.Animation.snappy) {
                    selectedFilter = .all
                }
            }
            .font(CultivationTheme.Fonts.body(14, weight: .medium))
            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.bottom, 16)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CultivationTheme.Colors.brandLeaf)
            Text("Loading\u{2026}")
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityIdentifier("garden_loading_indicator")
    }

    // MARK: - Add Bed Button

    private var addBedButton: some View {
        Button {
            if viewModel.selectedGarden != nil {
                showCreateBed = true
            } else {
                showCreateGarden = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add a bed")
                    .font(CultivationTheme.Fonts.body(14, weight: .medium))
            }
            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityIdentifier("garden_button_add_bed")
    }
}
