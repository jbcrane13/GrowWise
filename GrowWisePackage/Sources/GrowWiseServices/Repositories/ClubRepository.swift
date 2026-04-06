import Foundation
import GrowWiseModels
import SwiftData

@MainActor
public final class ClubRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [GardenClub] {
        let descriptor = FetchDescriptor<GardenClub>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }

    /// Fetches all clubs then filters in-memory for CloudKit compatibility
    /// (SwiftData #Predicate can't compare Bool optionals reliably).
    public func fetchActive() throws -> [GardenClub] {
        let all = try fetchAll()
        return all.filter { $0.isActive == true }
    }

    public func fetchByInviteCode(_ code: String) throws -> GardenClub? {
        let upper = code.uppercased()
        var descriptor = FetchDescriptor<GardenClub>(
            predicate: #Predicate<GardenClub> { club in
                club.inviteCode == upper
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Fetches all clubs then filters in-memory for member presence.
    public func fetchByMember(_ memberID: String) throws -> [GardenClub] {
        let all = try fetchAll()
        return all.filter { ($0.memberIDs ?? []).contains(memberID) }
    }

    public func save(_ club: GardenClub) throws {
        context.insert(club)
        do {
            try context.save()
        } catch {
            throw ClubRepositoryError.saveFailed(error)
        }
    }

    public func update(_ club: GardenClub) throws {
        do {
            try context.save()
        } catch {
            throw ClubRepositoryError.saveFailed(error)
        }
    }

    public func delete(_ club: GardenClub) throws {
        context.delete(club)
        do {
            try context.save()
        } catch {
            throw ClubRepositoryError.saveFailed(error)
        }
    }
}

public enum ClubRepositoryError: Error, LocalizedError {
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            "Failed to save club: \(error.localizedDescription)"
        }
    }
}
