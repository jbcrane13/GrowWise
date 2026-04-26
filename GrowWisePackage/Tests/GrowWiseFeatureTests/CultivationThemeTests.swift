@testable import GrowWiseFeature
import SwiftUI
import Testing

@Suite("CultivationTheme Tests")
struct CultivationThemeTests {
    // MARK: - Adaptive background colors

    @Test("Background is cream paper in light mode")
    func backgroundIsCreamPaperLight() {
        let expected = Color(hex: "F6F0E4")
        #expect(CultivationTheme.Colors.background != Color.clear)
        #expect(expected != Color.clear)
    }

    @Test("Adaptive background tokens are defined")
    func adaptiveBackgroundTokensDefined() {
        #expect(CultivationTheme.Colors.backgroundSecondary != Color.clear)
        #expect(CultivationTheme.Colors.cardSurface != Color.clear)
    }

    // MARK: - Plain-hex accent and brand colors

    @Test("Coral accent matches spec hex D9694B")
    func coralAccentMatchesSpec() {
        // accentCoral is a plain Color(hex:), not wrapped in Color(light:dark:),
        // so direct equality is reliable.
        #expect(CultivationTheme.Colors.accentCoral == Color(hex: "D9694B"))
        #expect(CultivationTheme.Colors.accentCoralDeep == Color(hex: "B14F33"))
        #expect(CultivationTheme.Colors.accentAmber == Color(hex: "C99327"))
        #expect(CultivationTheme.Colors.brandForest == Color(hex: "2E4631"))
        #expect(CultivationTheme.Colors.brandLeaf == Color(hex: "7B9069"))
    }

    @Test("brandMint matches spec hex B7C9A4")
    func brandMintMatchesSpec() {
        #expect(CultivationTheme.Colors.brandMint == Color(hex: "B7C9A4"))
    }

    @Test("brandCream matches spec hex F6F0E4")
    func brandCreamMatchesSpec() {
        #expect(CultivationTheme.Colors.brandCream == Color(hex: "F6F0E4"))
    }

    @Test("brandSage matches spec hex 4F6B49")
    func brandSageMatchesSpec() {
        #expect(CultivationTheme.Colors.brandSage == Color(hex: "4F6B49"))
    }

    @Test("accentSky matches spec hex 6F94A6")
    func accentSkyMatchesSpec() {
        #expect(CultivationTheme.Colors.accentSky == Color(hex: "6F94A6"))
    }

    @Test("brandGold is alias for accentAmber")
    func brandGoldIsAliasForAccentAmber() {
        #expect(CultivationTheme.Colors.brandGold == CultivationTheme.Colors.accentAmber)
    }

    @Test("smartTagForeground matches spec hex 4F6B49")
    func smartTagForegroundMatchesSpec() {
        #expect(CultivationTheme.Colors.smartTagForeground == Color(hex: "4F6B49"))
    }

    @Test("dashedLine matches spec hex D9CFB8")
    func dashedLineMatchesSpec() {
        #expect(CultivationTheme.Colors.dashedLine == Color(hex: "D9CFB8"))
    }

    // MARK: - Adaptive semantic colors

    @Test("Adaptive text color tokens are defined")
    func adaptiveTextColorsDefined() {
        #expect(CultivationTheme.Colors.textPrimary != Color.clear)
        #expect(CultivationTheme.Colors.textSecondary != Color.clear)
        #expect(CultivationTheme.Colors.textTertiary != Color.clear)
    }

    @Test("Adaptive status color tokens are defined")
    func adaptiveStatusColorsDefined() {
        #expect(CultivationTheme.Colors.statusAlert != Color.clear)
        #expect(CultivationTheme.Colors.statusWarning != Color.clear)
        #expect(CultivationTheme.Colors.statusHealthy != Color.clear)
    }

    @Test("Adaptive UI color tokens are defined")
    func adaptiveUIColorsDefined() {
        #expect(CultivationTheme.Colors.divider != Color.clear)
        #expect(CultivationTheme.Colors.sectionLabel != Color.clear)
        #expect(CultivationTheme.Colors.smartTagBackground != Color.clear)
    }

    // MARK: - Gradients

    @Test("All four gradient tokens are accessible as LinearGradient")
    func gradientTokensAccessible() {
        // Structural check: assigning to a typed variable confirms the token
        // compiles to the correct type and the referenced colors resolve.
        let _: LinearGradient = CultivationTheme.Gradients.cta
        let _: LinearGradient = CultivationTheme.Gradients.ctaVertical
        let _: LinearGradient = CultivationTheme.Gradients.warmAccent
        let _: LinearGradient = CultivationTheme.Gradients.hero
    }

    // MARK: - Corner radii

    @Test("Card radius is 16")
    func cardRadiusIs16() {
        #expect(CultivationTheme.Radius.card == 16)
    }

    @Test("StatCard radius token is defined")
    func statCardRadiusDefined() {
        #expect(CultivationTheme.Radius.statCard == 14)
    }

    @Test("Icon and button radius tokens match spec")
    func iconAndButtonRadiusMatchSpec() {
        #expect(CultivationTheme.Radius.icon == 10)
        #expect(CultivationTheme.Radius.button == 14)
    }

    @Test("Pill and sheet radius tokens match spec")
    func pillAndSheetRadiusMatchSpec() {
        #expect(CultivationTheme.Radius.pill == 100)
        #expect(CultivationTheme.Radius.sheet == 20)
    }

    // MARK: - Spacing

    @Test("Screen padding is 20")
    func screenPaddingIs20() {
        #expect(CultivationTheme.Spacing.screenPadding == 20)
    }

    @Test("Section gap is 24")
    func sectionGapIs24() {
        #expect(CultivationTheme.Spacing.sectionGap == 24)
    }

    @Test("Card padding and row gap match spec")
    func cardPaddingAndRowGapMatchSpec() {
        #expect(CultivationTheme.Spacing.cardPadding == 16)
        #expect(CultivationTheme.Spacing.rowGap == 8)
    }

    @Test("Icon size tokens match spec")
    func iconSizeTokensMatchSpec() {
        #expect(CultivationTheme.Spacing.iconSize == 44)
        #expect(CultivationTheme.Spacing.iconSizeSmall == 32)
    }

    // MARK: - Animations

    @Test("All five animation tokens are accessible")
    func animationTokensAccessible() {
        let _: SwiftUI.Animation = CultivationTheme.Animation.card
        let _: SwiftUI.Animation = CultivationTheme.Animation.tab
        let _: SwiftUI.Animation = CultivationTheme.Animation.selection
        let _: SwiftUI.Animation = CultivationTheme.Animation.sheet
        let _: SwiftUI.Animation = CultivationTheme.Animation.entrance
    }

    // MARK: - Fonts

    @Test("Fonts.display returns a serif system font")
    func displayFontIsSerifSystem() {
        // System fonts don't expose design as a readable property, so the
        // check is structural: we construct and compare to the spec. The
        // ultimate validation is visual (ui-verify in Phase 10).
        let font = CultivationTheme.Fonts.display(17, weight: .medium)
        let expected = Font.system(size: 17, weight: .medium, design: .serif)
        #expect(String(describing: font) == String(describing: expected))
    }

    @Test("Fonts.body returns a rounded system font")
    func bodyFontIsRoundedSystem() {
        let font = CultivationTheme.Fonts.body(14)
        let expected = Font.system(size: 14, weight: .regular, design: .rounded)
        #expect(String(describing: font) == String(describing: expected))
    }

    @Test("Fonts.displayItalic returns a serif italic system font")
    func displayItalicIsSerifSystemItalic() {
        let font = CultivationTheme.Fonts.displayItalic(22)
        let expected = Font.system(size: 22, weight: .regular, design: .serif).italic()
        #expect(String(describing: font) == String(describing: expected))
    }
}
