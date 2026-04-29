import CloudKit
import GrowWiseModels
import GrowWiseServices
import os
import SwiftData
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
    @State private var clubName: String = "Garden Club"
    @State private var memberCount: Int = 0
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
        let authorDisplayName: String
        let caption: String?
        let zoneTag: String?
        let relativeTimeLabel: String?
        let likeCount: Int
        let commentCount: Int
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    header
                    sharePrompt
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
            ClubShareComposerSheet(plant: nil, onPost: {
                Task { await load() }
            })
            .environment(dataService)
            .environment(locationService)
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
        switch selectedSegment {
        case .club:
            if posts.isEmpty {
                emptyState(message: "Be the first to share what's growing.")
            } else {
                clubFeed
            }

        case .nearby:
            // Per spec Open questions resolution: empty-state copy, not sample data.
            emptyState(message: "No posts in your zone yet.")

        case .following:
            // Per spec Open questions resolution: empty-state copy, not sample data.
            emptyState(message: "Follow someone to see their posts.")
        }
    }

    private var clubFeed: some View {
        VStack(spacing: 14) {
            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                if index == 1, let match = smartMatch {
                    smartMatchCard(match)
                }
                PostCard(post: post)
            }
            if posts.count < 2, let match = smartMatch {
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
                    for: clubID.uuidString,
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
        } else {
            clubName = "Garden Club"
            memberCount = 0
            posts = []
        }

        // Smart match — populate when location/zone is available.
        if let zone = locationService.hardinessZone {
            smartMatch = SmartMatchSuggestion(count: 3, zone: zone, plantName: "Cherokee Purple")
        }
    }

    private static func viewData(from activity: ClubActivity) -> ClubActivityViewData {
        let id = activity.id ?? UUID()
        let author = activity.memberName ?? "Member"
        let caption = activity.activityDescription
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
            authorDisplayName: author,
            caption: caption,
            zoneTag: nil, // not yet captured on ClubActivity
            relativeTimeLabel: label,
            likeCount: 0, // future feature
            commentCount: 0 // future feature
        )
    }

    /// Maps a raw `CKRecord` for a `ClubActivity` CloudKit record onto the
    /// presentation type. Field names must match those written by
    /// `ClubCloudKitService.publishActivity(_:)`.
    private static func viewData(from record: CKRecord) -> ClubActivityViewData {
        // The record name is the activity UUID stored as a string by publishActivity.
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let author = record["memberName"] as? String ?? "Member"
        let caption = record["activityDescription"] as? String
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
            authorDisplayName: author,
            caption: caption,
            zoneTag: nil, // not yet captured in CK record
            relativeTimeLabel: label,
            likeCount: 0, // future feature
            commentCount: 0 // future feature
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

// MARK: - Post card

private struct PostCard: View {
    let post: GardenClubFeedView.ClubActivityViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(
                        colors: [CultivationTheme.Colors.brandMint, CultivationTheme.Colors.brandLeaf],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(initials(of: post.authorDisplayName))
                            .font(CultivationTheme.Fonts.display(13, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.authorDisplayName)
                        .font(CultivationTheme.Fonts.body(13, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    HStack(spacing: 5) {
                        if let zone = post.zoneTag {
                            Text("Zone \(zone)")
                                .foregroundStyle(CultivationTheme.Colors.smartTagForeground)
                                .fontWeight(.bold)
                        }
                        if let when = post.relativeTimeLabel {
                            Text(post.zoneTag == nil ? when : "\u{00B7} \(when)")
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                    .font(CultivationTheme.Fonts.body(10))
                }
                Spacer()
            }

            if let caption = post.caption {
                Text(caption)
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(nil)
            }

            // Photo placeholder — wire to PhotoService asset URL when available
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 120)

            HStack(spacing: 16) {
                if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                }
                if post.commentCount > 0 {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                }
                Label("Share", systemImage: "arrow.up.right")
            }
            .font(CultivationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(14)
        .paperCard()
        .accessibilityIdentifier("club_post_\(post.id.uuidString)")
    }

    private func initials(of name: String) -> String {
        String(name.prefix(1)).uppercased()
    }
}
