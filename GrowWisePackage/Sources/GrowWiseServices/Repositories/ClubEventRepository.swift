import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ClubEventRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(for clubID: UUID) throws -> [ClubEvent] {
        let descriptor = FetchDescriptor<ClubEvent>(
            sortBy: [SortDescriptor(\.startDate)]
        )
        let all = try context.fetch(descriptor)
        return all.filter { $0.clubID == clubID }
    }

    /// Returns events whose startDate is on or after now, sorted ascending.
    public func fetchUpcoming(for clubID: UUID) throws -> [ClubEvent] {
        let now = Date()
        let all = try fetchAll(for: clubID)
        return all.filter { ($0.startDate ?? .distantPast) >= now }
    }

    public func save(_ event: ClubEvent) throws {
        context.insert(event)
        do {
            try context.save()
        } catch {
            throw ClubEventRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ event: ClubEvent) throws {
        context.delete(event)
        do {
            try context.save()
        } catch {
            throw ClubEventRepositoryError.saveFailed(error)
        }
    }
}

public enum ClubEventRepositoryError: Error, LocalizedError {
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            "Failed to save club event: \(error.localizedDescription)"
        }
    }
}
