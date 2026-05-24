import Foundation
import GrowWiseModels
import SwiftUI

struct ActivityRowView: View {
    let activity: ClubActivity

    private var icon: String {
        switch activity.activityType {
        case "watered": "drop.fill"
        case "harvested": "scissors"
        case "planted": "leaf.fill"
        case "journaled": "book.fill"
        case "diagnosed": "stethoscope"
        default: "star.fill"
        }
    }

    private var iconColor: Color {
        switch activity.activityType {
        case "watered": .blue
        case "harvested": CultivationTheme.Colors.accentAmber
        case "planted": CultivationTheme.Colors.brandLeaf
        case "journaled": .purple
        case "diagnosed": CultivationTheme.Colors.statusAlert
        default: CultivationTheme.Colors.brandForest
        }
    }

    private var timeAgo: String {
        guard let date = activity.timestamp else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.memberName ?? "A member")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    + Text(" \(activity.activityDescription ?? activity.activityType ?? "did something")")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)

                if !timeAgo.isEmpty {
                    Text(timeAgo)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }
}
