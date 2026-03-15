import GrowWiseModels
import SwiftUI

extension SpaceSize {
    var subtitle: String {
        switch self {
        case .tiny: "Windowsill / Indoor"
        case .small: "Balcony / Patio"
        case .medium: "Small Yard"
        case .large: "Large Yard"
        case .extraLarge: "Farm / Estate"
        }
    }

    var icon: String {
        switch self {
        case .tiny: "house.fill"
        case .small: "building.fill"
        case .medium: "rectangle.split.3x1.fill"
        case .large: "square.grid.2x2.fill"
        case .extraLarge: "map.fill"
        }
    }
}
