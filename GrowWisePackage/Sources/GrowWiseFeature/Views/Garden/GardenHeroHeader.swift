import GrowWiseModels
import SwiftUI

// MARK: - GardenHeroHeader

/// Hero header for the Garden tab.
/// Shows the garden name, search/add buttons, a garden switcher (multi-garden),
/// and a stat strip with total plant count and alert count.
struct GardenHeroHeader: View {
    let gardens: [Garden]
    let selectedGarden: Garden?
    let totalPlants: Int
    let alertCount: Int
    let onSelectGarden: (Garden) -> Void
    let onAdd: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Garden")
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .tracking(0.5)
                    Text(selectedGarden?.name ?? "Garden")
                        .font(.system(.title, design: .serif, weight: .regular))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(CultivationTheme.Colors.cardSurface)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("garden_button_search")

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(CultivationTheme.Gradients.warmAccent)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("garden_button_add")
                }
            }

            // Garden switcher pills — only shown when there are multiple gardens
            if gardens.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(gardens) { garden in
                            GlassPill(
                                label: garden.name ?? "Garden",
                                isSelected: garden.id == selectedGarden?.id,
                                accessibilityID: "garden_pill_\(garden.id?.uuidString ?? "unknown")",
                                action: { onSelectGarden(garden) }
                            )
                        }
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }
                .padding(.horizontal, -CultivationTheme.Spacing.screenPadding)
            }

            // Summary stat cards
            HStack(spacing: 10) {
                QuickStatCard(
                    value: totalPlants,
                    label: "Plants",
                    color: CultivationTheme.Colors.statusHealthy
                )
                QuickStatCard(
                    value: alertCount,
                    label: "Alerts",
                    color: alertCount > 0
                        ? CultivationTheme.Colors.statusAlert
                        : CultivationTheme.Colors.textTertiary
                )
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .heroBackground()
    }
}
