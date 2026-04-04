import Foundation
import SwiftData

@Model
public final class ClubMessage {
    public var id: UUID? = UUID()
    public var clubID: UUID?
    public var senderName: String?
    public var senderID: String?
    public var text: String?
    public var photoData: Data?
    public var timestamp: Date? = Date()

    public init(clubID: UUID, senderName: String, senderID: String, text: String) {
        self.id = UUID()
        self.clubID = clubID
        self.senderName = senderName
        self.senderID = senderID
        self.text = text
        self.timestamp = Date()
    }
}
