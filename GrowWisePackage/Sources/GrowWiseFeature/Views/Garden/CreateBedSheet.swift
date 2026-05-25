import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Sheet for creating a new GardenBed in a given garden.
struct CreateBedSheet: View {
    let garden: Garden
    let onCreated: (GardenBed) -> Void

    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService

    @State private var selectedType: BedType = .raisedBed
    @State private var bedName: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    // Drag handle
                    Capsule()
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    // Type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Container Type")
                            .sectionLabelStyle()
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(BedType.allCases, id: \.self) { type in
                                    BedTypeChip(
                                        bedType: type,
                                        isSelected: selectedType == type
                                    ) {
                                        selectedType = type
                                        if bedName.isEmpty {
                                            bedName = type.displayName
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        }
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .sectionLabelStyle()
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                        HStack(spacing: 10) {
                            IconBubble(
                                systemName: selectedType.iconName,
                                color: CultivationTheme.Colors.accentCoral,
                                size: 28,
                                iconSize: 13
                            )
                            TextField("e.g. South Bed, Herb Pots", text: $bedName)
                                .font(.system(.body))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                .accessibilityIdentifier("createbed_textfield_name")
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                        .glassCard()
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    Spacer()

                    Button {
                        saveBed()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add Container")
                        }
                    }
                    .buttonStyle(GradientButtonStyle(isDisabled: isSaveDisabled))
                    .disabled(isSaveDisabled)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .accessibilityIdentifier("createbed_button_save")
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Add Container")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("createbed_button_cancel")
                }
            }
        }
        .alert("Container Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
                .accessibilityIdentifier("createbed_button_error_dismiss")
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var isSaveDisabled: Bool {
        isSaving || bedName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveBed() {
        let trimmed = bedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        do {
            let bed = try dataService.createGardenBed(name: trimmed, bedType: selectedType, in: garden)
            isSaving = false
            onCreated(bed)
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "Could not create container: \(error.localizedDescription)"
        }
    }
}

// MARK: - BedTypeChip

private struct BedTypeChip: View {
    let bedType: BedType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: bedType.iconName)
                    .font(.system(size: 18, weight: .medium))
                Text(bedType.displayName)
                    .font(.system(.caption2, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 72)
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
        .accessibilityIdentifier("createbed_chip_\(bedType.rawValue)")
    }
}
