import Foundation
import SwiftData

@Model
public final class GardenClub {
    public var id: UUID? = UUID()
    public var name: String?
    public var inviteCode: String? // 6-char alphanumeric, unique
    public var createdDate: Date? = Date()
    public var ownerID: String? // User reference
    public var memberIDs: [String]? // Array of member identifiers
    public var sharedGardenIDs: [String]? // Garden references
    public var isActive: Bool? = true

    public init(name: String, ownerID: String, inviteCode: String) {
        self.id = UUID()
        self.name = name
        self.ownerID = ownerID
        self.inviteCode = inviteCode
        self.memberIDs = [ownerID]
        self.sharedGardenIDs = []
        self.createdDate = Date()
        self.isActive = true
    }
}
