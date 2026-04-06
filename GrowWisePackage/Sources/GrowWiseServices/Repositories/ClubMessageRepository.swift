import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ClubMessageRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Returns messages for a club sorted by timestamp ascending (oldest first).
    public func fetchAll(for clubID: UUID) throws -> [ClubMessage] {
        let descriptor = FetchDescriptor<ClubMessage>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let all = try context.fetch(descriptor)
        return all.filter { $0.clubID == clubID }
    }

    public func save(_ message: ClubMessage) throws {
        context.insert(message)
        do {
            try context.save()
        } catch {
            throw ClubMessageRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ message: ClubMessage) throws {
        context.delete(message)
        do {
            try context.save()
        } catch {
            throw ClubMessageRepositoryError.saveFailed(error)
        }
    }
}

public enum ClubMessageRepositoryError: Error, LocalizedError {
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            "Failed to save club message: \(error.localizedDescription)"
        }
    }
}
