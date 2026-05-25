// HomeView: Task-focused morning dashboard
// Hero header with greeting + stat cards, urgency-grouped task list, seasonal tip.

import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable file_length function_body_length large_tuple type_body_length

public struct HomeView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(LocationService.self)
    private var locationService
    @Environment(AppRouter.self)
    private var router
    @Environment(NotificationService.self)
    private var notificationService

    @State private var viewModel = HomeViewModel()
    @State private var showCareShareSheet = false
    @State private var careShareCaption = ""
    @State private var showSeasonalPlanner = false

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
                        StarterPlanCard(plan: viewModel.starterPlan) { action in
                            handleStarterPlanAction(action)
                        }
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    if let monthlyHarvestSummary = viewModel.monthlyHarvestSummary {
                        harvestTotalCard(monthlyHarvestSummary)
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

                    ForEach(viewModel.weatherAlerts) { alert in
                        WeatherAlertCard(alert: alert)
                            .accessibilityIdentifier("home_weather_alert_\(alert.id.uuidString)")
                    }

                    if !viewModel.readyToPlantSeeds.isEmpty {
                        SeedStartCard(seeds: viewModel.readyToPlantSeeds, zone: viewModel.hardinessZone)
                            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    }

                    Button {
                        showSeasonalPlanner = true
                    } label: {
                        SeasonalTipCard()
                    }
                    .buttonStyle(.plain)
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
                await viewModel.load(
                    dataService: dataService,
                    locationService: locationService,
                    notificationService: notificationService
                )
            }
            .refreshable {
                await viewModel.load(
                    dataService: dataService,
                    locationService: locationService,
                    notificationService: notificationService
                )
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
            .sheet(isPresented: $showSeasonalPlanner) {
                SeasonalPlannerView()
                    .environment(dataService)
                    .environment(locationService)
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
        let memberID = currentMemberID
        let canComplete = reminder.canBeCompleted(by: memberID)
        let canClaim = reminder.plant?.isSharedWithClub == true && reminder.assignedMemberID == nil
        let offersRainSkip = shouldOfferRainSkip(for: reminder)

        return HStack(spacing: 10) {
            if canClaim {
                Button {
                    claimReminder(reminder)
                } label: {
                    Text("Claim")
                        .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_claim_\(reminder.id.uuidString)")
                .accessibilityLabel("Claim \(reminder.title)")
            } else if canComplete {
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
            } else {
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .frame(width: 32, height: 28)
                    .accessibilityHidden(true)
            }

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

                if let assignedName = reminder.assignedMemberName {
                    Text("Assigned to \(assignedName)")
                        .font(CultivationTheme.Fonts.body(10, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                        .lineLimit(1)
                        .accessibilityIdentifier("home_badge_assigned_\(reminder.id.uuidString)")
                }
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

            let canSkipForRain = offersRainSkip && reminder.canBeCompleted(by: currentMemberID)

            if canSkipForRain {
                Button {
                    guard reminder.canBeCompleted(by: currentMemberID) else {
                        return
                    }
                    skipReminderForRain(reminder)
                } label: {
                    Text("Skip rain")
                        .font(CultivationTheme.Fonts.body(10, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.accentSky)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(CultivationTheme.Colors.accentSky.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_button_skip_rain_\(reminder.id.uuidString)")
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if reminder.id != viewModel.visibleCareReminders.last?.id {
                Divider()
                    .background(CultivationTheme.Colors.divider)
            }
        }
        .contextMenu {
            if reminder.assignedMemberID != nil, reminder.isAssigned(to: currentMemberID) {
                Button {
                    releaseReminderAssignment(reminder)
                } label: {
                    Label("Release assignment", systemImage: "person.fill.xmark")
                }
                .accessibilityIdentifier("home_context_release_assignment_\(reminder.id.uuidString)")
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

    private var currentMemberID: String? {
        dataService.getCurrentUser()?.id.uuidString
    }

    private var currentMemberName: String {
        dataService.getCurrentUser()?.displayName ?? "You"
    }

    private func claimReminder(_ reminder: PlantReminder) {
        guard let memberID = currentMemberID else {
            viewModel.errorMessage = "Create a profile before claiming shared care."
            return
        }

        do {
            try dataService.claimReminder(reminder, memberID: memberID, memberName: currentMemberName)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func releaseReminderAssignment(_ reminder: PlantReminder) {
        do {
            try dataService.releaseReminderAssignment(reminder)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func shouldOfferRainSkip(for reminder: PlantReminder) -> Bool {
        guard reminder.reminderType == .watering,
              viewModel.weatherAlerts.contains(where: { $0.type == .heavyRain })
        else { return false }
        return reminder.nextDueDate <= Date().addingTimeInterval(24 * 60 * 60)
    }

    private func skipReminderForRain(_ reminder: PlantReminder) {
        do {
            try dataService.snoozeReminder(reminder, for: .tomorrow)
            Task<Void, Never> {
                await viewModel.load(
                    dataService: dataService,
                    locationService: locationService,
                    notificationService: notificationService
                )
            }
        } catch {
            viewModel.errorMessage = "Failed to skip watering: \(error.localizedDescription)"
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

    private func harvestTotalCard(_ summary: String) -> some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: "basket.fill",
                color: CultivationTheme.Colors.accentCoral,
                size: 42,
                iconSize: 18
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Harvest")
                    .font(CultivationTheme.Fonts.body(11, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text(summary)
                    .font(CultivationTheme.Fonts.display(15, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("home_card_harvest_total")
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
