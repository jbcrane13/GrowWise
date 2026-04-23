import Foundation
import GrowWiseModels

/// Routing decision for the Club tab. Resolved from the user's club membership.
/// See ADR-019.
public enum GardenClubTabRoute: Equatable {
    case joinOrCreate
    case feed(GardenClub)
    case list([GardenClub])

    public static func resolve(clubs: [GardenClub]) -> GardenClubTabRoute {
        switch clubs.count {
        case 0:
            .joinOrCreate
        case 1:
            .feed(clubs[0])
        default:
            // Most-recently-created club is the natural default; sort newest first
            // so the list shows the freshest at the top.
            .list(clubs.sorted { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) })
        }
    }
}

extension GardenClub: @retroactive Equatable {
    public static func == (lhs: GardenClub, rhs: GardenClub) -> Bool {
        lhs.id == rhs.id
    }
}
