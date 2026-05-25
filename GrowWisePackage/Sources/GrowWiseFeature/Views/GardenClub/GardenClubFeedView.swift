import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

private let logger = Logger(subsystem: "com.growwise", category: "GardenClubFeedView")

/// Tab-3 entry point for Garden Club. Top-of-screen share prompt, segmented
/// feed (Club / Nearby / Following), and post cards. The "smart match" card
/// surfaces when nearby growers are tracking the same plant species as the user.
///
/// See ADR-019 and the v2 mockup at docs/mockups/cultivation-simplified-wireflow.html.
public struct GardenClubFeedView: View { // swiftlint:disable:this type_body_length
    @Environment(DataService.self)
    private var dataService
    @Environment(LocationService.self)
    private var locationService
    @Environment(ClubCloudKitService.self)
    private var clubCloudKitService

    @State private var selectedSegment: FeedSegment = .club
    @State private var posts: [ClubActivityViewData] = []
    @State private var smartMatch: SmartMatchSuggestion?
    @State private var sharedPlants: [Plant] = []
    @State private var clubName: String = "Garden Club"
    @State private var memberCount: Int = 0
    @State private var currentMemberID: String?
    @State private var currentZone: String?
    @State private var followedMemberIDs: [String] = []
    @State private var userInitial: String = "?"
    @State private var userName: String = "Gardener"
    @State private var isPresentingComposer = false
    @State private var followErrorMessage: String?

    private let club: GardenClub?

    public init(club: GardenClub? = nil) {
        self.club = club
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    header
                    sharePrompt
                    sharedPlantsStrip
                    segmentControl
                    feed
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task { await load() }
        .sheet(isPresented: $isPresentingComposer) {
            ClubShareComposerSheet(plant: nil, club: club, onPost: {
                Task<Void, Never> { await load() }
            })
            .environment(dataService)
            .environment(clubCloudKitService)
        }
        .alert(
            "Could not update follow",
            isPresented: Binding(
                get: { followErrorMessage != nil },
                set: { if !$0 { followErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("club_alert_follow_ok")
        } message: {
            Text(followErrorMessage ?? "Try again.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your club")
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text(clubName)
                    .font(CultivationTheme.Fonts.display(28, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(memberCount)")
                    .font(CultivationTheme.Fonts.display(20, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("members")
                    .font(CultivationTheme.Fonts.body(11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("club_header")
    }

    // MARK: - Share prompt (coral CTA)

    private var sharePrompt: some View {
        Button { isPresentingComposer = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(userInitial)
                            .font(CultivationTheme.Fonts.display(14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text("Share what's growing, ")
                            .font(CultivationTheme.Fonts.body(13, weight: .semibold)) +
                            Text("\(userName).")
                            .font(CultivationTheme.Fonts.displayItalic(13, weight: .medium))
                    )
                    .foregroundStyle(.white)
                    Text("Tap to add a photo")
                        .font(CultivationTheme.Fonts.body(11))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.accentCoral)
                    .shadow(color: CultivationTheme.Colors.accentCoral.opacity(0.35), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("club_share_prompt")
        .accessibilityLabel("Share what's growing")
    }

    // MARK: - Shared plants

    @ViewBuilder private var sharedPlantsStrip: some View {
        if !sharedPlants.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shared plants")
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sharedPlants) { plant in
                            sharedPlantChip(plant)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .accessibilityIdentifier("club_shared_plants")
        }
    }

    private func sharedPlantChip(_ plant: Plant) -> some View {
        let isReadOnly = plant.isReadOnlySharedPlant(for: dataService.getCurrentUser()?.id.uuidString)

        return HStack(spacing: 8) {
            Image(systemName: plant.plantType?.iconName ?? "leaf.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .frame(width: 26, height: 26)
                .background(Circle().fill(CultivationTheme.Colors.brandLeaf.opacity(0.1)))

            VStack(alignment: .leading, spacing: 1) {
                Text(plant.name ?? "Shared plant")
                    .font(CultivationTheme.Fonts.display(13, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(isReadOnly ? "Read-only" : "Shared care")
                    .font(CultivationTheme.Fonts.body(10, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.25), lineWidth: 1)
        )
        .accessibilityIdentifier("club_shared_plant_\(plant.id?.uuidString ?? "unknown")")
    }

    // MARK: - Segmented control

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(FeedSegment.allCases) { segment in
                Button {
                    withAnimation(CultivationTheme.Animation.selection) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(CultivationTheme.Fonts.body(11, weight: selectedSegment == segment ? .semibold : .medium))
                        .foregroundStyle(
                            selectedSegment == segment
                                ? CultivationTheme.Colors.textPrimary
                                : CultivationTheme.Colors.textTertiary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSegment == segment ? CultivationTheme.Colors.cardSurface : Color.clear)
                                .shadow(
                                    color: selectedSegment == segment
                                        ? Color(red: 0.12, green: 0.16, blue: 0.13, opacity: 0.14)
                                        : .clear,
                                    radius: 6,
                                    y: 2
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(Self.segmentAccessibilityIdentifier(segment))
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
        .accessibilityIdentifier("club_segment_control")
    }

    // MARK: - Feed body

    @ViewBuilder private var feed: some View {
        let visiblePosts = Self.filteredPosts(
            posts,
            for: selectedSegment,
            currentZone: currentZone,
            followedMemberIDs: followedMemberIDs,
            currentMemberID: currentMemberID
        )

        switch selectedSegment {
        case .club:
            if visiblePosts.isEmpty {
                emptyState(message: "Be the first to share what's growing.")
            } else {
                postList(visiblePosts, includesSmartMatch: true)
            }

        case .nearby:
            if visiblePosts.isEmpty {
                emptyState(message: nearbyEmptyMessage)
            } else {
                postList(visiblePosts, includesSmartMatch: false)
            }

        case .following:
            if visiblePosts.isEmpty {
                emptyState(message: followingEmptyMessage)
            } else {
                postList(visiblePosts, includesSmartMatch: false)
            }
        }
    }

    private func postList(_ posts: [ClubActivityViewData], includesSmartMatch: Bool) -> some View {
        VStack(spacing: 14) {
            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                if includesSmartMatch, index == 1, let match = smartMatch {
                    smartMatchCard(match)
                }
                ClubPostCard(
                    post: post,
                    isFollowingAuthor: Self.isFollowingMember(post.memberID, followedMemberIDs: followedMemberIDs),
                    canFollowAuthor: canFollowAuthor(post),
                    onToggleFollow: { toggleFollow(post.memberID) }
                )
            }
            if includesSmartMatch, posts.count < 2, let match = smartMatch {
                smartMatchCard(match)
            }
        }
    }

    private var nearbyEmptyMessage: String {
        if let currentZone {
            "No posts in Zone \(currentZone) yet."
        } else {
            "Add your hardiness zone to see nearby growers."
        }
    }

    private var followingEmptyMessage: String {
        followedMemberIDs.isEmpty ? "Follow someone to see their posts." : "No posts from followed growers yet."
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Text("No posts yet")
                .font(CultivationTheme.Fonts.display(18, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text(message)
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityIdentifier("club_empty_state")
    }

    private func smartMatchCard(_ match: SmartMatchSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SmartTag(label: "Smart match · \(match.count) nearby growers")
                .accessibilityIdentifier("club_smart_match_tag")

            (
                Text("\(match.count) people in ")
                    + Text("your zone").bold()
                    + Text(" are growing \(match.plantName) too. Want to see their tips?")
            )
            .font(CultivationTheme.Fonts.display(15).italic())
            .foregroundStyle(CultivationTheme.Colors.textPrimary)
            .lineLimit(nil)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .strokeBorder(
                    CultivationTheme.Colors.brandLeaf,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
        .accessibilityIdentifier("club_smart_match")
    }

    private func canFollowAuthor(_ post: ClubActivityViewData) -> Bool {
        Self.canFollowMember(post.memberID, currentMemberID: currentMemberID)
    }

    private func toggleFollow(_ memberID: String) {
        do {
            if Self.isFollowingMember(memberID, followedMemberIDs: followedMemberIDs) {
                try dataService.unfollowClubMember(memberID)
            } else {
                try dataService.followClubMember(memberID)
            }
            followedMemberIDs = dataService.getCurrentUser()?.followedMemberIDs ?? []
        } catch {
            followErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Data load

    @MainActor
    private func load() async {
        let user = dataService.getCurrentUser()
        configureCurrentUser(user)

        if let activeClub = resolveActiveClub() {
            await loadActiveClub(activeClub)
        } else {
            resetClub()
        }

        updateSmartMatch()
    }

    private func configureCurrentUser(_ user: User?) {
        currentMemberID = user?.id.uuidString
        currentZone = locationService.hardinessZone ?? user?.hardinessZone
        followedMemberIDs = user?.followedMemberIDs ?? []
        userName = Self.firstName(from: user?.displayName)
        userInitial = String(userName.prefix(1)).uppercased()
    }

    private func resolveActiveClub() -> GardenClub? {
        if let explicit = club {
            return explicit
        }

        do {
            return try dataService.fetchClubs().first
        } catch {
            logger.error("Failed to fetch clubs: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func loadActiveClub(_ activeClub: GardenClub) async {
        clubName = activeClub.name ?? "Garden Club"
        memberCount = activeClub.memberIDs?.count ?? 0
        loadSharedPlants(for: activeClub)

        guard let clubID = activeClub.id else {
            posts = []
            return
        }

        posts = await mergedPosts(for: activeClub, clubID: clubID)
    }

    private func loadSharedPlants(for club: GardenClub) {
        do {
            sharedPlants = try dataService.fetchSharedPlants(for: club)
        } catch {
            logger.error("Failed to fetch shared plants: \(error.localizedDescription, privacy: .public)")
            sharedPlants = []
        }
    }

    private func mergedPosts(for activeClub: GardenClub, clubID: UUID) async -> [ClubActivityViewData] {
        var merged = fetchLocalActivities(for: clubID).map(Self.viewData(from:))
        do {
            let ckRecords = try await clubCloudKitService.fetchRecentActivities(
                for: activeClub,
                memberID: currentMemberID,
                limit: 50
            )
            let ckViewData = ckRecords.map(Self.viewData(from:))
            let ckIDs = Set(ckViewData.map(\.id))
            let localOnly = merged.filter { !ckIDs.contains($0.id) }
            merged = ckViewData + localOnly
        } catch {
            logger.warning(
                "CloudKit fetch unavailable, using SwiftData-only feed: \(error.localizedDescription, privacy: .public)"
            )
        }
        return merged
    }

    private func fetchLocalActivities(for clubID: UUID) -> [ClubActivity] {
        do {
            return try dataService.fetchClubActivities(for: clubID)
        } catch {
            logger.error("Failed to fetch local club activities: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func resetClub() {
        clubName = "Garden Club"
        memberCount = 0
        posts = []
        sharedPlants = []
    }

    private func updateSmartMatch() {
        if let zone = currentZone {
            smartMatch = SmartMatchSuggestion(count: 3, zone: zone, plantName: "Cherokee Purple")
        } else {
            smartMatch = nil
        }
    }
}
