# Full UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reimagine the entire Cultivation app UI: 4-tab garden-centric navigation, Clean Minimal + Premium design language, glass-morphism cards, Apple system colors, grouped plant list as the hero screen.

**Architecture:** Build a shared component library and theme system first (Phase 1), restructure navigation to 4 tabs (Phase 2), then build each screen from Garden outward. All new components are pure SwiftUI using `@Observable` — no `ObservableObject` or `@Published`. Tests run on mac-mini via SSH.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, `@Observable`, iOS 17+, SF Pro Rounded (`.fontDesign(.rounded)`)

**Spec:** `docs/superpowers/specs/2026-03-09-full-ui-redesign-design.md`

**Test command (all tests):**
```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO 2>&1 | tail -20"
```

---

## Chunk 1: Design Foundation (Phase 1)

### Task 1: CultivationTheme — Design Tokens

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Extensions/Color+Theme.swift`

The theme file is the single source of truth for every color, spacing, radius, and animation value used across the redesigned app. It must NOT be spread across multiple files.

- [ ] **Create `CultivationTheme.swift`** with the following exact content:

```swift
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
        public static let cardBorder = Color(light: Color(black: 0, opacity: 0.07), dark: Color(white: 1, opacity: 0.08))

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

        // Hero glow
        public static let heroGlow = Color(hex: "4CAF50").opacity(0.08)

        // Interactive
        public static let divider = Color(light: Color(black: 0, opacity: 0.08), dark: Color(white: 1, opacity: 0.06))
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
        public static let pill: CGFloat = 100  // use Capsule shape
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
        public static func sectionLabel(_ text: String) -> Text {
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

    /// Light/dark adaptive color — works on both platforms
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        import UIKit
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        self = light
        #endif
    }
}
```

- [ ] **Update `Color+Theme.swift`** to add hex init guard (the new `CultivationTheme.swift` provides `init(hex:)` so we need to avoid duplicate — remove any existing `init(hex:)` if present, keep the existing adaptive colors for backward compatibility during migration):

```swift
// Keep existing adaptive colors for files not yet migrated.
// New code should use CultivationTheme.Colors.* directly.
// init(hex:) and init(light:dark:) are now defined in CultivationTheme.swift
```

- [ ] **Run build to verify no compile errors:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded|FAILED'"
```

Expected: `Build succeeded`

- [ ] **Commit:**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift
git add GrowWisePackage/Sources/GrowWiseFeature/Extensions/Color+Theme.swift
git commit -m "feat: add CultivationTheme design tokens"
```

---

### Task 2: ViewModifiers — Glass Card, Section Label, Hero Header

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift`

These modifiers are the building blocks applied throughout the app. Define them once, use everywhere.

- [ ] **Create `ViewModifiers.swift`:**

```swift
import SwiftUI

// MARK: - Glass Card Modifier

/// Applies the glass-morphism card surface treatment.
/// Dark: translucent surface + blur + fine border
/// Light: white + soft shadow + fine border
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.cardSurface)
                    .background(
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .fill(.ultraThinMaterial)
                            .opacity(colorScheme == .dark ? 1 : 0)
                    )
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
                        radius: 8,
                        y: 2
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
    /// Apply glass card surface treatment.
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Section Label Modifier

struct SectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(CultivationTheme.Colors.sectionLabel)
    }
}

extension View {
    func sectionLabelStyle() -> some View {
        modifier(SectionLabelModifier())
    }
}

// MARK: - Hero Header Background

/// Dark background with subtle green glow orb for Home and Garden tab headers.
struct HeroBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topTrailing) {
                    CultivationTheme.Colors.background

                    // Subtle green glow orb
                    Circle()
                        .fill(CultivationTheme.Colors.heroGlow)
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: 60, y: -40)
                }
            }
    }
}

extension View {
    func heroBackground() -> some View {
        modifier(HeroBackgroundModifier())
    }
}

// MARK: - Gradient CTA Button Style

struct GradientButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(
                        isDisabled
                            ? AnyShapeStyle(CultivationTheme.Colors.textTertiary)
                            : AnyShapeStyle(CultivationTheme.Gradients.cta)
                    )
                    .shadow(
                        color: isDisabled ? .clear : CultivationTheme.Colors.brandForest.opacity(0.30),
                        radius: 8,
                        y: 3
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}

// MARK: - Icon Bubble

/// A rounded-rect container for SF Symbols with tinted background.
struct IconBubble: View {
    let systemName: String
    let color: Color
    var size: CGFloat = CultivationTheme.Spacing.iconSize
    var iconSize: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Status Dot

/// Small colored dot indicating plant health status.
struct StatusDot: View {
    let status: PlantHealthStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

enum PlantHealthStatus {
    case healthy, warning, alert

    var color: Color {
        switch self {
        case .healthy: CultivationTheme.Colors.statusHealthy
        case .warning: CultivationTheme.Colors.statusWarning
        case .alert: CultivationTheme.Colors.statusAlert
        }
    }
}

// MARK: - Glass Pill

/// Filter chip / garden switcher pill with glass treatment.
struct GlassPill: View {
    let label: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(
                    isSelected
                        ? CultivationTheme.Colors.brandLeaf
                        : CultivationTheme.Colors.textSecondary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf.opacity(0.15)
                                : CultivationTheme.Colors.cardSurface
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected
                                ? CultivationTheme.Colors.brandLeaf.opacity(0.35)
                                : CultivationTheme.Colors.cardBorder,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .animation(CultivationTheme.Animation.selection, value: isSelected)
    }
}

// MARK: - Quick Stat Card

/// Summary stat card used in hero sections (Overdue / Due Today / All Good).
struct QuickStatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .fill(color.opacity(0.07))
                .background(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                        .fill(.ultraThinMaterial)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .stroke(color.opacity(0.15), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard))
    }
}
```

- [ ] **Run build:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded|FAILED'"
```

- [ ] **Commit:**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift
git commit -m "feat: add glass card, icon bubble, status dot, gradient button, stat card components"
```

---

### Task 3: Garden-Domain Shared Components

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift`

These are higher-level components specific to garden/plant display — built on top of Task 2's primitives.

- [ ] **Create `GardenComponents.swift`:**

```swift
import GrowWiseModels
import SwiftUI

// MARK: - Plant Row

/// A single plant row in the Garden grouped list.
/// Shows icon bubble + name + care info + status dot.
struct PlantRow: View {
    let plant: Plant
    var isUrgent: Bool = false
    var onQuickAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Icon bubble — tinted by health status
            IconBubble(
                systemName: plant.plantType.iconName,
                color: statusColor,
                size: CultivationTheme.Spacing.iconSize,
                iconSize: 20
            )

            // Plant info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plant.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    if isUrgent {
                        Text("OVERDUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CultivationTheme.Colors.statusAlert)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(CultivationTheme.Colors.statusAlert.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(plant.careSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            Spacer()

            // Quick action button (only for urgent) or status dot
            if isUrgent, let action = onQuickAction {
                Button(action: action) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(CultivationTheme.Gradients.ctaVertical)
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            } else {
                StatusDot(status: plant.healthStatus)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .overlay {
            if isUrgent {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(CultivationTheme.Colors.statusAlert.opacity(0.15), lineWidth: 1)
            }
        }
        .background {
            if isUrgent {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.statusAlert.opacity(0.04))
            }
        }
    }

    private var statusColor: Color {
        switch plant.healthStatus {
        case .alert: CultivationTheme.Colors.statusAlert
        case .warning: CultivationTheme.Colors.statusWarning
        case .healthy: CultivationTheme.Colors.statusHealthy
        }
    }
}

// MARK: - Bed Group Header

/// Header for a garden bed / container / area group.
struct BedGroupHeader: View {
    let name: String
    let subtitle: String
    let icon: String
    let plantCount: Int
    var onMenu: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            IconBubble(
                systemName: icon,
                color: CultivationTheme.Colors.brandLeaf,
                size: CultivationTheme.Spacing.iconSizeSmall,
                iconSize: 14
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            Spacer()

            Text("\(plantCount) plants")
                .font(.system(size: 11))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            if let menu = onMenu {
                Button(action: menu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bed options")
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
    }
}

// MARK: - Companion Tip

/// Inline contextual companion planting tip shown under a bed group.
struct CompanionTipCard: View {
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            IconBubble(
                systemName: "lightbulb.fill",
                color: CultivationTheme.Colors.brandLeaf,
                size: 32,
                iconSize: 13
            )

            Text(tip)
                .font(.system(size: 12))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.9))
                .lineLimit(2)

            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - Task Row (Home Tab)

/// A care task row for the Home tab — plant name + task description + garden/bed + complete button.
struct TaskRow: View {
    let plantName: String
    let taskDescription: String
    let location: String
    let isUrgent: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: urgentIconName,
                color: statusColor,
                size: 40,
                iconSize: 17
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(taskDescription)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(location)
                    .font(.system(size: 11))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            Spacer()

            Button(action: onComplete) {
                ZStack {
                    if isUrgent {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(CultivationTheme.Gradients.ctaVertical)
                            .frame(width: 36, height: 36)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(CultivationTheme.Colors.cardSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            }
                            .frame(width: 36, height: 36)
                    }

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isUrgent ? .white : CultivationTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .overlay {
            if isUrgent {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(CultivationTheme.Colors.statusAlert.opacity(0.12), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .fill(CultivationTheme.Colors.statusAlert.opacity(0.04))
                    )
            }
        }
    }

    private var urgentIconName: String { isUrgent ? "exclamationmark.circle.fill" : "drop.fill" }
    private var statusColor: Color { isUrgent ? CultivationTheme.Colors.statusAlert : CultivationTheme.Colors.statusWarning }
}

// MARK: - Plant Model Extensions

extension Plant {
    /// Subtitle shown under plant name in list rows.
    var careSubtitle: String {
        // Derived from reminder data; fallback to care description
        "Water in \(daysTillNextWater) day\(daysTillNextWater == 1 ? "" : "s")"
    }

    /// Placeholder — replace with real reminder-based logic in Garden Tab implementation
    var daysTillNextWater: Int { 3 }

    var healthStatus: PlantHealthStatus {
        switch healthCondition {
        case .healthy: .healthy
        case .needsAttention: .warning
        case .critical: .alert
        }
    }
}
```

- [ ] **Note:** `Plant.healthCondition` must exist in `GrowWiseModels`. Verify:

```bash
grep -r "healthCondition\|HealthCondition\|health" GrowWisePackage/Sources/GrowWiseModels --include="*.swift" | grep "var " | head -10
```

Adapt the `healthStatus` extension to match the actual model property name.

- [ ] **Run build:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|Build succeeded|FAILED'"
```

- [ ] **Commit:**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift
git commit -m "feat: add PlantRow, BedGroupHeader, CompanionTip, TaskRow shared components"
```

---

## Chunk 2: Navigation Restructure (Phase 2)

### Task 4: Rewrite MainAppView to 4 Tabs

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift`

The current file has 7 tabs. We restructure to 4. The initialization, service injection, and onboarding redirect logic stays unchanged — only the tab structure changes.

- [ ] **Read the current `MainAppView.swift`** to understand initialization and service injection before touching anything.

- [ ] **Identify the `TabView` block** (the section defining `.tabItem` for each tab). It will look like:

```swift
TabView(selection: $selectedTab) {
    HomeView()
        .tabItem { ... }
        .tag(TabSelection.home)
    // ... 6 more tabs
}
```

- [ ] **Replace the TabView and TabSelection enum** with 4-tab version:

```swift
// New TabSelection enum
public enum TabSelection: String, CaseIterable {
    case home
    case garden
    case journal
    case profile
}

// New TabView body
TabView(selection: $selectedTab) {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(TabSelection.home)
        .accessibilityIdentifier("tab_home")

    GardenView()
        .tabItem {
            Label("Garden", systemImage: "leaf.fill")
        }
        .tag(TabSelection.garden)
        .accessibilityIdentifier("tab_garden")

    JournalView()
        .tabItem {
            Label("Journal", systemImage: "book.fill")
        }
        .tag(TabSelection.journal)
        .accessibilityIdentifier("tab_journal")

    ProfileView()
        .tabItem {
            Label("Profile", systemImage: "person.fill")
        }
        .tag(TabSelection.profile)
        .accessibilityIdentifier("tab_profile")
}
.tint(CultivationTheme.Colors.brandLeaf)
```

- [ ] **Create stub `GardenView`** (the new garden tab — placeholder until Phase 3):

```swift
// GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
import SwiftUI

public struct GardenView: View {
    public init() {}
    public var body: some View {
        NavigationStack {
            Text("Garden — coming in Phase 3")
                .navigationTitle("Garden")
        }
    }
}
```

- [ ] **Run build:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build ... 2>&1 | grep -E 'error:|Build succeeded|FAILED'"
```

- [ ] **Run existing tests to confirm no regressions:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test ... 2>&1 | tail -10"
```

- [ ] **Commit:**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
git commit -m "feat: restructure navigation to 4 tabs (Home/Garden/Journal/Profile)"
```

---

## Chunk 3: Garden Tab — Hero Screen (Phase 3)

### Task 5: Garden Tab — Data Layer Prep

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenViewModel.swift`

- [ ] **Read existing `MyGardenView.swift`** to understand how plant data is currently loaded (DataService calls, garden selection logic).

- [ ] **Create `GardenViewModel.swift`** — `@Observable` class that loads plants grouped by garden bed:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// View model for the Garden tab grouped plant list.
@Observable
final class GardenViewModel {
    var selectedGarden: Garden?
    var gardens: [Garden] = []
    var plantsByBed: [(bed: GardenBed?, plants: [Plant])] = []
    var isLoading = false
    var error: Error?

    func load(dataService: DataService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            gardens = try await dataService.getAllGardens()
            if selectedGarden == nil { selectedGarden = gardens.first }
            if let garden = selectedGarden {
                plantsByBed = try await dataService.plantsGroupedByBed(gardenID: garden.id)
            }
        } catch {
            self.error = error
        }
    }

    func selectGarden(_ garden: Garden, dataService: DataService) async {
        selectedGarden = garden
        await load(dataService: dataService)
    }
}
```

- [ ] **Check if `DataService` has `plantsGroupedByBed` or equivalent.** Search:

```bash
grep -r "plantsGrouped\|groupedBy\|GardenBed" GrowWisePackage/Sources/GrowWiseServices --include="*.swift" | head -10
```

If not, add a helper to `DataService` or derive the grouping in the ViewModel from `getAllPlants(in:)`.

- [ ] **Run build. Commit:**

```bash
git commit -m "feat: add GardenViewModel for grouped plant list"
```

---

### Task 6: Garden Tab — Main View

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenHeroHeader.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenBedSection.swift`

- [ ] **Create `GardenHeroHeader.swift`:**

```swift
import GrowWiseModels
import SwiftUI

struct GardenHeroHeader: View {
    let gardens: [Garden]
    let selectedGarden: Garden?
    let stats: (plants: Int, needWater: Int, alerts: Int)
    let onSelectGarden: (Garden) -> Void
    let onAdd: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Garden")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .tracking(0.5)

                    Text(selectedGarden?.name ?? "Garden")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                }

                Spacer()

                // Search + Add buttons
                HStack(spacing: 8) {
                    Button(action: onSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(CultivationTheme.Colors.cardSurface)
                            .overlay { RoundedRectangle(cornerRadius: 8).stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1) }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search plants")
                    .accessibilityIdentifier("garden_button_search")

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(CultivationTheme.Gradients.ctaVertical)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add plant")
                    .accessibilityIdentifier("garden_button_add")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, 16)

            // Garden switcher pills
            if gardens.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(gardens) { garden in
                            GlassPill(
                                label: garden.name,
                                isSelected: garden.id == selectedGarden?.id
                            ) {
                                onSelectGarden(garden)
                            }
                            .accessibilityIdentifier("garden_pill_\(garden.id)")
                        }
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }
                .padding(.top, 12)
            }

            // Stats strip
            HStack(spacing: 16) {
                statItem(value: stats.plants, label: "plants", color: CultivationTheme.Colors.textPrimary)
                statItem(value: stats.needWater, label: "need water", color: CultivationTheme.Colors.statusWarning)
                statItem(value: stats.alerts, label: "alerts", color: CultivationTheme.Colors.statusAlert)
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .heroBackground()
    }

    private func statItem(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
    }
}
```

- [ ] **Create `GardenBedSection.swift`:**

```swift
import GrowWiseModels
import SwiftUI

struct GardenBedSection: View {
    let bed: GardenBed?
    let plants: [Plant]
    let onTapPlant: (Plant) -> Void
    let onCompleteTask: (Plant) -> Void
    let companionTip: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bed header
            BedGroupHeader(
                name: bed?.name ?? "Unassigned",
                subtitle: bedSubtitle,
                icon: bedIcon,
                plantCount: plants.count
            )

            // Plant rows — urgent first
            VStack(spacing: 6) {
                ForEach(sortedPlants) { plant in
                    PlantRow(
                        plant: plant,
                        isUrgent: plant.healthStatus == .alert,
                        onQuickAction: plant.healthStatus == .alert ? { onCompleteTask(plant) } : nil
                    )
                    .onTapGesture { onTapPlant(plant) }
                    .accessibilityIdentifier("garden_plant_\(plant.id)")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Companion tip (if any)
            if let tip = companionTip {
                CompanionTipCard(tip: tip)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            }
        }
    }

    private var sortedPlants: [Plant] {
        plants.sorted { $0.healthStatus.sortOrder < $1.healthStatus.sortOrder }
    }

    private var bedSubtitle: String {
        bed?.bedDescription ?? "Container"
    }

    private var bedIcon: String {
        bed == nil ? "circle.grid.2x2.fill" : "rectangle.split.3x1.fill"
    }
}

extension PlantHealthStatus {
    var sortOrder: Int {
        switch self {
        case .alert: 0
        case .warning: 1
        case .healthy: 2
        }
    }
}
```

- [ ] **Rewrite `GardenView.swift`** as the real garden tab:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct GardenView: View {
    @Environment(DataService.self) private var dataService
    @State private var viewModel = GardenViewModel()
    @State private var selectedPlant: Plant?
    @State private var showingAddPlant = false
    @State private var showingSearch = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CultivationTheme.Spacing.sectionGap, pinnedViews: []) {
                    // Bed sections
                    ForEach(viewModel.plantsByBed, id: \.bed?.id) { item in
                        GardenBedSection(
                            bed: item.bed,
                            plants: item.plants,
                            onTapPlant: { selectedPlant = $0 },
                            onCompleteTask: { plant in
                                Task { await viewModel.completeCareTask(plant: plant, dataService: dataService) }
                            },
                            companionTip: viewModel.companionTip(for: item.plants)
                        )
                    }

                    // Add bed/area button
                    addBedButton
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                GardenHeroHeader(
                    gardens: viewModel.gardens,
                    selectedGarden: viewModel.selectedGarden,
                    stats: viewModel.stats,
                    onSelectGarden: { garden in
                        Task { await viewModel.selectGarden(garden, dataService: dataService) }
                    },
                    onAdd: { showingAddPlant = true },
                    onSearch: { showingSearch = true }
                )
            }
            .task { await viewModel.load(dataService: dataService) }
            .sheet(item: $selectedPlant) { plant in
                PlantQuickCard(plant: plant)
            }
            .sheet(isPresented: $showingAddPlant) {
                AddPlantSheet()
            }
        }
        .accessibilityIdentifier("GardenView")
    }

    private var addBedButton: some View {
        Button {
            // TODO: Phase 3 — add bed/area sheet
        } label: {
            HStack {
                Image(systemName: "plus")
                Text("Add Bed or Area")
                    .font(.system(.subheadline, design: .rounded))
            }
            .foregroundStyle(CultivationTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(CultivationTheme.Colors.cardBorder)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add garden bed or area")
        .accessibilityIdentifier("garden_button_add_bed")
    }
}
```

- [ ] **Create `PlantQuickCard.swift`** (bottom sheet on plant tap):

```swift
import GrowWiseModels
import SwiftUI

struct PlantQuickCard: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(CultivationTheme.Colors.cardBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Plant header
            HStack(spacing: 14) {
                IconBubble(
                    systemName: plant.plantType.iconName,
                    color: plant.healthStatus.color,
                    size: 56,
                    iconSize: 26
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text(plant.locationDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()
                StatusDot(status: plant.healthStatus)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Quick stats
            HStack(spacing: 8) {
                QuickStatCard(value: plant.daysTillNextWater, label: "days water", color: CultivationTheme.Colors.brandLeaf)
                QuickStatCard(value: plant.healthScore, label: "health", color: plant.healthStatus.color)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Quick actions
            HStack(spacing: 8) {
                quickActionButton("drop.fill", "Water", CultivationTheme.Gradients.cta, isPrimary: true) {}
                quickActionButton("scissors", "Prune", nil, isPrimary: false) {}
                quickActionButton("camera.fill", "Log", nil, isPrimary: false) {}
                quickActionButton("book.pages.fill", "Guide", nil, isPrimary: false) {}
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Full detail link
            NavigationLink(destination: PlantDetailView(plant: plant)) {
                Text("View Full Details")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassCard()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(CultivationTheme.Colors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("plant_quick_card")
    }

    private func quickActionButton(_ icon: String, _ label: String, _ gradient: LinearGradient?, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isPrimary
                                ? AnyShapeStyle(CultivationTheme.Gradients.ctaVertical)
                                : AnyShapeStyle(CultivationTheme.Colors.cardSurface)
                        )
                        .overlay {
                            if !isPrimary {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            }
                        }
                        .frame(height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isPrimary ? .white : CultivationTheme.Colors.textPrimary)
                }

                Text(label)
                    .font(.system(size: 11, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("quick_action_\(label.lowercased())")
    }
}

// Placeholder extensions — replace with real model data
extension Plant {
    var locationDescription: String { "Raised Bed A" }
    var healthScore: Int { 95 }
}
```

- [ ] **Run build.**

- [ ] **Commit:**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
git commit -m "feat: implement Garden tab grouped list with bed sections and plant quick card"
```

---

## Chunk 4: Home Tab (Phase 4)

### Task 7: Home Tab — Task Dashboard

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift`
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/SeasonalTipCard.swift`

- [ ] **Create `HomeViewModel.swift`:**

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

@Observable
final class HomeViewModel {
    var overdueTasks: [PlantReminder] = []
    var todayTasks: [PlantReminder] = []
    var allGoodCount: Int = 0
    var weather: WeatherInfo?
    var seasonalTip: String?
    var isLoading = false

    func load(dataService: DataService, locationService: LocationService) async {
        isLoading = true
        defer { isLoading = false }
        // Load reminders grouped by urgency
        let reminders = (try? dataService.getActiveReminders()) ?? []
        let now = Date()
        overdueTasks = reminders.filter { $0.dueDate < now }
        todayTasks = reminders.filter { Calendar.current.isDateInToday($0.dueDate) && $0.dueDate >= now }
        let totalPlants = (try? dataService.getAllPlants())?.count ?? 0
        allGoodCount = totalPlants - overdueTasks.count - todayTasks.count
        seasonalTip = SeasonalTipService.tip(for: now, zone: locationService.hardinessZone)
    }

    func completeTask(_ reminder: PlantReminder, dataService: DataService) async {
        // Mark reminder complete via DataService
        try? dataService.completeReminder(reminder)
        // Remove from lists with animation
        overdueTasks.removeAll { $0.id == reminder.id }
        todayTasks.removeAll { $0.id == reminder.id }
        allGoodCount += 1
    }
}
```

- [ ] **Create `HomeHeroHeader.swift`:**

```swift
import SwiftUI

struct HomeHeroHeader: View {
    let userName: String
    let weather: WeatherInfo?
    let overdueCount: Int
    let todayCount: Int
    let allGoodCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Text(userName)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                }

                Spacer()

                // Weather glass pill
                if let w = weather {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: w.iconName)
                                .foregroundStyle(CultivationTheme.Colors.brandGold)
                            Text(w.temperatureString)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                        Text(w.gardeningNote)
                            .font(.system(size: 10))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CultivationTheme.Colors.cardSurface)
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, 16)

            // Stat cards row
            HStack(spacing: 10) {
                QuickStatCard(value: overdueCount, label: "Overdue", color: CultivationTheme.Colors.statusAlert)
                    .accessibilityIdentifier("home_stat_overdue")
                QuickStatCard(value: todayCount, label: "Due Today", color: CultivationTheme.Colors.statusWarning)
                    .accessibilityIdentifier("home_stat_today")
                QuickStatCard(value: allGoodCount, label: "All Good", color: CultivationTheme.Colors.statusHealthy)
                    .accessibilityIdentifier("home_stat_allgood")
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .heroBackground()
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }
}
```

- [ ] **Create `SeasonalTipCard.swift`:**

```swift
import SwiftUI

struct SeasonalTipCard: View {
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBubble(
                systemName: "leaf.circle.fill",
                color: CultivationTheme.Colors.brandLeaf,
                size: 36,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Seasonal Tip")
                    .font(.system(size: 12, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                Text(tip)
                    .font(.system(size: 13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.12), lineWidth: 1)
        }
    }
}
```

- [ ] **Rewrite `HomeView.swift`** (keep existing service injection and `.task` loading — rewrite the body):

```swift
public struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService

    @State private var viewModel = HomeViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CultivationTheme.Spacing.sectionGap) {

                    // Overdue section
                    if !viewModel.overdueTasks.isEmpty {
                        taskSection(
                            label: "Overdue",
                            color: CultivationTheme.Colors.statusAlert,
                            tasks: viewModel.overdueTasks,
                            isUrgent: true
                        )
                    }

                    // Due today section
                    if !viewModel.todayTasks.isEmpty {
                        taskSection(
                            label: "Due Today",
                            color: CultivationTheme.Colors.statusWarning,
                            tasks: viewModel.todayTasks,
                            isUrgent: false
                        )
                    }

                    // All done empty state
                    if viewModel.overdueTasks.isEmpty && viewModel.todayTasks.isEmpty {
                        allGoodState
                    }

                    // Seasonal tip
                    if let tip = viewModel.seasonalTip {
                        SeasonalTipCard(tip: tip)
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                HomeHeroHeader(
                    userName: "Blake",  // TODO: load from DataService user
                    weather: viewModel.weather,
                    overdueCount: viewModel.overdueTasks.count,
                    todayCount: viewModel.todayTasks.count,
                    allGoodCount: viewModel.allGoodCount
                )
            }
            .task {
                await viewModel.load(dataService: dataService, locationService: locationService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService, locationService: locationService)
            }
        }
        .accessibilityIdentifier("HomeView")
    }

    private func taskSection(label: String, color: Color, tasks: [PlantReminder], isUrgent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .sectionLabelStyle()
                .foregroundStyle(color)
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    TaskRow(
                        plantName: task.plant?.name ?? "",
                        taskDescription: task.title,
                        location: task.locationDescription,
                        isUrgent: isUrgent
                    ) {
                        withAnimation(CultivationTheme.Animation.card) {
                            Task { await viewModel.completeTask(task, dataService: dataService) }
                        }
                    }
                    .accessibilityIdentifier("home_task_\(task.id)")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        }
    }

    private var allGoodState: some View {
        VStack(spacing: 12) {
            IconBubble(systemName: "checkmark.circle.fill", color: CultivationTheme.Colors.statusHealthy, size: 56, iconSize: 28)

            Text("Your garden is thriving")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("No tasks due today")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassCard()
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .accessibilityIdentifier("home_all_good_state")
    }
}
```

- [ ] **Run build and existing tests.**

- [ ] **Commit:**

```bash
git commit -m "feat: rewrite Home tab as task-focused dashboard with glass design"
```

---

## Chunk 5: Journal & Profile Restyle (Phase 5)

### Task 8: Journal Tab Restyle

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryRow.swift`

These are restyled, not rewritten. The data loading, search, and navigation logic stays. Only the visual layer changes.

- [ ] **Read `JournalView.swift`** to identify the exact list/scroll structure and toolbar items.

- [ ] **Update `JournalView` navigation title + background:**

```swift
// Replace .navigationTitle("Journal") with inline title in a custom header
// Add: .background(CultivationTheme.Colors.background.ignoresSafeArea())
// Add: .scrollContentBackground(.hidden)
```

- [ ] **Update filter pills** — replace existing filter chips with `GlassPill` components.

- [ ] **Update `JournalEntryRow`** to use `.glassCard()` instead of `RoundedRectangle().fill(Color(.secondarySystemBackground))`.

- [ ] **Update section date headers** to use `.sectionLabelStyle()`.

- [ ] **Run build. Commit:**

```bash
git commit -m "feat: restyle Journal tab with glass cards and botanical typography"
```

---

### Task 9: Profile Tab Restyle

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/ProfileView.swift`

- [ ] **Read `ProfileView.swift`** to understand current structure (subscription cards, stats).

- [ ] **Rewrite Profile layout** with the new grouped-settings design:

```
User card (avatar gradient + name + skill + zone)
Stats row (Plants / Streak / Entries)
Learning section header + grouped glass card:
  - Tutorials row
  - Achievements row
Settings section header + grouped glass card:
  - Notifications row → links to ReminderSettingsView
  - Subscription row
  - App Settings row
```

- [ ] **Replace old bordered plan cards** with `GlassPill` styled subscription row.

- [ ] **Run build. Commit:**

```bash
git commit -m "feat: restyle Profile tab with user card, stats row, grouped settings"
```

---

## Chunk 6: Detail Views & Sheets (Phase 6)

### Task 10: Plant Detail View Restyle

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift`

- [ ] **Read `MyGardenPlantDetailView.swift`** — it's 644 lines. Identify key sections: hero photo, care requirements, photo gallery, journal entries, reminders, care actions.

- [ ] **Update hero section** — apply `heroBackground()` modifier to the top photo/gradient section.

- [ ] **Update all cards** — replace `Color(.secondarySystemBackground)` / `Color(.systemGray6)` with `.glassCard()`.

- [ ] **Update action buttons** — replace bordered buttons with `GradientButtonStyle` for primary actions (Water, Fertilize).

- [ ] **Update section headers** — apply `.sectionLabelStyle()`.

- [ ] **Run build. Commit:**

```bash
git commit -m "feat: restyle Plant Detail view with glass treatment and gradient actions"
```

---

### Task 11: Add Plant Sheet Restyle

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/AddPlantSheet.swift`

- [ ] **Read `AddPlantSheet.swift`** — 437 lines. Identify form sections.

- [ ] **Update form background** — `.scrollContentBackground(.hidden)` + `CultivationTheme.Colors.background`.

- [ ] **Update form section labels** — `.sectionLabelStyle()`.

- [ ] **Update primary button** — `GradientButtonStyle`.

- [ ] **Run build. Commit.**

---

### Task 12: Reminder & Journal Sheets Restyle

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/AddReminderView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/AddJournalEntryView.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Journal/JournalEntryDetailView.swift`

- [ ] For each file: update background, card surfaces, section labels, primary buttons to use the design system. Do not change logic.

- [ ] **Run build. Commit.**

---

## Chunk 7: Polish & Cleanup (Phase 7)

### Task 13: Remove Deprecated Views

**Files to delete:**
- `Views/TutorialsView.swift` (absorbed into Profile)
- `Components/WelcomeSection.swift` (absorbed into HomeHeroHeader)
- `Components/WeatherSection.swift` (absorbed into HomeHeroHeader)
- `Components/QuickActionsSection.swift` (removed — actions are contextual)
- `Components/StatsSection.swift` (replaced by QuickStatCard)
- `Views/ReminderManagementView.swift` (absorbed into Home tab)

- [ ] **Verify each is no longer imported anywhere:**

```bash
grep -r "TutorialsView\|WelcomeSection\|WeatherSection\|QuickActionsSection\|StatsSection\|ReminderManagementView" GrowWisePackage --include="*.swift"
```

- [ ] **Delete files, run build, fix any stragglers.**

- [ ] **Commit:**

```bash
git commit -m "chore: remove deprecated views absorbed by redesign"
```

---

### Task 14: Animation Polish Pass

- [ ] Audit every `withAnimation` in the codebase — replace `.easeInOut` with `CultivationTheme.Animation.card` or `.selection`.
- [ ] Verify tab switch animation uses `.spring()`.
- [ ] Run through all screens in Simulator, check for any jerky or missing transitions.
- [ ] Commit.

---

### Task 15: Light Mode Verification

- [ ] Open Simulator, toggle to Light Mode in Settings.
- [ ] Walk through all 4 tabs — verify no dark surfaces bleed into light mode.
- [ ] Verify `cardSurface` renders as white with shadow in light mode.
- [ ] Verify `heroBackground()` renders as off-white gradient in light mode.
- [ ] Fix any issues. Commit.

---

### Task 16: Accessibility Audit

- [ ] Run Accessibility Inspector on Home, Garden, Journal, Profile.
- [ ] Verify all buttons have `accessibilityLabel`.
- [ ] Verify all interactive elements have `accessibilityIdentifier`.
- [ ] Verify VoiceOver reads task rows correctly.
- [ ] Fix any gaps. Commit.

---

### Task 17: Final Build & Full Test Suite

- [ ] **Run full test suite on mac-mini:**

```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild test -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO 2>&1 | tail -20"
```

Expected: All tests pass (1 known pre-existing failure in FeatureFlagServiceTests is acceptable).

- [ ] **Push to remote:**

```bash
git push
```
