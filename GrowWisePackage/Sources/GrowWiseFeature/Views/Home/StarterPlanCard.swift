import GrowWiseServices
import SwiftUI

struct StarterPlanCard: View {
    let plan: StarterPlan
    let onSelect: (StarterPlanAction) -> Void

    private var actions: [StarterPlanAction] {
        plan.actions
    }

    private var upcomingDays: [StarterPlanDay] {
        plan.days.filter { !$0.tasks.isEmpty }.prefix(5).map(\.self)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Starter plan")
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                Spacer()

                Text("\(actions.count) steps")
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            ForEach(actions) { action in
                Button {
                    onSelect(action)
                } label: {
                    StarterPlanActionRow(action: action)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home_starter_plan_action_\(action.kind.rawValue)")
            }

            if !upcomingDays.isEmpty {
                Divider()
                    .background(CultivationTheme.Colors.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Next 14 days")
                        .font(CultivationTheme.Fonts.body(11, weight: .bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)

                    ForEach(upcomingDays) { day in
                        StarterPlanDayRow(day: day)
                    }
                }
                .accessibilityIdentifier("home_starter_plan_days")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("home_starter_plan_card")
    }
}

private struct StarterPlanDayRow: View {
    let day: StarterPlanDay

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("D\(day.dayOffset + 1)")
                .font(CultivationTheme.Fonts.body(10, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .frame(width: 32, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CultivationTheme.Colors.brandLeaf.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                ForEach(day.tasks.prefix(2)) { task in
                    Text(task.title)
                        .font(CultivationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("home_starter_plan_day_\(day.dayOffset)")
    }
}

private struct StarterPlanActionRow: View {
    let action: StarterPlanAction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(tint.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(CultivationTheme.Fonts.display(14, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(action.detail)
                    .font(CultivationTheme.Fonts.body(11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private var tint: Color {
        switch action.kind {
        case .createGarden, .addPlant:
            CultivationTheme.Colors.brandLeaf

        case .reviewWateringReminder:
            CultivationTheme.Colors.accentSky

        case .browseRecommendations:
            CultivationTheme.Colors.accentAmber

        case .startTutorial:
            CultivationTheme.Colors.accentCoral
        }
    }
}
