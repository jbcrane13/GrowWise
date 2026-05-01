import Foundation

enum ClubInviteSharing {
    static func shareItem(code: String) -> String {
        "Join my garden club on Cultivation! Use invite code: \(code)"
    }

    static func shareMessage(clubName: String?, code: String) -> String {
        let resolvedName = clubName ?? "our club"
        return "Join \(resolvedName) on Cultivation with code \(code)"
    }
}
