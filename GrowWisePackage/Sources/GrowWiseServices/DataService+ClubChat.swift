import Foundation
import GrowWiseModels
import SwiftData

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

/// Club Chat (messages) convenience methods on DataService.
public extension DataService {
    // MARK: - Messages

    /// Fetch messages for a club, sorted by timestamp ascending.
    @MainActor
    func fetchClubMessages(for clubID: UUID) throws -> [ClubMessage] {
        let repo = ClubMessageRepository(context: mainContext)
        return try repo.fetchAll(for: clubID)
    }

    /// Mark all messages in a club as read by the supplied member.
    @MainActor
    func markClubMessagesRead(for clubID: UUID, memberID: String) throws {
        let repo = ClubMessageRepository(context: mainContext)
        let messages = try repo.fetchAll(for: clubID)
        for message in messages where message.senderID != memberID {
            message.markRead(by: memberID)
        }
        try mainContext.save()
    }

    /// Send a text message to a club.
    @MainActor
    func sendClubMessage(clubID: UUID, senderID: String, senderName: String, text: String) throws -> ClubMessage {
        let message = ClubMessage(clubID: clubID, senderName: senderName, senderID: senderID, text: text)
        message.deliveryState = .sent
        let repo = ClubMessageRepository(context: mainContext)
        try repo.save(message)
        return message
    }

    /// Send a photo message to a club.
    @MainActor
    func sendClubPhoto(clubID: UUID, senderID: String, senderName: String, photoData: Data, caption: String? = nil) throws -> ClubMessage {
        let message = ClubMessage(clubID: clubID, senderName: senderName, senderID: senderID, text: caption ?? "")
        message.photoData = photoData
        message.deliveryState = .sent
        let repo = ClubMessageRepository(context: mainContext)
        try repo.save(message)
        return message
    }

    /// Delete a message (sender only).
    @MainActor
    func deleteClubMessage(_ message: ClubMessage) throws {
        let repo = ClubMessageRepository(context: mainContext)
        try repo.delete(message)
    }
}

// swiftlint:enable line_length
