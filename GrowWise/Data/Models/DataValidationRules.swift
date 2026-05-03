import Foundation
import GrowWiseModels
import GrowWiseServices
import os
import SwiftData

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable cyclomatic_complexity file_length type_body_length

private let logger = Logger(subsystem: "com.growwise", category: "DataValidationRules")

/// Comprehensive data validation rules for GrowWise entities
enum DataValidationRules {
    // MARK: - Validation Results

    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
        let warnings: [String]

        static let valid = ValidationResult(isValid: true, errors: [], warnings: [])

        static func invalid(errors: [String], warnings: [String] = []) -> ValidationResult {
            ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let maxNameLength = 100
        static let maxDescriptionLength = 1000
        static let maxNotesLength = 2000
        static let maxCustomNameLength = 150
        static let maxReminderTitleLength = 200
    }

    // MARK: - User Validation

    static func validateUser(_ user: User) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Email validation
        if user.email?.isEmpty ?? true {
            errors.append("Email is required")
        } else if !isValidEmail(user.email ?? "") {
            errors.append("Invalid email format")
        }

        // Display name validation
        if (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Display name is required")
        }

        // Date validation
        if user.createdDate > Date() {
            errors.append("Created date cannot be in the future")
        }

        if user.lastLoginDate < user.createdDate {
            warnings.append("Last login date is before created date")
        }

        // Hardiness zone validation
        if let hardinessZone = user.hardinessZone,
           !isValidHardinessZone(hardinessZone)
        {
            warnings.append("Hardiness zone format may be invalid: \(hardinessZone)")
        }

        // Experience years validation
        if user.experienceYears < 0 {
            errors.append("Experience years cannot be negative")
        }

        if user.experienceYears > 100 {
            warnings.append("Experience years seems unusually high: \(user.experienceYears)")
        }

        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }

    // MARK: - Plant Validation

    static func validatePlant(_ plant: Plant) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Required fields
        if (plant.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Plant name is required")
        } else if (plant.name?.count ?? 0) > Constants.maxNameLength {
            errors.append("Plant name is too long (max \(Constants.maxNameLength) characters)")
        }

        // Date validations
        if let plantingDate = plant.plantingDate,
           plantingDate > Date()
        {
            errors.append("Planting date cannot be in the future")
        }

        if let harvestDate = plant.harvestDate,
           harvestDate < Date()
        {
            warnings.append("Harvest date is in the past")
        }

        if let plantingDate = plant.plantingDate,
           let harvestDate = plant.harvestDate,
           harvestDate <= plantingDate
        {
            errors.append("Harvest date must be after planting date")
        }

        if let lastWatered = plant.lastWatered,
           lastWatered > Date()
        {
            errors.append("Last watered date cannot be in the future")
        }

        if let lastFertilized = plant.lastFertilized,
           lastFertilized > Date()
        {
            errors.append("Last fertilized date cannot be in the future")
        }

        if let lastPruned = plant.lastPruned,
           lastPruned > Date()
        {
            errors.append("Last pruned date cannot be in the future")
        }

        // Notes length
        if (plant.notes?.count ?? 0) > Constants.maxNotesLength {
            warnings.append("Plant notes are very long (over \(Constants.maxNotesLength) characters)")
        }

        // Bed assignment validation: if a bed is set but has no name, warn.
        if let bed = plant.bed, (bed.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Garden bed should have a name if assigned")
        }

        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }

    // MARK: - Garden Validation

    static func validateGarden(_ garden: Garden) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Required fields
        if (garden.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Garden name is required")
        } else if (garden.name?.count ?? 0) > Constants.maxNameLength {
            errors.append("Garden name is too long (max \(Constants.maxNameLength) characters)")
        }

        // Date validation
        if let createdDate = garden.createdDate, createdDate > Date() {
            errors.append("Garden created date cannot be in the future")
        }

        if let lastModified = garden.lastModified, let createdDate = garden.createdDate, lastModified < createdDate {
            warnings.append("Last modified date is before created date")
        }

        // Hardiness zone validation
        if let hardinessZone = garden.hardinessZone,
           !isValidHardinessZone(hardinessZone)
        {
            warnings.append("Hardiness zone format may be invalid: \(hardinessZone)")
        }

        // Planting date range validation
        if let startDate = garden.plantingStartDate,
           let endDate = garden.plantingEndDate,
           endDate < startDate
        {
            errors.append("Planting end date cannot be before start date")
        }

        // Location validation
        if let lat = garden.latitude {
            if lat < -90 || lat > 90 {
                errors.append("Invalid latitude: must be between -90 and 90")
            }
        }

        if let lng = garden.longitude {
            if lng < -180 || lng > 180 {
                errors.append("Invalid longitude: must be between -180 and 180")
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }

    // MARK: - UserPlant Validation

    static func validateUserPlant(_ plant: Plant) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Validate this is actually a user plant
        if !(plant.isUserPlant ?? false) {
            errors.append("Plant must be marked as a user plant")
        }

        // Required relationships
        if plant.garden == nil {
            errors.append("User plant must be associated with a garden")
        }

        // Date validations
        if let plantingDate = plant.plantingDate,
           plantingDate > Date()
        {
            errors.append("Planting date cannot be in the future")
        }

        if let lastWatered = plant.lastWatered,
           lastWatered > Date()
        {
            errors.append("Last watered date cannot be in the future")
        }

        if let lastFertilized = plant.lastFertilized,
           lastFertilized > Date()
        {
            errors.append("Last fertilized date cannot be in the future")
        }

        if let lastPruned = plant.lastPruned,
           lastPruned > Date()
        {
            errors.append("Last pruned date cannot be in the future")
        }

        // Logical date ordering
        if let plantingDate = plant.plantingDate,
           let lastWatered = plant.lastWatered,
           lastWatered < plantingDate
        {
            warnings.append("Last watered date is before planting date")
        }

        // Name validation
        if (plant.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Plant name cannot be empty")
        }
        if (plant.name?.count ?? 0) > Constants.maxCustomNameLength {
            errors.append("Plant name exceeds maximum length of \(Constants.maxCustomNameLength) characters")
        }

        // Bed assignment validation
        if let bed = plant.bed, (bed.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Garden bed name should not be empty")
        }

        // Notes length
        if (plant.notes?.count ?? 0) > Constants.maxNotesLength {
            warnings.append("Plant notes are very long (over \(Constants.maxNotesLength) characters)")
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Reminder Validation

    static func validateReminder(_ reminder: PlantReminder) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Required fields
        if reminder.title.isEmpty {
            errors.append("Reminder title is required")
        }

        if reminder.message.isEmpty {
            errors.append("Reminder message is required")
        }

        // Date validations
        if reminder.nextDueDate <= Date() {
            warnings.append("Reminder is already due or overdue")
        }

        if let lastCompleted = reminder.lastCompletedDate,
           lastCompleted > Date()
        {
            errors.append("Last completed date cannot be in the future")
        }

        if reminder.nextDueDate < reminder.createdDate {
            warnings.append("Next due date is before created date")
        }

        // Required relationships
        if reminder.plant == nil {
            errors.append("Reminder must be associated with a plant")
        }

        if reminder.user == nil {
            errors.append("Reminder must be associated with a user")
        }

        // Logic validation
        if !reminder.isEnabled, reminder.nextDueDate > Date() {
            warnings.append("Disabled reminder has a future due date")
        }

        // Snooze validation
        if reminder.snoozeCount > reminder.maxSnoozeCount {
            errors.append("Snooze count exceeds maximum allowed snoozes")
        }

        // Title length
        if reminder.title.count > Constants.maxReminderTitleLength {
            warnings.append("Reminder title is very long")
        }

        // Message length
        if reminder.message.count > Constants.maxNotesLength {
            warnings.append("Reminder message is very long")
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Journal Entry Validation

    static func validateJournalEntry(_ entry: JournalEntry) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Date validations
        if entry.entryDate > Date() {
            errors.append("Entry date cannot be in the future")
        }

        if entry.lastModified < entry.entryDate {
            warnings.append("Last modified date is before entry date")
        }

        // Content validation
        if entry.title.isEmpty, entry.content.isEmpty {
            warnings.append("Journal entry has no title or content")
        }

        if entry.content.count > Constants.maxNotesLength * 2 { // Allow longer content for journal
            warnings.append("Journal entry content is very long")
        }

        // Title length validation
        if entry.title.count > Constants.maxNameLength {
            warnings.append("Journal entry title is very long")
        }

        // Measurement validations
        if let height = entry.heightMeasurement, height < 0 {
            errors.append("Height measurement cannot be negative")
        }

        if let width = entry.widthMeasurement, width < 0 {
            errors.append("Width measurement cannot be negative")
        }

        if let temp = entry.temperature {
            if temp < -50 || temp > 150 {
                warnings.append("Temperature seems unusual: \(temp)°")
            }
        }

        if let humidity = entry.humidity {
            if humidity < 0 || humidity > 100 {
                errors.append("Humidity must be between 0 and 100%")
            }
        }

        if let wateringAmount = entry.wateringAmount, wateringAmount < 0 {
            errors.append("Watering amount cannot be negative")
        }

        // Relationship validation
        if entry.user == nil {
            errors.append("Journal entry must be associated with a user")
        }

        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }

    // MARK: - Helper Methods

    private static func isValidHardinessZone(_ zone: String) -> Bool {
        // USDA hardiness zones: 1-13, with optional 'a' or 'b' suffix
        let pattern = "^([1-9]|1[0-3])[ab]?$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: zone.utf16.count)
        return regex?.firstMatch(in: zone, options: [], range: range) != nil
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let emailPattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: email.utf16.count)
        return regex?.firstMatch(in: email, options: [], range: range) != nil
    }

    // MARK: - Batch Validation

    /// Validates a sample of all entities with memory-safe limits
    /// Validation queries are limited to prevent memory exhaustion. For full validation, use paginated approach.
    static func validateAllEntities(in context: ModelContext) -> [String: [ValidationResult]] {
        let validationLimit = 100 // Limit validation to prevent memory issues
        var results: [String: [ValidationResult]] = [:]

        do {
            // Validate users (limited sample)
            logger.info("Validating users (limit: \(validationLimit))...")
            var userDescriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
            userDescriptor.fetchLimit = validationLimit
            let users = try context.fetch(userDescriptor)
            results["User"] = users.map { validateUser($0) }
            if users.count == validationLimit {
                logger.info("User validation limited to \(validationLimit) records. Some users not validated.")
            }

            // Validate plants (limited sample)
            logger.info("Validating plants (limit: \(validationLimit))...")
            var plantDescriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
            plantDescriptor.fetchLimit = validationLimit
            let plants = try context.fetch(plantDescriptor)
            results["Plant"] = plants.map { validatePlant($0) }
            if plants.count == validationLimit {
                logger.info("Plant validation limited to \(validationLimit) records. Some plants not validated.")
            }

            // Validate gardens (limited sample)
            logger.info("Validating gardens (limit: \(validationLimit))...")
            var gardenDescriptor = FetchDescriptor<Garden>(sortBy: [SortDescriptor(\.name)])
            gardenDescriptor.fetchLimit = validationLimit
            let gardens = try context.fetch(gardenDescriptor)
            results["Garden"] = gardens.map { validateGarden($0) }
            if gardens.count == validationLimit {
                logger.info("Garden validation limited to \(validationLimit) records. Some gardens not validated.")
            }

            // Validate plant reminders (limited sample)
            logger.info("Validating reminders (limit: \(validationLimit))...")
            var reminderDescriptor = FetchDescriptor<PlantReminder>(sortBy: [SortDescriptor(\.nextDueDate)])
            reminderDescriptor.fetchLimit = validationLimit
            let reminders = try context.fetch(reminderDescriptor)
            results["PlantReminder"] = reminders.map { validateReminder($0) }
            if reminders.count == validationLimit {
                logger.info("Reminder validation limited to \(validationLimit) records. Some reminders not validated.")
            }

            // Validate journal entries (limited sample)
            logger.info("Validating journal entries (limit: \(validationLimit))...")
            var entryDescriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.entryDate, order: .reverse)])
            entryDescriptor.fetchLimit = validationLimit
            let entries = try context.fetch(entryDescriptor)
            results["JournalEntry"] = entries.map { validateJournalEntry($0) }
            if entries.count == validationLimit {
                logger.info("Journal entry validation limited to \(validationLimit) records. Some entries not validated.")
            }
        } catch {
            logger.error("Error fetching entities for validation: \(error.localizedDescription, privacy: .public)")
        }

        return results
    }

    /// Validates all entities in batches using autoreleasepool for memory efficiency
    /// This is the preferred method for production use with large datasets
    @MainActor
    static func validateAllEntitiesPaginated(
        in context: ModelContext,
        batchSize: Int = 50
    ) async -> [String: [ValidationResult]] {
        var results: [String: [ValidationResult]] = [:]
        let memoryBefore = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576
        logger.info("Starting paginated validation - Memory: \(Int(memoryBefore))MB")

        do {
            // Validate users in batches
            results["User"] = try await validateEntityBatch(
                context: context,
                entityType: User.self,
                batchSize: batchSize,
                validator: validateUser
            )

            // Validate plants in batches
            results["Plant"] = try await validateEntityBatch(
                context: context,
                entityType: Plant.self,
                batchSize: batchSize,
                validator: validatePlant
            )

            // Validate gardens in batches
            results["Garden"] = try await validateEntityBatch(
                context: context,
                entityType: Garden.self,
                batchSize: batchSize,
                validator: validateGarden
            )

            // Validate reminders in batches
            results["PlantReminder"] = try await validateEntityBatch(
                context: context,
                entityType: PlantReminder.self,
                batchSize: batchSize,
                validator: validateReminder
            )

            // Validate journal entries in batches
            results["JournalEntry"] = try await validateEntityBatch(
                context: context,
                entityType: JournalEntry.self,
                batchSize: batchSize,
                validator: validateJournalEntry
            )
        } catch {
            logger.error("Error in paginated validation: \(error.localizedDescription, privacy: .public)")
        }

        let memoryAfter = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576
        let memoryDelta = memoryAfter - memoryBefore
        logger.info("Validation memory usage: \(Int(memoryDelta))MB")

        if memoryDelta > 10 {
            logger.info("High memory usage during validation: \(Int(memoryDelta))MB")
        }

        return results
    }

    /// Helper method to validate entities in batches with autoreleasepool
    @MainActor
    private static func validateEntityBatch<T: PersistentModel>(
        context: ModelContext,
        entityType: T.Type,
        batchSize: Int,
        validator: @escaping (T) -> ValidationResult
    ) async throws -> [ValidationResult] {
        var allResults: [ValidationResult] = []
        var offset = 0
        var hasMore = true

        while hasMore {
            // Wrap batch processing in autoreleasepool
            let batchResults = try autoreleasepool { () -> [ValidationResult] in
                var descriptor = FetchDescriptor<T>()
                descriptor.fetchLimit = batchSize
                descriptor.fetchOffset = offset

                let entities = try context.fetch(descriptor)
                hasMore = entities.count == batchSize
                offset += batchSize

                return entities.map(validator)
            }

            allResults.append(contentsOf: batchResults)

            // Yield control to keep UI responsive
            await Task.yield()
        }

        return allResults
    }
}

// swiftlint:enable cyclomatic_complexity file_length type_body_length
