import CloudKit
import Foundation
import GrowWiseModels

extension GardenClubFeedView {
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

    /// Presentation-only adapter for ClubActivity. Maps model and CloudKit fields
    /// onto the surface the post card consumes without introducing a ViewModel.
    struct ClubActivityViewData: Identifiable {
        let id: UUID
        let authorDisplayName: String
        let caption: String?
        let zoneTag: String?
        let photoURL: String?
        let relativeTimeLabel: String?
        let likeCount: Int
        let commentCount: Int
        let memberID: String
        let hardinessZone: String?
    }

    static func filteredPosts(
        _ posts: [ClubActivityViewData],
        for segment: FeedSegment,
        currentZone: String?,
        followedMemberIDs: [String],
        currentMemberID: String?
    ) -> [ClubActivityViewData] {
        switch segment {
        case .club:
            return posts

        case .nearby:
            guard let zone = normalizedZone(currentZone) else { return [] }
            let currentID = normalizedMemberID(currentMemberID)
            return posts.filter { post in
                normalizedMemberID(post.memberID) != currentID && normalizedZone(post.hardinessZone) == zone
            }

        case .following:
            let followedIDs = Set(followedMemberIDs.compactMap(normalizedMemberID))
            let currentID = normalizedMemberID(currentMemberID)
            guard !followedIDs.isEmpty else { return [] }
            return posts.filter { post in
                guard let memberID = normalizedMemberID(post.memberID) else { return false }
                return memberID != currentID && followedIDs.contains(memberID)
            }
        }
    }

    static func segmentAccessibilityIdentifier(_ segment: FeedSegment) -> String {
        switch segment {
        case .club:
            "club_segcontrol_feed"

        case .nearby:
            "club_segcontrol_nearby"

        case .following:
            "club_segcontrol_following"
        }
    }

    static func canFollowMember(_ memberID: String, currentMemberID: String?) -> Bool {
        guard let memberID = normalizedMemberID(memberID) else { return false }
        return memberID != normalizedMemberID(currentMemberID)
    }

    static func isFollowingMember(_ memberID: String, followedMemberIDs: [String]) -> Bool {
        guard let memberID = normalizedMemberID(memberID) else { return false }
        return Set(followedMemberIDs.compactMap(normalizedMemberID)).contains(memberID)
    }

    static func viewData(from activity: ClubActivity) -> ClubActivityViewData {
        ClubActivityViewData(
            id: activity.id ?? UUID(),
            authorDisplayName: activity.memberName ?? "Member",
            caption: activity.activityDescription,
            zoneTag: activity.gardenName,
            photoURL: activity.photoURL,
            relativeTimeLabel: relativeTimeLabel(for: activity.timestamp),
            likeCount: 0, // future feature
            commentCount: 0, // future feature
            memberID: activity.memberID ?? "",
            hardinessZone: activity.hardinessZone
        )
    }

    /// Maps a raw `CKRecord` for a `ClubActivity` CloudKit record onto the
    /// presentation type. Field names must match those written by
    /// `ClubCloudKitService.publishActivity(_:)`.
    static func viewData(from record: CKRecord) -> ClubActivityViewData {
        let photoURL = (record["photo"] as? CKAsset)?.fileURL?.absoluteString
            ?? record["photoURL"] as? String

        return ClubActivityViewData(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            authorDisplayName: record["memberName"] as? String ?? "Member",
            caption: record["activityDescription"] as? String,
            zoneTag: record["gardenName"] as? String,
            photoURL: photoURL,
            relativeTimeLabel: relativeTimeLabel(for: record["timestamp"] as? Date),
            likeCount: 0, // future feature
            commentCount: 0, // future feature
            memberID: record["memberID"] as? String ?? "",
            hardinessZone: record["hardinessZone"] as? String
        )
    }

    static func firstName(from displayName: String?) -> String {
        guard let displayName,
              let first = displayName.split(separator: " ").first
        else {
            return "Gardener"
        }
        return String(first)
    }

    private static func relativeTimeLabel(for timestamp: Date?) -> String? {
        guard let timestamp else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: .now)
    }

    private static func normalizedZone(_ zone: String?) -> String? {
        guard let trimmed = zone?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed.lowercased()
    }

    private static func normalizedMemberID(_ memberID: String?) -> String? {
        guard let trimmed = memberID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
