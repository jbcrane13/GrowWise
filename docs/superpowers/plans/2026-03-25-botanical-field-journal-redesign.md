# Botanical Field Journal Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Cultivation's visual identity from tech-glass-morphism to a warm "Botanical Field Journal" aesthetic — stone/sage palette with coral/amber accents, serif headings, monospace data, and editorial layouts.

**Architecture:** Theme-first approach — update CultivationTheme tokens, then shared components (ViewModifiers), then views top-down (Home, Garden, PlantDetail). No structural/architectural changes — same MV pattern, same services, same navigation. Pure visual redesign.

**Tech Stack:** SwiftUI, SF Pro Serif/Rounded/Monospaced system font variants (no custom font registration needed), existing CultivationTheme token system.

**Mockup reference:** `docs/mockups/cultivation-redesign-v2.html`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `GrowWiseFeature/Design/CultivationTheme.swift` | All color, gradient, typography, animation, and radius tokens |
| Modify | `GrowWiseFeature/Design/ViewModifiers.swift` | GlassCard, HeroBackground, GlassPill, QuickStatCard, IconBubble, GradientButtonStyle, StatusDot |
| Modify | `GrowWiseFeature/Design/GardenComponents.swift` | TaskRow, PlantRow, BedGroupHeader, CompanionTipCard pill/button colors |
| Modify | `GrowWiseFeature/Views/Home/HomeHeroHeader.swift` | Serif greeting, seasonal subtitle, stat cards |
| Modify | `GrowWiseFeature/Views/HomeView.swift` | Timeline section headers, seasonal tip integration |
| Modify | `GrowWiseFeature/Views/Home/HomeViewModel.swift` | Add `totalPlantCount` computed property for hero |
| Modify | `GrowWiseFeature/Views/Home/SeasonalTipCard.swift` | Update to use new amber accent + serif title |
| Modify | `GrowWiseFeature/Views/GardenView.swift` | Dashboard header with zone/season context, filter pills, FAB |
| Modify | `GrowWiseFeature/Views/Garden/GardenCardView.swift` | Bed chip pills, health dots, editorial card layout |
| Modify | `GrowWiseFeature/Views/MyGardenPlantDetailView.swift` | Serif plant name, botanical subtitle, vitals strip, moss/sage CTA |
| Modify | `GrowWiseFeature/Main/MainAppView.swift` | Tab bar tint to coral accent |

---

## Task 1: Update CultivationTheme Color Tokens

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift`

This is the foundation — every other file references these tokens. The new palette shifts from bright green brand colors to stone/sage/coral/amber.

- [ ] **Step 1: Replace the Colors enum**

Replace the entire `Colors` enum body with the new stone & sage palette:

```swift
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
    public static let brandForest = Color(hex: "4A6650")   // moss — deep green anchor
    public static let brandLeaf = Color(hex: "7A917A")     // sage — primary green
    public static let brandMint = Color(hex: "C0CCC5")     // frost — light sage
    public static let brandCream = Color(hex: "F4F5F2")    // parchment
    public static let brandGold = Color(hex: "E0A456")     // amber — warm accent
    public static let brandSage = Color(hex: "96AC96")     // lichen — mid sage

    // Accent — coral and amber (the new warm identity)
    public static let accentCoral = Color(hex: "D4725C")
    public static let accentAmber = Color(hex: "E0A456")

    /// Hero glow — subtle sage instead of bright green
    public static let heroGlow = Color(hex: "7A917A").opacity(0.06)

    // Interactive
    public static let divider = Color(light: Color(white: 0, opacity: 0.08), dark: Color(white: 1, opacity: 0.06))
    public static let sectionLabel = Color(light: Color(hex: "888888"), dark: Color(hex: "666666"))
}
```

- [ ] **Step 2: Update the Gradients enum**

Replace CTA gradients from forest→leaf green to moss→sage:

```swift
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
```

- [ ] **Step 3: Update Typography enum to use serif/mono variants**

Replace the Typography enum to use `.serif` design for headings and `.monospaced` for stats:

```swift
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
        Text(text).font(.system(size: 13, design: .monospaced, weight: .medium))
    }
}
```

- [ ] **Step 4: Build to verify tokens compile**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -5`
Expected: Build succeeds (downstream views still reference the same token names)

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift
git commit -m "feat: update CultivationTheme to Botanical Field Journal palette

Stone/sage base with coral/amber accents. Serif headings,
monospaced stats. Replaces bright green brand identity."
```

---

## Task 2: Update Shared View Modifiers

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift`

Update shared components to use the new palette and visual language.

- [ ] **Step 1: Update HeroBackgroundModifier**

Replace the green glow orb with a dual-tone atmospheric background (subtle coral top-right, subtle sage center-left):

```swift
struct HeroBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topTrailing) {
                    CultivationTheme.Colors.background

                    // Subtle coral glow orb (top-right)
                    Circle()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(0.05))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: 60, y: -40)

                    // Subtle sage glow orb (center-left)
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.04))
                        .frame(width: 180, height: 180)
                        .blur(radius: 50)
                        .offset(x: -80, y: 60)
                }
            }
    }
}
```

- [ ] **Step 2: Update GlassPill selected state**

Change from green tint to coral tint when selected:

```swift
struct GlassPill: View {
    let label: String
    var isSelected: Bool = false
    var accessibilityID: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? CultivationTheme.Colors.accentCoral
                        : CultivationTheme.Colors.textSecondary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? CultivationTheme.Colors.accentCoral.opacity(0.12)
                                : CultivationTheme.Colors.cardSurface
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected
                                ? CultivationTheme.Colors.accentCoral.opacity(0.3)
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

- [ ] **Step 3: Update QuickStatCard to use monospaced numbers**

Change the value text to monospaced design:

```swift
struct QuickStatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
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

- [ ] **Step 4: Build to verify**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/ViewModifiers.swift
git commit -m "feat: update shared modifiers for Botanical Field Journal theme

Coral-tinted selection pills, atmospheric dual-glow hero bg,
monospaced stat numbers."
```

---

## Task 3: Update GardenComponents

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift`

Update TaskRow, PlantRow, and BedGroupHeader to use coral accent for active states instead of green.

- [ ] **Step 1: Update TaskRow — urgent button uses warmAccent gradient**

In the `TaskRow` struct, change the urgent button gradient and the non-urgent button tint:

Find: `Capsule().fill(CultivationTheme.Gradients.cta)` in the urgent button
Replace with: `Capsule().fill(CultivationTheme.Gradients.warmAccent)`

Find: `.foregroundStyle(CultivationTheme.Colors.brandLeaf)` in the non-urgent "Done" button
Replace with: `.foregroundStyle(CultivationTheme.Colors.accentCoral)`

Find: `.fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))` in the non-urgent button bg
Replace with: `.fill(CultivationTheme.Colors.accentCoral.opacity(0.08))`

Find: `.stroke(CultivationTheme.Colors.brandLeaf.opacity(0.35), lineWidth: 1)` in the non-urgent button border
Replace with: `.stroke(CultivationTheme.Colors.accentCoral.opacity(0.3), lineWidth: 1)`

- [ ] **Step 2: Update TaskRow convenience init — default statusColor**

In the `TaskRow` extension `init(reminder:isUrgent:onComplete:)`, change the non-urgent status color:

Find: `CultivationTheme.Colors.brandLeaf` (the non-urgent case)
Replace with: `CultivationTheme.Colors.brandLeaf` (keep sage — this is the icon tint for the care type, sage is correct)

No change needed here actually — sage icons are intentional.

- [ ] **Step 3: Update BedGroupHeader pill from green to sage**

The plant count pill already uses `brandLeaf` which is now sage — this is correct. No change needed.

- [ ] **Step 4: Update PlantRow urgent complete button**

In the `PlantRow` struct, change the urgent "Done" button gradient:

Find: `Capsule().fill(CultivationTheme.Gradients.cta)` in PlantRow
Replace with: `Capsule().fill(CultivationTheme.Gradients.warmAccent)`

- [ ] **Step 5: Build to verify**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Design/GardenComponents.swift
git commit -m "feat: update GardenComponents with coral accent buttons

Urgent action buttons use warm coral/amber gradient.
Non-urgent buttons tinted coral instead of green."
```

---

## Task 4: Redesign HomeHeroHeader

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift`
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift`

Transform the hero from rounded-sans greeting to serif editorial greeting with seasonal context.

- [ ] **Step 1: Add totalPlantCount to HomeViewModel**

In `HomeViewModel`, add a property and populate it in `load()`:

```swift
var totalPlantCount: Int = 0
```

Inside `load(dataService:)`, after fetching reminders, add:

```swift
totalPlantCount = (try? dataService.plants.fetchAll().count) ?? 0
```

- [ ] **Step 2: Rewrite HomeHeroHeader with serif typography and seasonal subtitle**

Replace the full body of `HomeHeroHeader`:

```swift
struct HomeHeroHeader: View {
    let userName: String
    let overdueCount: Int
    let dueTodayCount: Int
    let allGoodCount: Int
    let totalPlantCount: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var seasonalNote: String {
        let month = Calendar.current.component(.month, from: Date())
        let taskCount = overdueCount + dueTodayCount
        let taskPhrase = taskCount == 1 ? "1 task needs" : "\(taskCount) tasks need"
        switch month {
        case 3 ... 5: return "\(taskPhrase) attention. Your spring garden is waking up."
        case 6 ... 8: return "\(taskPhrase) attention. Peak growing season is here."
        case 9 ... 11: return "\(taskPhrase) attention. Time to prepare for the harvest."
        default: return "\(taskPhrase) attention. Plan ahead for next season."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + ", " + (userName.isEmpty ? "Gardener" : userName))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .accessibilityIdentifier("home_label_greeting")

                Text("Your garden is ")
                    .font(.system(.title, design: .serif)) +
                Text("thriving")
                    .font(.system(.title, design: .serif))
                    .italic()
                    .foregroundColor(CultivationTheme.Colors.accentAmber)

                Text(seasonalNote)
                    .font(.system(size: 14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .padding(.top, 2)
                    .accessibilityIdentifier("home_label_seasonal_note")
            }
            .accessibilityIdentifier("home_label_username")

            HStack(spacing: 10) {
                QuickStatCard(
                    value: overdueCount,
                    label: "Overdue",
                    color: CultivationTheme.Colors.statusAlert
                )
                .accessibilityIdentifier("home_stat_overdue")

                QuickStatCard(
                    value: dueTodayCount,
                    label: "Due Today",
                    color: CultivationTheme.Colors.statusWarning
                )
                .accessibilityIdentifier("home_stat_duetoday")

                QuickStatCard(
                    value: totalPlantCount,
                    label: "Plants",
                    color: CultivationTheme.Colors.brandLeaf
                )
                .accessibilityIdentifier("home_stat_plants")
            }
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .heroBackground()
    }
}
```

- [ ] **Step 3: Update HomeView to pass totalPlantCount**

In `HomeView`, update the `HomeHeroHeader` call to include the new parameter:

```swift
HomeHeroHeader(
    userName: viewModel.userName,
    overdueCount: overdueVisible.count,
    dueTodayCount: dueTodayVisible.count,
    allGoodCount: viewModel.allGoodCount,
    totalPlantCount: viewModel.totalPlantCount
)
```

- [ ] **Step 4: Update HomeView section labels to use serif**

In `HomeView`, update the "Overdue" and "Due Today" section labels. Currently they use `.sectionLabelStyle()` which is fine — keep as-is since those are uppercase mono-weight labels.

- [ ] **Step 5: Update HomeView empty state to use serif**

In the `emptyStateView`, change the headline:

Find:
```swift
Text("Your garden is thriving")
    .font(.system(.headline, design: .rounded, weight: .bold))
```

Replace:
```swift
Text("Your garden is thriving")
    .font(.system(.headline, design: .serif))
```

- [ ] **Step 6: Update the preview**

```swift
#Preview {
    HomeHeroHeader(
        userName: "Blake",
        overdueCount: 2,
        dueTodayCount: 4,
        allGoodCount: 7,
        totalPlantCount: 12
    )
}
```

- [ ] **Step 7: Build to verify**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 8: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeHeroHeader.swift \
       GrowWisePackage/Sources/GrowWiseFeature/Views/Home/HomeViewModel.swift \
       GrowWisePackage/Sources/GrowWiseFeature/Views/HomeView.swift
git commit -m "feat: redesign Home hero with serif typography and seasonal context

Serif italic 'thriving' accent, seasonal note, total plant count
stat card replaces 'All Good' card."
```

---

## Task 5: Update SeasonalTipCard

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Home/SeasonalTipCard.swift`

Update to use amber accent and serif title.

- [ ] **Step 1: Update the card**

Replace the "Seasonal Tip" header styling and update the icon color to use `accentAmber`:

Find:
```swift
Text("Seasonal Tip")
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(CultivationTheme.Colors.brandGold)
    .tracking(0.5)
```

Replace:
```swift
Text("Seasonal Tip")
    .font(.system(size: 13, design: .serif))
    .foregroundStyle(CultivationTheme.Colors.accentAmber)
```

The `brandGold` reference for the IconBubble is now `accentAmber` (same token value), but update for naming consistency:

Find: `color: CultivationTheme.Colors.brandGold,`
Replace: `color: CultivationTheme.Colors.accentAmber,`

- [ ] **Step 2: Build and commit**

```bash
cd GrowWisePackage && swift build 2>&1 | tail -5
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Home/SeasonalTipCard.swift
git commit -m "feat: update SeasonalTipCard with amber accent and serif title"
```

---

## Task 6: Redesign GardenView Dashboard Header

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift`

Update the dashboard header to the editorial style with zone context and coral FAB.

- [ ] **Step 1: Update dashboardHeader**

Replace the `dashboardHeader` computed property:

```swift
private var dashboardHeader: some View {
    VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GARDENS")
                    .font(.system(size: 10, design: .monospaced, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                Text(viewModel.userName.isEmpty ? "My Gardens" : "\(viewModel.userName)'s Gardens")
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("\(viewModel.gardens.count) gardens \u{00B7} \(viewModel.totalPlantsAllGardens) plants")
                    .font(.system(size: 13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                showCreateGarden = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(CultivationTheme.Gradients.warmAccent)
                    .clipShape(Circle())
                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.3), radius: 8, y: 3)
            }
            .accessibilityIdentifier("garden_button_add")
        }

        if !viewModel.gardens.isEmpty {
            HStack(spacing: 10) {
                QuickStatCard(
                    value: viewModel.gardens.count,
                    label: "Gardens",
                    color: CultivationTheme.Colors.brandLeaf
                )
                QuickStatCard(
                    value: viewModel.totalPlantsAllGardens,
                    label: "Plants",
                    color: CultivationTheme.Colors.statusHealthy
                )
                QuickStatCard(
                    value: viewModel.totalAlertsAllGardens,
                    label: "Alerts",
                    color: viewModel.totalAlertsAllGardens > 0
                        ? CultivationTheme.Colors.statusAlert
                        : CultivationTheme.Colors.textTertiary
                )
            }
        }
    }
    .padding(.top, 16)
}
```

- [ ] **Step 2: Add userName to GardenViewModel**

GardenViewModel does NOT currently have a `userName` property. Add it and populate in `load()`:

```swift
var userName: String = ""
// In load():
userName = dataService.getCurrentUser()?.displayName ?? ""
```

- [ ] **Step 3: Update empty state to use serif**

In the `emptyState` view, update:

Find:
```swift
Text("Plant your first garden")
    .font(.system(.title3, design: .rounded, weight: .semibold))
```

Replace:
```swift
Text("Plant your first garden")
    .font(.system(.title3, design: .serif))
```

- [ ] **Step 4: Update QuickStartChip icon color from green to sage**

In `QuickStartChip`, change:

Find: `.foregroundStyle(CultivationTheme.Colors.brandLeaf)`
Replace: `.foregroundStyle(CultivationTheme.Colors.accentCoral)`

This makes the quick-start chips use the warm accent for visual interest.

- [ ] **Step 5: Build and commit**

```bash
cd GrowWisePackage && swift build 2>&1 | tail -5
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift
git commit -m "feat: redesign Garden tab header with serif title and coral FAB

Editorial header with monospaced overline, serif garden name,
warm accent FAB button."
```

---

## Task 7: Update GardenCardView

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenCardView.swift`

Update garden cards with the new palette. The GardenMiniLayout bed colors need updating.

- [ ] **Step 1: Update GardenMiniLayout bedColors palette**

Replace the bed color palette with the new stone/sage tones:

Find the `bedColors` array:
```swift
private static let bedColors: [Color] = [
    Color(hex: "52B788"),
    Color(hex: "7A9D68"),
    Color(hex: "E9C46A"),
    Color(hex: "9DC5BB"),
    Color(hex: "B7E4C7"),
    Color(hex: "D4A373"),
    Color(hex: "A8DADC"),
    Color(hex: "CDB4DB"),
]
```

Replace with:
```swift
private static let bedColors: [Color] = [
    Color(hex: "7A917A"), // sage
    Color(hex: "D4725C"), // coral
    Color(hex: "E0A456"), // amber
    Color(hex: "96AC96"), // lichen
    Color(hex: "B09090"), // dusty rose
    Color(hex: "C0CCC5"), // frost
    Color(hex: "4A6650"), // moss
    Color(hex: "C8C4AE"), // wheat
]
```

- [ ] **Step 2: Update GardenCardView garden icon tint**

In the garden type icon background, change from `brandLeaf` to use the garden type's contextual color. For now, keep `brandLeaf` (which is now sage):

No change needed — `brandLeaf` is now sage, which works.

- [ ] **Step 3: Update card heading to serif**

Find:
```swift
Text(garden.name ?? "Garden")
    .font(.system(.headline, design: .rounded, weight: .semibold))
```

Replace:
```swift
Text(garden.name ?? "Garden")
    .font(.system(.headline, design: .serif))
```

- [ ] **Step 4: Update AddGardenCard accent from green to coral**

Find all `CultivationTheme.Colors.brandLeaf` references in `AddGardenCard` and replace with `CultivationTheme.Colors.accentCoral`:

- The plus icon: `.foregroundStyle(CultivationTheme.Colors.accentCoral.opacity(0.6))`
- The fill: `.fill(CultivationTheme.Colors.accentCoral.opacity(0.03))`
- The stroke: `.stroke(CultivationTheme.Colors.accentCoral.opacity(0.3), ...)`

- [ ] **Step 5: Build and commit**

```bash
cd GrowWisePackage && swift build 2>&1 | tail -5
git add GrowWisePackage/Sources/GrowWiseFeature/Views/Garden/GardenCardView.swift
git commit -m "feat: update GardenCardView with stone/sage bed colors and serif titles

New bed palette, serif garden names, coral add-garden card."
```

---

## Task 8: Update PlantDetailView

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift`

Update the plant detail screen with serif plant name, coral CTA, and the new palette.

- [ ] **Step 1: Update hero placeholder gradient**

In `heroImageSection`, update the gradient placeholder:

Find:
```swift
LinearGradient(
    colors: [
        CultivationTheme.Colors.brandForest.opacity(0.25),
        CultivationTheme.Colors.brandLeaf.opacity(0.12),
    ],
```

Replace:
```swift
LinearGradient(
    colors: [
        CultivationTheme.Colors.brandForest.opacity(0.2),
        CultivationTheme.Colors.accentCoral.opacity(0.08),
    ],
```

- [ ] **Step 2: Update plant name in hero to serif**

Find:
```swift
Text(plant.name ?? "Unknown Plant")
    .font(.system(.title3, design: .rounded, weight: .semibold))
```

Replace:
```swift
Text(plant.name ?? "Unknown Plant")
    .font(.system(.title3, design: .serif))
```

- [ ] **Step 3: Update "Water Now" CTA to warm accent**

In `actionButtonsSection`, the `GradientButtonStyle` already uses `Gradients.cta` which is now moss→sage. For the primary water action, this works. But update the button icon to use `drop.fill` (already done).

Optionally, to make the primary action warmer, we could use `warmAccent`. But since watering is a "natural" action, keeping the green gradient is intentional. Leave as-is.

- [ ] **Step 4: Update "View All" and "Manage" link colors**

In `careHistorySection`, find the "View All" button:
```swift
Button("View All") {
    // Navigate to full journal view
}
.font(.system(.caption, design: .rounded))
.foregroundStyle(CultivationTheme.Colors.brandLeaf)
```
Change `.brandLeaf` to `.accentCoral` on that line only.

In `upcomingRemindersSection`, find the "Manage" button:
```swift
Button("Manage") {
    // Navigate to reminder management
}
.font(.system(.caption, design: .rounded))
.foregroundStyle(CultivationTheme.Colors.brandLeaf)
```
Change `.brandLeaf` to `.accentCoral` on that line only.

Do NOT change other `brandLeaf` references in this file — they are intentional sage-green icon tints.

- [ ] **Step 5: Build and commit**

```bash
cd GrowWisePackage && swift build 2>&1 | tail -5
git add GrowWisePackage/Sources/GrowWiseFeature/Views/MyGardenPlantDetailView.swift
git commit -m "feat: update PlantDetailView with serif names and coral accents

Serif plant name in hero, coral link colors, updated gradient."
```

---

## Task 9: Update MainAppView Tab Tint

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift`

- [ ] **Step 1: Change the tab bar tint from leaf green to coral**

Find: `.tint(Color(hex: "52B788"))` (line 135 of MainAppView.swift — hardcoded hex, not a token)

Replace with: `.tint(CultivationTheme.Colors.accentCoral)`

- [ ] **Step 2: Build and commit**

```bash
cd GrowWisePackage && swift build 2>&1 | tail -5
git add GrowWisePackage/Sources/GrowWiseFeature/Main/MainAppView.swift
git commit -m "feat: update tab bar tint to coral accent"
```

---

## Task 10: Final Build Verification and Cleanup

- [ ] **Step 1: Full build**

Run: `cd GrowWisePackage && swift build 2>&1 | tail -20`
Expected: Build succeeds with no errors (warnings OK)

- [ ] **Step 2: Grep for any remaining bright green references**

Search for any hardcoded `#52B788` or `brandLeaf` usage that should have been updated to `accentCoral`:

```bash
grep -rn "52B788\|2D6A4F\|B7E4C7\|E9C46A\|F5F0E8\|7A9D68" GrowWisePackage/Sources/GrowWiseFeature/
```

Only `CultivationTheme.swift` should contain hex values. Any view files with hardcoded colors should use tokens.

- [ ] **Step 3: Run tests via SSH**

```bash
ssh mac-mini "cd ~/Projects/GrowWise/GrowWisePackage && swift test 2>&1 | tail -20"
```

Expected: Tests pass (visual-only changes shouldn't break tests)

- [ ] **Step 4: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: cleanup remaining bright green references"
```

- [ ] **Step 5: Push**

```bash
git push
```
