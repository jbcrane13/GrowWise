import GrowWiseModels
import SwiftUI

// MARK: - AddShoppingItemSheet

/// Sheet for manually adding an item to a garden's shopping list.
struct AddShoppingItemSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    let garden: Garden

    @State private var name: String = ""
    @State private var category: ShoppingCategory = .seeds
    @State private var quantity: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ITEM NAME")
                            .sectionLabelStyle()
                        TextField("e.g. Tomato seeds", text: $name)
                            .font(.system(.body, design: .rounded))
                            .padding(12)
                            .glassCard()
                            .accessibilityIdentifier("shopping_add_name")
                    }

                    // Category picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATEGORY")
                            .sectionLabelStyle()
                        VStack(spacing: 0) {
                            ForEach(ShoppingCategory.allCases, id: \.self) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 15))
                                            .foregroundStyle(
                                                category == cat
                                                    ? CultivationTheme.Colors.brandLeaf
                                                    : CultivationTheme.Colors.textTertiary
                                            )
                                            .frame(width: 24)

                                        Text(cat.displayName)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(CultivationTheme.Colors.textPrimary)

                                        Spacer()

                                        if category == cat {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                                        }
                                    }
                                    .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("shopping_add_category_\(cat.rawValue)")

                                if cat != ShoppingCategory.allCases.last {
                                    Divider()
                                        .foregroundStyle(CultivationTheme.Colors.cardBorder)
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .glassCard()
                    }

                    // Quantity field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QUANTITY")
                            .sectionLabelStyle()
                        TextField("e.g. 2 bags, 1 packet", text: $quantity)
                            .font(.system(.body, design: .rounded))
                            .padding(12)
                            .glassCard()
                            .accessibilityIdentifier("shopping_add_quantity")
                    }

                    // Notes field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES")
                            .sectionLabelStyle()
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(3, reservesSpace: true)
                            .padding(12)
                            .glassCard()
                            .accessibilityIdentifier("shopping_add_notes")
                    }

                    // Save button
                    Button("Add to Shopping List") {
                        saveItem()
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("shopping_add_save")
                    .padding(.top, 8)
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Item")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("shopping_add_cancel")
                }
            }
        }
    }

    // MARK: - Save

    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let item = ShoppingItem(
            name: trimmedName,
            category: category,
            quantity: quantity.isEmpty ? nil : quantity,
            isAutoGenerated: false
        )
        item.notes = notes.isEmpty ? nil : notes
        item.garden = garden

        modelContext.insert(item)
        dismiss()
    }
}
