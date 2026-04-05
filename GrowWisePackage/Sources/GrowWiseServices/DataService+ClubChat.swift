import Foundation
import GrowWiseModels
import SwiftData

/// Club Chat (messages) convenience methods on DataService.
public extension DataService {
    // MARK: - Messages

    /// Fetch messages for a club, sorted by timestamp ascending.
    @MainActor
    func fetchClubMessages(for clubID: UUID) throws -> [ClubMessage] {
        let ctx = ModelContext(container)
        let repo = ClubMessageRepository(context: ctx)
        return try repo.fetchAll(for: clubID)
    }

    /// Send a text message to a club.
    @MainActor
    func sendClubMessage(clubID: UUID, senderID: String, senderName: String, text: String) throws -> ClubMessage {
        let message = ClubMessage(clubID: clubID, senderName: senderName, senderID: senderID, text: text)
        let ctx = ModelContext(container)
        let repo = ClubMessageRepository(context: ctx)
        try repo.save(message)
        return message
    }

    /// Send a photo message to a club.
    @MainActor
    func sendClubPhoto(clubID: UUID, senderID: String, senderName: String, photoData: Data, caption: String? = nil) throws -> ClubMessage {
        let message = ClubMessage(clubID: clubID, senderName: senderName, senderID: senderID, text: caption ?? "")
        message.photoData = photoData
        let ctx = ModelContext(container)
        let repo = ClubMessageRepository(context: ctx)
        try repo.save(message)
        return message
    }

    /// Delete a message (sender only).
    @MainActor
    func deleteClubMessage(_ message: ClubMessage) throws {
        let ctx = ModelContext(container)
        let repo = ClubMessageRepository(context: ctx)
        try repo.delete(message)
    }
}