import GrowWiseModels
import SwiftUI

public extension PlantType {
    var iconName: String {
        switch self {
        case .vegetable: "carrot.fill"
        case .herb: "leaf.fill"
        case .flower: "sparkles"
        case .houseplant: "house.fill"
        case .fruit: "apple.logo"
        case .succulent: "circle.grid.3x3.fill"
        case .tree: "tree.fill"
        case .shrub: "tree.fill"
        }
    }

    var color: Color {
        switch self {
        case .houseplant: .green
        case .succulent: .mint
        case .flower: .pink
        case .vegetable: .orange
        case .herb: .green
        case .tree: .brown
        case .shrub: .green
        case .fruit: .red
        }
    }
}
