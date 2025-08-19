import Foundation
import CoreData

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
        static let validSkillLevels = ["beginner", "intermediate", "advanced"]
        static let validDifficultyLevels = ["beginner", "intermediate", "advanced"]
        static let validMaintenanceLevels = ["low", "medium", "high"]
        static let validGardenTypes = ["indoor", "outdoor", "container", "raised_bed", "greenhouse"]
        static let validSunRequirements = ["full_sun", "partial_sun", "partial_shade", "full_shade", "bright_indirect", "low_light"]
        static let validSoilTypes = ["clay", "sandy", "loamy", "well_draining", "rich_loamy", "acidic", "alkaline", "potting_mix", "succulent_mix", "moist", "poor_to_average"]
        static let validHealthStatuses = ["healthy", "stressed", "diseased", "dormant", "recovering"]
        static let validGrowthStages = ["seed", "seedling", "juvenile", "vegetative", "flowering", "fruiting", "mature", "dormant", "declining"]
        static let validReminderTypes = ["watering", "fertilizing", "pruning", "repotting", "pest_check", "harvesting", "custom"]
        static let validPriorities = ["low", "medium", "high", "critical"]
        static let validJournalEntryTypes = ["observation", "care", "harvest", "problem", "milestone", "general"]
        static let validPlantCategories = ["herb", "vegetable", "flower", "succulent", "houseplant", "fruit", "tree", "shrub"]
        
        static let minWateringFrequency = 1
        static let maxWateringFrequency = 365
        static let minTemperature = -50.0
        static let maxTemperature = 150.0
        static let maxNameLength = 100
        static let maxDescriptionLength = 1000
        static let maxNotesLength = 2000
    }
    
    // MARK: - User Validation
    
    static func validateUser(_ user: User) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Skill level validation
        if let skillLevel = user.skillLevel,
           !Constants.validSkillLevels.contains(skillLevel) {
            errors.append("Invalid skill level: \(skillLevel)")
        }
        
        // Garden type validation
        if let gardenType = user.gardenType,
           !Constants.validGardenTypes.contains(gardenType) {
            errors.append("Invalid garden type: \(gardenType)")
        }
        
        // Date validation
        if let createdDate = user.createdDate,
           createdDate > Date() {
            errors.append("Created date cannot be in the future")
        }
        
        if let lastActiveDate = user.lastActiveDate,
           let createdDate = user.createdDate,
           lastActiveDate < createdDate {
            warnings.append("Last active date is before created date")
        }
        
        // Hardiness zone validation
        if let hardinessZone = user.hardinessZone,
           !isValidHardinessZone(hardinessZone) {
            warnings.append("Hardiness zone format may be invalid: \(hardinessZone)")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - Plant Validation
    
    static func validatePlant(_ plant: Plant) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Required fields
        if plant.name?.isEmpty ?? true {
            errors.append("Plant name is required")
        } else if let name = plant.name, name.count > Constants.maxNameLength {
            errors.append("Plant name is too long (max \(Constants.maxNameLength) characters)")
        }
        
        if plant.category?.isEmpty ?? true {
            errors.append("Plant category is required")
        } else if let category = plant.category,
                  !Constants.validPlantCategories.contains(category.lowercased()) {
            warnings.append("Unusual plant category: \(category)")
        }
        
        // Difficulty and maintenance levels
        if let difficultyLevel = plant.difficultyLevel,
           !Constants.validDifficultyLevels.contains(difficultyLevel) {
            errors.append("Invalid difficulty level: \(difficultyLevel)")
        }
        
        if let maintenanceLevel = plant.maintenanceLevel,
           !Constants.validMaintenanceLevels.contains(maintenanceLevel) {
            errors.append("Invalid maintenance level: \(maintenanceLevel)")
        }
        
        // Watering frequency
        if plant.wateringFrequencyDays < Constants.minWateringFrequency ||
           plant.wateringFrequencyDays > Constants.maxWateringFrequency {
            errors.append("Watering frequency must be between \(Constants.minWateringFrequency) and \(Constants.maxWateringFrequency) days")
        }
        
        // Sun requirement
        if let sunRequirement = plant.sunRequirement,
           !Constants.validSunRequirements.contains(sunRequirement) {
            errors.append("Invalid sun requirement: \(sunRequirement)")
        }
        
        // Temperature range
        if plant.temperatureMin < Constants.minTemperature ||
           plant.temperatureMin > Constants.maxTemperature {
            warnings.append("Temperature minimum seems unusual: \(plant.temperatureMin)°F")
        }
        
        if plant.temperatureMax < Constants.minTemperature ||
           plant.temperatureMax > Constants.maxTemperature {
            warnings.append("Temperature maximum seems unusual: \(plant.temperatureMax)°F")
        }
        
        if plant.temperatureMin > plant.temperatureMax {
            errors.append("Minimum temperature cannot be higher than maximum temperature")
        }
        
        // Harvest time validation
        if plant.harvestTimeWeeks < 0 || plant.harvestTimeWeeks > 520 { // ~10 years
            warnings.append("Harvest time seems unusual: \(plant.harvestTimeWeeks) weeks")
        }
        
        // Fertilizing frequency
        if plant.fertilizingFrequencyWeeks < 0 || plant.fertilizingFrequencyWeeks > 52 {
            warnings.append("Fertilizing frequency seems unusual: \(plant.fertilizingFrequencyWeeks) weeks")
        }
        
        // Description length
        if let description = plant.plantDescription,
           description.count > Constants.maxDescriptionLength {
            warnings.append("Plant description is very long (over \(Constants.maxDescriptionLength) characters)")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - Garden Validation
    
    static func validateGarden(_ garden: Garden) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Required fields
        if garden.name?.isEmpty ?? true {
            errors.append("Garden name is required")
        } else if let name = garden.name, name.count > Constants.maxNameLength {
            errors.append("Garden name is too long (max \(Constants.maxNameLength) characters)")
        }
        
        if garden.gardenType?.isEmpty ?? true {
            errors.append("Garden type is required")
        } else if let gardenType = garden.gardenType,
                  !Constants.validGardenTypes.contains(gardenType) {
            errors.append("Invalid garden type: \(gardenType)")
        }
        
        if garden.sunExposure?.isEmpty ?? true {
            errors.append("Sun exposure is required")
        } else if let sunExposure = garden.sunExposure,
                  !Constants.validSunRequirements.contains(sunExposure) {
            errors.append("Invalid sun exposure: \(sunExposure)")
        }
        
        // Date validation
        if let createdDate = garden.createdDate,
           createdDate > Date() {
            errors.append("Garden created date cannot be in the future")
        }
        
        if let lastModified = garden.lastModifiedDate,
           let created = garden.createdDate,
           lastModified < created {
            warnings.append("Last modified date is before created date")
        }
        
        // Owner validation
        if garden.owner == nil {
            errors.append("Garden must have an owner")
        }
        
        // Soil type validation
        if let soilType = garden.soilType,
           !Constants.validSoilTypes.contains(soilType) {
            warnings.append("Unusual soil type: \(soilType)")
        }
        
        // Notes length
        if let notes = garden.notes,
           notes.count > Constants.maxNotesLength {
            warnings.append("Garden notes are very long (over \(Constants.maxNotesLength) characters)")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - UserPlant Validation
    
    static func validateUserPlant(_ userPlant: UserPlant) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Required relationships
        if userPlant.plant == nil {
            errors.append("User plant must be associated with a plant")
        }
        
        if userPlant.garden == nil {
            errors.append("User plant must be associated with a garden")
        }
        
        // Date validations
        if let plantingDate = userPlant.plantingDate,
           plantingDate > Date() {
            errors.append("Planting date cannot be in the future")
        }
        
        if let lastWatered = userPlant.lastWateredDate,
           lastWatered > Date() {
            errors.append("Last watered date cannot be in the future")
        }
        
        if let lastFertilized = userPlant.lastFertilizedDate,
           lastFertilized > Date() {
            errors.append("Last fertilized date cannot be in the future")
        }
        
        if let lastPruned = userPlant.lastPrunedDate,
           lastPruned > Date() {
            errors.append("Last pruned date cannot be in the future")
        }
        
        // Logical date ordering
        if let plantingDate = userPlant.plantingDate,
           let lastWatered = userPlant.lastWateredDate,
           lastWatered < plantingDate {
            warnings.append("Last watered date is before planting date")
        }
        
        // Health status validation
        if let healthStatus = userPlant.healthStatus,
           !Constants.validHealthStatuses.contains(healthStatus) {
            errors.append("Invalid health status: \(healthStatus)")
        }
        
        // Growth stage validation
        if let growthStage = userPlant.currentGrowthStage,
           !Constants.validGrowthStages.contains(growthStage) {
            errors.append("Invalid growth stage: \(growthStage)")
        }
        
        // Custom frequencies validation
        if userPlant.customWateringFrequency < 0 || userPlant.customWateringFrequency > 365 {
            warnings.append("Custom watering frequency seems unusual: \(userPlant.customWateringFrequency) days")
        }
        
        if userPlant.customFertilizingFrequency < 0 || userPlant.customFertilizingFrequency > 52 {
            warnings.append("Custom fertilizing frequency seems unusual: \(userPlant.customFertilizingFrequency) weeks")
        }
        
        // Notes length
        if let notes = userPlant.notes,
           notes.count > Constants.maxNotesLength {
            warnings.append("Plant notes are very long (over \(Constants.maxNotesLength) characters)")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - Reminder Validation
    
    static func validateReminder(_ reminder: Reminder) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Required fields
        if reminder.title?.isEmpty ?? true {
            errors.append("Reminder title is required")
        }
        
        if reminder.type?.isEmpty ?? true {
            errors.append("Reminder type is required")
        } else if let type = reminder.type,
                  !Constants.validReminderTypes.contains(type) {
            errors.append("Invalid reminder type: \(type)")
        }
        
        // Frequency validation
        if reminder.frequencyDays <= 0 || reminder.frequencyDays > 365 {
            errors.append("Reminder frequency must be between 1 and 365 days")
        }
        
        // Priority validation
        if let priority = reminder.priority,
           !Constants.validPriorities.contains(priority) {
            errors.append("Invalid priority: \(priority)")
        }
        
        // Date validations
        if let nextDue = reminder.nextDueDate,
           let created = reminder.createdDate,
           nextDue < created {
            warnings.append("Next due date is before created date")
        }
        
        if let lastCompleted = reminder.lastCompletedDate,
           lastCompleted > Date() {
            errors.append("Last completed date cannot be in the future")
        }
        
        // Relationship validation
        if reminder.userPlant == nil {
            errors.append("Reminder must be associated with a user plant")
        }
        
        // Logic validation
        if reminder.isCompleted && reminder.lastCompletedDate == nil {
            warnings.append("Reminder is marked completed but has no completion date")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }
    
    // MARK: - Journal Entry Validation
    
    static func validateJournalEntry(_ entry: JournalEntry) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Date validations
        if let entryDate = entry.entryDate,
           entryDate > Date() {
            errors.append("Entry date cannot be in the future")
        }
        
        if let created = entry.createdDate,
           created > Date() {
            errors.append("Created date cannot be in the future")
        }
        
        if let entryDate = entry.entryDate,
           let created = entry.createdDate,
           entryDate > created.addingTimeInterval(24 * 60 * 60) { // Allow 1 day tolerance
            warnings.append("Entry date is significantly after created date")
        }
        
        // Entry type validation
        if let entryType = entry.entryType,
           !Constants.validJournalEntryTypes.contains(entryType) {
            warnings.append("Unusual entry type: \(entryType)")
        }
        
        // Content validation
        if entry.title?.isEmpty ?? true && entry.content?.isEmpty ?? true {
            warnings.append("Journal entry has no title or content")
        }
        
        if let content = entry.content,
           content.count > Constants.maxNotesLength * 2 { // Allow longer content for journal
            warnings.append("Journal entry content is very long")
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
    
    // MARK: - Batch Validation
    
    static func validateAllEntities(in context: NSManagedObjectContext) -> [String: [ValidationResult]] {
        var results: [String: [ValidationResult]] = [:]
        
        // Validate all users
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        if let users = try? context.fetch(userRequest) {
            results["User"] = users.map { validateUser($0) }
        }
        
        // Validate all plants
        let plantRequest: NSFetchRequest<Plant> = Plant.fetchRequest()
        if let plants = try? context.fetch(plantRequest) {
            results["Plant"] = plants.map { validatePlant($0) }
        }
        
        // Validate all gardens
        let gardenRequest: NSFetchRequest<Garden> = Garden.fetchRequest()
        if let gardens = try? context.fetch(gardenRequest) {
            results["Garden"] = gardens.map { validateGarden($0) }
        }
        
        // Validate all user plants
        let userPlantRequest: NSFetchRequest<UserPlant> = UserPlant.fetchRequest()
        if let userPlants = try? context.fetch(userPlantRequest) {
            results["UserPlant"] = userPlants.map { validateUserPlant($0) }
        }
        
        // Validate all reminders
        let reminderRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        if let reminders = try? context.fetch(reminderRequest) {
            results["Reminder"] = reminders.map { validateReminder($0) }
        }
        
        // Validate all journal entries
        let entryRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        if let entries = try? context.fetch(entryRequest) {
            results["JournalEntry"] = entries.map { validateJournalEntry($0) }
        }
        
        return results
    }
}