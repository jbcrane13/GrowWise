import SwiftUI

/// Enum representing available quick actions in the home view.
public enum QuickAction: CaseIterable {
    case waterPlants
    case addJournalEntry
    case plantDatabase
    case myGarden

    public var icon: String {
        switch self {
        case .waterPlants: "drop.fill"
        case .addJournalEntry: "book.fill"
        case .plantDatabase: "books.vertical.fill"
        case .myGarden: "leaf.fill"
        }
    }

    public var label: String {
        switch self {
        case .waterPlants: "Water Plants"
        case .addJournalEntry: "Add Journal Entry"
        case .plantDatabase: "Plant Database"
        case .myGarden: "My Garden"
        }
    }

    public var color: Color {
        switch self {
        case .waterPlants: .blue
        case .addJournalEntry: .green
        case .plantDatabase: .orange
        case .myGarden: .mint
        }
    }

    public var accessibilityLabel: String {
        label
    }
}

/// A reusable quick actions section component that displays action buttons in a grid.
public struct QuickActionsSection: View {
    let onActionTap: (QuickAction) -> Void

    public init(onActionTap: @escaping (QuickAction) -> Void) {
        self.onActionTap = onActionTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    QuickActionButton(
                        icon: action.icon,
                        label: action.label,
                        color: action.color
                    ) {
                        onActionTap(action)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quick actions for plant care")
        }
    }
}

#Preview {
    QuickActionsSection { action in
        print("Tapped: \(action.label)")
    }
    .padding()
}
