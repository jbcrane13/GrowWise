import Foundation
import SwiftData

@Model
public final class ClubActivity {
    public var id: UUID? = UUID()
    public var clubID: UUID?
    public var memberName: String?
    public var memberID: String?
    public var activityType: String? // "watered", "harvested", "planted", "journaled", "diagnosed"
    public var activityDescription: String?
    public var gardenName: String?
    public var photoURL: String?
    public var timestamp: Date? = Date()

    public init(clubID: UUID, memberName: String, memberID: String, activityType: String, description: String) {
        self.id = UUID()
        self.clubID = clubID
        self.memberName = memberName
        self.memberID = memberID
        self.activityType = activityType
        self.activityDescription = description
        self.timestamp = Date()
    }
}
