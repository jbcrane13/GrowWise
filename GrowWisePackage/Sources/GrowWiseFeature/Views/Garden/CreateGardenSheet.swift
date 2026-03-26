import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - CreateGardenSheet

/// Sheet for creating a new garden with name, type, and environment settings.
struct CreateGardenSheet: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(\.dismiss)
    private var dismiss

    var onCreated: (Garden) -> Void = { _ in }

    @State private var gardenName: String = ""
    @State private var selectedType: GardenType = .outdoor
    @State private var selectedSun: SunExposure = .fullSun
    @State private var selectedSize: GrowWiseModels.SpaceSize = .medium
    @State private var isSaving = false

    private var isValid: Bool {
        !gardenName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                        // Drag handle
                        Capsule()
                            .fill(CultivationTheme.Colors.cardBorder)
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Garden Name")
                                .sectionLabelStyle()
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                            HStack(spacing: 10) {
                                Image(systemName: selectedType.iconName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                    .frame(width: 28)

                                TextField("e.g. Backyard, Herb Window, Patio", text: $gardenName)
                                    .font(.system(.body))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                    .accessibilityIdentifier("creategarden_textfield_name")
                            }
                            .padding(CultivationTheme.Spacing.cardPadding)
                            .glassCard()
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        }

                        // Garden type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Garden Type")
                                .sectionLabelStyle()
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(GardenType.allCases, id: \.self) { type in
                                        GardenTypeChip(
                                            gardenType: type,
                                            isSelected: selectedType == type
                                        ) {
                                            withAnimation(CultivationTheme.Animation.selection) {
                                                selectedType = type
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                            }
                        }

                        // Sun exposure
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sun Exposure")
                                .sectionLabelStyle()
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                            VStack(spacing: 6) {
                                ForEach(SunExposure.allCases, id: \.self) { sun in
                                    SunExposureRow(
                                        exposure: sun,
                                        isSelected: selectedSun == sun
                                    ) {
                                        withAnimation(CultivationTheme.Animation.selection) {
                                            selectedSun = sun
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        }

                        // Space size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Space Available")
                                .sectionLabelStyle()
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(GrowWiseModels.SpaceSize.allCases, id: \.self) { size in
                                        GlassPill(
                                            label: size.displayName,
                                            isSelected: selectedSize == size,
                                            accessibilityID: "creategarden_pill_\(size.rawValue)"
                                        ) {
                                            withAnimation(CultivationTheme.Animation.selection) {
                                                selectedSize = size
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                }

                // Save button pinned to bottom
                VStack {
                    Spacer()

                    Button {
                        saveGarden()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Garden")
                        }
                    }
                    .buttonStyle(GradientButtonStyle(isDisabled: !isValid))
                    .disabled(!isValid || isSaving)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.bottom, 24)
                    .background {
                        LinearGradient(
                            colors: [
                                CultivationTheme.Colors.backgroundSecondary.opacity(0),
                                CultivationTheme.Colors.backgroundSecondary,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false)
                    }
                    .accessibilityIdentifier("creategarden_button_save")
                }
            }
            .navigationTitle("New Garden")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("creategarden_button_cancel")
                }
            }
        }
    }

    private func saveGarden() {
        let trimmed = gardenName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true

        let isIndoor = selectedType == .indoor || selectedType == .windowsill
        do {
            let garden = try dataService.gardens.create(
                name: trimmed,
                type: selectedType,
                isIndoor: isIndoor,
                user: nil
            )
            garden.sunExposure = selectedSun
            garden.spaceAvailable = selectedSize
            try dataService.mainContext.save()
            onCreated(garden)
            dismiss()
        } catch {
            isSaving = false
        }
    }
}

// MARK: - GardenTypeChip

private struct GardenTypeChip: View {
    let gardenType: GardenType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: gardenType.iconName)
                    .font(.system(size: 20, weight: .medium))
                Text(gardenType.displayName)
                    .font(.system(.caption2, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 76)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.accentCoral.opacity(0.15)
                            : CultivationTheme.Colors.cardSurface
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .stroke(
                                isSelected
                                    ? CultivationTheme.Colors.accentCoral
                                    : CultivationTheme.Colors.cardBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
            }
            .foregroundStyle(
                isSelected
                    ? CultivationTheme.Colors.accentCoral
                    : CultivationTheme.Colors.textSecondary
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("creategarden_chip_\(gardenType.rawValue)")
    }
}

// MARK: - SunExposureRow

private struct SunExposureRow: View {
    let exposure: SunExposure
    let isSelected: Bool
    let onTap: () -> Void

    private var iconName: String {
        switch exposure {
        case .fullSun: "sun.max.fill"
        case .partialSun: "sun.haze.fill"
        case .partialShade: "cloud.sun.fill"
        case .fullShade: "cloud.fill"
        case .artificial: "lightbulb.fill"
        }
    }

    private var iconColor: Color {
        switch exposure {
        case .fullSun: Color(hex: "F59E0B")
        case .partialSun: Color(hex: "F59E0B").opacity(0.8)
        case .partialShade: Color(hex: "6B7280")
        case .fullShade: Color(hex: "6B7280")
        case .artificial: Color(hex: "A855F7")
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? iconColor : CultivationTheme.Colors.textTertiary)
                    .frame(width: 24)

                Text(exposure.displayName)
                    .font(.system(.subheadline))
                    .foregroundStyle(
                        isSelected
                            ? CultivationTheme.Colors.textPrimary
                            : CultivationTheme.Colors.textSecondary
                    )

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(
                        isSelected
                            ? CultivationTheme.Colors.accentCoral.opacity(0.08)
                            : CultivationTheme.Colors.cardSurface
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(
                        isSelected
                            ? CultivationTheme.Colors.accentCoral.opacity(0.3)
                            : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("creategarden_sun_\(exposure.rawValue)")
    }
}
