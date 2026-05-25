import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// MARK: - SeedInventoryView

/// Seed inventory list grouped by plant type with search and floating add button.
struct SeedInventoryView: View {
    @Environment(DataService.self)
    private var dataService

    private let logger = Logger(subsystem: "com.growwise.seeds", category: "SeedInventoryView")

    @State private var seeds: [Seed] = []
    @State private var searchText: String = ""
    @State private var showAddSheet = false
    @State private var loadError: String?

    private var filteredSeeds: [Seed] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return seeds
        }
        let query = searchText.lowercased()
        return seeds.filter { seed in
            seed.varietyName?.lowercased().contains(query) == true ||
                seed.brand?.lowercased().contains(query) == true
        }
    }

    private var groupedSeeds: [(PlantType, [Seed])] {
        let grouped = Dictionary(grouping: filteredSeeds) { $0.plantType ?? .vegetable }
        return PlantType.allCases.compactMap { type in
            guard let typeSeeds = grouped[type], !typeSeeds.isEmpty else { return nil }
            return (type, typeSeeds)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    // Search bar
                    searchBar

                    if filteredSeeds.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedSeeds, id: \.0) { type, typeSeeds in
                            seedSection(type: type, seeds: typeSeeds)
                        }
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 80)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())

            // Floating add button
            addButton
        }
        .navigationTitle("Seed Inventory")
        .gwNavigationBarTitleDisplayMode(.inline)
        .task { loadSeeds() }
        .sheet(
            isPresented: $showAddSheet,
            onDismiss: { loadSeeds() },
            content: {
                AddSeedSheet()
                    .presentationDragIndicator(.hidden)
            }
        )
        .alert("Error", isPresented: .constant(loadError != nil)) {
            Button("OK", role: .cancel) {
                loadError = nil
            }
            .accessibilityIdentifier("seed_inventory_button_error_ok")
        } message: {
            Text(loadError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            TextField("Search seeds...", text: $searchText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .accessibilityIdentifier("seed_inventory_search")
        }
        .padding(12)
        .glassCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            Text("No Seeds Yet")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Tap + to add your first seed packet")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityIdentifier("seed_inventory_empty")
    }

    // MARK: - Seed Section

    private func seedSection(type: PlantType, seeds: [Seed]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                Text(type.displayName.uppercased())
                    .sectionLabelStyle()
            }

            VStack(spacing: 0) {
                ForEach(seeds, id: \.id) { seed in
                    NavigationLink(value: seed.id) {
                        seedRow(seed)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("seed_inventory_cell_\(seed.id?.uuidString ?? "unknown")")

                    if seed.id != seeds.last?.id {
                        Divider()
                            .foregroundStyle(CultivationTheme.Colors.cardBorder)
                            .padding(.leading, CultivationTheme.Spacing.iconSize + 12)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Seed Row

    private func seedRow(_ seed: Seed) -> some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: iconName(for: seed.plantType ?? .vegetable),
                color: CultivationTheme.Colors.brandLeaf
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(seed.varietyName ?? "Unknown")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    if seed.plantDatabaseID != nil {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                    }
                }

                HStack(spacing: 4) {
                    if let brand = seed.brand, !brand.isEmpty {
                        Text(brand)
                    }
                    if let year = seed.expirationYear {
                        if seed.brand != nil {
                            Text("·")
                        }
                        Text("Exp \(String(year))")
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            Spacer()

            // Quantity badge
            if let qty = seed.quantity, qty > 0 {
                Text("\(qty)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                    }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Floating Add Button

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(CultivationTheme.Gradients.warmAccent)
                        .shadow(
                            color: CultivationTheme.Colors.accentCoral.opacity(0.35),
                            radius: 10,
                            y: 4
                        )
                }
        }
        .buttonStyle(.plain)
        .padding(.trailing, CultivationTheme.Spacing.screenPadding)
        .padding(.bottom, 24)
        .accessibilityIdentifier("seed_inventory_button_add")
    }

    // MARK: - Helpers

    private func loadSeeds() {
        do {
            seeds = try dataService.seeds.fetchAll()
        } catch {
            logger.error("Failed to load seeds: \(error.localizedDescription, privacy: .public)")
            seeds = []
            loadError = "Failed to load seed inventory. Please try again."
        }
    }

    private func iconName(for type: PlantType) -> String {
        switch type {
        case .vegetable: "carrot.fill"
        case .herb: "leaf.fill"
        case .flower: "rosette"
        case .houseplant: "house.fill"
        case .fruit: "apple.whole.fill"
        case .succulent: "circle.grid.3x3.fill"
        case .tree: "tree.fill"
        case .shrub: "leaf.circle.fill"
        }
    }
}
