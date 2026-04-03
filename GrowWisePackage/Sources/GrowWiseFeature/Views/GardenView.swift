import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenView

/// Garden tab — dashboard showing all gardens as visual cards.
/// Tap a garden card to drill into its plant list.
/// Prominent "New Garden" card for easy garden creation.
public struct GardenView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(\.modelContext)
    private var modelContext

    @State private var viewModel = GardenViewModel()
    @State private var showCreateGarden = false
    @State private var gardenToNavigate: Garden?
    @State private var gardenToDelete: Garden?
    @State private var showDeleteConfirmation = false
    @State private var showPlantDatabase = false
    @State private var showPlantScanner = false
    @State private var showAddPlantMenu = false
    @State private var showAddPlantSheet = false
    @State private var showFAB = false
    @State private var shoppingListGarden: Garden?
    @State private var showSeedInventory = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Dashboard header
                    dashboardHeader
                        .padding(.bottom, CultivationTheme.Spacing.sectionGap)

                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.gardens.isEmpty {
                        emptyState
                    } else {
                        // Garden cards grid
                        gardenGrid

                        // Shopping List link
                        shoppingListSection
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 32)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAddPlantMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(CultivationTheme.Colors.brandLeaf)
                        .clipShape(Circle())
                        .shadow(color: CultivationTheme.Colors.brandLeaf.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 24)
                .scaleEffect(showFAB ? 1 : 0.5)
                .opacity(showFAB ? 1 : 0)
                .accessibilityIdentifier("garden_fab_addplant")
            }
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    showFAB = true
                }
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .task {
                await viewModel.load(dataService: dataService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService)
            }
            .navigationDestination(item: $gardenToNavigate) { garden in
                GardenDetailView(garden: garden)
            }
            .navigationDestination(item: $shoppingListGarden) { garden in
                ShoppingListView(garden: garden)
            }
            .navigationDestination(isPresented: $showSeedInventory) {
                SeedInventoryView()
            }
            .sheet(
                isPresented: $showCreateGarden,
                onDismiss: {
                    Task { await viewModel.load(dataService: dataService) }
                },
                content: {
                    CreateGardenSheet { _ in
                        Task { await viewModel.load(dataService: dataService) }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
            )
            .alert("Delete Garden?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    gardenToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let garden = gardenToDelete {
                        Task {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showPlantDatabase = true
                    } label: {
                        Image(systemName: "book.fill")
                    }
                    .accessibilityIdentifier("garden_button_plantguide")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPlantScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                    .accessibilityIdentifier("garden_button_scanplant")
                }
            }
            .sheet(isPresented: $showPlantDatabase) {
                PlantDatabaseView()
            }
            .sheet(isPresented: $showPlantScanner) {
                PlantScannerView()
            }
            .sheet(isPresented: $showAddPlantSheet) {
                AddPlantSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .confirmationDialog("Add a Plant", isPresented: $showAddPlantMenu, titleVisibility: .visible) {
                Button("Browse Plant Database") {
                    showPlantDatabase = true
                }
                .accessibilityIdentifier("garden_fab_option_browse")

                Button("Scan a Plant") {
                    showPlantScanner = true
                }
                .accessibilityIdentifier("garden_fab_option_scan")

                Button("Add Manually") {
                    showAddPlantSheet = true
                }
                .accessibilityIdentifier("garden_fab_option_manual")
            }
        }
        .accessibilityIdentifier("screen_garden")
    }

    // MARK: - Dashboard Header

    private var seedCount: Int {
        (try? dataService.seeds.fetchAll().count) ?? 0
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GARDENS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                    Text(viewModel.userName.isEmpty ? "My Gardens" : "\(viewModel.userName)'s Gardens")
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text("\(viewModel.gardens.count) gardens \u{00B7} \(viewModel.totalPlantsAllGardens) plants")
                        .font(.system(size: 13))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    showCreateGarden = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(CultivationTheme.Gradients.warmAccent)
                        .clipShape(Circle())
                        .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.3), radius: 8, y: 3)
                }
                .accessibilityIdentifier("garden_button_add")
            }

            if !viewModel.gardens.isEmpty {
                HStack(spacing: 10) {
                    QuickStatCard(
                        value: viewModel.gardens.count,
                        label: "Gardens",
                        color: CultivationTheme.Colors.brandLeaf
                    )
                    QuickStatCard(
                        value: viewModel.totalPlantsAllGardens,
                        label: "Plants",
                        color: CultivationTheme.Colors.statusHealthy
                    )
                    QuickStatCard(
                        value: viewModel.totalAlertsAllGardens,
                        label: "Alerts",
                        color: viewModel.totalAlertsAllGardens > 0
                            ? CultivationTheme.Colors.statusAlert
                            : CultivationTheme.Colors.textTertiary
                    )
                    QuickStatCard(
                        value: seedCount,
                        label: "Seeds",
                        color: CultivationTheme.Colors.accentCoral
                    )
                    .onTapGesture { showSeedInventory = true }
                    .accessibilityIdentifier("garden_stat_seeds")
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Garden Grid

    private var gardenGrid: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.gardenSummaries) { summary in
                GardenCardView(
                    garden: summary.garden,
                    plantCount: summary.plantCount,
                    bedCount: summary.bedCount,
                    alertCount: summary.alertCount,
                    onTap: {
                        gardenToNavigate = summary.garden
                    }
                )
                .contextMenu {
                    Button {
                        gardenToNavigate = summary.garden
                    } label: {
                        Label("Open", systemImage: "arrow.right.circle")
                    }

                    Button(role: .destructive) {
                        gardenToDelete = summary.garden
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Garden", systemImage: "trash")
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // Add garden card — always visible at the bottom
            AddGardenCard {
                showCreateGarden = true
            }
        }
    }

    // MARK: - Shopping List

    private var shoppingListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHOPPING")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)
                .padding(.top, CultivationTheme.Spacing.sectionGap)

            ForEach(viewModel.gardens) { garden in
                Button {
                    shoppingListGarden = garden
                } label: {
                    HStack(spacing: 12) {
                        IconBubble(
                            systemName: "cart.fill",
                            color: CultivationTheme.Colors.accentAmber,
                            size: 36,
                            iconSize: 16
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(garden.name ?? "Garden")
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Text("Shopping list")
                                .font(.system(.caption))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("garden_button_shopping_\(garden.id?.uuidString ?? "unknown")")
            }
        }
        .padding(.top, CultivationTheme.Spacing.rowGap)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CultivationTheme.Colors.brandLeaf)
            Text("Loading gardens\u{2026}")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityIdentifier("garden_loading_indicator")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            // Illustration
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
                Text("Plant your first garden")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("Create a garden for your backyard, balcony,\nwindowsill, or anywhere you grow")
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Your First Garden") {
                showCreateGarden = true
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityIdentifier("garden_button_create_first")

            // Quick-start suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("POPULAR SETUPS")
                    .sectionLabelStyle()

                HStack(spacing: 10) {
                    QuickStartChip(icon: "sun.max.fill", label: "Backyard") {
                        showCreateGarden = true
                    }
                    QuickStartChip(icon: "building.2.fill", label: "Balcony") {
                        showCreateGarden = true
                    }
                    QuickStartChip(icon: "house.fill", label: "Indoor") {
                        showCreateGarden = true
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - QuickStartChip

private struct QuickStartChip: View {
    let icon: String
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}
