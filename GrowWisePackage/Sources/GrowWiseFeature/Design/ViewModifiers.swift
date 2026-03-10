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

/// Filter chip / garden switcher pill with glass treatment.
struct GlassPill: View {
    let label: String
    var isSelected: Bool = false
    var accessibilityID: String = ""
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
        .accessibilityIdentifier(accessibilityID)
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
