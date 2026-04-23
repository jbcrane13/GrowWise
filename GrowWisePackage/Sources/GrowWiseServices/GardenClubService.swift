import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class GardenClubService {
    private let clubRepository: ClubRepository

    public init(context: ModelContext) {
        self.clubRepository = ClubRepository(context: context)
    }

    // MARK: - Club Lifecycle

    public func createClub(name: String, ownerID: String) throws -> GardenClub {
        let code = generateInviteCode()
        let club = GardenClub(name: name, ownerID: ownerID, inviteCode: code)
        try clubRepository.save(club)
        return club
    }

    public func joinClub(inviteCode: String, memberID: String) throws -> GardenClub {
        let upper = inviteCode.uppercased()
        guard let club = try clubRepository.fetchByInviteCode(upper) else {
            throw GardenClubError.invalidInviteCode
        }
        guard club.isActive == true else {
            throw GardenClubError.clubInactive
        }
        guard !(club.memberIDs ?? []).contains(memberID) else {
            throw GardenClubError.alreadyMember
        }
        club.memberIDs = (club.memberIDs ?? []) + [memberID]
        try clubRepository.update(club)
        return club
    }

    public func leaveClub(clubID: UUID, memberID: String) throws {
        let clubs = try clubRepository.fetchAll()
        guard let club = clubs.first(where: { $0.id == clubID }) else {
            throw GardenClubError.clubNotFound
        }
        guard (club.memberIDs ?? []).contains(memberID) else {
            throw GardenClubError.notMember
        }
        // Owner leaving deactivates the club
        if club.ownerID == memberID {
            club.isActive = false
        } else {
            club.memberIDs = (club.memberIDs ?? []).filter { $0 != memberID }
        }
        try clubRepository.update(club)
    }

    // MARK: - Garden Sharing

    public func shareGarden(gardenID: String, clubID: UUID) throws {
        let clubs = try clubRepository.fetchAll()
        guard let club = clubs.first(where: { $0.id == clubID }) else {
            throw GardenClubError.clubNotFound
        }
        guard !(club.sharedGardenIDs ?? []).contains(gardenID) else { return }
        club.sharedGardenIDs = (club.sharedGardenIDs ?? []) + [gardenID]
        try clubRepository.update(club)
    }

    public func removeGarden(gardenID: String, clubID: UUID) throws {
        let clubs = try clubRepository.fetchAll()
        guard let club = clubs.first(where: { $0.id == clubID }) else {
            throw GardenClubError.clubNotFound
        }
        club.sharedGardenIDs = (club.sharedGardenIDs ?? []).filter { $0 != gardenID }
        try clubRepository.update(club)
    }

    // MARK: - Member Management

    public func removeMember(memberID: String, clubID: UUID, requestingMemberID: String) throws {
        let clubs = try clubRepository.fetchAll()
        guard let club = clubs.first(where: { $0.id == clubID }) else {
            throw GardenClubError.clubNotFound
        }
        guard club.ownerID == requestingMemberID else {
            throw GardenClubError.notOwner
        }
        guard (club.memberIDs ?? []).contains(memberID) else {
            throw GardenClubError.notMember
        }
        club.memberIDs = (club.memberIDs ?? []).filter { $0 != memberID }
        try clubRepository.update(club)
    }

    // MARK: - Private Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no ambiguous I/1/O/0
        return String((0 ..< 6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Errors

public enum GardenClubError: Error, LocalizedError {
    case invalidInviteCode
    case clubInactive
    case alreadyMember
    case notMember
    case notOwner
    case clubNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidInviteCode:
            "The invite code is invalid or has expired."

        case .clubInactive:
            "This garden club is no longer active."

        case .alreadyMember:
            "You are already a member of this club."

        case .notMember:
            "The specified user is not a member of this club."

        case .notOwner:
            "Only the club owner can perform this action."

        case .clubNotFound:
            "The garden club could not be found."
        }
    }
}
