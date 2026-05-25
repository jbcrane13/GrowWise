import CloudKit
import GrowWiseModels
import GrowWiseServices
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.growwise", category: "GardenClubFeedView")

// SwiftLint suppression for the v1.1 beta Club feed surface; follow-up refactor can split view/data loading.
// swiftlint:disable file_length function_body_length

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

    private let club: GardenClub?

    public init(club: GardenClub? = nil) {
        self.club = club
    }

    enum FeedSegment: String, CaseIterable, Identifiable {
        case club = "Club feed"
        case nearby = "Nearby"
        case following = "Following"
        var id: String {
            rawValue
        }
    }

    struct SmartMatchSuggestion {
        let count: Int
        let zone: String
        let plantName: String
    }

    /// Presentation-only adapter for ClubActivity. Maps the SwiftData model's
    /// fields onto the surface the post card consumes. Allowed under strict MV —
    /// view-local presentation types are fine; a separate ViewModel class is not.
    /// Per the 2026-04-22 plan Phase 5 Adapter note.
    struct ClubActivityViewData: Identifiable {
        let id: UUID
        let memberID: String
        let authorDisplayName: String
        let caption: String?
        let gardenName: String?
        let hardinessZone: String?
        let photoURL: String?
        let relativeTimeLabel: String?
        let likeCount: Int
        let commentCount: Int
    }

    struct ClubFeedBetaState {
        let posts: [ClubActivityViewData]
        let currentMemberID: String?
        let currentZone: String?
        let followedMemberIDs: [String]

        func posts(for segment: FeedSegment) -> [ClubActivityViewData] {
            switch segment {
            case .club:
                return posts

            case .nearby:
                guard let currentZone = Self.normalizedZone(currentZone) else { return [] }
                let currentMemberID = Self.normalizedMemberID(currentMemberID)
                return posts.filter { post in
                    guard let postMemberID = Self.normalizedMemberID(post.memberID),
                          let postZone = Self.normalizedZone(post.hardinessZone)
                    else {
                        return false
                    }
                    return postZone == currentZone && postMemberID != currentMemberID
                }

            case .following:
                let followed = Set(followedMemberIDs.compactMap(Self.normalizedMemberID))
                guard !followed.isEmpty else { return [] }
                return posts.filter { post in
                    guard let postMemberID = Self.normalizedMemberID(post.memberID) else { return false }
                    return followed.contains(postMemberID)
                }
            }
        }

        func emptyMessage(for segment: FeedSegment) -> String {
            switch segment {
            case .club:
                "Be the first to share what's growing."

            case .nearby:
                Self.normalizedZone(currentZone) == nil
                    ? "Add your hardiness zone to discover nearby growers."
                    : "No posts in your zone yet."

            case .following:
                "Follow someone to see their posts."
            }
        }

        private static func normalizedMemberID(_ memberID: String?) -> String? {
            memberID?.trimmedNonEmpty
        }

        private static func normalizedZone(_ zone: String?) -> String? {
            zone?.trimmedNonEmpty?.lowercased()
        }
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
                .accessibilityIdentifier("club_segment_\(segment.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
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
        let state = ClubFeedBetaState(
            posts: posts,
            currentMemberID: currentMemberID,
            currentZone: currentZone,
            followedMemberIDs: followedMemberIDs
        )
        let visiblePosts = state.posts(for: selectedSegment)

        if visiblePosts.isEmpty {
            emptyState(message: state.emptyMessage(for: selectedSegment))
        } else {
            postList(visiblePosts)
        }
    }

    private func postList(_ visiblePosts: [ClubActivityViewData]) -> some View {
        VStack(spacing: 14) {
            ForEach(Array(visiblePosts.enumerated()), id: \.element.id) { index, post in
                if selectedSegment == .club, index == 1, let match = smartMatch {
                    smartMatchCard(match)
                }
                ClubPostCard(post: post)
            }
            if selectedSegment == .club, visiblePosts.count < 2, let match = smartMatch {
                smartMatchCard(match)
            }
        }
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

    // MARK: - Data load

    @MainActor
    private func load() async {
        let user = dataService.getCurrentUser()
        userName = firstName(from: user?.displayName)
        userInitial = String(userName.prefix(1)).uppercased()
        currentMemberID = user?.id.uuidString
        currentZone = (locationService.hardinessZone ?? user?.hardinessZone)?.trimmedNonEmpty
        followedMemberIDs = user?.followedMemberIDs.compactMap(\.trimmedNonEmpty) ?? []

        // Resolve the active club: explicit > first available > none.
        let resolved: GardenClub?
        if let explicit = club {
            resolved = explicit
        } else {
            do {
                resolved = try dataService.fetchClubs().first
            } catch {
                logger.error("Failed to fetch clubs: \(error.localizedDescription, privacy: .public)")
                resolved = nil
            }
        }

        if let activeClub = resolved {
            clubName = activeClub.name ?? "Garden Club"
            memberCount = activeClub.memberIDs?.count ?? 0
            do {
                sharedPlants = try dataService.fetchSharedPlants(for: activeClub)
            } catch {
                logger.error("Failed to fetch shared plants: \(error.localizedDescription, privacy: .public)")
                sharedPlants = []
            }
            guard let clubID = activeClub.id else {
                posts = []
                return
            }

            // Fetch from SwiftData as the baseline.
            var localActivities: [ClubActivity] = []
            do {
                localActivities = try dataService.fetchClubActivities(for: clubID)
            } catch {
                logger.error("Failed to fetch local club activities: \(error.localizedDescription, privacy: .public)")
            }

            // Attempt a CloudKit fetch. On any error (no iCloud account, network
            // outage, etc.) log a warning and fall through to the SwiftData results.
            var merged: [ClubActivityViewData] = localActivities.map(Self.viewData(from:))
            do {
                let ckRecords = try await clubCloudKitService.fetchRecentActivities(
                    for: activeClub,
                    memberID: dataService.getCurrentUser()?.id.uuidString,
                    limit: 50
                )
                let ckViewData = ckRecords.map(Self.viewData(from:))

                // Merge: start with CloudKit records (source of truth), then append
                // any local records whose IDs are not already represented in CloudKit.
                let ckIDs = Set(ckViewData.map(\.id))
                let localOnly = merged.filter { !ckIDs.contains($0.id) }
                merged = ckViewData + localOnly
            } catch {
                logger.warning(
                    "CloudKit fetch unavailable, using SwiftData-only feed: \(error.localizedDescription, privacy: .public)"
                )
            }

            posts = merged
            smartMatch = Self.smartMatch(
                from: merged,
                currentMemberID: currentMemberID,
                currentZone: currentZone,
                sharedPlants: sharedPlants
            )
        } else {
            clubName = "Garden Club"
            memberCount = 0
            posts = []
            sharedPlants = []
            smartMatch = nil
        }
    }

    static func viewData(from activity: ClubActivity) -> ClubActivityViewData {
        let id = activity.id ?? UUID()
        let memberID = activity.memberID?.trimmedNonEmpty ?? ""
        let author = activity.memberName?.trimmedNonEmpty ?? "Member"
        let caption = activity.activityDescription?.trimmedNonEmpty
        let label: String?
        if let timestamp = activity.timestamp {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            label = formatter.localizedString(for: timestamp, relativeTo: .now)
        } else {
            label = nil
        }
        return ClubActivityViewData(
            id: id,
            memberID: memberID,
            authorDisplayName: author,
            caption: caption,
            gardenName: activity.gardenName?.trimmedNonEmpty,
            hardinessZone: activity.hardinessZone?.trimmedNonEmpty,
            photoURL: activity.photoURL?.trimmedNonEmpty,
            relativeTimeLabel: label,
            likeCount: 0, // future feature
            commentCount: 0 // future feature
        )
    }

    /// Maps a raw `CKRecord` for a `ClubActivity` CloudKit record onto the
    /// presentation type. Field names must match those written by
    /// `ClubCloudKitService.publishActivity(_:)`.
    static func viewData(from record: CKRecord) -> ClubActivityViewData {
        // The record name is the activity UUID stored as a string by publishActivity.
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let memberID = (record["memberID"] as? String)?.trimmedNonEmpty ?? ""
        let author = (record["memberName"] as? String)?.trimmedNonEmpty ?? "Member"
        let caption = (record["activityDescription"] as? String)?.trimmedNonEmpty
        let gardenName = (record["gardenName"] as? String)?.trimmedNonEmpty
        let hardinessZone = (record["hardinessZone"] as? String)?.trimmedNonEmpty
        let photoURL = (record["photo"] as? CKAsset)?.fileURL?.absoluteString
            ?? (record["photoURL"] as? String)?.trimmedNonEmpty
        let timestamp = record["timestamp"] as? Date
        let label: String?
        if let timestamp {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            label = formatter.localizedString(for: timestamp, relativeTo: .now)
        } else {
            label = nil
        }
        return ClubActivityViewData(
            id: id,
            memberID: memberID,
            authorDisplayName: author,
            caption: caption,
            gardenName: gardenName,
            hardinessZone: hardinessZone,
            photoURL: photoURL,
            relativeTimeLabel: label,
            likeCount: 0, // future feature
            commentCount: 0 // future feature
        )
    }

    static func smartMatch(
        from posts: [ClubActivityViewData],
        currentMemberID: String?,
        currentZone: String?,
        sharedPlants: [Plant]
    ) -> SmartMatchSuggestion? {
        guard let currentZone = currentZone?.trimmedNonEmpty?.lowercased() else { return nil }
        let currentMemberID = currentMemberID?.trimmedNonEmpty
        let nearbyMemberIDs = Set(posts.compactMap { post -> String? in
            guard let memberID = post.memberID.trimmedNonEmpty,
                  let postZone = post.hardinessZone?.trimmedNonEmpty?.lowercased(),
                  postZone == currentZone,
                  memberID != currentMemberID
            else {
                return nil
            }
            return memberID
        })
        guard !nearbyMemberIDs.isEmpty else { return nil }
        return SmartMatchSuggestion(
            count: nearbyMemberIDs.count,
            zone: currentZone,
            plantName: sharedPlants.first?.name ?? "your plants"
        )
    }

    private func firstName(from displayName: String?) -> String {
        guard let displayName,
              let first = displayName.split(separator: " ").first
        else {
            return "Gardener"
        }
        return String(first)
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// swiftlint:enable file_length function_body_length
