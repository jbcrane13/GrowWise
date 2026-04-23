import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Single source of truth for all Cultivation design tokens.
///
/// v2 (2026-04-20): Cream paper "field journal" replaces dark glass-morphism.
/// See ADR-019 and docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md.
public enum CultivationTheme {
    // MARK: - Colors

    public enum Colors {
        // Backgrounds — warm cream paper, not dark
        public static let background = Color(light: Color(hex: "F6F0E4"), dark: Color(hex: "181816"))
        public static let backgroundSecondary = Color(light: Color(hex: "EFE6D3"), dark: Color(hex: "1F1E1C"))

        // Card surfaces — warm white on light, soft warm-dark on dark
        public static let cardSurface = Color(light: Color(hex: "FFFDF7"), dark: Color(hex: "232220"))
        public static let cardBorder = Color(light: Color(red: 0.12, green: 0.16, blue: 0.13, opacity: 0.08), dark: Color(white: 1, opacity: 0.06))

        // Text — ink on cream, cream on ink
        public static let textPrimary = Color(light: Color(hex: "1F2A22"), dark: Color(hex: "EAE2D2"))
        public static let textSecondary = Color(light: Color(hex: "3F4A40"), dark: Color(hex: "C9C2B4"))
        public static let textTertiary = Color(light: Color(hex: "6E7368"), dark: Color(hex: "8A8378"))

        // Status — softer hues that read on cream
        public static let statusAlert = Color(light: Color(hex: "B14F33"), dark: Color(hex: "E27559"))
        public static let statusWarning = Color(light: Color(hex: "C99327"), dark: Color(hex: "DBA640"))
        public static let statusHealthy = Color(light: Color(hex: "4F6B49"), dark: Color(hex: "7B9069"))

        // Brand — sage and moss green family
        public static let brandForest = Color(hex: "2E4631") // moss — deep anchor
        public static let brandLeaf = Color(hex: "7B9069") // sage — primary
        public static let brandMint = Color(hex: "B7C9A4") // soft sage tint
        public static let brandCream = Color(hex: "F6F0E4") // paper
        public static let brandSage = Color(hex: "4F6B49") // sage-deep — for labels on cream

        // Accent — coral is the action color, honey is the warmth
        public static let accentCoral = Color(hex: "D9694B")
        public static let accentCoralDeep = Color(hex: "B14F33")
        public static let accentAmber = Color(hex: "C99327") // honey
        public static let accentSky = Color(hex: "6F94A6") // for water/sky icons
        public static let brandGold = accentAmber // legacy alias

        /// Smart-enrichment marker color (sage on cream)
        public static let smartTagBackground = Color(red: 0.482, green: 0.565, blue: 0.412, opacity: 0.18)
        public static let smartTagForeground = Color(hex: "4F6B49")

        /// Hero glow — kept for legacy callers but should be unused in v2
        public static let heroGlow = Color(hex: "7B9069").opacity(0.05)

        // Interactive
        public static let divider = Color(light: Color(hex: "D9CFB8"), dark: Color(white: 1, opacity: 0.08))
        public static let dashedLine = Color(hex: "D9CFB8")
        public static let sectionLabel = Color(light: Color(hex: "6E7368"), dark: Color(hex: "8A8378"))
    }

    // MARK: - Gradients

    public enum Gradients {
        /// Primary CTA gradient — moss to sage. Used for "Mark all done" style commits.
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

        /// Coral/honey banner — used on the Home club card.
        public static let warmAccent = LinearGradient(
            colors: [Colors.accentCoral, Colors.accentAmber],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Hero background gradient — paper-on-paper, for screen tops.
        public static let hero = LinearGradient(
            colors: [
                Color(light: Color(hex: "EFE6D3"), dark: Color(hex: "1F1E1C")),
                Color(light: Color(hex: "F6F0E4"), dark: Color(hex: "181816")),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Corner Radii

    public enum Radius {
        public static let card: CGFloat = 16 // was 14
        public static let icon: CGFloat = 10
        public static let button: CGFloat = 14
        public static let pill: CGFloat = 100
        public static let sheet: CGFloat = 20
        public static let statCard: CGFloat = 14
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let screenPadding: CGFloat = 20 // was 16 — more breathing room
        public static let cardPadding: CGFloat = 16 // was 14
        public static let sectionGap: CGFloat = 24 // was 20
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

    // MARK: - Fonts

    /// Fraunces (display/headlines) + Manrope (body/UI) with system fallbacks.
    /// Fonts are registered via FontRegistration.registerIfNeeded() at app launch.
    public enum Fonts {
        #if canImport(UIKit)
        private static var frauncesReady: Bool {
            UIFont.familyNames.contains("Fraunces")
        }

        private static var manropeReady: Bool {
            UIFont.familyNames.contains("Manrope")
        }
        #else
        private static var frauncesReady: Bool {
            false
        }

        private static var manropeReady: Bool {
            false
        }
        #endif

        public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            frauncesReady
                ? .custom("Fraunces", size: size).weight(weight)
                : .system(size: size, weight: weight, design: .serif)
        }

        public static func displayItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            frauncesReady
                ? .custom("Fraunces", size: size).weight(weight).italic()
                : .system(size: size, weight: weight, design: .serif).italic()
        }

        public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            manropeReady
                ? .custom("Manrope", size: size).weight(weight)
                : .system(size: size, weight: weight, design: .rounded)
        }
    }

    // MARK: - Typography (legacy API, now using Fonts under the hood)

    public enum Typography {
        public static func largeTitle(_ text: String) -> Text {
            Text(text).font(Fonts.display(34, weight: .medium))
        }

        public static func title(_ text: String) -> Text {
            Text(text).font(Fonts.display(22, weight: .medium))
        }

        public static func headline(_ text: String) -> Text {
            Text(text).font(Fonts.display(17, weight: .semibold))
        }

        public static func body(_ text: String) -> Text {
            Text(text).font(Fonts.body(16))
        }

        public static func caption(_ text: String) -> Text {
            Text(text).font(Fonts.body(12))
        }

        public static func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(Fonts.body(11, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Colors.sectionLabel)
        }

        public static func stat(_ text: String) -> Text {
            Text(text).font(Fonts.display(22, weight: .semibold))
        }

        public static func dataLabel(_ text: String) -> Text {
            Text(text).font(Fonts.body(13, weight: .semibold))
        }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
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
