// HomeView: Task-focused morning dashboard
// Hero header with greeting + stat cards, urgency-grouped task list, seasonal tip.

import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct HomeView: View {
    @Environment(DataService.self)
    private var dataService

    @State private var viewModel = HomeViewModel()

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
                        .padding(.bottom, CultivationTheme.Spacing.sectionGap)
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
            .accessibilityIdentifier("home_screen")
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
