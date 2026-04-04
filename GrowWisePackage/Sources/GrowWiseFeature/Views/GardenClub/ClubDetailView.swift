import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct ClubDetailView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub

    @State private var activities: [ClubActivity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLeaveAlert = false
    @State private var showRemoveMemberAlert = false
    @State private var memberToRemove: String?
    @State private var codeCopied = false

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    private var isOwner: Bool {
        club.ownerID == currentUserID
    }

    private var memberCount: Int {
        (club.memberIDs ?? []).count
    }

    private var inviteCode: String {
        club.inviteCode ?? "------"
    }

    private var recentActivities: [ClubActivity] {
        Array(activities.prefix(10))
    }

    public init(club: GardenClub) {
        self.club = club
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            scrollContent
        }
        .navigationTitle(club.name ?? "Club")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .toolbar { toolbarContent }
            .task { await loadActivities() }
            .alert("Leave Club", isPresented: $showLeaveAlert) {
                Button("Leave", role: .destructive) { Task { await leaveClub() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to leave this club?")
            }
            .alert("Remove Member", isPresented: $showRemoveMemberAlert, presenting: memberToRemove) { id in
                Button("Remove", role: .destructive) { Task { await removeMember(id) } }
                Button("Cancel", role: .cancel) { memberToRemove = nil }
            } message: { _ in
                Text("Remove this member from the club?")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                headerCard
                inviteCodeCard
                membersSection
                sharedGardensSection
                recentActivitySection
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 60, height: 60)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name ?? "Unnamed Club")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Label("\(memberCount) member\(memberCount == 1 ? "" : "s")", systemImage: "person.fill")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            Spacer()

            if isOwner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CultivationTheme.Colors.accentAmber)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Invite Code

    private var inviteCodeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Invite Code")
                .sectionLabelStyle()
                .padding(.leading, 4)

            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = inviteCode
                #endif
                withAnimation { codeCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { codeCopied = false }
                }
            } label: {
                HStack {
                    Text(inviteCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(CultivationTheme.Colors.brandForest)
                        .tracking(6)

                    Spacer()

                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            codeCopied
                                ? CultivationTheme.Colors.statusHealthy
                                : CultivationTheme.Colors.textTertiary
                        )
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("club_detail_invite_code")

            Text("Tap to copy • Share with friends to invite them")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Members")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: CultivationTheme.Spacing.rowGap) {
                ForEach(club.memberIDs ?? [], id: \.self) { memberID in
                    memberRow(memberID: memberID)
                }
            }
        }
    }

    private func memberRow(memberID: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Colors.brandMint)
                    .frame(width: 36, height: 36)
                Text(memberID.prefix(1).uppercased())
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(memberID == club.ownerID ? "Owner" : "Member")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    if memberID == club.ownerID {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CultivationTheme.Colors.accentAmber)
                    }
                }
                Text(memberID == currentUserID ? "You" : memberID.prefix(8) + "…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            Spacer()

            // Owner action: remove member
            if isOwner, memberID != currentUserID {
                Button {
                    memberToRemove = memberID
                    showRemoveMemberAlert = true
                } label: {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 16))
                        .foregroundStyle(CultivationTheme.Colors.statusAlert)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("club_remove_member_\(memberID)")
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Shared Gardens

    private var sharedGardensSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Shared Gardens")
                .sectionLabelStyle()
                .padding(.leading, 4)

            let gardens = club.sharedGardenIDs ?? []
            if gardens.isEmpty {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Text("No gardens shared yet")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
            } else {
                ForEach(gardens, id: \.self) { gardenID in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                                .fill(CultivationTheme.Colors.brandMint)
                                .frame(width: 36, height: 36)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(CultivationTheme.Colors.brandForest)
                        }
                        Text(gardenID.prefix(8) + "…")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Recent Activity")
                .sectionLabelStyle()
                .padding(.leading, 4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if recentActivities.isEmpty {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    Text("No recent activity")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
            } else {
                ForEach(recentActivities, id: \.id) { activity in
                    ActivityRowView(activity: activity)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let code = club.inviteCode {
                    ShareLink(
                        item: "Join my garden club on GrowWise! Invite code: \(code)",
                        subject: Text("Garden Club Invite"),
                        message: Text("Use code \(code) to join on GrowWise")
                    ) {
                        Label("Share Invite Code", systemImage: "square.and.arrow.up")
                    }
                }
                if !isOwner {
                    Divider()
                    Button(role: .destructive) {
                        showLeaveAlert = true
                    } label: {
                        Label("Leave Club", systemImage: "person.badge.minus")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }
            .accessibilityIdentifier("club_detail_menu")
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadActivities() async {
        isLoading = true
        defer { isLoading = false }
        do {
            activities = try dataService.fetchClubActivities(for: club.id ?? UUID())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func leaveClub() async {
        do {
            try dataService.leaveClub(clubID: club.id ?? UUID(), memberID: currentUserID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func removeMember(_ memberID: String) async {
        do {
            try dataService.removeMember(memberID: memberID, clubID: club.id ?? UUID(), requestingMemberID: currentUserID)
            memberToRemove = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Activity Row

private struct ActivityRowView: View {
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
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
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

#Preview {
    let club = GardenClub(name: "Backyard Growers", ownerID: "user1", inviteCode: "GROW42")
    NavigationStack {
        ClubDetailView(club: club)
    }
}
