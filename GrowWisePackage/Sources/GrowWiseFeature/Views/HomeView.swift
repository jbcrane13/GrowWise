// HomeView: Task-focused morning dashboard
// Hero header with greeting + stat cards, urgency-grouped task list, seasonal tip.

import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable function_body_length large_tuple type_body_length

public struct HomeView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(LocationService.self)
    private var locationService
    @Environment(AppRouter.self)
    private var router

    @State private var viewModel = HomeViewModel()
    @State private var showCareShareSheet = false
    @State private var careShareCaption = ""

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    todayCareCard
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .padding(.top, CultivationTheme.Spacing.sectionGap)

                    if !viewModel.starterPlan.actions.isEmpty {
                        StarterPlanCard(actions: viewModel.starterPlan.actions) { action in
                            handleStarterPlanAction(action)
                        }
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    Button {
                        router.selectedTab = .club
                    } label: {
                        clubCard
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Garden Club")
                    .accessibilityIdentifier("home_card_club")
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

                    SeasonalTipCard()
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .padding(.bottom, CultivationTheme.Spacing.sectionGap)
                }
            }
            .accessibilityIdentifier("home_screen")
            .safeAreaInset(edge: .top, spacing: 0) {
                HomeHeroHeader(
                    userName: viewModel.userName,
                    weatherPillText: weatherPillText
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
            .sheet(isPresented: $showCareShareSheet) {
                ClubShareComposerSheet(initialCaption: careShareCaption)
                    .environment(dataService)
            }
            .accessibilityIdentifier("home_screen")
        }
    }

    // MARK: - Today's Care

    private var todayCareCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's care · \(viewModel.visibleCareTaskCount) \(taskCountLabel)")
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                Spacer()

                if viewModel.visibleOverdueCount > 0 {
                    Text("\(viewModel.visibleOverdueCount) overdue")
                        .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.accentCoralDeep)
                }
            }
            .padding(.bottom, 2)

            if viewModel.visibleCareReminders.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.visibleCareReminders) { reminder in
                    careTaskRow(reminder)
                }

                Button {
                    Task<Void, Never> {
                        await completeVisibleCareTasks()
                    }
                } label: {
                    Text("Mark all done")
                        .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                                .fill(CultivationTheme.Colors.brandForest)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
                .accessibilityIdentifier("home_button_mark_all_done")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("home_card_today_care")
    }

    private func handleStarterPlanAction(_ action: StarterPlanAction) {
        switch action.kind {
        case .createGarden, .addPlant, .reviewWateringReminder, .browseRecommendations:
            router.selectedTab = .garden

        case .startTutorial:
            router.selectedTab = .profile
        }
    }

    private func careTaskRow(_ reminder: PlantReminder) -> some View {
        let isUrgent = isTopPriorityOverdue(reminder)

        return HStack(spacing: 10) {
            Button {
                Task<Void, Never> {
                    let succeeded = await viewModel.complete(reminder: reminder, dataService: dataService)
                    if succeeded, dataService.fetchPrimaryClub() != nil {
                        careShareCaption = postCareCaption(for: reminder)
                        showCareShareSheet = true
                    }
                }
            } label: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isUrgent ? CultivationTheme.Colors.accentCoral : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isUrgent ? CultivationTheme.Colors.accentCoral : CultivationTheme.Colors.divider,
                                lineWidth: 1.5
                            )
                    }
                    .overlay {
                        if isUrgent {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home_button_complete_\(reminder.id.uuidString)")
            .accessibilityLabel("Complete \(reminder.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title.isEmpty ? reminder.reminderType.displayName : reminder.title)
                    .font(CultivationTheme.Fonts.display(14, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(careTaskMeta(for: reminder))
                    .font(CultivationTheme.Fonts.body(11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: reminder.reminderType.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(careActionColor(for: reminder))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CultivationTheme.Colors.backgroundSecondary)
                )
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if reminder.id != viewModel.visibleCareReminders.last?.id {
                Divider()
                    .background(CultivationTheme.Colors.divider)
            }
        }
        .accessibilityIdentifier("home_row_task_\(reminder.id.uuidString)")
    }

    private var taskCountLabel: String {
        viewModel.visibleCareTaskCount == 1 ? "task" : "tasks"
    }

    @MainActor
    private func completeVisibleCareTasks() async {
        let reminders = viewModel.visibleCareReminders
        for reminder in reminders {
            await viewModel.complete(reminder: reminder, dataService: dataService)
        }
    }

    private func isTopPriorityOverdue(_ reminder: PlantReminder) -> Bool {
        guard let firstOverdue = viewModel.visibleCareReminders.first(where: { isOverdue($0) }) else {
            return false
        }
        return firstOverdue.id == reminder.id
    }

    private func isOverdue(_ reminder: PlantReminder) -> Bool {
        reminder.nextDueDate < Calendar.current.startOfDay(for: Date())
    }

    private func careTaskMeta(for reminder: PlantReminder) -> String {
        let location = reminder.plant?.bed?.name ?? reminder.plant?.name ?? "Garden"
        return "\(location) · \(dueLabel(for: reminder))"
    }

    private func dueLabel(for reminder: PlantReminder) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        if reminder.nextDueDate < startOfToday {
            let dayCount = abs(calendar.dateComponents([.day], from: reminder.nextDueDate, to: startOfToday).day ?? 1)
            return "\(dayCount) \(dayCount == 1 ? "day" : "days") overdue"
        }
        return "due today"
    }

    private func careActionColor(for reminder: PlantReminder) -> Color {
        switch reminder.reminderType {
        case .watering:
            CultivationTheme.Colors.accentSky

        case .fertilizing:
            CultivationTheme.Colors.brandLeaf

        case .pruning:
            CultivationTheme.Colors.accentAmber

        default:
            CultivationTheme.Colors.textTertiary
        }
    }

    // MARK: - Club

    private var clubCard: some View {
        Group {
            if let post = viewModel.latestClubPost {
                YourClubCard(post: post)
            } else {
                HomeClubPlaceholderCard()
            }
        }
    }

    // MARK: - Weather

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

    private var weatherPillText: String {
        guard let weatherData = locationService.weatherData else {
            return "\(seasonalWeatherSymbol) \(seasonalContextTitle)"
        }
        let temperature = Int(weatherData.current.temperature.converted(to: .fahrenheit).value)
        return "\(weatherConditionSymbol(for: weatherData)) \(temperature)° · \(gardenWeatherTip(for: weatherData))"
    }

    private func weatherConditionSymbol(for data: WeatherData) -> String {
        switch weatherConditionIcon(for: data) {
        case "cloud.rain.fill": "☔"

        case "cloud.fill": "☁"

        case "snowflake": "❄"

        default: "☀"
        }
    }

    /// Computes month once and returns all seasonal display values together,
    /// avoiding redundant Calendar calls across separate computed properties.
    private var seasonalContext: (icon: String, symbol: String, title: String) {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3 ... 5: return ("leaf.fill", "🌿", "Spring Growing Season")
        case 6 ... 8: return ("sun.max.fill", "☀", "Peak Summer Growth")
        case 9 ... 11: return ("wind", "🍂", "Fall Harvest Season")
        default: return ("snowflake", "❄", "Winter Planning Season")
        }
    }

    private var seasonalWeatherSymbol: String {
        seasonalContext.symbol
    }

    private var seasonalWeatherIcon: String {
        seasonalContext.icon
    }

    private var seasonalContextTitle: String {
        seasonalContext.title
    }

    // MARK: - Share Prompt

    private func postCareCaption(for reminder: PlantReminder) -> String {
        let plantName = reminder.plant?.name ?? "my plant"
        switch reminder.reminderType {
        case .watering: return "Just watered \(plantName) 💧"
        case .fertilizing: return "Fed \(plantName) today 🌿"
        case .pruning: return "Pruned \(plantName) ✂️"
        default: return "Took care of \(plantName) today"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your garden is thriving")
                .font(CultivationTheme.Fonts.display(16, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("No overdue or pending tasks today.")
                .font(CultivationTheme.Fonts.body(13))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityIdentifier("home_empty_state")
    }
}

private struct HomeClubPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Club")
                .font(CultivationTheme.Fonts.body(10, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.85))

            Text("Share what's growing with nearby gardeners.")
                .font(CultivationTheme.Fonts.display(17, weight: .medium))
                .foregroundStyle(Color.white)

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }

                Text("Tap to open Garden Club")
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Gradients.warmAccent)
                .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.25), radius: 12, y: 6)
        )
        .accessibilityIdentifier("home_card_your_club_placeholder")
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let dataService = try! DataService()
    HomeView()
        .environment(dataService)
        .environment(AppRouter())
}

// swiftlint:enable function_body_length large_tuple type_body_length
