import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Adaptive green colors for the app
    static var adaptiveGreen: Color {
        Color(light: .green, dark: Color(red: 0.2, green: 0.8, blue: 0.4))
    }

    static var adaptiveGreenBackground: Color {
        Color(light: Color.green.opacity(0.1), dark: Color.green.opacity(0.2))
    }

    static var adaptiveSelectionBackground: Color {
        Color(light: Color.green, dark: Color(red: 0.2, green: 0.7, blue: 0.4))
    }

    /// Background colors that work in both modes
    static var adaptiveCardBackground: Color {
        Color(.secondarySystemBackground)
    }

    static var adaptiveTertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }

    /// Initialize a color that adapts to light/dark mode
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                UIColor(dark)

            default:
                UIColor(light)
            }
        })
        #else
        self = light
        #endif
    }
}
