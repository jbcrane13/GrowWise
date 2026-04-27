import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// MARK: - GardenHealthCardView

struct GardenHealthCardView: View {
    @Environment(DataService.self)
    private var dataService

    @Environment(GardenHealthService.self)
    private var gardenHealthService

    @State private var healthScore: GardenHealthScore?
    @State private var showBreakdown = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let score = healthScore {
                Button {
                    showBreakdown = true
                } label: {
                    HStack(spacing: 14) {
                        // Circular progress ring
                        scoreRing(score: score.overallScore)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Garden Health")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                                trendIndicator(score.trend)
                            }

                            Text(scoreLabel(score.overallScore))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_gardenhealth")
                .sheet(isPresented: $showBreakdown) {
                    GardenHealthBreakdownSheet(score: score)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .alert("Data Load Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("gardenhealth_button_error_dismiss")
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
    }

    // MARK: - Score Ring

    private func scoreRing(score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(
                    CultivationTheme.Colors.cardBorder,
                    lineWidth: 4
                )

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    scoreColor(score),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(scoreColor(score))
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Trend Indicator

    private func trendIndicator(_ trend: HealthTrend) -> some View {
        Image(systemName: trend.icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(trendColor(trend))
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score < 40 { return CultivationTheme.Colors.statusAlert }
        if score < 70 { return CultivationTheme.Colors.statusWarning }
        return CultivationTheme.Colors.statusHealthy
    }

    private func trendColor(_ trend: HealthTrend) -> Color {
        switch trend {
        case .improving: CultivationTheme.Colors.statusHealthy
        case .declining: CultivationTheme.Colors.statusAlert
        case .stable: CultivationTheme.Colors.textTertiary
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        if score < 40 { return "Needs attention" }
        if score < 70 { return "Getting there" }
        return "Looking great"
    }

    // MARK: - Data Loading

    func loadHealthScore() {
        let logger = Logger(subsystem: "com.growwise", category: "GardenHealthCardView")
        let allPlants: [Plant]
        do {
            allPlants = try dataService.plants.fetchAll()
        } catch {
            allPlants = []
            logger.error("Failed to load plants: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to load plants: \(error.localizedDescription)"
        }
        let allReminders: [PlantReminder]
        do {
            allReminders = try dataService.reminders.fetchAll()
        } catch {
            allReminders = []
            logger.error("Failed to load reminders: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to load reminders: \(error.localizedDescription)"
        }
        let gardenPlants = allPlants.filter { $0.garden != nil }

        guard !gardenPlants.isEmpty else {
            healthScore = nil
            return
        }

        healthScore = gardenHealthService.calculateScore(plants: gardenPlants, reminders: allReminders)
    }
}

// MARK: - GardenHealthBreakdownSheet

struct GardenHealthBreakdownSheet: View {
    let score: GardenHealthScore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    // Overall score header
                    HStack {
                        Spacer()
                        overallScoreView
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Category breakdowns
                    VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
                        Text("BREAKDOWN")
                            .sectionLabelStyle()
                            .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                        categoryBar(
                            label: "Watering",
                            icon: "drop.fill",
                            score: score.breakdown.wateringScore,
                            weight: "35%"
                        )
                        categoryBar(
                            label: "Plant Health",
                            icon: "leaf.fill",
                            score: score.breakdown.healthScore,
                            weight: "30%"
                        )
                        categoryBar(
                            label: "Care Consistency",
                            icon: "checkmark.circle.fill",
                            score: score.breakdown.careConsistency,
                            weight: "20%"
                        )
                        categoryBar(
                            label: "Fertilizing",
                            icon: "drop.triangle.fill",
                            score: score.breakdown.fertilizingScore,
                            weight: "15%"
                        )
                    }
                }
                .padding(CultivationTheme.Spacing.screenPadding)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Garden Health")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .accessibilityIdentifier("healthbreakdown_button_done")
                }
            }
        }
        .accessibilityIdentifier("healthbreakdown_screen")
    }

    // MARK: - Overall Score View

    private var overallScoreView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(
                        CultivationTheme.Colors.cardBorder,
                        lineWidth: 6
                    )

                Circle()
                    .trim(from: 0, to: CGFloat(score.overallScore) / 100)
                    .stroke(
                        scoreGradient(score.overallScore),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score.overallScore)")
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .foregroundStyle(scoreColor(score.overallScore))

                    HStack(spacing: 3) {
                        Image(systemName: score.trend.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(score.trend.rawValue.capitalized)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(trendColor(score.trend))
                }
            }
            .frame(width: 100, height: 100)
        }
    }

    // MARK: - Category Bar

    private func categoryBar(label: String, icon: String, score: Int, weight: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(scoreColor(score))

                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Spacer()

                Text("\(score)")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(scoreColor(score))

                Text(weight)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("healthbreakdown_category_\(label.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score < 40 { return CultivationTheme.Colors.statusAlert }
        if score < 70 { return CultivationTheme.Colors.statusWarning }
        return CultivationTheme.Colors.statusHealthy
    }

    private func scoreGradient(_ score: Int) -> AngularGradient {
        let color = scoreColor(score)
        return AngularGradient(
            colors: [color.opacity(0.3), color],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * Double(score) / 100)
        )
    }

    private func trendColor(_ trend: HealthTrend) -> Color {
        switch trend {
        case .improving: CultivationTheme.Colors.statusHealthy
        case .declining: CultivationTheme.Colors.statusAlert
        case .stable: CultivationTheme.Colors.textTertiary
        }
    }
}
