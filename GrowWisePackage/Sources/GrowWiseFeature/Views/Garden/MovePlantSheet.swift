import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

/// Two-step sheet to move a plant to a different garden and/or container.
/// Step 1: pick a garden. Step 2: pick a bed (or Unassigned).
struct MovePlantSheet: View {
    let plant: Plant

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DataService.self) private var dataService

    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var selectedBed: GardenBed?
    @State private var availableBeds: [GardenBed] = []
    @State private var step: MoveStep = .garden

    private enum MoveStep { case garden, bed }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    Capsule()
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    if step == .garden {
                        gardenStep
                    } else {
                        bedStep
                    }
                }
            }
            .navigationTitle("Move Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("moveplant_button_cancel")
                }
                if step == .bed {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            step = .garden
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Garden")
                            }
                        }
                        .accessibilityIdentifier("moveplant_button_back")
                    }
                }
            }
            .task { loadGardens() }
        }
    }

    // MARK: - Garden Step

    private var gardenStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Garden")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            VStack(spacing: 0) {
                ForEach(gardens) { garden in
                    Button {
                        selectedGarden = garden
                        availableBeds = (garden.beds ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
                        selectedBed = nil
                        withAnimation { step = .bed }
                    } label: {
                        HStack {
                            Text(garden.name ?? "Unnamed Garden")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Spacer()
                            if garden.id == plant.garden?.id {
                                Text("Current")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                    }
                    .accessibilityIdentifier("moveplant_garden_\(garden.id?.uuidString ?? "")")

                    if garden.id != gardens.last?.id {
                        Divider()
                            .background(CultivationTheme.Colors.divider)
                            .padding(.leading, CultivationTheme.Spacing.cardPadding)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            Spacer()
        }
    }

    // MARK: - Bed Step

    private var bedStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Container")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            VStack(spacing: 0) {
                Button {
                    selectedBed = nil
                    confirmMove()
                } label: {
                    HStack {
                        IconBubble(systemName: "tray", color: CultivationTheme.Colors.textSecondary, size: 28, iconSize: 13)
                        Text("Unassigned")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Spacer()
                        if plant.bed == nil, selectedGarden?.id == plant.garden?.id {
                            Text("Current")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                }
                .accessibilityIdentifier("moveplant_bed_unassigned")

                ForEach(availableBeds) { bed in
                    Divider()
                        .background(CultivationTheme.Colors.divider)
                        .padding(.leading, CultivationTheme.Spacing.cardPadding)

                    Button {
                        selectedBed = bed
                        confirmMove()
                    } label: {
                        HStack {
                            IconBubble(
                                systemName: bed.bedType?.iconName ?? "tray",
                                color: CultivationTheme.Colors.brandLeaf,
                                size: 28,
                                iconSize: 13
                            )
                            Text(bed.name ?? "Unnamed")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Spacer()
                            if bed.id == plant.bed?.id {
                                Text("Current")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            }
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                    }
                    .accessibilityIdentifier("moveplant_bed_\(bed.id?.uuidString ?? "")")
                }
            }
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func loadGardens() {
        gardens = (try? dataService.gardens.fetchAll()) ?? []
    }

    private func confirmMove() {
        plant.garden = selectedGarden
        plant.bed = selectedBed
        dismiss()
    }
}
