import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - ShoppingListView

/// Shopping list for a garden, with auto-generation from garden/plant data
/// and manual item addition. Items grouped by category with purchase tracking.
struct ShoppingListView: View {
    @Environment(\.modelContext)
    private var modelContext

    let garden: Garden

    @State private var service = ShoppingListService()
    @State private var items: [ShoppingItem] = []
    @State private var showAddItem = false

    private var purchasedCount: Int {
        items.filter(\.isPurchased).count
    }

    private var groupedItems: [(ShoppingCategory, [ShoppingItem])] {
        let grouped = Dictionary(grouping: items) { $0.category ?? .other }
        return ShoppingCategory.allCases.compactMap { category in
            guard let categoryItems = grouped[category], !categoryItems.isEmpty else { return nil }
            return (category, categoryItems)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                // Progress header
                progressHeader

                // Action buttons
                actionButtons

                if items.isEmpty {
                    emptyState
                } else {
                    // Category sections
                    ForEach(groupedItems, id: \.0) { category, categoryItems in
                        categorySection(category: category, items: categoryItems)
                    }
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 32)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Shopping List")
        .gwNavigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("shopping_list")
        .task { loadItems() }
        .sheet(
            isPresented: $showAddItem,
            onDismiss: { loadItems() },
            content: {
                AddShoppingItemSheet(garden: garden)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
        )
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(purchasedCount) of \(items.count) items purchased")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                Spacer()
                if !items.isEmpty {
                    Text("\(Int(Double(purchasedCount) / Double(items.count) * 100))%")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }
            }

            if !items.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CultivationTheme.Colors.cardSurface)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CultivationTheme.Colors.brandLeaf)
                            .frame(
                                width: geo.size.width * CGFloat(purchasedCount) / CGFloat(max(items.count, 1)),
                                height: 8
                            )
                            .animation(CultivationTheme.Animation.card, value: purchasedCount)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.top, 8)
        .accessibilityIdentifier("shopping_progress")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                generateItems()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Generate from Garden")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
            .accessibilityIdentifier("shopping_generate_button")

            Button {
                showAddItem = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Item")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlineButtonStyle())
            .accessibilityIdentifier("shopping_add_button")
        }
    }

    // MARK: - Category Section

    private func categorySection(category: ShoppingCategory, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                Text(category.displayName.uppercased())
                    .sectionLabelStyle()
            }
            .accessibilityIdentifier("shopping_category_\(category.rawValue)")

            VStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    shoppingItemRow(item)

                    if item.id != items.last?.id {
                        Divider()
                            .foregroundStyle(CultivationTheme.Colors.cardBorder)
                            .padding(.leading, 44)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Item Row

    private func shoppingItemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            Button {
                service.togglePurchased(item)
                // Trigger list re-sort
                loadItems()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        item.isPurchased
                            ? CultivationTheme.Colors.statusHealthy
                            : CultivationTheme.Colors.textTertiary
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping_item_toggle_\(item.id?.uuidString ?? "unknown")")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Item")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(
                        item.isPurchased
                            ? CultivationTheme.Colors.textTertiary
                            : CultivationTheme.Colors.textPrimary
                    )
                    .strikethrough(item.isPurchased)

                if let quantity = item.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isAutoGenerated {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
                    .foregroundStyle(CultivationTheme.Colors.brandGold)
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.cardPadding)
        .padding(.vertical, 10)
        .accessibilityIdentifier("shopping_item_\(item.id?.uuidString ?? "unknown")")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                service.deleteItem(item, context: modelContext)
                loadItems()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "cart")
                    .font(.system(size: 36))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }

            VStack(spacing: 6) {
                Text("Shopping list is empty")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Generate items from your garden plan or add items manually")
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Data

    private func loadItems() {
        items = service.fetchItems(for: garden, context: modelContext)
    }

    private func generateItems() {
        let plants = (garden.plants ?? [])
        let newItems = service.generateShoppingList(for: garden, plants: plants)

        // Insert generated items into the model context
        for item in newItems {
            modelContext.insert(item)
        }

        loadItems()
    }
}
