import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// NOTE: Color.init(hex:) and Color.init(light:dark:) are defined in CultivationTheme.swift
// New code should use CultivationTheme.Colors.* tokens directly.
// Existing colors below are kept for backward compatibility during migration.

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

    // MARK: - Botanical Design System

    /// Deep forest green — primary brand color
    static let botanicalForest = Color(red: 0.176, green: 0.420, blue: 0.310)
    /// Vibrant growth green — interactive / accent
    static let botanicalLeaf = Color(red: 0.322, green: 0.718, blue: 0.533)
    /// Soft mint — light accent / backgrounds
    static let botanicalMint = Color(red: 0.718, green: 0.894, blue: 0.780)
    /// Warm cream — page background
    static let botanicalCream = Color(red: 0.965, green: 0.957, blue: 0.937)
    /// Earthy brown — warmth accent
    static let botanicalEarth = Color(red: 0.498, green: 0.337, blue: 0.224)
    /// Harvest gold — highlight accent
    static let botanicalGold = Color(red: 0.918, green: 0.773, blue: 0.416)
    /// Soft sage — secondary text / icon backgrounds
    static let botanicalSage = Color(red: 0.576, green: 0.722, blue: 0.576)
}
