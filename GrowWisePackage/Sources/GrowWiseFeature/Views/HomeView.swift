// HomeView: Task-focused morning dashboard
// Hero header with greeting + stat cards, urgency-grouped task list, seasonal tip.

import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct HomeView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(TutorialService.self)
    private var tutorialService
    @Environment(LocationService.self)
    private var locationService

    @State private var viewModel = HomeViewModel()
    @State private var showPlantDatabase = false
    @State private var showTutorials = false
    @State private var tutorials: [TutorialTopic] = []

    public init() {}

    // MARK: - Derived visible lists (filter out optimistically-completed rows)

    //
    // These computed properties re-filter on every render, but the cost is
    // negligible: both source arrays are small (typically <20 reminders) and
    // the predicate is a Set<UUID>.contains() lookup — O(1) per element.
    // Caching in @State would add complexity (manual invalidation when
    // completedIDs or the source arrays change) with no measurable benefit.

    private var overdueVisible: [PlantReminder] {
        viewModel.overdueReminders.filter { !viewModel.completedIDs.contains($0.id) }
    }

    private var dueTodayVisible: [PlantReminder] {
        viewModel.dueTodayReminders.filter { !viewModel.completedIDs.contains($0.id) }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
                    if let post = viewModel.latestClubPost {
                        YourClubCard(post: post)
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                            .padding(.top, CultivationTheme.Spacing.sectionGap)
                    }

                    if viewModel.allTasksDone {
                        emptyStateView
                    } else {
                        // OVERDUE section
                        if !overdueVisible.isEmpty {
                            Text("Overdue")
                                .sectionLabelStyle()
                                .foregroundStyle(CultivationTheme.Colors.statusAlert)
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .padding(.top, CultivationTheme.Spacing.sectionGap)
                                .accessibilityIdentifier("home_label_section_overdue")

                            ForEach(overdueVisible) { reminder in
                                TaskRow(
                                    reminder: reminder,
                                    isUrgent: true,
                                    onComplete: {
                                        Task {
                                            await viewModel.complete(
                                                reminder: reminder,
                                                dataService: dataService
                                            )
                                        }
                                    }
                                )
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .accessibilityIdentifier("home_row_task_\(reminder.id.uuidString)")
                            }
                        }

                        // DUE TODAY section
                        if !dueTodayVisible.isEmpty {
                            Text("Due Today")
                                .sectionLabelStyle()
                                .foregroundStyle(CultivationTheme.Colors.statusWarning)
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .padding(
                                    .top,
                                    overdueVisible.isEmpty
                                        ? CultivationTheme.Spacing.sectionGap
                                        : CultivationTheme.Spacing.rowGap
                                )
                                .accessibilityIdentifier("home_label_section_duetoday")

                            ForEach(dueTodayVisible) { reminder in
                                TaskRow(
                                    reminder: reminder,
                                    isUrgent: false,
                                    onComplete: {
                                        Task {
                                            await viewModel.complete(
                                                reminder: reminder,
                                                dataService: dataService
                                            )
                                        }
                                    }
                                )
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .accessibilityIdentifier("home_row_task_\(reminder.id.uuidString)")
                            }
                        }
                    }

                    // Seasonal tip — always shown
                    SeasonalTipCard()
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .padding(.top, CultivationTheme.Spacing.sectionGap)

                    // Ready to Plant — seeds in their indoor start window
                    if !viewModel.readyToPlantSeeds.isEmpty {
                        ReadyToPlantCard(seeds: viewModel.readyToPlantSeeds)
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    // Browse Plant Guide
                    Button {
                        showPlantDatabase = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Browse Plant Guide")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                Text("Explore 50+ plants with care instructions")
                                    .font(.system(.caption))
                                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                        .padding(CultivationTheme.Spacing.cardPadding)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .accessibilityIdentifier("home_button_plantguide")

                    // Garden health score
                    GardenHealthCardView()
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                    // Seasonal planner link
                    NavigationLink {
                        SeasonalPlannerView()
                    } label: {
                        HStack(spacing: 10) {
                            IconBubble(
                                systemName: "calendar.badge.clock",
                                color: CultivationTheme.Colors.brandSage,
                                size: CultivationTheme.Spacing.iconSizeSmall,
                                iconSize: 14
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Seasonal Planner")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                Text("See what to plant this month")
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
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .accessibilityIdentifier("home_button_seasonalplanner")

                    // Weather card
                    weatherCard
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                    // Learning section
                    learningSection
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                    // Community card
                    NavigationLink {
                        CommunityFeedView()
                    } label: {
                        HStack(spacing: 10) {
                            IconBubble(
                                systemName: "person.2.fill",
                                color: CultivationTheme.Colors.accentCoral,
                                size: CultivationTheme.Spacing.iconSizeSmall,
                                iconSize: 14
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Community")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                Text("See what other gardeners are growing")
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
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.bottom, CultivationTheme.Spacing.sectionGap)
                    .accessibilityIdentifier("home_button_community")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HomeHeroHeader(
                    userName: viewModel.userName,
                    overdueCount: overdueVisible.count,
                    dueTodayCount: dueTodayVisible.count,
                    totalPlantCount: viewModel.totalPlantCount
                )
            }
            .toolbarBackground(.hidden)
            .task {
                await viewModel.load(dataService: dataService)
            }
            .refreshable {
                await viewModel.load(dataService: dataService)
            }
            .background(CultivationTheme.Colors.background)
            .alert(
                "Action Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("home_alert_button_ok")
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showPlantDatabase) {
                PlantDatabaseView()
            }
            .sheet(isPresented: $showTutorials) {
                TutorialsView()
            }
            .task {
                tutorials = Array(tutorialService.getAllTutorials().prefix(3))
            }
            .accessibilityIdentifier("home_screen")
        }
    }

    // MARK: - Weather Card

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GARDEN WEATHER")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            if let weatherData = locationService.weatherData {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: weatherConditionIcon(for: weatherData))
                                .font(.system(size: 22))
                                .foregroundStyle(CultivationTheme.Colors.accentAmber)

                            Text(temperatureString(for: weatherData))
                                .font(.system(.title2, design: .monospaced, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }

                        Text(weatherConditionLabel(for: weatherData))
                            .font(.system(.caption))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(gardenWeatherTip(for: weatherData))
                            .font(.system(.caption))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("home_card_weather")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: seasonalWeatherIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(CultivationTheme.Colors.accentAmber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(seasonalContextTitle)
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text(seasonalContextSubtitle)
                            .font(.system(.caption))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("home_card_weather_seasonal")
            }
        }
    }

    private func weatherConditionIcon(for data: WeatherData) -> String {
        let temp = data.current.temperature.converted(to: .fahrenheit).value
        if temp <= 32 { return "snowflake" }
        if temp >= 95 { return "sun.max.trianglebadge.exclamationmark.fill" }
        if data.current.condition == .rain || data.current.condition == .heavyRain {
            return "cloud.rain.fill"
        }
        if data.current.condition == .cloudy || data.current.condition == .mostlyCloudy {
            return "cloud.fill"
        }
        return "sun.max.fill"
    }

    private func temperatureString(for data: WeatherData) -> String {
        let temp = data.current.temperature.converted(to: .fahrenheit).value
        return "\(Int(temp))°F"
    }

    private func weatherConditionLabel(for data: WeatherData) -> String {
        data.current.condition.description
    }

    private func gardenWeatherTip(for data: WeatherData) -> String {
        let temp = data.current.temperature.converted(to: .fahrenheit).value
        if temp <= 32 { return "Frost risk — protect tender plants" }
        if temp >= 95 { return "Heat stress — water early morning" }
        if data.current.condition == .rain || data.current.condition == .heavyRain {
            return "Skip watering — rain has you covered"
        }
        if temp >= 75 { return "Great growing weather — check moisture" }
        return "Mild conditions — ideal for garden work"
    }

    private var seasonalWeatherIcon: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3 ... 5: return "leaf.fill"
        case 6 ... 8: return "sun.max.fill"
        case 9 ... 11: return "wind"
        default: return "snowflake"
        }
    }

    private var seasonalContextTitle: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3 ... 5: return "Spring Growing Season"
        case 6 ... 8: return "Peak Summer Growth"
        case 9 ... 11: return "Fall Harvest Season"
        default: return "Winter Planning Season"
        }
    }

    private var seasonalContextSubtitle: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3 ... 5: return "Warm days ahead — great time to plant cool-season crops"
        case 6 ... 8: return "Water deeply and mulch to retain moisture"
        case 9 ... 11: return "Harvest regularly and prepare beds for winter"
        default: return "Plan your spring garden and order seeds"
        }
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LEARNING")
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                Spacer()

                Button {
                    showTutorials = true
                } label: {
                    Text("See All")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
                .accessibilityIdentifier("home_button_seeall_tutorials")
            }

            ForEach(tutorials) { tutorial in
                Button {
                    showTutorials = true
                } label: {
                    HStack(spacing: 12) {
                        IconBubble(
                            systemName: tutorialIcon(for: tutorial.category),
                            color: CultivationTheme.Colors.brandLeaf,
                            size: 40,
                            iconSize: 17
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tutorial.title)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                .lineLimit(1)

                            Text("\(tutorial.estimatedDuration) min · \(tutorial.difficultyLevel.displayName)")
                                .font(.system(.caption))
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
                .accessibilityIdentifier("home_card_tutorial_\(tutorial.id)")
            }
        }
    }

    private func tutorialIcon(for category: TutorialCategory) -> String {
        switch category {
        case .planning: "map.fill"
        case .preparation: "shovel.fill"
        case .care: "drop.fill"
        case .environment: "sun.max.fill"
        case .problemSolving: "ant.fill"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            IconBubble(
                systemName: "checkmark.seal.fill",
                color: CultivationTheme.Colors.statusHealthy,
                size: 64,
                iconSize: 28
            )
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Your garden is thriving")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("No overdue or pending tasks — great work!")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .accessibilityIdentifier("home_empty_state")
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let dataService = try! DataService()
    HomeView()
        .environment(dataService)
}
