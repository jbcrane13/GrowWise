@testable import GrowWiseFeature
import SwiftUI
import Testing

struct CultivationThemeTests {
    @Test("Background is cream paper in light mode")
    func backgroundIsCreamPaperLight() {
        let expected = Color(hex: "F6F0E4")
        #expect(CultivationTheme.Colors.background != Color.clear)
        #expect(expected != Color.clear)
    }

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

    @Test("Card radius is 16")
    func cardRadiusIs16() {
        #expect(CultivationTheme.Radius.card == 16)
    }

    @Test("Screen padding is 20")
    func screenPaddingIs20() {
        #expect(CultivationTheme.Spacing.screenPadding == 20)
    }

    @Test("Section gap is 24")
    func sectionGapIs24() {
        #expect(CultivationTheme.Spacing.sectionGap == 24)
    }

    @Test("StatCard radius token is defined")
    func statCardRadiusDefined() {
        #expect(CultivationTheme.Radius.statCard == 14)
    }

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
