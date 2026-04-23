import GrowWiseModels
import SwiftUI

/// Home-tab card surfacing the latest post from the user's club with a coral/honey
/// gradient banner. Rendered only when HomeViewModel.latestClubPost is non-nil.
struct YourClubCard: View {
    let post: ClubActivity

    private var displayName: String {
        post.memberName ?? "Member"
    }

    private var caption: String? {
        let raw = post.activityDescription
        return (raw?.isEmpty ?? true) ? nil : raw
    }

    private var relativeTime: String? {
        guard let timestamp = post.timestamp else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("✦")
                Text("Your Club")
            }
            .font(CultivationTheme.Fonts.body(10, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(.white)

            if let caption {
                Text(caption)
                    .font(CultivationTheme.Fonts.display(16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Text(displayName)
                    .fontWeight(.semibold)
                if let relativeTime {
                    Text("· \(relativeTime)")
                }
            }
            .font(CultivationTheme.Fonts.body(11))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Gradients.warmAccent)
                .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.25), radius: 12, y: 6)
        )
        .accessibilityIdentifier("home_card_your_club")
        .accessibilityLabel("Latest from Your Club")
    }
}
