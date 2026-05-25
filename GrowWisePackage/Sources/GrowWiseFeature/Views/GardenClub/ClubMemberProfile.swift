import Foundation
import GrowWiseModels

struct ClubMemberProfile: Identifiable {
    let memberID: String
    let roleTitle: String
    let isCurrentUser: Bool
    let isFollowed: Bool
    let canShowPublicDetails: Bool
    let displayName: String
    let avatarLetters: String
    let bio: String?
    let hardinessZone: String?
    let memberSinceDate: Date?
    let plantCount: Int?
    let publicGardenCount: Int?
    let recentContributions: [ClubActivity]

    var id: String {
        memberID
    }

    init(
        memberID: String,
        club: GardenClub,
        user: User?,
        activities: [ClubActivity],
        currentUserID: String,
        followedMemberIDs: [String] = []
    ) {
        self.memberID = memberID
        roleTitle = memberID == club.ownerID ? "Owner" : "Member"
        isCurrentUser = memberID == currentUserID
        isFollowed = !isCurrentUser && followedMemberIDs.contains(memberID)
        canShowPublicDetails = isCurrentUser || user?.isProfilePublic == true

        if canShowPublicDetails, let name = user?.displayName?.trimmedNonEmpty {
            displayName = name
        } else {
            displayName = "Club member"
        }

        avatarLetters = Self.avatarLetters(
            displayName: canShowPublicDetails ? user?.displayName : nil,
            memberID: memberID
        )
        bio = canShowPublicDetails ? user?.bio?.trimmedNonEmpty : nil
        hardinessZone = canShowPublicDetails ? user?.hardinessZone?.trimmedNonEmpty : nil
        memberSinceDate = canShowPublicDetails ? club.createdDate : nil
        plantCount = canShowPublicDetails ? Self.plantCount(for: user) : nil
        publicGardenCount = canShowPublicDetails ? Self.publicGardenCount(for: user, club: club) : nil
        recentContributions = canShowPublicDetails ? Self.recentActivities(
            for: memberID,
            activities: activities
        ) : []
    }

    private static func plantCount(for user: User?) -> Int {
        (user?.gardens ?? []).reduce(0) { total, garden in
            total + (garden.plants ?? []).count
        }
    }

    private static func publicGardenCount(for user: User?, club: GardenClub) -> Int {
        let sharedGardenIDs = Set(club.sharedGardenIDs ?? [])
        guard !sharedGardenIDs.isEmpty else { return 0 }
        return (user?.gardens ?? []).count(where: { garden in
            guard let id = garden.id?.uuidString else { return false }
            return sharedGardenIDs.contains(id)
        })
    }

    private static func recentActivities(
        for memberID: String,
        activities: [ClubActivity]
    ) -> [ClubActivity] {
        Array(
            activities
                .filter { $0.memberID == memberID }
                .sorted { lhs, rhs in
                    (lhs.timestamp ?? .distantPast) > (rhs.timestamp ?? .distantPast)
                }
                .prefix(3)
        )
    }

    private static func avatarLetters(displayName: String?, memberID: String) -> String {
        if let displayName = displayName?.trimmedNonEmpty {
            let initials = displayName
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)
                .map { String($0).uppercased() }
                .joined()
            if !initials.isEmpty { return initials }
        }

        if let firstAlphanumeric = memberID.first(where: { $0.isLetter || $0.isNumber }) {
            return String(firstAlphanumeric).uppercased()
        }

        return "M"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
