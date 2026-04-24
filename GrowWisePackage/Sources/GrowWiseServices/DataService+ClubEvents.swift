import Foundation
import GrowWiseModels
import SwiftData

/// Club Events (scheduling + RSVP) convenience methods on DataService.
public extension DataService {
    // MARK: - Events

    /// Fetch all events for a club, sorted by start date.
    @MainActor
    func fetchClubEvents(for clubID: UUID) throws -> [ClubEvent] {
        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        return try repo.fetchAll(for: clubID)
    }

    /// Fetch only upcoming events for a club.
    @MainActor
    func fetchUpcomingClubEvents(for clubID: UUID) throws -> [ClubEvent] {
        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        return try repo.fetchUpcoming(for: clubID)
    }

    /// Create a new event.
    @MainActor
    @discardableResult
    func createClubEvent(clubID: UUID, title: String, description: String?, location: String?, startDate: Date, endDate: Date?, createdBy: String) throws -> ClubEvent {
        let event = ClubEvent(clubID: clubID, title: title, startDate: startDate, createdBy: createdBy)
        event.eventDescription = description
        event.location = location
        event.endDate = endDate
        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        try repo.save(event)
        return event
    }

    /// Update an existing event.
    @MainActor
    func updateClubEvent(_ event: ClubEvent, title: String? = nil, description: String? = nil, location: String? = nil, startDate: Date? = nil, endDate: Date? = nil) throws {
        if let title { event.title = title }
        if let description { event.eventDescription = description }
        if let location { event.location = location }
        if let startDate { event.startDate = startDate }
        if let endDate { event.endDate = endDate }
        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        try repo.save(event)
    }

    /// Delete an event.
    @MainActor
    func deleteClubEvent(_ event: ClubEvent) throws {
        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        try repo.delete(event)
    }

    // MARK: - RSVP

    /// RSVP to an event.
    @MainActor
    func rsvpToEvent(_ event: ClubEvent, memberID: String, response: ClubRSVPResponse) throws {
        // Remove from all lists first
        event.rsvpAccepted = (event.rsvpAccepted ?? []).filter { $0 != memberID }
        event.rsvpDeclined = (event.rsvpDeclined ?? []).filter { $0 != memberID }
        event.rsvpMaybe = (event.rsvpMaybe ?? []).filter { $0 != memberID }

        // Add to appropriate list
        switch response {
        case .accepted:
            event.rsvpAccepted = (event.rsvpAccepted ?? []) + [memberID]

        case .declined:
            event.rsvpDeclined = (event.rsvpDeclined ?? []) + [memberID]

        case .maybe:
            event.rsvpMaybe = (event.rsvpMaybe ?? []) + [memberID]
        }

        let ctx = ModelContext(container)
        let repo = ClubEventRepository(context: ctx)
        try repo.save(event)
    }
}

/// RSVP response options.
public enum ClubRSVPResponse: String, CaseIterable {
    case accepted
    case declined
    case maybe
}
