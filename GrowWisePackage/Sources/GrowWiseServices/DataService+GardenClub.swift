import Foundation
import GrowWiseModels
import SwiftData

/// Garden Club convenience methods on DataService.
/// Delegates to GardenClubService and the club repositories.
public extension DataService {
    // MARK: - Clubs

    /// Fetch all active clubs.
    func fetchClubs() throws -> [GardenClub] {
        try ClubRepository(context: mainContext).fetchActive()
    }

    /// Create a new club owned by `ownerID`.
    @discardableResult
    func createClub(name: String, ownerID: String) throws -> GardenClub {
        let service = GardenClubService(context: mainContext)
        return try service.createClub(name: name, ownerID: ownerID)
    }

    /// Join a club via invite code.
    @discardableResult
    func joinClub(inviteCode: String, memberID: String) throws -> GardenClub {
        let service = GardenClubService(context: mainContext)
        return try service.joinClub(inviteCode: inviteCode, memberID: memberID)
    }

    /// Leave a club.
    func leaveClub(clubID: UUID, memberID: String) throws {
        let service = GardenClubService(context: mainContext)
        try service.leaveClub(clubID: clubID, memberID: memberID)
    }

    /// Remove a member from a club (owner only).
    func removeMember(memberID: String, clubID: UUID, requestingMemberID: String) throws {
        let service = GardenClubService(context: mainContext)
        try service.removeMember(memberID: memberID, clubID: clubID, requestingMemberID: requestingMemberID)
    }

    // MARK: - Activities

    /// Fetch recent activities for a club (up to 10 most recent).
    @MainActor
    func fetchClubActivities(for clubID: UUID) throws -> [ClubActivity] {
        let repo = ClubActivityRepository(context: mainContext)
        return try repo.fetchAll(for: clubID)
    }

    // MARK: - Posting

    /// Create and persist a new ClubActivity post for the current user's primary club.
    /// - Parameters:
    ///   - caption: The post body text (required, non-empty).
    ///   - activityType: One of "shared", "watered", "harvested", "planted", etc.
    ///   - plantName: Optional plant name prepended to the description.
    ///   - gardenName: Optional garden context displayed as the post's location tag.
    /// - Throws: `CreateClubPostError.noClub` if the user is not in any club.
    @discardableResult
    func createClubPost(
        caption: String,
        activityType: String,
        plantName: String? = nil,
        gardenName: String? = nil,
        club: GardenClub? = nil,
        photoURL: String? = nil
    ) throws -> ClubActivity {
        guard let club = club ?? fetchPrimaryClub(), let clubID = club.id else {
            throw CreateClubPostError.noClub
        }
        let user = getCurrentUser()
        let memberName = user?.displayName ?? "Gardener"
        let memberID = user?.id.uuidString ?? UUID().uuidString
        let description: String = if let plantName {
            "\(plantName): \(caption)"
        } else {
            caption
        }
        let activity = ClubActivity(
            clubID: clubID,
            memberName: memberName,
            memberID: memberID,
            activityType: activityType,
            description: description
        )
        activity.gardenName = gardenName
        activity.hardinessZone = user?.hardinessZone
        activity.photoURL = photoURL
        let repo = ClubActivityRepository(context: mainContext)
        try repo.save(activity)
        return activity
    }

    func followClubMember(_ memberID: String) throws {
        guard let memberID = memberID.trimmedNonEmpty else { return }
        guard let user = getCurrentUser() else { throw CreateClubPostError.noCurrentUser }
        guard memberID != user.id.uuidString else { return }
        let originalFollowed = user.followedMemberIDs
        var followed = originalFollowed.compactMap(\.trimmedNonEmpty)
        if followed.contains(memberID) {
            if followed != originalFollowed {
                user.followedMemberIDs = followed
                try updateUser(user)
            }
            return
        }
        followed.append(memberID)
        user.followedMemberIDs = followed
        try updateUser(user)
    }

    func unfollowClubMember(_ memberID: String) throws {
        guard let memberID = memberID.trimmedNonEmpty else { return }
        guard let user = getCurrentUser() else { throw CreateClubPostError.noCurrentUser }
        let followed = user.followedMemberIDs.compactMap(\.trimmedNonEmpty).filter { $0 != memberID }
        guard followed.count != user.followedMemberIDs.count else { return }
        user.followedMemberIDs = followed
        try updateUser(user)
    }
}

public enum CreateClubPostError: Error, LocalizedError {
    case noClub
    case noCurrentUser

    public var errorDescription: String? {
        switch self {
        case .noClub:
            "You're not in a club yet. Join or create one first."

        case .noCurrentUser:
            "Create a profile before following club members."
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
