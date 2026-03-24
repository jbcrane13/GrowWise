import Foundation

public enum PlantError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .notFound: "Plant not found in the database."
        case .saveFailed(let err): "Failed to save plant: \(err.localizedDescription)"
        }
    }
}

public enum GardenError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum ReminderRepositoryError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum JournalRepositoryError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}

public enum UserRepositoryError: Error, LocalizedError {
    case notFound
    case saveFailed(Error)
}
