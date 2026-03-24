import SwiftUI

/// Single source of truth for all Cultivation design tokens.
public enum CultivationTheme {
    // MARK: - Colors

    public enum Colors {
        // Backgrounds
        public static let background = Color(light: Color(hex: "FAFAF8"), dark: Color(hex: "0C0C0C"))
        public static let backgroundSecondary = Color(light: Color(hex: "F0EDE6"), dark: Color(hex: "141414"))

        // Card surfaces — use with .glassCard() modifier
        public static let cardSurface = Color(light: .white, dark: Color(white: 1, opacity: 0.04))
        public static let cardBorder = Color(light: Color(white: 0, opacity: 0.07), dark: Color(white: 1, opacity: 0.08))

        // Text
        public static let textPrimary = Color(light: Color(hex: "1A1A1A"), dark: Color(hex: "E5E5E5"))
        public static let textSecondary = Color(light: Color(hex: "666666"), dark: Color(white: 1, opacity: 0.4))
        public static let textTertiary = Color(light: Color(hex: "999999"), dark: Color(hex: "666666"))

        // Status — Apple system colors, vivid on dark bg
        public static let statusAlert = Color(light: Color(hex: "D70015"), dark: Color(hex: "FF453A"))
        public static let statusWarning = Color(light: Color(hex: "9D7200"), dark: Color(hex: "FFD60A"))
        public static let statusHealthy = Color(light: Color(hex: "1A7F37"), dark: Color(hex: "30D158"))

        // Brand
        public static let brandForest = Color(hex: "2D6A4F")
        public static let brandLeaf = Color(hex: "52B788")
        public static let brandMint = Color(hex: "B7E4C7")
        public static let brandCream = Color(hex: "F5F0E8")
        public static let brandGold = Color(hex: "E9C46A")
        public static let brandSage = Color(hex: "7A9D68")

        /// Hero glow
        public static let heroGlow = Color(hex: "4CAF50").opacity(0.08)

        // Interactive
        public static let divider = Color(light: Color(white: 0, opacity: 0.08), dark: Color(white: 1, opacity: 0.06))
        public static let sectionLabel = Color(light: Color(hex: "888888"), dark: Color(hex: "666666"))
    }

    // MARK: - Gradients

    public enum Gradients {
        public static let cta = LinearGradient(
            colors: [Colors.brandForest, Colors.brandLeaf],
            startPoint: .leading,
            endPoint: .trailing
        )

        public static let ctaVertical = LinearGradient(
            colors: [Colors.brandForest, Colors.brandLeaf],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let hero = LinearGradient(
            colors: [
                Color(light: Color(hex: "F0EDE6"), dark: Color(hex: "0C0C0C")),
                Color(light: Color(hex: "FAFAF8"), dark: Color(hex: "0C0C0C")),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Corner Radii

    public enum Radius {
        public static let card: CGFloat = 14
        public static let icon: CGFloat = 10
        public static let button: CGFloat = 14
        public static let pill: CGFloat = 100 // use Capsule shape
        public static let sheet: CGFloat = 20
        public static let statCard: CGFloat = 14
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let screenPadding: CGFloat = 16
        public static let cardPadding: CGFloat = 14
        public static let sectionGap: CGFloat = 20
        public static let rowGap: CGFloat = 8
        public static let iconSize: CGFloat = 44
        public static let iconSizeSmall: CGFloat = 32
    }

    // MARK: - Animations

    public enum Animation {
        public static let card = SwiftUI.Animation.spring(duration: 0.3, bounce: 0.2)
        public static let tab = SwiftUI.Animation.spring(duration: 0.4, bounce: 0.05)
        public static let selection = SwiftUI.Animation.spring(duration: 0.25, bounce: 0.2)
        public static let sheet = SwiftUI.Animation.spring(duration: 0.45, bounce: 0.05)
        public static let entrance = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.1)
    }

    // MARK: - Typography

    public enum Typography {
        public static func largeTitle(_ text: String) -> Text {
            Text(text).font(.system(.largeTitle, design: .rounded, weight: .bold))
        }

        public static func title(_ text: String) -> Text {
            Text(text).font(.system(.title2, design: .rounded, weight: .bold))
        }

        public static func headline(_ text: String) -> Text {
            Text(text).font(.system(.headline, design: .rounded, weight: .semibold))
        }

        public static func body(_ text: String) -> Text {
            Text(text).font(.system(.body, design: .default))
        }

        public static func caption(_ text: String) -> Text {
            Text(text).font(.system(.caption, design: .default))
        }

        public static func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .textCase(.uppercase)
        }

        public static func stat(_ text: String) -> Text {
            Text(text).font(.system(.title2, design: .rounded, weight: .bold))
        }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        // swiftlint:disable:next identifier_name
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)

        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }

    /// Light/dark adaptive color
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}
