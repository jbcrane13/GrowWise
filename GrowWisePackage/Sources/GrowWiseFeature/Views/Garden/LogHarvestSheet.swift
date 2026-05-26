import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LogHarvestSheet: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(PhotoService.self)
    private var photoService
    @Environment(\.dismiss)
    private var dismiss

    let plant: Plant
    var onSaved: (() -> Void)?

    @State private var quantity: String = ""
    @State private var selectedUnit: HarvestUnit = .pieces
    @State private var harvestDate = Date()
    @State private var notes: String = ""
    @State private var shareToClub = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    #if os(iOS)
    @State private var selectedPhotoPreview: UIImage?
    #endif
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    plantHeader
                    quantitySection
                    unitPicker
                    dateSection
                    photoSection
                    shareSection
                    notesSection
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Log Harvest")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("logharvest_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task { await saveHarvest() }
                    }
                    .disabled(quantity.isEmpty || Double(quantity) == nil || isSaving)
                    .accessibilityIdentifier("logharvest_button_save")
                }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("logharvest_button_error_ok")
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .accessibilityIdentifier("logharvest_sheet")
    }

    private var plantHeader: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: "leaf.fill",
                color: CultivationTheme.Colors.brandLeaf,
                size: 44,
                iconSize: 20
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name ?? "Plant")
                    .font(CultivationTheme.Fonts.display(16, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Recording today's harvest")
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUANTITY")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            TextField("0", text: $quantity)
                .font(CultivationTheme.Fonts.display(22, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("logharvest_textfield_quantity")
        }
    }

    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNIT")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HarvestUnit.allCases, id: \.self) { unit in
                        GlassPill(
                            label: unit.displayName,
                            isSelected: selectedUnit == unit
                        ) { selectedUnit = unit }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES (OPTIONAL)")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            TextEditor(text: $notes)
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .frame(minHeight: 80)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("logharvest_texteditor_notes")
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            DatePicker("Harvest date", selection: $harvestDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("logharvest_datepicker_date")
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTO")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 12) {
                    #if os(iOS)
                    if let selectedPhotoPreview {
                        Image(uiImage: selectedPhotoPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        photoPlaceholder
                    }
                    #else
                    photoPlaceholder
                    #endif

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPhotoData == nil ? "Add harvest photo" : "Photo attached")
                            .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text("Optional")
                            .font(CultivationTheme.Fonts.body(11))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                    Spacer()
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .fill(CultivationTheme.Colors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logharvest_button_photo")
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(CultivationTheme.Colors.backgroundSecondary)
            .frame(width: 52, height: 52)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
    }

    private var shareSection: some View {
        Toggle("Share harvest to Club", isOn: $shareToClub)
            .font(CultivationTheme.Fonts.body(14, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textPrimary)
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .accessibilityIdentifier("logharvest_toggle_share")
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            selectedPhotoData = data
            #if os(iOS)
            selectedPhotoPreview = UIImage(data: data)
            #endif
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func saveHarvest() async {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity greater than 0"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let photoURL: String? = if let selectedPhotoData {
                try await photoService.saveClubPostPhotoData(selectedPhotoData)
            } else {
                nil
            }

            try dataService.logHarvest(
                quantity: quantityValue,
                unit: selectedUnit,
                plant: plant,
                date: harvestDate,
                notes: notes,
                photoURL: photoURL
            )
            if shareToClub {
                try dataService.createClubPost(
                    caption: harvestCaption(quantity: quantityValue, unit: selectedUnit),
                    activityType: "harvested",
                    plantName: plant.name,
                    gardenName: plant.garden?.name,
                    photoURL: photoURL
                )
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Failed to save harvest: \(error.localizedDescription)"
        }
    }

    private func harvestCaption(quantity: Double, unit: HarvestUnit) -> String {
        let formattedQuantity = quantity.formatted(.number.precision(.fractionLength(0 ... 1)))
        return "Harvested \(formattedQuantity) \(unit.displayNamePlural)"
    }
}
