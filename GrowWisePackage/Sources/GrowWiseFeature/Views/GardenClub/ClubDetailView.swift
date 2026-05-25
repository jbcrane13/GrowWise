import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes type_body_length

private struct SelectedMember: Identifiable {
    let id: String
}

public struct ClubDetailView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub

    @State private var activities: [ClubActivity] = []
    @State private var memberUsers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLeaveAlert = false
    @State private var showRemoveMemberAlert = false
    @State private var memberToRemove: String?
    @State private var selectedMemberID: String?
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
            .task { await loadClubData() }
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
            .navigationDestination(isPresented: $navigateToChat) {
                ClubChatView(club: club)
            }
            .navigationDestination(isPresented: $navigateToEvents) {
                ClubEventsView(club: club)
            }
            .sheet(item: Binding(
                get: { selectedMemberID.map { SelectedMember(id: $0) } },
                set: { selectedMemberID = $0?.id }
            )) { selection in
                ClubMemberProfileView(profile: memberProfile(for: selection.id))
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
                Task<Void, Never> {
                    try? await Task.sleep(for: .seconds(2))
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
        let profile = memberProfile(for: memberID)

        return HStack(spacing: 12) {
            Button {
                selectedMemberID = memberID
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CultivationTheme.Colors.brandMint)
                            .frame(width: 36, height: 36)
                        Text(profile.avatarLetters)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(CultivationTheme.Colors.brandForest)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(profile.displayName)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            if memberID == club.ownerID {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(CultivationTheme.Colors.accentAmber)
                            }
                        }
                        Text(profile.isCurrentUser ? "You" : profile.roleTitle)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clubprofile_button_member_\(accessibilitySafeMemberID(memberID))")

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

    // MARK: - Navigation Destinations

    @State private var navigateToChat = false
    @State private var navigateToEvents = false

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 16) {
                Button {
                    navigateToChat = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }
                .accessibilityIdentifier("club_detail_chat_button")

                Button {
                    navigateToEvents = true
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }
                .accessibilityIdentifier("club_detail_events_button")

                Menu {
                    if let code = club.inviteCode {
                        ShareLink(
                            item: ClubInviteSharing.shareItem(code: code),
                            subject: Text("Garden Club Invite"),
                            message: Text(ClubInviteSharing.shareMessage(clubName: club.name, code: code))
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
    }

    // MARK: - Actions

    @MainActor
    private func loadClubData() async {
        loadMemberUsers()
        await loadActivities()
    }

    @MainActor
    private func loadMemberUsers() {
        let memberIDs = Set(club.memberIDs)

        guard !memberIDs.isEmpty else {
            memberUsers = []
            return
        }

        do {
            memberUsers = try dataService.users.fetchAll().filter { memberIDs.contains($0.id.uuidString) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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

    private func memberProfile(for memberID: String) -> ClubMemberProfile {
        ClubMemberProfile(
            memberID: memberID,
            club: club,
            user: memberUser(for: memberID),
            activities: activities,
            currentUserID: currentUserID
        )
    }

    private func memberUser(for memberID: String) -> User? {
        if let currentUser = dataService.getCurrentUser(),
           currentUser.id.uuidString == memberID
        {
            return currentUser
        }
        return memberUsers.first { $0.id.uuidString == memberID }
    }

    private func accessibilitySafeMemberID(_ memberID: String) -> String {
        String(memberID.map { character in
            character.isLetter || character.isNumber ? character : "_"
        })
    }
}

#Preview {
    let club = GardenClub(name: "Backyard Growers", ownerID: "user1", inviteCode: "GROW42")
    NavigationStack {
        ClubDetailView(club: club)
    }
}

// swiftlint:enable attributes type_body_length
