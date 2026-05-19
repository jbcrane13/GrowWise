import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct LogHarvestSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let plant: Plant

    @State private var quantity: String = ""
    @State private var selectedUnit: HarvestUnit = .pieces
    @State private var notes: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    plantHeader
                    quantitySection
                    unitPicker
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
                    Button("Save") { saveHarvest() }
                        .disabled(quantity.isEmpty || Double(quantity) == nil)
                        .accessibilityIdentifier("logharvest_button_save")
                }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
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

    private func saveHarvest() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity greater than 0"
            return
        }

        do {
            try dataService.logHarvest(
                quantity: quantityValue,
                unit: selectedUnit,
                plant: plant,
                notes: notes
            )
            dismiss()
        } catch {
            errorMessage = "Failed to save harvest: \(error.localizedDescription)"
        }
    }
}
