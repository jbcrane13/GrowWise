import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ClubActivityRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(for clubID: UUID) throws -> [ClubActivity] {
        // Fetch all, filter in-memory (CloudKit / SwiftData #Predicate UUID limitation)
        let descriptor = FetchDescriptor<ClubActivity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        return all.filter { $0.clubID == clubID }
    }

    public func save(_ activity: ClubActivity) throws {
        context.insert(activity)
        do {
            try context.save()
        } catch {
            throw ClubActivityRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ activity: ClubActivity) throws {
        context.delete(activity)
        do {
            try context.save()
        } catch {
            throw ClubActivityRepositoryError.saveFailed(error)
        }
    }
}

public enum ClubActivityRepositoryError: Error, LocalizedError {
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            "Failed to save club activity: \(error.localizedDescription)"
        }
    }
}
