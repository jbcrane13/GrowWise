import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes

// MARK: - SeedDetailView

/// Read-only detail view for a seed, showing packet photo, growing requirements, and linked plant info.
struct SeedDetailView: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService

    private let logger = Logger(subsystem: "com.growwise.gardening", category: "SeedDetailView")

    let seed: Seed

    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var isExpired: Bool {
        guard let year = seed.expirationYear else { return false }
        return year < Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                // Packet photo
                packetPhoto

                // Details section
                detailsSection

                // Growing requirements section
                growingRequirementsSection

                // Linked plant section
                linkedPlantSection

                // Delete button
                deleteButton
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 32)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(seed.varietyName ?? "Seed Details")
        .gwNavigationBarTitleDisplayMode(.inline)
        .alert("Delete Seed", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("seed_detail_button_delete_cancel")
            Button("Delete", role: .destructive) {
                deleteSeed()
            }
            .accessibilityIdentifier("seed_detail_button_delete_confirm")
        } message: {
            Text("Are you sure you want to delete \(seed.varietyName ?? "this seed")? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("seed_detail_button_error_dismiss")
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Packet Photo

    @ViewBuilder
    private var packetPhoto: some View {
        if let urlString = seed.packetPhotoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))

                case .failure:
                    photoPlaceholder

                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)

                @unknown default:
                    photoPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("seed_detail_photo")
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
            .fill(CultivationTheme.Colors.cardSurface)
            .frame(height: 120)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DETAILS")
                .sectionLabelStyle()

            VStack(spacing: 0) {
                detailRow(label: "Variety", value: seed.varietyName ?? "—")
                rowDivider
                detailRow(label: "Brand", value: seed.brand ?? "—")
                rowDivider
                detailRow(label: "Type", value: seed.plantType?.displayName ?? "—")
                rowDivider
                detailRow(label: "Quantity", value: seed.quantity.map { "\($0)" } ?? "—")
                rowDivider
                expirationRow
            }
            .glassCard()
        }
    }

    private var expirationRow: some View {
        HStack {
            Text("Expiration")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
            if let year = seed.expirationYear {
                Text(String(year))
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(isExpired ? CultivationTheme.Colors.statusAlert : CultivationTheme.Colors.textPrimary)
            } else {
                Text("—")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Growing Requirements Section

    @ViewBuilder
    private var growingRequirementsSection: some View {
        let hasAny = seed.sunRequirement != nil || seed.wateringFrequency != nil ||
            seed.spaceRequirement != nil || seed.plantingDepthInches != nil ||
            seed.seedSpacingInches != nil || seed.daysToGermination != nil ||
            seed.daysToHarvest != nil || seed.indoorStartWeeks != nil

        if hasAny {
            VStack(alignment: .leading, spacing: 14) {
                Text("GROWING REQUIREMENTS")
                    .sectionLabelStyle()

                VStack(spacing: 0) {
                    if let sun = seed.sunRequirement {
                        detailRow(label: "Sun", value: sun.displayName)
                        rowDivider
                    }
                    if let water = seed.wateringFrequency {
                        detailRow(label: "Water", value: water.displayName)
                        rowDivider
                    }
                    if let space = seed.spaceRequirement {
                        detailRow(label: "Space", value: space.displayName)
                        rowDivider
                    }
                    if let depth = seed.plantingDepthInches {
                        detailRow(label: "Depth", value: String(format: "%.1f in", depth))
                        rowDivider
                    }
                    if let spacing = seed.seedSpacingInches {
                        detailRow(label: "Spacing", value: String(format: "%.1f in", spacing))
                        rowDivider
                    }
                    if let germination = seed.daysToGermination {
                        detailRow(label: "Germination", value: "\(germination) days")
                        rowDivider
                    }
                    if let harvest = seed.daysToHarvest {
                        detailRow(label: "Harvest", value: "\(harvest) days")
                        rowDivider
                    }
                    if let indoor = seed.indoorStartWeeks {
                        detailRow(label: "Indoor Start", value: "\(indoor) weeks before last frost")
                    }
                }
                .glassCard()
            }
        }
    }

    // MARK: - Linked Plant Section

    @ViewBuilder
    private var linkedPlantSection: some View {
        if seed.plantDatabaseID != nil {
            VStack(alignment: .leading, spacing: 14) {
                Text("LINKED PLANT")
                    .sectionLabelStyle()

                HStack(spacing: 12) {
                    IconBubble(
                        systemName: "leaf.fill",
                        color: CultivationTheme.Colors.statusHealthy,
                        size: CultivationTheme.Spacing.iconSizeSmall,
                        iconSize: 15
                    )

                    Text("Linked to plant database")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Spacer()
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("seed_detail_linked_plant")
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                Text("Delete Seed")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .foregroundStyle(CultivationTheme.Colors.statusAlert)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(CultivationTheme.Colors.statusAlert.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .stroke(CultivationTheme.Colors.statusAlert.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("seed_detail_button_delete")
    }

    // MARK: - Reusable Row Components

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
        .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Divider()
            .foregroundStyle(CultivationTheme.Colors.cardBorder)
            .padding(.leading, CultivationTheme.Spacing.cardPadding)
    }

    // MARK: - Actions

    private func deleteSeed() {
        do {
            try dataService.seeds.delete(seed)
            dismiss()
        } catch {
            logger.error("Failed to delete seed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to delete seed. Please try again."
            showError = true
        }
    }
}

// swiftlint:enable attributes
