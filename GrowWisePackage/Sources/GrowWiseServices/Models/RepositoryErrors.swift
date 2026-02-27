import Foundation

public enum PlantError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notFound: return "Plant not found in the database."
        case .saveFailed(let err): return "Failed to save plant: \(err.localizedDescription)"
        }
    }
}

public enum GardenError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum ReminderError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum JournalError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum UserError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}
