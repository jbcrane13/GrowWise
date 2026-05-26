import SwiftUI

// MARK: - Paper Card Modifier

/// Applies the cream-paper card surface treatment (v2 — replaces GlassCardModifier).
/// Soft warm shadow on cream, no blur.
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
    func paperCard() -> some View {
        modifier(PaperCardModifier())
    }

    /// Backwards compatibility — old call sites can keep using glassCard().
    /// Routes to the new paperCard treatment.
    func glassCard() -> some View {
        modifier(PaperCardModifier())
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

/// Cream-paper background with soft coral + sage glow for Home and Garden tab headers.
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

// MARK: - Coral CTA Button Style

/// Share-to-Club primary action button.
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

// MARK: - Secondary Button Style

/// Outlined secondary action button — cream surface with border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CultivationTheme.Fonts.body(16, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(CultivationTheme.Animation.card, value: configuration.isPressed)
    }
}

// MARK: - Smart Tag

/// Sage '✦' chip marking smart-enrichment surfaces (auto-ID, weather, zone).
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
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}

/// UI-layer health status enum (maps to model-layer health data).
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

/// Filter chip / garden switcher pill. Active state uses moss fill.
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
        .accessibilityIdentifier(resolvedAccessibilityID)
    }

    private var resolvedAccessibilityID: String {
        guard accessibilityID.isEmpty else { return accessibilityID }

        let sanitizedLabel = label
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : "_"
            }

        return "glasspill_\(String(sanitizedLabel))"
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

// MARK: - Paper Grain Overlay

/// Deterministic paper-grain texture drawn via Canvas.
/// Apply as a full-screen overlay at low opacity for tactile depth.
struct PaperGrainOverlay: View {
    var opacity: Double = 0.045

    var body: some View {
        Canvas { context, size in
            // 800-point grid of tiny specks using a deterministic LCG seed
            var seed: UInt64 = 0xA5A5_A5A5_A5A5_A5A5
            for _ in 0 ..< 800 {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let x = Double(seed >> 33) / Double(UInt32.max) * size.width
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let y = Double(seed >> 33) / Double(UInt32.max) * size.height
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let alpha = 0.15 + Double(seed >> 33) / Double(UInt32.max) * 0.35
                let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(alpha)))
            }
        }
        .opacity(opacity)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Overlays a subtle paper-grain texture for tactile depth.
    func paperGrain(opacity: Double = 0.045) -> some View {
        overlay(PaperGrainOverlay(opacity: opacity).ignoresSafeArea())
    }
}
