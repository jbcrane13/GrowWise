import Foundation
import GrowWiseModels
import SwiftData

public enum SharedPlantError: Error, Equatable, LocalizedError {
    case missingClubID
    case missingPlantID
    case plantNotShared
    case reminderNotShared
    case alreadyClaimed

    public var errorDescription: String? {
        switch self {
        case .missingClubID:
            "This club is missing its identifier."

        case .missingPlantID:
            "This plant is missing its identifier."

        case .plantNotShared:
            "This plant is not shared with a club."

        case .reminderNotShared:
            "Only reminders for shared plants can be claimed."

        case .alreadyClaimed:
            "This reminder has already been claimed."
        }
    }
}

public enum ReminderAssignmentError: Error, Equatable, LocalizedError {
    case notAssignedToCurrentMember

    public var errorDescription: String? {
        switch self {
        case .notAssignedToCurrentMember:
            "This shared reminder is assigned to another club member."
        }
    }
}

public extension DataService {
    @discardableResult
    func sharePlant(_ plant: Plant, withClub club: GardenClub) throws -> Plant {
        guard let clubID = club.id else { throw SharedPlantError.missingClubID }
        guard let plantID = plant.id else { throw SharedPlantError.missingPlantID }

        plant.sharedWithClubID = clubID
        plant.sharedOwnerID = getCurrentUser()?.id.uuidString ?? club.ownerID
        plant.sharedDate = Date()

        var sharedPlantIDs = club.sharedPlantIDs ?? []
        let plantIDString = plantID.uuidString
        if !sharedPlantIDs.contains(plantIDString) {
            sharedPlantIDs.append(plantIDString)
            club.sharedPlantIDs = sharedPlantIDs
        }

        try mainContext.save()
        invalidateSharedPlantCaches(for: plant)
        return plant
    }

    @discardableResult
    func unsharePlant(_ plant: Plant) throws -> Plant {
        guard plant.sharedWithClubID != nil else { throw SharedPlantError.plantNotShared }
        let plantIDString = plant.id?.uuidString

        plant.sharedWithClubID = nil
        plant.sharedOwnerID = nil
        plant.sharedDate = nil

        if let plantIDString {
            let clubs = try fetchClubs()
            for club in clubs {
                let updated = (club.sharedPlantIDs ?? []).filter { $0 != plantIDString }
                if updated.count != club.sharedPlantIDs?.count {
                    club.sharedPlantIDs = updated
                }
            }
        }

        try mainContext.save()
        invalidateSharedPlantCaches(for: plant)
        return plant
    }

    func fetchSharedPlants(for club: GardenClub) throws -> [Plant] {
        guard let clubID = club.id else { throw SharedPlantError.missingClubID }
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.sharedWithClubID == clubID
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try mainContext.fetch(descriptor)
    }

    func claimReminder(_ reminder: PlantReminder, memberID: String, memberName: String) throws {
        guard reminder.plant?.sharedWithClubID != nil else { throw SharedPlantError.reminderNotShared }
        if let assignedMemberID = reminder.assignedMemberID, assignedMemberID != memberID {
            throw SharedPlantError.alreadyClaimed
        }

        reminder.claimAssignment(memberID: memberID, memberName: memberName)
        try mainContext.save()
        invalidateReminderCaches()
    }

    func releaseReminderAssignment(_ reminder: PlantReminder) throws {
        reminder.releaseAssignment()
        try mainContext.save()
        invalidateReminderCaches()
    }
}

extension DataService {
    struct SharedCareActivityPayload {
        let caption: String
        let activityType: String
        let plantName: String?
        let gardenName: String?
        let club: GardenClub
    }

    func assertReminderCompletionAllowed(_ reminder: PlantReminder) throws {
        let currentMemberID = getCurrentUser()?.id.uuidString
        guard reminder.canBeCompleted(by: currentMemberID) else {
            throw ReminderAssignmentError.notAssignedToCurrentMember
        }
    }

    func sharedCareActivityPayload(for reminder: PlantReminder) -> SharedCareActivityPayload? {
        guard let activityType = clubActivityType(for: reminder.reminderType),
              let plant = reminder.plant,
              let clubID = plant.sharedWithClubID,
              let club = fetchClub(withID: clubID)
        else {
            return nil
        }

        return SharedCareActivityPayload(
            caption: "\(reminder.reminderType.displayName.lowercased()) completed",
            activityType: activityType,
            plantName: plant.name,
            gardenName: plant.garden?.name,
            club: club
        )
    }

    func publishSharedCareActivity(_ payload: SharedCareActivityPayload) throws {
        try createClubPost(
            caption: payload.caption,
            activityType: payload.activityType,
            plantName: payload.plantName,
            gardenName: payload.gardenName,
            club: payload.club
        )
    }

    func fetchClub(withID clubID: UUID) -> GardenClub? {
        let descriptor = FetchDescriptor<GardenClub>()
        return try? mainContext.fetch(descriptor).first { $0.id == clubID }
    }

    private func clubActivityType(for reminderType: ReminderType) -> String? {
        switch reminderType {
        case .watering:
            "watered"

        case .fertilizing:
            "fertilized"

        case .pruning:
            "pruned"

        default:
            nil
        }
    }

    private func invalidateSharedPlantCaches(for plant: Plant) {
        cache.invalidateAll(withPrefix: "plants:")
        cache.invalidateAll(withPrefix: "stats:count:")
        if let plantID = plant.id {
            cache.invalidate("plants:\(plantID.uuidString)")
        }
    }
}
