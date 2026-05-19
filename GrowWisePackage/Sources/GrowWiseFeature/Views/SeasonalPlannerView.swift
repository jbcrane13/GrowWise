import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// MARK: - SeasonalPlannerView

public struct SeasonalPlannerView: View {
    @Environment(DataService.self)
    private var dataService

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var activities: [PlantActivity] = []
    @State private var plants: [Plant] = []
    @State private var seeds: [Seed] = []
    @State private var userZone: String?
    @State private var frostDate: FrostDate?
    @State private var errorMessage: String?
    @State private var showAnnualCalendar = false

    private let monthNames = Calendar.current.shortMonthSymbols

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                // Frost date indicator
                if let frostDate {
                    frostDateBanner(frostDate)
                }

                // Month strip
                monthStrip
                annualCalendarButton

                // Activities for selected month
                if activities.isEmpty {
                    emptyState
                } else {
                    activitiesList
                }
            }
            .padding(.vertical, CultivationTheme.Spacing.screenPadding)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Seasonal Planner")
        .gwNavigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
        .onChange(of: selectedMonth) {
            refreshActivities()
        }
        .sheet(isPresented: $showAnnualCalendar) {
            NavigationStack {
                AnnualCalendarView(plants: plants, seeds: seeds, zone: userZone)
                    .environment(dataService)
            }
        }
        .accessibilityIdentifier("seasonalplanner_screen")
        .alert("Data Load Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("seasonalplanner_button_error_dismiss")
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
    }

    // MARK: - Month Strip

    private var monthStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1 ... 12, id: \.self) { month in
                        let isSelected = month == selectedMonth
                        let isCurrent = month == Calendar.current.component(.month, from: Date())

                        Button {
                            withAnimation(CultivationTheme.Animation.selection) {
                                selectedMonth = month
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(monthNames[month - 1])
                                    .font(.system(.caption, design: .rounded, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(
                                        isSelected
                                            ? .white
                                            : isCurrent
                                            ? CultivationTheme.Colors.brandLeaf
                                            : CultivationTheme.Colors.textSecondary
                                    )

                                if isCurrent {
                                    Circle()
                                        .fill(isSelected ? .white : CultivationTheme.Colors.brandLeaf)
                                        .frame(width: 4, height: 4)
                                } else {
                                    Circle()
                                        .fill(.clear)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 48, height: 48)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                                        .fill(CultivationTheme.Gradients.ctaVertical)
                                } else {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                                        .fill(CultivationTheme.Colors.cardSurface)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                                    .stroke(
                                        isSelected
                                            ? .clear
                                            : CultivationTheme.Colors.cardBorder,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .id(month)
                        .accessibilityIdentifier("seasonalplanner_button_month_\(month)")
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .center)
            }
        }
    }

    // MARK: - Activities List

    private var annualCalendarButton: some View {
        Button {
            showAnnualCalendar = true
        } label: {
            Label("Annual calendar", systemImage: "calendar")
                .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .accessibilityIdentifier("seasonalplanner_button_annual_calendar")
    }

    private var activitiesList: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("ACTIVITIES FOR \(fullMonthName(selectedMonth).uppercased())")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            ForEach(activities) { activity in
                activityRow(activity)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            }
        }
    }

    private func activityRow(_ activity: PlantActivity) -> some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: activity.icon,
                color: colorForActivity(activity.activityType),
                size: CultivationTheme.Spacing.iconSize,
                iconSize: 18
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.plantName)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text(activity.activityType.displayName)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(colorForActivity(activity.activityType))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(colorForActivity(activity.activityType).opacity(0.12))
                        }
                }

                Text(activity.description)
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("seasonalplanner_row_activity_\(activity.id.uuidString)")
    }

    // MARK: - Frost Date Banner

    private func frostDateBanner(_ frost: FrostDate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "thermometer.snowflake")
                .font(.system(size: 20))
                .foregroundStyle(CultivationTheme.Colors.accentCoral)

            VStack(alignment: .leading, spacing: 2) {
                Text("FROST DATES")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Last Spring:")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        Text(frost.lastSpringFrostDescription)
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    }

                    HStack(spacing: 4) {
                        Text("First Fall:")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        Text(frost.firstFallFrostDescription)
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    }
                }
            }

            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .accessibilityIdentifier("seasonalplanner_card_frostdates")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            IconBubble(
                systemName: "calendar",
                color: CultivationTheme.Colors.textTertiary,
                size: 56,
                iconSize: 24
            )

            Text("No activities this month")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Add plants to your gardens to see seasonal activities")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .accessibilityIdentifier("seasonalplanner_empty_state")
    }

    // MARK: - Helpers

    private func colorForActivity(_ activity: SeasonalActivity) -> Color {
        switch activity {
        case .startIndoors: CultivationTheme.Colors.accentAmber
        case .directSow: CultivationTheme.Colors.accentSky
        case .transplant: CultivationTheme.Colors.brandLeaf
        case .activeGrowing: CultivationTheme.Colors.statusHealthy
        case .harvest: CultivationTheme.Colors.accentCoral
        case .winterPrep: CultivationTheme.Colors.brandSage
        case .pruning: CultivationTheme.Colors.brandForest
        case .fertilize: CultivationTheme.Colors.statusWarning
        }
    }

    private func fullMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return monthNames[month - 1]
    }

    // MARK: - Data Loading

    @MainActor
    private func loadData() async {
        let user = dataService.getCurrentUser()
        userZone = user?.hardinessZone

        let service = SeasonalPlannerService(dataService: dataService)
        frostDate = service.getFrostDate(for: userZone)

        // Gather all plants from all gardens
        let allPlants: [Plant]
        do {
            allPlants = try dataService.plants.fetchAll()
        } catch {
            allPlants = []
            Logger(subsystem: "com.growwise", category: "SeasonalPlannerView")
                .error("Failed to load plants: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to load plants: \(error.localizedDescription)"
        }
        plants = allPlants.filter { $0.garden != nil }

        // Load seeds that have indoor-start or direct-sow data for the planner
        let allSeeds: [Seed]
        do {
            allSeeds = try dataService.seeds.fetchAll()
        } catch {
            allSeeds = []
            Logger(subsystem: "com.growwise", category: "SeasonalPlannerView")
                .error("Failed to load seeds: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to load seeds: \(error.localizedDescription)"
        }
        seeds = allSeeds.filter { ($0.indoorStartWeeks ?? 0) > 0 || !($0.directSowMonths ?? []).isEmpty }

        refreshActivities()
    }

    private func refreshActivities() {
        let service = SeasonalPlannerService(dataService: dataService)
        activities = service.getMonthlyActivities(
            for: selectedMonth,
            plants: plants,
            seeds: seeds,
            zone: userZone
        )
    }
}

private struct AnnualCalendarView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(\.dismiss)
    private var dismiss

    let plants: [Plant]
    let seeds: [Seed]
    let zone: String?

    private let monthNames = Calendar.current.monthSymbols

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(1 ... 12, id: \.self) { month in
                    monthSection(month)
                }
            }
            .padding(CultivationTheme.Spacing.screenPadding)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Annual Calendar")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("annualcalendar_button_done")
            }
        }
        .accessibilityIdentifier("annualcalendar_screen")
    }

    private func monthSection(_ month: Int) -> some View {
        let activities = SeasonalPlannerService(dataService: dataService)
            .getMonthlyActivities(for: month, plants: plants, seeds: seeds, zone: zone)

        return VStack(alignment: .leading, spacing: 8) {
            Text(monthNames[month - 1])
                .font(CultivationTheme.Fonts.display(18, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            if activities.isEmpty {
                Text("No scheduled garden tasks")
                    .font(CultivationTheme.Fonts.body(12))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            } else {
                ForEach(activities.prefix(4)) { activity in
                    Label(activity.description, systemImage: activity.icon)
                        .font(CultivationTheme.Fonts.body(12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("annualcalendar_month_\(month)")
    }
}
