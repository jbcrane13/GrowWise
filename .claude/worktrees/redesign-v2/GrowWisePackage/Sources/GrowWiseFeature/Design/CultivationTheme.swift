import SwiftUI

/// Single source of truth for all Cultivation design tokens.
public enum CultivationTheme {
    // MARK: - Colors

    public enum Colors {
        // Backgrounds — cool charcoal, not warm brown
        public static let background = Color(light: Color(hex: "F4F5F2"), dark: Color(hex: "0B0D0E"))
        public static let backgroundSecondary = Color(light: Color(hex: "E8EAE5"), dark: Color(hex: "151819"))

        // Card surfaces — stone-toned
        public static let cardSurface = Color(light: .white, dark: Color(white: 1, opacity: 0.04))
        public static let cardBorder = Color(light: Color(white: 0, opacity: 0.07), dark: Color(white: 1, opacity: 0.07))

        // Text — neutral cool cast
        public static let textPrimary = Color(light: Color(hex: "1A1A1A"), dark: Color(hex: "E4E6E4"))
        public static let textSecondary = Color(light: Color(hex: "666666"), dark: Color(white: 0.89, opacity: 0.55))
        public static let textTertiary = Color(light: Color(hex: "999999"), dark: Color(white: 0.89, opacity: 0.3))

        // Status — clean, vivid
        public static let statusAlert = Color(light: Color(hex: "D42020"), dark: Color(hex: "E05848"))
        public static let statusWarning = Color(light: Color(hex: "9D7200"), dark: Color(hex: "DBA640"))
        public static let statusHealthy = Color(light: Color(hex: "2D7A3A"), dark: Color(hex: "5EA06A"))

        // Brand — stone & sage with coral/amber accents
        public static let brandForest = Color(hex: "4A6650") // moss — deep green anchor
        public static let brandLeaf = Color(hex: "7A917A") // sage — primary green
        public static let brandMint = Color(hex: "C0CCC5") // frost — light sage
        public static let brandCream = Color(hex: "F4F5F2") // parchment
        public static let brandSage = Color(hex: "96AC96") // lichen — mid sage

        // Accent — coral and amber (the new warm identity)
        public static let accentCoral = Color(hex: "D4725C")
        public static let accentAmber = Color(hex: "E0A456")
        public static let brandGold = accentAmber // legacy alias — prefer accentAmber

        /// Hero glow — subtle sage for background orbs
        public static let heroGlow = Color(hex: "7A917A").opacity(0.06)

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

        /// Warm accent gradient for FAB and primary CTAs
        public static let warmAccent = LinearGradient(
            colors: [Colors.accentCoral, Colors.accentAmber],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let hero = LinearGradient(
            colors: [
                Color(light: Color(hex: "E8EAE5"), dark: Color(hex: "0B0D0E")),
                Color(light: Color(hex: "F4F5F2"), dark: Color(hex: "0B0D0E")),
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
            Text(text).font(.system(.largeTitle, design: .serif, weight: .regular))
        }

        public static func title(_ text: String) -> Text {
            Text(text).font(.system(.title2, design: .serif, weight: .regular))
        }

        public static func headline(_ text: String) -> Text {
            Text(text).font(.system(.headline, design: .serif, weight: .regular))
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

        /// Monospaced stat display — for data/numbers
        public static func stat(_ text: String) -> Text {
            Text(text).font(.system(.title2, design: .monospaced, weight: .medium))
        }

        /// Monospaced data label — for small numeric values
        public static func dataLabel(_ text: String) -> Text {
            Text(text).font(.system(size: 13, weight: .medium, design: .monospaced))
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
