import GrowWiseServices
import SwiftUI

struct StarterPlanCard: View {
    let actions: [StarterPlanAction]
    let onSelect: (StarterPlanAction) -> Void

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
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("home_starter_plan_card")
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
