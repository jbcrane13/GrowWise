import SwiftUI
import GrowWiseModels

extension PlantType {
    public var iconName: String {
        switch self {
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .flower: return "sparkles"
        case .houseplant: return "house.fill"
        case .fruit: return "apple.logo"
        case .succulent: return "circle.grid.3x3.fill"
        case .tree: return "tree.fill"
        case .shrub: return "tree.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .houseplant: return .green
        case .succulent: return .mint
        case .flower: return .pink
        case .vegetable: return .orange
        case .herb: return .green
        case .tree: return .brown
        case .shrub: return .green
        case .fruit: return .red
        }
    }
}
