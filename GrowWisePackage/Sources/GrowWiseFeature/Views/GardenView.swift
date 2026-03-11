import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - GardenView

/// Garden tab — dashboard showing all gardens as visual cards.
/// Tap a garden card to drill into its plant list.
/// Prominent "New Garden" card for easy garden creation.
public struct GardenView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = GardenViewModel()
    @State private var showCreateGarden = false
    @State private var gardenToNavigate: Garden?
    @State private var gardenToDelete: Garden?
    @State private var showDeleteConfirmation = false

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
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 32)
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
            .sheet(isPresented: $showCreateGarden, onDismiss: {
                Task { await viewModel.load(dataService: dataService) }
            }) {
                CreateGardenSheet { _ in
                    Task { await viewModel.load(dataService: dataService) }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
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
                    Text("This will permanently delete \"\(garden.name ?? "this garden")\" and its \(plantCount) plant\(plantCount == 1 ? "" : "s").")
                }
            }
        }
        .accessibilityIdentifier("screen_garden")
    }

    // MARK: - Dashboard Header

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MY GARDENS")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .tracking(0.5)
                    Text("Gardens")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                }

                Spacer()

                Button {
                    showCreateGarden = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(CultivationTheme.Gradients.ctaVertical)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("garden_button_add")
            }

            // Global stats
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
                    .font(.system(.title3, design: .rounded, weight: .semibold))
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
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
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
