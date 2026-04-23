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
public struct GardenClubFeedView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService

    @State private var selectedSegment: FeedSegment = .club
    @State private var posts: [ClubActivityViewData] = []
    @State private var smartMatch: SmartMatchSuggestion?
    @State private var clubName: String = "Garden Club"
    @State private var memberCount: Int = 0
    @State private var userInitial: String = "?"
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
        .navigationBarHidden(true)
        #endif
        .task { await load() }
        .sheet(isPresented: $isPresentingComposer) {
            // Share composer — real composer wiring is a follow-up issue.
            // First cut: placeholder so the prompt is reachable.
            Text("Share composer placeholder")
                .padding()
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
                    Text("Share what's growing")
                        .font(CultivationTheme.Fonts.body(13))
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
        HStack(spacing: 18) {
            ForEach(FeedSegment.allCases) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    VStack(spacing: 6) {
                        Text(segment.rawValue)
                            .font(CultivationTheme.Fonts.body(13, weight: selectedSegment == segment ? .semibold : .medium))
                            .foregroundStyle(
                                selectedSegment == segment
                                    ? CultivationTheme.Colors.textPrimary
                                    : CultivationTheme.Colors.textTertiary
                            )
                        Rectangle()
                            .fill(selectedSegment == segment ? CultivationTheme.Colors.accentCoral : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("club_segment_\(segment.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
            }
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CultivationTheme.Colors.divider)
                .frame(height: 1)
        }
    }

    // MARK: - Feed body

    @ViewBuilder
    private var feed: some View {
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
            HStack(spacing: 5) {
                Text("\u{2726}")
                Text("Smart match \u{00B7} \(match.count) nearby growers")
            }
            .font(CultivationTheme.Fonts.body(10, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(CultivationTheme.Colors.smartTagForeground)

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
        userInitial = String(user?.displayName?.prefix(1) ?? "?").uppercased()

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
            if let clubID = activeClub.id {
                do {
                    let activities = try dataService.fetchClubActivities(for: clubID)
                    posts = activities.map(Self.viewData(from:))
                } catch {
                    logger.error("Failed to fetch club activities: \(error.localizedDescription, privacy: .public)")
                    posts = []
                }
            } else {
                posts = []
            }
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
                        startPoint: .topLeading, endPoint: .bottomTrailing
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
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 120)

            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
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
