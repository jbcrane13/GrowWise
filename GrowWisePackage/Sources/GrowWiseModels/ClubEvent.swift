import Foundation
import SwiftData

@Model
public final class ClubEvent {
    public var id: UUID? = UUID()
    public var clubID: UUID?
    public var title: String?
    public var eventDescription: String?
    public var location: String?
    public var startDate: Date?
    public var endDate: Date?
    public var createdBy: String?
    public var rsvpAccepted: [String]?
    public var rsvpDeclined: [String]?
    public var rsvpMaybe: [String]?

    public init(clubID: UUID, title: String, startDate: Date, createdBy: String) {
        self.id = UUID()
        self.clubID = clubID
        self.title = title
        self.startDate = startDate
        self.createdBy = createdBy
        self.rsvpAccepted = [createdBy]
        self.rsvpDeclined = []
        self.rsvpMaybe = []
    }
}
