import Foundation
import SwiftData
import GrowWiseModels

/// Comprehensive data validation rules for GrowWise entities
struct DataValidationRules {
    
    // MARK: - Validation Results
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
        let warnings: [String]
        
        static let valid = ValidationResult(isValid: true, errors: [], warnings: [])
        
        static func invalid(errors: [String], warnings: [String] = []) -> ValidationResult {
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
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
        if user.email.isEmpty {
            errors.append("Email is required")
        } else if !isValidEmail(user.email) {
            errors.append("Invalid email format")
        }
        
        // Display name validation
        if user.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
           !isValidHardinessZone(hardinessZone) {
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
        if plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Plant name is required")
        } else if plant.name.count > Constants.maxNameLength {
            errors.append("Plant name is too long (max \(Constants.maxNameLength) characters)")
        }
        
        // Date validations
        if let plantingDate = plant.plantingDate,
           plantingDate > Date() {
            errors.append("Planting date cannot be in the future")
        }
        
        if let harvestDate = plant.harvestDate,
           harvestDate < Date() {
            warnings.append("Harvest date is in the past")
        }
        
        if let plantingDate = plant.plantingDate,
           let harvestDate = plant.harvestDate,
           harvestDate <= plantingDate {
            errors.append("Harvest date must be after planting date")
        }
        
        if let lastWatered = plant.lastWatered,
           lastWatered > Date() {
            errors.append("Last watered date cannot be in the future")
        }
        
        if let lastFertilized = plant.lastFertilized,
           lastFertilized > Date() {
            errors.append("Last fertilized date cannot be in the future")
        }
        
        if let lastPruned = plant.lastPruned,
           lastPruned > Date() {
            errors.append("Last pruned date cannot be in the future")
        }
        
        // Notes length
        if plant.notes.count > Constants.maxNotesLength {
            warnings.append("Plant notes are very long (over \(Constants.maxNotesLength) characters)")
        }
        
        // Garden location validation
        if let location = plant.gardenLocation,
           location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Garden location should not be empty if provided")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - Garden Validation
    
    static func validateGarden(_ garden: Garden) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Required fields
        if garden.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Garden name is required")
        } else if garden.name.count > Constants.maxNameLength {
            errors.append("Garden name is too long (max \(Constants.maxNameLength) characters)")
        }
        
        // Date validation
        if garden.createdDate > Date() {
            errors.append("Garden created date cannot be in the future")
        }
        
        if garden.lastModified < garden.createdDate {
            warnings.append("Last modified date is before created date")
        }
        
        // Hardiness zone validation
        if let hardinessZone = garden.hardinessZone,
           !isValidHardinessZone(hardinessZone) {
            warnings.append("Hardiness zone format may be invalid: \(hardinessZone)")
        }
        
        // Planting date range validation
        if let startDate = garden.plantingStartDate,
           let endDate = garden.plantingEndDate,
           endDate < startDate {
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
        if !plant.isUserPlant {
            errors.append("Plant must be marked as a user plant")
        }
        
        // Required relationships
        if plant.garden == nil {
            errors.append("User plant must be associated with a garden")
        }
        
        // Date validations
        if let plantingDate = plant.plantingDate,
           plantingDate > Date() {
            errors.append("Planting date cannot be in the future")
        }
        
        if let lastWatered = plant.lastWatered,
           lastWatered > Date() {
            errors.append("Last watered date cannot be in the future")
        }
        
        if let lastFertilized = plant.lastFertilized,
           lastFertilized > Date() {
            errors.append("Last fertilized date cannot be in the future")
        }
        
        if let lastPruned = plant.lastPruned,
           lastPruned > Date() {
            errors.append("Last pruned date cannot be in the future")
        }
        
        // Logical date ordering
        if let plantingDate = plant.plantingDate,
           let lastWatered = plant.lastWatered,
           lastWatered < plantingDate {
            warnings.append("Last watered date is before planting date")
        }
        
        // Name validation
        if plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Plant name cannot be empty")
        }
        if plant.name.count > Constants.maxCustomNameLength {
            errors.append("Plant name exceeds maximum length of \(Constants.maxCustomNameLength) characters")
        }
        
        // Garden location validation
        if let location = plant.gardenLocation {
            if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("Garden location should not be empty")
            }
        }
        
        // Notes length
        if plant.notes.count > Constants.maxNotesLength {
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
           lastCompleted > Date() {
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
        if !reminder.isEnabled && reminder.nextDueDate > Date() {
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
        if entry.title.isEmpty && entry.content.isEmpty {
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
    
    static func validateAllEntities(in context: ModelContext) -> [String: [ValidationResult]] {
        var results: [String: [ValidationResult]] = [:]
        
        do {
            // Validate all users
            let userDescriptor = FetchDescriptor<User>()
            let users = try context.fetch(userDescriptor)
            results["User"] = users.map { validateUser($0) }
            
            // Validate all plants
            let plantDescriptor = FetchDescriptor<Plant>()
            let plants = try context.fetch(plantDescriptor)
            results["Plant"] = plants.map { validatePlant($0) }
            
            // Validate all gardens
            let gardenDescriptor = FetchDescriptor<Garden>()
            let gardens = try context.fetch(gardenDescriptor)
            results["Garden"] = gardens.map { validateGarden($0) }
            
            // Validate all plant reminders
            let reminderDescriptor = FetchDescriptor<PlantReminder>()
            let reminders = try context.fetch(reminderDescriptor)
            results["PlantReminder"] = reminders.map { validateReminder($0) }
            
            // Validate all journal entries
            let entryDescriptor = FetchDescriptor<JournalEntry>()
            let entries = try context.fetch(entryDescriptor)
            results["JournalEntry"] = entries.map { validateJournalEntry($0) }
            
        } catch {
            print("Error fetching entities for validation: \(error)")
        }
        
        return results
    }
}
