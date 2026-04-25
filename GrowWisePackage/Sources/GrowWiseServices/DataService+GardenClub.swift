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
}
