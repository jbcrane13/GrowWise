import GrowWiseModels
import SwiftUI

// MARK: - GardenCardView

/// Visual card representing a single garden in the dashboard grid.
/// Shows garden type icon, name, a mini visual layout of beds, and stats.
struct GardenCardView: View {
    let garden: Garden
    let plantCount: Int
    let bedCount: Int
    let alertCount: Int
    let onTap: () -> Void

    private var gardenType: GardenType {
        garden.gardenType ?? .outdoor
    }

    private var healthSummary: GardenHealthSummary {
        let plants = garden.plants ?? []
        var healthy = 0
        var warning = 0
        var critical = 0
        for plant in plants {
            switch plant.healthStatus ?? .healthy {
            case .healthy:
                healthy += 1

            case .needsAttention, .sick:
                warning += 1

            case .dying, .dead:
                critical += 1
            }
        }
        return GardenHealthSummary(healthy: healthy, warning: warning, critical: critical)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top: icon + name + type badge
                HStack(spacing: 10) {
                    Image(systemName: gardenType.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(garden.name ?? "Garden")
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Text(gardenType.displayName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    Spacer()

                    if alertCount > 0 {
                        Text("\(alertCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(CultivationTheme.Colors.statusAlert))
                    }
                }

                // Mini garden layout visualization
                GardenMiniLayout(garden: garden)
                    .frame(height: 72)

                // Stats row
                HStack(spacing: 0) {
                    GardenMiniStat(
                        icon: "leaf.fill",
                        value: "\(plantCount)",
                        label: plantCount == 1 ? "Plant" : "Plants",
                        color: CultivationTheme.Colors.statusHealthy
                    )

                    Spacer()

                    GardenMiniStat(
                        icon: "square.grid.2x2.fill",
                        value: "\(bedCount)",
                        label: bedCount == 1 ? "Bed" : "Beds",
                        color: CultivationTheme.Colors.brandLeaf
                    )

                    Spacer()

                    healthIndicator
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("garden_card_\(garden.id?.uuidString ?? "unknown")")
    }

    @ViewBuilder private var healthIndicator: some View {
        let summary = healthSummary
        if plantCount == 0 {
            GardenMiniStat(
                icon: "sparkles",
                value: "--",
                label: "Health",
                color: CultivationTheme.Colors.textTertiary
            )
        } else if summary.critical > 0 {
            GardenMiniStat(
                icon: "exclamationmark.triangle.fill",
                value: "\(summary.critical)",
                label: "Critical",
                color: CultivationTheme.Colors.statusAlert
            )
        } else if summary.warning > 0 {
            GardenMiniStat(
                icon: "exclamationmark.circle.fill",
                value: "\(summary.warning)",
                label: "Attention",
                color: CultivationTheme.Colors.statusWarning
            )
        } else {
            GardenMiniStat(
                icon: "checkmark.circle.fill",
                value: "All",
                label: "Healthy",
                color: CultivationTheme.Colors.statusHealthy
            )
        }
    }
}

// MARK: - GardenHealthSummary

private struct GardenHealthSummary {
    let healthy: Int
    let warning: Int
    let critical: Int
}

// MARK: - GardenMiniStat

private struct GardenMiniStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - GardenMiniLayout

/// A visual mini-map of the garden's beds rendered as colored tiles.
/// Creates a spatial feel for how the garden is organized.
struct GardenMiniLayout: View {
    let garden: Garden

    private var beds: [GardenBed] {
        (garden.beds ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

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

    var body: some View {
        if beds.isEmpty {
            emptyLayout
        } else {
            filledLayout
        }
    }

    private var emptyLayout: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(CultivationTheme.Colors.brandLeaf.opacity(0.05))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Text("No beds yet")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        CultivationTheme.Colors.brandLeaf.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [4])
                    )
            }
    }

    private var filledLayout: some View {
        let layout = computeLayout()
        return GeometryReader { geo in
            let spacing: CGFloat = 3
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height

            ZStack(alignment: .topLeading) {
                // Background soil/grass texture hint
                RoundedRectangle(cornerRadius: 8)
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.04))

                ForEach(Array(layout.enumerated()), id: \.offset) { index, rect in
                    let color = Self.bedColors[index % Self.bedColors.count]
                    let bed = beds[index]
                    let plantCount = (bed.plants ?? []).count

                    BedTile(
                        name: bed.name ?? "Bed",
                        plantCount: plantCount,
                        color: color
                    )
                    .frame(
                        width: rect.width * totalWidth - spacing,
                        height: rect.height * totalHeight - spacing
                    )
                    .offset(
                        x: rect.minX * totalWidth + spacing / 2,
                        y: rect.minY * totalHeight + spacing / 2
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Compute a proportional layout for beds.
    /// Uses a simple row-packing algorithm to create a visually interesting grid.
    private func computeLayout() -> [CGRect] {
        let count = beds.count
        guard count > 0 else { return [] }

        switch count {
        case 1:
            return [CGRect(x: 0, y: 0, width: 1.0, height: 1.0)]

        case 2:
            return [
                CGRect(x: 0, y: 0, width: 0.55, height: 1.0),
                CGRect(x: 0.55, y: 0, width: 0.45, height: 1.0),
            ]

        case 3:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 1.0),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            ]

        case 4:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            ]

        case 5:
            return [
                CGRect(x: 0, y: 0, width: 0.6, height: 0.55),
                CGRect(x: 0.6, y: 0, width: 0.4, height: 0.55),
                CGRect(x: 0, y: 0.55, width: 0.33, height: 0.45),
                CGRect(x: 0.33, y: 0.55, width: 0.33, height: 0.45),
                CGRect(x: 0.66, y: 0.55, width: 0.34, height: 0.45),
            ]

        default:
            // For 6+ beds, pack into a 3-column grid with varying heights
            let cols = 3
            let rows = (count + cols - 1) / cols
            let rowHeight = 1.0 / Double(rows)
            return (0 ..< count).map { i in
                let row = i / cols
                let col = i % cols
                let colWidth = 1.0 / Double(min(cols, count - row * cols))
                return CGRect(
                    x: Double(col) * colWidth,
                    y: Double(row) * rowHeight,
                    width: colWidth,
                    height: rowHeight
                )
            }
        }
    }
}

// MARK: - BedTile

/// A small colored tile representing a bed in the mini layout.
private struct BedTile: View {
    let name: String
    let plantCount: Int
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.2))
            RoundedRectangle(cornerRadius: 5)
                .stroke(color.opacity(0.4), lineWidth: 1)

            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if plantCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0 ..< min(plantCount, 5), id: \.self) { _ in
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 4, height: 4)
                        }
                        if plantCount > 5 {
                            Text("+\(plantCount - 5)")
                                .font(.system(size: 6, weight: .medium, design: .rounded))
                                .foregroundStyle(color.opacity(0.6))
                        }
                    }
                }
            }
            .padding(3)
        }
    }
}

// MARK: - AddGardenCard

/// A dashed-border card prompting the user to add a new garden.
struct AddGardenCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral.opacity(0.6))

                VStack(spacing: 2) {
                    Text("New Garden")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text("Backyard, balcony, indoor...")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.accentCoral.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .stroke(
                        CultivationTheme.Colors.accentCoral.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("garden_button_newgarden")
    }
}
