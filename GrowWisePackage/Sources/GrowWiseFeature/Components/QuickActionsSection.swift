import SwiftUI

/// Enum representing available quick actions in the home view.
public enum QuickAction: CaseIterable {
    case waterPlants
    case addJournalEntry
    case plantDatabase
    case myGarden

    public var icon: String {
        switch self {
        case .waterPlants: return "drop.fill"
        case .addJournalEntry: return "book.fill"
        case .plantDatabase: return "books.vertical.fill"
        case .myGarden: return "leaf.fill"
        }
    }

    public var label: String {
        switch self {
        case .waterPlants: return "Water Plants"
        case .addJournalEntry: return "Add Journal Entry"
        case .plantDatabase: return "Plant Database"
        case .myGarden: return "My Garden"
        }
    }

    public var color: Color {
        switch self {
        case .waterPlants: return .blue
        case .addJournalEntry: return .green
        case .plantDatabase: return .orange
        case .myGarden: return .mint
        }
    }

    public var accessibilityLabel: String {
        return label
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
