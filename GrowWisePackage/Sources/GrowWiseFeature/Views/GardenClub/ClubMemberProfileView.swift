import GrowWiseModels
import SwiftUI

struct ClubMemberProfileView: View {
    @Environment(\.dismiss)
    private var dismiss

    let profile: ClubMemberProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    header

                    if profile.canShowPublicDetails {
                        publicDetails
                    } else {
                        privateProfileMessage
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Member Profile")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("clubprofile_button_done")
                    }
                }
        }
        .accessibilityIdentifier("clubprofile_screen")
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 84, height: 84)
                Text(profile.avatarLetters)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("clubprofile_avatar")

            VStack(spacing: 5) {
                Text(profile.displayName)
                    .font(CultivationTheme.Fonts.display(26, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("clubprofile_label_name")

                HStack(spacing: 8) {
                    Label(profile.roleTitle, systemImage: profile.roleTitle == "Owner" ? "crown.fill" : "person.fill")
                    if profile.isCurrentUser {
                        Text("You")
                    }
                }
                .font(CultivationTheme.Fonts.body(13, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .accessibilityIdentifier("clubprofile_label_role")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    private var publicDetails: some View {
        VStack(spacing: CultivationTheme.Spacing.rowGap) {
            if let bio = profile.bio {
                profileSection(title: "Bio") {
                    Text(bio)
                        .font(CultivationTheme.Fonts.body(15))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            profileSection(title: "Garden Snapshot") {
                VStack(spacing: 12) {
                    if let hardinessZone = profile.hardinessZone {
                        factRow(icon: "thermometer.sun.fill", title: "Hardiness Zone", value: hardinessZone)
                    }
                    if let memberSinceDate = profile.memberSinceDate {
                        factRow(
                            icon: "calendar",
                            title: "Member Since",
                            value: memberSinceDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    factRow(icon: "leaf.fill", title: "Plants", value: "\(profile.plantCount ?? 0)")
                    factRow(icon: "globe.americas.fill", title: "Public Gardens", value: "\(profile.publicGardenCount ?? 0)")
                }
            }

            profileSection(title: "Recent Contributions") {
                if profile.recentContributions.isEmpty {
                    emptyContributionRow
                } else {
                    VStack(spacing: CultivationTheme.Spacing.rowGap) {
                        ForEach(profile.recentContributions, id: \.id) { activity in
                            contributionRow(activity)
                        }
                    }
                }
            }
        }
    }

    private var privateProfileMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Text("This member has not shared a public profile.")
                .font(CultivationTheme.Fonts.body(15))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("clubprofile_private_message")
    }

    private var emptyContributionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            Text("No recent contributions")
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
        }
    }

    private func profileSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text(title)
                .sectionLabelStyle()
                .padding(.leading, 4)
            content()
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
        }
    }

    private func factRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .frame(width: 24)
            Text(title)
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
    }

    private func contributionRow(_ activity: ClubActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: contributionIcon(for: activity.activityType))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.activityDescription ?? activity.activityType ?? "Shared an update")
                    .font(CultivationTheme.Fonts.body(14, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                if let timestamp = activity.timestamp {
                    Text(timestamp.formatted(date: .abbreviated, time: .omitted))
                        .font(CultivationTheme.Fonts.body(11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            Spacer()
        }
    }

    private func contributionIcon(for activityType: String?) -> String {
        switch activityType {
        case "watered": "drop.fill"
        case "harvested": "scissors"
        case "planted": "leaf.fill"
        case "journaled": "book.fill"
        case "diagnosed": "stethoscope"
        default: "sparkles"
        }
    }
}
