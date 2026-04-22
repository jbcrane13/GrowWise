> **Execution note (2026-04-22):** Phase 2 ("Font registration") is obsolete. The active plan ships iOS system fonts via `CultivationTheme.Fonts` — no custom `.ttf` files, no `UIAppFonts`, no `FontRegistration.swift`. See `docs/superpowers/plans/2026-04-22-cultivation-redesign-and-rename.md` for the current task list. Everything else in this file (ViewModifiers, MainAppView tab restructure, GardenClubFeedView source, HomeView/GardenView/PlantDetail skeletons) remains load-bearing reference material.

---

# Simplified UI v2 — Implementation Guide

**Companion to:** `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md`
**ADR:** `docs/architecture/ADR.md` → ADR-019
**Mockup:** `docs/mockups/cultivation-simplified-wireflow.html`
**Branch:** `redesign/v2-simplified-ui` (worktree at `.claude/worktrees/redesign-v2`)
**Audience for this doc:** Either Blake working at the keyboard, or another Claude session with Swift toolchain access.

---

## Why this is a guide and not a finished branch

This guide was produced from a Cowork session that had no Swift toolchain and no SSH route to mac-mini, so the normal `swift build` → fix → `swift test` loop was unavailable. Rather than write 2000 lines of unverified Swift, we stopped at the spec/ADR and produced this. The work is fully scoped — execution should be straightforward in a session with `swift build` access.

The Superpowers `ios-swift-development` skill is the source of truth for code conventions; this guide assumes you've read it.

---

## Order of operations

Each phase ends with a `swift build` checkpoint. Don't move to the next phase with a red build.

| Phase | Files | Validation |
|---|---|---|
| 1. Theme tokens | `Design/CultivationTheme.swift`, `Design/ViewModifiers.swift` | `swift build` |
| 2. Font registration | `GrowWisePackage/Sources/GrowWiseFeature/Resources/Fonts/`, `Package.swift`, `GrowWise/Info.plist` | App boots, fonts visible |
| 3. Tab restructure | `Main/MainAppView.swift`, `Views/ProfileView.swift` (one ref) | `swift build` |
| 4. Delete Reminders + Journal tabs | `Views/RemindersListView.swift`, `Views/Journal/*.swift` | grep for refs is clean |
| 5. Garden Club feed | new `Views/GardenClub/GardenClubFeedView.swift` | `swift build`, app navigates |
| 6. Home rewrite | `Views/HomeView.swift`, `Views/Home/*.swift` | `swift build`, screen renders |
| 7. Garden rewrite | `Views/GardenView.swift`, `Views/Garden/GardenComponents.swift` | `swift build`, screen renders |
| 8. Plant Detail rewrite | `Views/MyGardenPlantDetailView.swift` | `swift build`, screen renders |
| 9. Test fixes | `GrowWisePackage/Tests/**` | `swift test` green |
| 10. Lint + format + code-review | repo-wide | `swiftlint --strict`, `swiftformat --lint` |

Total estimate: 6–10 hours of focused work for a Swift-fluent operator.

---

## Phase 1 — Theme tokens

### File: `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

**Replace the entire file** with the following. Keeps the public API surface (`CultivationTheme.Colors.X`, `Gradients`, `Radius`, `Spacing`, `Animation`, `Typography`) so most call sites compile without changes — what shifts is the *values* and the addition of a `Fonts` namespace.

```swift
import SwiftUI

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
        public static let brandForest = Color(hex: "2E4631")    // moss — deep anchor
        public static let brandLeaf = Color(hex: "7B9069")      // sage — primary
        public static let brandMint = Color(hex: "B7C9A4")      // soft sage tint
        public static let brandCream = Color(hex: "F6F0E4")     // paper
        public static let brandSage = Color(hex: "4F6B49")      // sage-deep — for labels on cream

        // Accent — coral is the action color, honey is the warmth
        public static let accentCoral = Color(hex: "D9694B")
        public static let accentCoralDeep = Color(hex: "B14F33")
        public static let accentAmber = Color(hex: "C99327")    // honey
        public static let accentSky = Color(hex: "6F94A6")      // for water/sky icons
        public static let brandGold = accentAmber               // legacy alias

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
        public static let card: CGFloat = 16        // was 14
        public static let icon: CGFloat = 10
        public static let button: CGFloat = 14
        public static let pill: CGFloat = 100
        public static let sheet: CGFloat = 20
        public static let statCard: CGFloat = 14
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let screenPadding: CGFloat = 20    // was 16 — more breathing room
        public static let cardPadding: CGFloat = 16      // was 14
        public static let sectionGap: CGFloat = 24       // was 20
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

    /// Custom font helpers with system fallbacks. Fraunces is the display serif,
    /// Manrope is the humanist sans for UI/body. If the custom fonts fail to
    /// register, the helpers fall back to SF Pro Rounded / SF Pro respectively.
    public enum Fonts {
        /// Returns true if Fraunces is registered and ready to use.
        public static var displayAvailable: Bool {
            #if canImport(UIKit)
            UIFont(name: "Fraunces-Regular", size: 14) != nil
                || UIFont(name: "Fraunces", size: 14) != nil
            #else
            false
            #endif
        }

        /// Returns true if Manrope is registered and ready to use.
        public static var bodyAvailable: Bool {
            #if canImport(UIKit)
            UIFont(name: "Manrope-Regular", size: 14) != nil
                || UIFont(name: "Manrope", size: 14) != nil
            #else
            false
            #endif
        }

        /// Display serif (Fraunces). Falls back to SF Pro Rounded.
        public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            if displayAvailable {
                let name: String
                switch weight {
                case .bold, .heavy, .black: name = "Fraunces-Bold"
                case .semibold: name = "Fraunces-SemiBold"
                case .medium: name = "Fraunces-Medium"
                default: name = "Fraunces-Regular"
                }
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .serif)
        }

        /// Italic display (Fraunces italic). Used for accent words in headlines.
        public static func displayItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            if displayAvailable {
                return .custom("Fraunces-Italic", size: size)
            }
            return .system(size: size, weight: weight, design: .serif).italic()
        }

        /// UI / body font (Manrope). Falls back to SF Pro.
        public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            if bodyAvailable {
                let name: String
                switch weight {
                case .bold, .heavy, .black: name = "Manrope-Bold"
                case .semibold: name = "Manrope-SemiBold"
                case .medium: name = "Manrope-Medium"
                default: name = "Manrope-Regular"
                }
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .default)
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
```

### File: `GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift`

**Targeted edits:**

1. **Replace `GlassCardModifier` with `PaperCardModifier`** (drop the blur, add a soft warm shadow):

```swift
struct PaperCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.cardSurface)
                    .shadow(
                        color: Color(red: 0.12, green: 0.16, blue: 0.13, opacity: 0.06),
                        radius: 1,
                        y: 1
                    )
                    .shadow(
                        color: Color(red: 0.12, green: 0.16, blue: 0.13, opacity: 0.18),
                        radius: 24,
                        y: 12
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
    }
}

extension View {
    /// Apply paper card surface treatment (replaces glassCard).
    func paperCard() -> some View { modifier(PaperCardModifier()) }

    /// Backwards compatibility — old call sites can keep using glassCard().
    /// Will route to the new paperCard treatment.
    func glassCard() -> some View { modifier(PaperCardModifier()) }
}
```

> Keeping `glassCard()` as an alias means existing call sites compile without edits. You can grep-and-rename later if you want.

2. **Replace `HeroBackgroundModifier`** to drop dark + glow and use cream paper:

```swift
struct HeroBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            CultivationTheme.Gradients.hero
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.04))
                        .frame(width: 220, height: 220)
                        .blur(radius: 60)
                        .offset(x: 80, y: -40)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.05))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: -60, y: 40)
                }
        }
    }
}
```

3. **Update `GradientButtonStyle`** to use Manrope font + moss CTA:

```swift
struct GradientButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CultivationTheme.Fonts.body(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(
                        isDisabled
                            ? AnyShapeStyle(CultivationTheme.Colors.textTertiary)
                            : AnyShapeStyle(CultivationTheme.Colors.brandForest)
                    )
                    .shadow(
                        color: isDisabled ? .clear : CultivationTheme.Colors.brandForest.opacity(0.30),
                        radius: 12,
                        y: 6
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}
```

4. **Add a new `CoralButtonStyle`** for the Share-to-Club action:

```swift
struct CoralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CultivationTheme.Fonts.body(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(CultivationTheme.Colors.accentCoral)
                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.35), radius: 12, y: 6)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}
```

5. **Add `SmartTag`** view (the `✦` sage chip):

```swift
struct SmartTag: View {
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("✦")
                .font(CultivationTheme.Fonts.body(9, weight: .bold))
            Text(label.uppercased())
                .font(CultivationTheme.Fonts.body(9, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(CultivationTheme.Colors.smartTagForeground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(CultivationTheme.Colors.smartTagBackground)
        )
        .accessibilityLabel("Smart enrichment: \(label)")
    }
}
```

6. **Update `IconBubble`** to use the new color helpers (no structural change, but verify the `.opacity(0.12)` reads well on cream — bump to `0.16` if it's too soft).

7. **Update `GlassPill`** to use coral active state on cream:

```swift
struct GlassPill: View {
    let label: String
    var isSelected: Bool = false
    var accessibilityID: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(CultivationTheme.Fonts.body(12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : CultivationTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(
                        isSelected
                            ? CultivationTheme.Colors.brandForest
                            : CultivationTheme.Colors.cardSurface
                    )
                }
                .overlay {
                    Capsule().stroke(
                        isSelected
                            ? Color.clear
                            : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(.plain)
        .animation(CultivationTheme.Animation.selection, value: isSelected)
        .accessibilityIdentifier(accessibilityID)
    }
}
```

8. **Update `QuickStatCard`** — drop `.ultraThinMaterial` (no glass on cream):

```swift
struct QuickStatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(CultivationTheme.Fonts.display(24, weight: .semibold))
                .foregroundStyle(color)

            Text(label)
                .font(CultivationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .fill(CultivationTheme.Colors.cardSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .stroke(color.opacity(0.20), lineWidth: 1)
        }
    }
}
```

**Phase 1 checkpoint:** `cd GrowWisePackage && swift build`. There should be no errors at this point — every public API stayed the same, you only changed values + added new helpers.

---

## Phase 2 — Font registration

### Step A — download font files

Fetch the variable-font `.ttf` files for Fraunces and Manrope (both SIL Open Font License, free):

- Fraunces: https://fonts.google.com/specimen/Fraunces → "Get font" → Download family
- Manrope: https://fonts.google.com/specimen/Manrope → "Get font" → Download family

You need at minimum:

```
Fraunces-Regular.ttf
Fraunces-Medium.ttf
Fraunces-SemiBold.ttf
Fraunces-Bold.ttf
Fraunces-Italic.ttf
Manrope-Regular.ttf
Manrope-Medium.ttf
Manrope-SemiBold.ttf
Manrope-Bold.ttf
```

(If you prefer the variable fonts, use `Fraunces[opsz,SOFT,WONK,wght].ttf` and `Manrope[wght].ttf` — the helper code already tries both `Fraunces-Regular` and `Fraunces` as the PostScript name.)

### Step B — drop them in the SPM resources folder

```bash
mkdir -p GrowWisePackage/Sources/GrowWiseFeature/Resources/Fonts
# move the .ttf files into that folder
```

`Package.swift` already has `resources: [.process("Resources")]` for the `GrowWiseFeature` target, so the font files will be picked up automatically.

### Step C — register in `GrowWise/Info.plist`

Add the `UIAppFonts` array:

```xml
<key>UIAppFonts</key>
<array>
    <string>Fraunces-Regular.ttf</string>
    <string>Fraunces-Medium.ttf</string>
    <string>Fraunces-SemiBold.ttf</string>
    <string>Fraunces-Bold.ttf</string>
    <string>Fraunces-Italic.ttf</string>
    <string>Manrope-Regular.ttf</string>
    <string>Manrope-Medium.ttf</string>
    <string>Manrope-SemiBold.ttf</string>
    <string>Manrope-Bold.ttf</string>
</array>
```

> **Important:** SPM-bundled resources are NOT registered automatically by `Info.plist`'s `UIAppFonts` because the bundle is the package bundle, not the main bundle. You'll need a small bootstrap.

### Step D — register fonts on app launch

Add this file:

**`GrowWisePackage/Sources/GrowWiseFeature/Design/FontRegistration.swift`**:

```swift
import CoreText
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.growwise", category: "FontRegistration")

/// Registers custom .ttf font files bundled in the GrowWiseFeature SPM resource bundle.
///
/// Call once at app launch (from `MainAppView.init`) before any view that uses `CultivationTheme.Fonts` is constructed.
public enum FontRegistration {
    private static var hasRun = false

    public static func registerFonts() {
        guard !hasRun else { return }
        hasRun = true

        let bundle = Bundle.module
        let fontFiles = [
            "Fraunces-Regular", "Fraunces-Medium", "Fraunces-SemiBold",
            "Fraunces-Bold", "Fraunces-Italic",
            "Manrope-Regular", "Manrope-Medium", "Manrope-SemiBold",
            "Manrope-Bold",
        ]

        for fontName in fontFiles {
            guard let url = bundle.url(forResource: fontName, withExtension: "ttf") else {
                logger.warning("Font missing from bundle: \(fontName, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                if let cfError = error?.takeRetainedValue() {
                    let nsError = cfError as Error
                    // .alreadyRegistered is fine — happens on hot reload
                    let isAlreadyRegistered = (nsError as NSError).code == 105
                    if !isAlreadyRegistered {
                        logger.error("Failed to register font \(fontName, privacy: .public): \(nsError.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }
}
```

Then in `Main/MainAppView.swift`, add to `init()`:

```swift
public init() {
    FontRegistration.registerFonts()
    // … existing init body
}
```

The fallback paths in `CultivationTheme.Fonts` mean if registration fails for any reason, you get SF Pro Rounded / SF Pro instead of crashing.

**Phase 2 checkpoint:** Boot the app. Anything that uses `CultivationTheme.Typography.title("…")` should render in Fraunces. Verify in the simulator with the debugger or a screenshot.

---

## Phase 3 — Tab restructure (5 → 4)

### File: `Main/MainAppView.swift`

**Replace `mainTabView` with:**

```swift
private var mainTabView: some View {
    TabView(selection: $selectedTab) {
        HomeView()
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(TabSelection.home)
            .accessibilityIdentifier("tab_home")

        GardenView()
            .tabItem { Label("Garden", systemImage: "leaf.fill") }
            .tag(TabSelection.garden)
            .accessibilityIdentifier("tab_garden")

        NavigationStack {
            GardenClubFeedView()
        }
        .tabItem { Label("Club", systemImage: "sparkles") }
        .tag(TabSelection.club)
        .accessibilityIdentifier("tab_club")

        ProfileView()
            .tabItem { Label("Me", systemImage: "person.fill") }
            .tag(TabSelection.profile)
            .accessibilityIdentifier("tab_profile")
    }
    .tint(CultivationTheme.Colors.accentCoral)
}
```

**Replace `TabSelection` enum:**

```swift
public enum TabSelection: String, CaseIterable {
    case home
    case garden
    case club
    case profile
}
```

### File: `Views/ProfileView.swift`

Remove the `RemindersListView` reference at line 87. Replace the `navigationDestination(isPresented: $showNotifications)` block with a simple `EmptyView()` placeholder, OR remove the `showNotifications` state and the row that triggers it. Reminders are managed inline on Home + per-plant going forward.

```bash
# Find the current state and decide:
grep -n "showNotifications" GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift
```

**Phase 3 checkpoint:** `swift build` — should compile because `GardenClubFeedView` is the next phase, so until then **stub it**:

```swift
// GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift
import SwiftUI

public struct GardenClubFeedView: View {
    public init() {}
    public var body: some View {
        Text("Club feed — coming next")
    }
}
```

---

## Phase 4 — Delete Reminders + Journal

### Delete files

```bash
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/RemindersListView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryRow.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift
git rm GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/AddJournalEntryView.swift
```

> **Keep:** `GrowWisePackage/Sources/GrowWiseModels/JournalEntry.swift` — the model is still attached to plants and is what the new Plant Detail photo strip renders. Also keep `Views/AddReminderView.swift` (still reachable from per-plant detail) and `Views/PlantReminderDetailView.swift`.

### Find leftover references

```bash
grep -rn "JournalView\|RemindersListView\|JournalEntryRow\|JournalEntryDetailView\|AddJournalEntryView" \
    GrowWisePackage/Sources/ GrowWiseUITests/ --include="*.swift"
```

For each match, either delete or replace with the inline equivalent (e.g., a "View on Plant Detail" navigation push if it was a "View entry" link).

### Test files

```bash
grep -rn "JournalView\|RemindersListView" GrowWisePackage/Tests/ --include="*.swift"
```

Delete tests that exercised those views as routes. Tests on `JournalEntry` model behavior stay.

**Phase 4 checkpoint:** `swift build` — anything that referenced the deleted views should have a clear compile error pointing you to the next thing to fix.

---

## Phase 5 — Garden Club feed (new)

### File: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`

This is a new file — full content below:

```swift
import GrowWiseModels
import GrowWiseServices
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.growwise", category: "GardenClubFeedView")

/// Tab-3 entry point for Garden Club. Top-of-screen share prompt, segmented
/// feed (Club / Nearby / Following), and post cards. The "smart match" card
/// surfaces when nearby growers are tracking the same plant species as the user.
///
/// See ADR-019 and the v2 mockup at docs/mockups/cultivation-simplified-wireflow.html.
public struct GardenClubFeedView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService

    @State private var selectedSegment: FeedSegment = .club
    @State private var posts: [ClubActivity] = []
    @State private var smartMatch: SmartMatchSuggestion?
    @State private var clubName: String = "Garden Club"
    @State private var memberCount: Int = 0
    @State private var userInitial: String = "?"
    @State private var isPresentingComposer = false

    public init() {}

    enum FeedSegment: String, CaseIterable, Identifiable {
        case club = "Club feed"
        case nearby = "Nearby"
        case following = "Following"
        var id: String { rawValue }
    }

    struct SmartMatchSuggestion {
        let count: Int
        let zone: String
        let plantName: String
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    header
                    sharePrompt
                    segmentControl
                    feed
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
        .sheet(isPresented: $isPresentingComposer) {
            // Share composer — wire up to existing photo + post creation flow
            // For first cut, use a placeholder; replace with real composer once
            // the existing GardenClub PublishGardenSheet pattern is adapted.
            Text("Share composer placeholder")
                .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your club")
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text(clubName)
                    .font(CultivationTheme.Fonts.display(28, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(memberCount)")
                    .font(CultivationTheme.Fonts.display(20, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("members")
                    .font(CultivationTheme.Fonts.body(11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Share prompt (coral CTA)

    private var sharePrompt: some View {
        Button { isPresentingComposer = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(userInitial)
                            .font(CultivationTheme.Fonts.display(14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share what's growing")
                        .font(CultivationTheme.Fonts.body(13))
                        .foregroundStyle(.white)
                    Text("Tap to add a photo")
                        .font(CultivationTheme.Fonts.body(11))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.accentCoral)
                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.35), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("club_share_prompt")
        .accessibilityLabel("Share what's growing")
    }

    // MARK: - Segmented control

    private var segmentControl: some View {
        HStack(spacing: 18) {
            ForEach(FeedSegment.allCases) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    VStack(spacing: 6) {
                        Text(segment.rawValue)
                            .font(CultivationTheme.Fonts.body(13, weight: selectedSegment == segment ? .semibold : .medium))
                            .foregroundStyle(
                                selectedSegment == segment
                                    ? CultivationTheme.Colors.textPrimary
                                    : CultivationTheme.Colors.textTertiary
                            )
                        Rectangle()
                            .fill(selectedSegment == segment ? CultivationTheme.Colors.accentCoral : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("club_segment_\(segment.rawValue.lowercased())")
            }
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CultivationTheme.Colors.divider)
                .frame(height: 1)
        }
    }

    // MARK: - Feed body

    @ViewBuilder
    private var feed: some View {
        if posts.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    if index == 1, let match = smartMatch {
                        smartMatchCard(match)
                    }
                    PostCard(post: post)
                }
                if posts.count < 2, let match = smartMatch {
                    smartMatchCard(match)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No posts yet")
                .font(CultivationTheme.Fonts.display(18, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Be the first to share what's growing.")
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func smartMatchCard(_ match: SmartMatchSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("✦")
                Text("Smart match · \(match.count) nearby growers")
            }
            .font(CultivationTheme.Fonts.body(10, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(CultivationTheme.Colors.smartTagForeground)

            (Text("\(match.count) people in ")
                + Text("your zone").bold()
                + Text(" are growing \(match.plantName) too. Want to see their tips?"))
                .font(CultivationTheme.Fonts.display(15).italic())
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(nil)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
        )
        .accessibilityIdentifier("club_smart_match")
    }

    // MARK: - Data load

    @MainActor
    private func load() async {
        // Resolve the user's primary club, member count, and recent activity.
        // Wire to your real services here. The existing ForumService and
        // GardenClub services hold the relevant fetches; consult ClubListView
        // for the patterns currently in use.

        let user = dataService.getCurrentUser()
        userInitial = String(user?.displayName?.prefix(1) ?? "?").uppercased()

        // TODO(GW-redesign-v2): hydrate from a real ClubService.
        // For now, populate from whatever ForumService / DataService surfaces.
        posts = []
        clubName = "Garden Club"
        memberCount = 0

        // Smart match — derive from the user's plants vs nearby growers.
        // Stub: when location + zone are available, populate.
        if let zone = locationService.currentHardinessZone {
            smartMatch = SmartMatchSuggestion(
                count: 3, zone: zone, plantName: "Cherokee Purple"
            )
        }
    }
}

// MARK: - Post card

private struct PostCard: View {
    let post: ClubActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(
                        colors: [CultivationTheme.Colors.brandMint, CultivationTheme.Colors.brandLeaf],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(initials(of: post.authorDisplayName ?? "?"))
                            .font(CultivationTheme.Fonts.display(13, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.authorDisplayName ?? "Member")
                        .font(CultivationTheme.Fonts.body(13, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    HStack(spacing: 5) {
                        if let zone = post.zoneTag {
                            Text("Zone \(zone)")
                                .foregroundStyle(CultivationTheme.Colors.smartTagForeground)
                                .fontWeight(.bold)
                        }
                        if let when = post.relativeTimeLabel {
                            Text("· \(when)")
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                    .font(CultivationTheme.Fonts.body(10))
                }
                Spacer()
            }

            if let caption = post.caption {
                Text(caption)
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(nil)
            }

            // Photo placeholder — wire to PhotoService asset URL when available
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 120)

            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
                Label("Share", systemImage: "arrow.up.right")
            }
            .font(CultivationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(14)
        .paperCard()
    }

    private func initials(of name: String) -> String {
        String(name.prefix(1)).uppercased()
    }
}
```

> **Adapt to your model:** the code above assumes `ClubActivity` has `authorDisplayName`, `zoneTag`, `relativeTimeLabel`, `caption`, `likeCount`, `commentCount`. Check `GrowWisePackage/Sources/GrowWiseModels/ClubActivity.swift` for the actual property names and adjust. If those fields don't exist yet, add a `ClubActivityViewData` struct in the view file as a presentation-only adapter (this is allowed under MV — view-local presentation types are fine, just don't make a separate `class ViewModel`).

> **LocationService:** confirm `currentHardinessZone: String?` is the right property name. Adjust to whatever the service exposes.

**Phase 5 checkpoint:** `swift build` clean. Tab into the app, you should see Club tab with the share-prompt and a hardcoded smart-match card.

---

## Phases 6–8 — Screen rewrites (skeletons)

These three screens are too large for full source listings here. The patterns to follow are concrete:

### Phase 6 — `Views/HomeView.swift`

Structure:

```swift
public struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(ReminderService.self) private var reminderService
    @State private var viewModel = HomeViewModel()
    @State private var weatherSummary: WeatherSummary?
    @State private var latestClubPost: ClubActivity?

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    GreetingBlock(name: viewModel.userName, weather: weatherSummary)
                    TodaysCareCard(
                        priority: viewModel.overdueReminders.first,
                        upcoming: Array(viewModel.dueTodayReminders.prefix(3)),
                        onComplete: { /* viewModel.complete($0) */ },
                        onMarkAllDone: { /* viewModel.markAllDone() */ }
                    )
                    if let post = latestClubPost {
                        ClubActivityCard(post: post)
                    }
                    if let tip = SeasonalTipResolver.tip(for: locationService.currentHardinessZone) {
                        SeasonalTipCard(tip: tip)
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .task {
            await viewModel.load(dataService: dataService)
            weatherSummary = await locationService.fetchWeatherSummary()
            // latestClubPost = await clubService.latestPost()
        }
    }
}
```

Component shapes (extract these as private structs in HomeView.swift, or move into Views/Home/ if they grow):

- **`GreetingBlock`** — section label "Saturday · April 18", Fraunces "Good morning, **Blake.**" with the name italic + coral, weather pill below
- **`TodaysCareCard`** — card with header "Today's care · 3 things", priority row with coral check, two outline rows, "Mark all done" moss button
- **`ClubActivityCard`** — coral/honey gradient banner with "Your Club" tag + club name, body with avatar + post + photo + ♥/💬/↗ row
- **`SeasonalTipCard`** — paperDeep card, dashed sage border, "✦ Seasonal tip · Zone 9b" label, italic Fraunces body

Update `Views/Home/HomeViewModel.swift` to add a `loadLatestClubPost()` step. Keep all existing logic intact. The view model already does the right thing for tasks — you only need to surface `overdueReminders.first` differently in the new layout.

### Phase 7 — `Views/GardenView.swift`

Structure:

```swift
public struct GardenView: View {
    @Environment(DataService.self) private var dataService
    @State private var viewModel = GardenViewModel()
    @State private var selectedFilter: GardenFilter = .all

    enum GardenFilter: String, CaseIterable {
        case all = "All"
        case needsCare = "Needs care"
        case blooming = "Blooming"
        case edible = "Edible"
        case herbs = "Herbs"
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GardenHeader(name: viewModel.gardenName, summary: viewModel.summary)
                    FilterChipBar(filters: GardenFilter.allCases, selection: $selectedFilter)
                    ForEach(viewModel.filtered(by: selectedFilter)) { bedGroup in
                        BedSection(group: bedGroup)
                    }
                    AddBedButton()
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .task { await viewModel.load(dataService: dataService) }
    }
}
```

Update `Design/GardenComponents.swift`:

- **`PlantRow`** → `PlantCard` — 56pt thumbnail (LinearGradient placeholder), Fraunces plant name, italic latin, status dot + status text, "Next care: ___" line. Drop the row chevron — taps push detail.
- **`BedGroupHeader`** → keep but restyle: 28pt icon bubble + Fraunces 15pt name + meta plant count
- **`TaskRow`** — used on Home, restyle for cream + new icon bubbles
- **`CompanionTipCard`** — restyle to match the seasonal tip card on Home (paperDeep + dashed sage)

### Phase 8 — `Views/MyGardenPlantDetailView.swift`

Structure (follow the mockup closely):

```swift
public struct MyGardenPlantDetailView: View {
    let plant: Plant
    @Environment(DataService.self) private var dataService
    @Environment(PhotoService.self) private var photoService
    @Environment(PlantCareAdviceService.self) private var adviceService
    @State private var advice: PlantCareAdvice?
    @State private var entries: [JournalEntry] = []
    @State private var isLogCarePresented = false
    @State private var isShareSheetPresented = false

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HeroPhoto(plant: plant)
                    TitleBlock(plant: plant) // includes SmartTag("Auto-identified")
                    StatRow(plant: plant)    // sun / water / soil
                    HStack(spacing: 8) {
                        Button("Log care") { isLogCarePresented = true }
                            .buttonStyle(GradientButtonStyle())
                        Button("Get advice") { /* expand advice card */ }
                            .buttonStyle(SecondaryButtonStyle()) // add this if needed
                    }
                    Button("Share to Bayou Growers") { isShareSheetPresented = true }
                        .buttonStyle(CoralButtonStyle())
                    AdviceCard(advice: advice)
                    PhotoJournalStrip(entries: entries, plant: plant)
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(false)
        .task {
            advice = await adviceService.fetchAdvice(for: plant)
            entries = await dataService.fetchJournalEntries(for: plant)
        }
    }
}
```

Where each block lives in the same file as private structs — keeps the rewrite contained. The share sheet should reuse the existing `Community/PublishGardenSheet.swift` pattern, adapted for a single-plant share rather than a whole garden.

> **Photo journal strip:** dump the existing `JournalEntryRow` styling and use a horizontal `ScrollView(.horizontal)` of 60×60 thumbnails with a date overlay + a dashed `+` cell at the end. Tapping a thumbnail can either expand into a full-screen viewer (preferred) or push a `JournalEntryDetailView` if you keep the model — but you're deleting that view, so the inline expansion is cleaner.

---

## Phase 9 — Test fixes

After phases 1–8 build cleanly, run:

```bash
cd GrowWisePackage && swift test 2>&1 | tail -30
```

Expected categories of failures:

1. **Tests that import deleted views** — `JournalViewTests`, `RemindersListViewTests` (if present). Delete them.
2. **Snapshot tests on the redesigned screens** — re-record under the new theme.
3. **`MainAppView` tab tests** — update tab count from 5 to 4 and selectors from `tab_journal` / `tab_reminders` to `tab_club`.
4. **`HomeViewModel` tests** — should still pass; behavior is unchanged.

Document any deliberately deleted tests in the commit message: "Removed N tests for tabs that no longer exist (see ADR-019)."

---

## Phase 10 — Lint, format, code-review

```bash
swiftlint lint --strict --config .swiftlint.yml
swiftformat --lint --config .swiftformat GrowWisePackage/Sources GrowWise

# Then invoke the code-review skill (see .claude/skills/code-review/SKILL.md)
```

Code-review focus areas for this branch:

- **MV compliance** — no new ViewModels except the existing `HomeViewModel` and `GardenViewModel` (allowed per ADR-015)
- **Swift 6 concurrency** — services accessed via `@Environment` are MainActor; `Task<Void, Never> { }` if any new ones in Button actions
- **`try?` audit** — no silent error swallowing in the new screens
- **Accessibility** — every interactive element has `.accessibilityIdentifier`
- **No `print()`** — `os.Logger` only

---

## Verification checklist

- [ ] `swift build` clean on the package
- [ ] `xcodebuild` clean on the app via SSH
- [ ] `swift test` passes (with documented test deletions)
- [ ] `swiftlint --strict` clean
- [ ] `swiftformat --lint` clean
- [ ] App launches without crashing
- [ ] All four tabs render
- [ ] Custom fonts visible in the simulator (verify with a screenshot — Fraunces should look obviously serif on plant names)
- [ ] Plant Detail "Share to [Club]" button is reachable and presents a share composer
- [ ] Home shows latest club post when one exists
- [ ] No leftover references to `JournalView`, `RemindersListView`, `tab_journal`, `tab_reminders`
- [ ] ADR-019 committed
- [ ] Spec committed at `docs/superpowers/specs/2026-04-20-simplified-ui-v2-design.md`

---

## Things to leave alone

- `JournalEntry` SwiftData model — still used, just rendered differently
- `AddReminderView`, `PlantReminderDetailView` — still reachable from per-plant flows
- `Views/Community/*` — keep accessible from "Me" but no longer surfaced via tab; do not delete
- `Views/GardenClub/ClubListView.swift` and friends — still useful as the "manage my clubs" screen accessible from the new feed view's `…` menu

---

## Open questions for the implementer

1. **Club source of truth.** The current codebase has both `Views/Community/` (forum-style) and `Views/GardenClub/` (clubs). The new `GardenClubFeedView` assumes Garden Club is canonical. Confirm with Blake whether to fold Community in or leave it separately accessible.
2. **Smart match data path.** The mockup shows "3 people in your zone are growing X." This needs a real query. Is there a service that can return "users with the same plant species in the same hardiness zone", or does that need to be added to `CloudSyncService` / a new `ClubMatchService`?
3. **Photo strip vs. full journal.** If you delete `JournalEntryDetailView`, the photo-strip thumbnails need an inline full-screen viewer. Acceptable, but worth confirming before deleting.
4. **Mark all done semantics.** Spec says batch by care type. Implementer needs to decide whether to batch silently or show a confirmation ("Mark 3 watering tasks done?").
