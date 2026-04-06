import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Reusable card that displays Perenual API-enriched data for any Plant.
/// Drop into any view — handles async loading, caching, and graceful fallback.
/// Shows: image, origin, hardiness zone, growth rate, description, safety warnings.
public struct PerenualEnrichmentCard: View {
    let plant: Plant
    @Environment(PerenualEnrichmentService.self) private var enrichment
    @State private var detail: PerenualSpeciesDetail?
    @State private var isLoading = true
    @State private var hasChecked = false

    public init(plant: Plant) {
        self.plant = plant
    }

    public var body: some View {
        Group {
            if let detail {
                enrichedContent(detail)
            } else if isLoading, !hasChecked {
                loadingView
            }
            // If hasChecked && detail == nil → show nothing (no Perenual data)
        }
        .task(id: plant.scientificName) {
            await loadEnrichment()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Loading plant encyclopedia...")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Enriched Content

    private func enrichedContent(_ detail: PerenualSpeciesDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
                Text("Plant Encyclopedia")
                    .sectionLabelStyle()
                Spacer()
                Text("Perenual")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            // Hero image from API
            if let imageURL = detail.defaultImage?.bestURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    case .failure:
                        EmptyView()
                    default:
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .fill(CultivationTheme.Colors.backgroundSecondary)
                            .frame(height: 180)
                            .overlay { ProgressView() }
                    }
                }
            }

            // Description
            if let desc = detail.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(4)
            }

            // Facts grid
            factsGrid(detail)

            // Safety warnings
            safetyWarnings(detail)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Facts Grid

    private func factsGrid(_ d: PerenualSpeciesDetail) -> some View {
        let facts = buildFacts(d)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(facts, id: \.label) { fact in
                HStack(spacing: 8) {
                    Image(systemName: fact.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(fact.color)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(fact.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        Text(fact.value)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private struct Fact {
        let icon: String
        let label: String
        let value: String
        let color: Color
    }

    private func buildFacts(_ d: PerenualSpeciesDetail) -> [Fact] {
        var facts: [Fact] = []

        if let hardiness = d.hardiness, let min = hardiness.min {
            let zone = hardiness.max != nil && hardiness.max != min
                ? "\(min)–\(hardiness.max!)" : min
            facts.append(Fact(icon: "thermometer", label: "Hardiness", value: "Zone \(zone)", color: CultivationTheme.Colors.accentCoral))
        }

        if let growth = d.growthRate {
            facts.append(Fact(icon: "chart.line.uptrend.xyaxis", label: "Growth", value: growth, color: CultivationTheme.Colors.brandLeaf))
        }

        if let cycle = d.cycle {
            facts.append(Fact(icon: "arrow.triangle.2.circlepath", label: "Lifecycle", value: cycle, color: CultivationTheme.Colors.brandSage))
        }

        if let origin = d.origin, !origin.isEmpty {
            let originText = origin.count > 2
                ? "\(origin.prefix(2).joined(separator: ", ")) +\(origin.count - 2)"
                : origin.joined(separator: ", ")
            facts.append(Fact(icon: "globe", label: "Origin", value: originText, color: .blue))
        }

        if let care = d.careLevel {
            facts.append(Fact(icon: "gauge.medium", label: "Care Level", value: care, color: .purple))
        }

        if let benchmark = d.wateringGeneralBenchmark, let val = benchmark.value, let unit = benchmark.unit {
            facts.append(Fact(icon: "drop.fill", label: "Watering", value: "Every \(val) \(unit)", color: .blue))
        }

        if let pruning = d.pruningMonth, !pruning.isEmpty {
            facts.append(Fact(icon: "scissors", label: "Prune", value: pruning.prefix(3).joined(separator: ", "), color: CultivationTheme.Colors.brandForest))
        }

        if let flowering = d.floweringSeason, !flowering.isEmpty {
            facts.append(Fact(icon: "camera.macro", label: "Flowers", value: flowering, color: CultivationTheme.Colors.accentAmber))
        }

        if d.droughtTolerant == true {
            facts.append(Fact(icon: "sun.haze", label: "Drought", value: "Tolerant", color: .orange))
        }

        if d.edibleFruit == true || d.edibleLeaf == true {
            let what = [d.edibleFruit == true ? "Fruit" : nil, d.edibleLeaf == true ? "Leaves" : nil]
                .compactMap(\.self).joined(separator: " & ")
            facts.append(Fact(icon: "fork.knife", label: "Edible", value: what, color: CultivationTheme.Colors.brandForest))
        }

        return facts
    }

    // MARK: - Safety Warnings

    private func safetyWarnings(_ d: PerenualSpeciesDetail) -> some View {
        let warnings = buildWarnings(d)
        return Group {
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings, id: \.text) { w in
                        HStack(spacing: 8) {
                            Image(systemName: w.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(CultivationTheme.Colors.statusAlert)
                            Text(w.text)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CultivationTheme.Colors.statusAlert.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
            }
        }
    }

    private struct Warning {
        let icon: String
        let text: String
    }

    private func buildWarnings(_ d: PerenualSpeciesDetail) -> [Warning] {
        var w: [Warning] = []
        if d.poisonousToPets == true { w.append(Warning(icon: "pawprint.fill", text: "Toxic to pets")) }
        if d.poisonousToHumans == true { w.append(Warning(icon: "person.fill.xmark", text: "Toxic to humans")) }
        if d.invasive == true { w.append(Warning(icon: "exclamationmark.triangle.fill", text: "Invasive species")) }
        if d.thorny == true { w.append(Warning(icon: "bolt.fill", text: "Has thorns — handle with care")) }
        return w
    }

    // MARK: - Data Loading

    private func loadEnrichment() async {
        // First check synchronous cache
        if let cached = enrichment.enrichment(for: plant) {
            detail = cached
            isLoading = false
            hasChecked = true
            return
        }

        // Wait a moment for the async fetch the enrichment(for:) call triggered
        isLoading = true
        try? await Task.sleep(for: .milliseconds(200))

        // Poll for result (the service fires a background task on first call)
        for _ in 0 ..< 30 { // Up to ~6 seconds
            if let cached = enrichment.enrichment(for: plant) {
                detail = cached
                isLoading = false
                hasChecked = true
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        isLoading = false
        hasChecked = true
    }
}

// MARK: - Compact variant for cards

/// Compact enrichment pill — shows just the Perenual image thumbnail and key stat.
/// Use in list rows, quick cards, etc.
public struct PerenualEnrichmentThumbnail: View {
    let plant: Plant
    @Environment(PerenualEnrichmentService.self) private var enrichment
    @State private var imageURL: String?
    @State private var hardinessZone: String?

    public init(plant: Plant) {
        self.plant = plant
    }

    public var body: some View {
        Group {
            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        plantPlaceholder
                    }
                }
            } else {
                plantPlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon))
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if let zone = hardinessZone {
                Text(zone)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(CultivationTheme.Colors.brandForest)
                    .clipShape(Capsule())
                    .offset(x: 2, y: 2)
            }
        }
        .task(id: plant.scientificName) {
            loadFromCache()
        }
    }

    private var plantPlaceholder: some View {
        ZStack {
            CultivationTheme.Colors.backgroundSecondary
            Image(systemName: plant.plantType?.iconName ?? "leaf.fill")
                .font(.system(size: 20))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.5))
        }
    }

    private func loadFromCache() {
        guard let detail = enrichment.enrichment(for: plant) else { return }
        imageURL = detail.defaultImage?.thumbnail ?? detail.defaultImage?.smallUrl
        if let min = detail.hardiness?.min {
            hardinessZone = "Z\(min)"
        }
    }
}
