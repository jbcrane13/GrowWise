import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable multiline_arguments

// MARK: - AR Plant Placement Overlay

#if canImport(ARKit) && os(iOS)

/// SwiftUI overlay providing AR controls: plant picker, spacing info, clear/done actions.
/// Displayed as a bottom sheet overlay on top of the AR camera view.
struct ARPlantPlacementView: View {
    @Binding var placedPlants: [ARPlacedPlant]
    @Binding var selectedPlant: Plant?
    @Binding var showPlantPicker: Bool
    let onClearAll: () -> Void
    let onDone: () -> Void

    @State private var showConfirmClear = false

    var body: some View {
        VStack {
            // Top instruction banner
            if selectedPlant == nil {
                instructionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            // Bottom control panel
            bottomPanel
                .transition(.move(edge: .bottom))
        }
        .animation(CultivationTheme.Animation.card, value: selectedPlant?.id)
        .animation(CultivationTheme.Animation.card, value: placedPlants.count)
        .alert("Clear All Plants?", isPresented: $showConfirmClear) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("ar_placement_button_clear_cancel")
            Button("Clear All", role: .destructive) {
                onClearAll()
            }
            .accessibilityIdentifier("ar_placement_button_clear_confirm")
        } message: {
            Text("This will remove all \(placedPlants.count) placed plants from the AR view.")
        }
    }

    // MARK: - Instruction Banner

    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)

            Text("Select a plant, then tap a surface to place it")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(CultivationTheme.Colors.brandForest.opacity(0.7))
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Selected plant info or picker prompt
            selectedPlantSection
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Plant count summary
            if !placedPlants.isEmpty {
                plantSummarySection
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.top, 12)
            }

            // Action buttons
            actionButtons
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .padding(.bottom, 16)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.sheet)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Selected Plant Section

    private var selectedPlantSection: some View {
        Group {
            if let plant = selectedPlant {
                HStack(spacing: 12) {
                    Image(systemName: plant.plantType?.iconName ?? "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(plant.plantType?.color ?? .green)
                        .frame(width: 44, height: 44)
                        .background(
                            (plant.plantType?.color ?? .green).opacity(0.15)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(plant.name ?? "Plant")
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(.white)

                        if let space = plant.spaceRequirement {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 10))
                                Text("Spacing: \(space.displayName)")
                                    .font(.system(.caption))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    Button {
                        showPlantPicker = true
                    } label: {
                        Text("Change")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.accentCoral)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CultivationTheme.Colors.brandLeaf.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("ar_change_plant_button")
                }
            } else {
                Button {
                    showPlantPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(CultivationTheme.Colors.accentCoral)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Select a Plant")
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(.white)

                            Text("Choose from your garden to place in AR")
                                .font(.system(.caption))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
                .accessibilityIdentifier("ar_plant_picker")
            }
        }
    }

    // MARK: - Plant Summary

    private var plantSummarySection: some View {
        let grouped = Dictionary(grouping: placedPlants, by: { $0.plant.plantType ?? .vegetable })

        return VStack(alignment: .leading, spacing: 6) {
            Text("PLACED PLANTS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(grouped.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                        let count = grouped[type]?.count ?? 0
                        HStack(spacing: 4) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(type.color)
                            Text("\(count)")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(type.color.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    // Total
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(placedPlants.count) total")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Clear All
            Button {
                if placedPlants.isEmpty {
                    onClearAll()
                } else {
                    showConfirmClear = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Clear All")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(
                    placedPlants.isEmpty
                        ? .white.opacity(0.3)
                        : CultivationTheme.Colors.statusAlert
                )
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    placedPlants.isEmpty
                        ? Color.white.opacity(0.05)
                        : CultivationTheme.Colors.statusAlert.opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.button))
                .overlay {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                        .stroke(
                            placedPlants.isEmpty
                                ? Color.white.opacity(0.08)
                                : CultivationTheme.Colors.statusAlert.opacity(0.3),
                            lineWidth: 1
                        )
                }
            }
            .disabled(placedPlants.isEmpty)
            .accessibilityIdentifier("ar_clear_button")

            // Done
            Button(action: onDone) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Done")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(CultivationTheme.Gradients.warmAccent)
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.button))
                .shadow(
                    color: CultivationTheme.Colors.brandForest.opacity(0.3),
                    radius: 8, y: 3
                )
            }
            .accessibilityIdentifier("ar_done_button")
        }
    }
}

#else

// MARK: - Fallback Stub (macOS / unsupported platforms)

/// Empty placeholder so cross-platform compilation succeeds.
/// The actual AR overlay is iOS-only; on macOS, ARGardenView shows a fallback message.
struct ARPlantPlacementView: View {
    var body: some View {
        EmptyView()
    }
}

#endif

// swiftlint:enable multiline_arguments
