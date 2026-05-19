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
    public var readByMemberIDs: [String]? = []
    public var deliveryStateRawValue: String? = ClubMessageDeliveryState.sent.rawValue

    public init(clubID: UUID, senderName: String, senderID: String, text: String) {
        self.id = UUID()
        self.clubID = clubID
        self.senderName = senderName
        self.senderID = senderID
        self.text = text
        self.timestamp = Date()
        self.readByMemberIDs = [senderID]
        self.deliveryStateRawValue = ClubMessageDeliveryState.sent.rawValue
    }

    public var deliveryState: ClubMessageDeliveryState {
        get {
            ClubMessageDeliveryState(rawValue: deliveryStateRawValue ?? "") ?? .sent
        }
        set {
            deliveryStateRawValue = newValue.rawValue
        }
    }

    public func markRead(by memberID: String) {
        var readers = readByMemberIDs ?? []
        if !readers.contains(memberID) {
            readers.append(memberID)
            readByMemberIDs = readers
        }
    }

    public func isSeenByAll(memberIDs: [String]?) -> Bool {
        let readers = Set(readByMemberIDs ?? [])
        let expectedReaders = Set((memberIDs ?? []).filter { $0 != senderID })
        guard !expectedReaders.isEmpty else { return false }
        return expectedReaders.isSubset(of: readers)
    }
}

public enum ClubMessageDeliveryState: String, Codable, Sendable {
    case sending
    case sent
    case failed
}
