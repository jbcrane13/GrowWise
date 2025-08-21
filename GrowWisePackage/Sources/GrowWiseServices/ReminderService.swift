import Foundation
import SwiftData
import WeatherKit
import CoreLocation
import GrowWiseModels

@MainActor
public final class ReminderService: ObservableObject {
    public let dataService: DataService
    public let notificationService: NotificationService
    private let weatherService = WeatherService.shared
    
    public init(dataService: DataService, notificationService: NotificationService) {
        self.dataService = dataService
        self.notificationService = notificationService
    }
    
    // MARK: - Smart Reminder Scheduling
    
    public func createSmartReminder(
        for plant: Plant,
        type: ReminderType,
        baseFrequencyDays: Int,
        enableWeatherAdjustment: Bool = true,
        priority: ReminderPriority = .medium,
        preferredTime: Date? = nil
    ) async throws -> PlantReminder {
        
        let nextDueDate = await calculateNextDueDate(
            baseFrequencyDays: baseFrequencyDays,
            reminderType: type,
            plant: plant,
            enableWeatherAdjustment: enableWeatherAdjustment,
            preferredTime: preferredTime
        )
        
        let reminder = try dataService.createReminder(
            title: generateReminderTitle(type: type, plant: plant),
            message: generateReminderMessage(type: type, plant: plant),
            type: type,
            frequency: .custom(days: baseFrequencyDays),
            dueDate: nextDueDate,
            plant: plant
        )
        
        // Set smart reminder properties
        reminder.priority = priority
        reminder.enableWeatherAdjustment = enableWeatherAdjustment
        reminder.baseFrequencyDays = baseFrequencyDays
        
        // Set preferred notification time if provided
        if let preferredTime = preferredTime {
            reminder.preferredNotificationTime = preferredTime
        }
        
        try await notificationService.scheduleReminderNotification(for: reminder)
        
        return reminder
    }
    
    // MARK: - Watering Reminder Specific Features
    
    public func createWateringReminder(
        for plant: Plant,
        frequency: ReminderFrequency,
        preferredTime: Date? = nil,
        enableSmartAdjustment: Bool = true
    ) async throws -> PlantReminder {
        
        let baseFrequencyDays = frequency.days
        
        return try await createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: baseFrequencyDays,
            enableWeatherAdjustment: enableSmartAdjustment,
            priority: .high,
            preferredTime: preferredTime
        )
    }
    
    public func updateWateringSchedule(
        for reminder: PlantReminder,
        newFrequency: ReminderFrequency,
        preferredTime: Date? = nil
    ) async throws {
        guard reminder.reminderType == .watering else {
            throw ReminderError.invalidReminderType
        }
        
        reminder.frequency = newFrequency
        reminder.baseFrequencyDays = newFrequency.days
        
        if let preferredTime = preferredTime {
            reminder.preferredNotificationTime = preferredTime
        }
        
        // Recalculate next due date with new frequency
        if let plant = reminder.plant {
            reminder.nextDueDate = await calculateNextDueDate(
                baseFrequencyDays: newFrequency.days,
                reminderType: .watering,
                plant: plant,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                preferredTime: preferredTime
            )
        }
        
        // Update notification
        try await notificationService.scheduleReminderNotification(for: reminder)
    }
    
    public func getWateringReminders(for plant: Plant? = nil) -> [PlantReminder] {
        let allReminders = dataService.fetchActiveReminders()
        let wateringReminders = allReminders.filter { $0.reminderType == .watering }
        
        if let plant = plant {
            return wateringReminders.filter { $0.plant?.id == plant.id }
        }
        
        return wateringReminders
    }
    
    public func getOverdueWateringReminders() -> [PlantReminder] {
        let wateringReminders = getWateringReminders()
        return wateringReminders.filter { $0.nextDueDate < Date() && $0.isEnabled }
    }
    
    public func getTodaysWateringReminders() -> [PlantReminder] {
        let wateringReminders = getWateringReminders()
        let calendar = Calendar.current
        
        return wateringReminders.filter { reminder in
            calendar.isDate(reminder.nextDueDate, inSameDayAs: Date()) && reminder.isEnabled
        }
    }
    
    private func calculateNextDueDate(
        baseFrequencyDays: Int,
        reminderType: ReminderType,
        plant: Plant,
        enableWeatherAdjustment: Bool,
        preferredTime: Date? = nil
    ) async -> Date {
        let baseDate = Calendar.current.date(byAdding: .day, value: baseFrequencyDays, to: Date()) ?? Date()
        
        var adjustedDate = baseDate
        
        if enableWeatherAdjustment {
            adjustedDate = await adjustDateForWeather(baseDate: baseDate, reminderType: reminderType, plant: plant)
        }
        
        // Apply preferred time if specified
        if let preferredTime = preferredTime {
            adjustedDate = applyPreferredTime(to: adjustedDate, preferredTime: preferredTime)
        }
        
        // Respect quiet hours
        adjustedDate = adjustForQuietHours(date: adjustedDate)
        
        return adjustedDate
    }
    
    private func applyPreferredTime(to date: Date, preferredTime: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: preferredTime)
        return calendar.date(bySettingHour: timeComponents.hour ?? 9, 
                           minute: timeComponents.minute ?? 0, 
                           second: 0, 
                           of: date) ?? date
    }
    
    private func adjustForQuietHours(date: Date) -> Date {
        if notificationService.isInQuietHours() {
            // If the scheduled time is in quiet hours, move to next available time
            let calendar = Calendar.current
            var adjustedDate = date
            
            // Move to 8 AM the next day if in quiet hours
            if let nextMorning = calendar.date(byAdding: .day, value: 1, to: date) {
                adjustedDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: nextMorning) ?? date
            }
            
            return adjustedDate
        }
        
        return date
    }
    
    private func adjustDateForWeather(
        baseDate: Date,
        reminderType: ReminderType,
        plant: Plant
    ) async -> Date {
        // For demo purposes, we'll simulate weather adjustment
        // In a real app, you'd integrate with WeatherKit or similar service
        
        switch reminderType {
        case .watering:
            return await adjustWateringForWeather(baseDate: baseDate, plant: plant)
        case .fertilizing:
            return adjustFertilizingForWeather(baseDate: baseDate)
        case .pruning:
            return adjustPruningForWeather(baseDate: baseDate)
        case .pestControl:
            return adjustPestCheckForWeather(baseDate: baseDate)
        case .harvest:
            return baseDate // Harvest timing usually doesn't adjust for weather
        case .repotting, .planting, .inspection, .soilTest, .mulching:
            return baseDate // These tasks don't typically adjust for weather
        case .custom:
            return baseDate
        }
    }
    
    private func adjustWateringForWeather(baseDate: Date, plant: Plant) async -> Date {
        // Simulate weather-based watering adjustment
        let random = Double.random(in: 0...1)
        
        if random < 0.3 { // 30% chance of rain delay
            return Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        } else if random > 0.8 { // 20% chance of hot weather advancement
            return Calendar.current.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate
        }
        
        return baseDate
    }
    
    private func adjustFertilizingForWeather(baseDate: Date) -> Date {
        // Avoid fertilizing during extreme weather
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: baseDate)
        
        // Prefer mid-week fertilizing (Tuesday-Thursday)
        if weekday == 1 || weekday == 7 { // Weekend
            return calendar.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate
        }
        
        return baseDate
    }
    
    private func adjustPruningForWeather(baseDate: Date) -> Date {
        // Prefer dry days for pruning to prevent disease
        // This is a simplified implementation
        return baseDate
    }
    
    private func adjustPestCheckForWeather(baseDate: Date) -> Date {
        // Increase frequency during warm, humid conditions
        // This is a simplified implementation
        return baseDate
    }
    
    // MARK: - Seasonal Care Automation
    
    public func createSeasonalCareSchedule(for plant: Plant, year: Int = Calendar.current.component(.year, from: Date())) async throws {
        let seasonalTasks = generateSeasonalTasks(for: plant, year: year)
        
        for task in seasonalTasks {
            let _ = try await createSmartReminder(
                for: plant,
                type: task.type,
                baseFrequencyDays: task.frequencyDays,
                enableWeatherAdjustment: task.weatherSensitive,
                priority: task.priority
            )
            
            // Note: Seasonal context could be stored in reminder.message if needed
            // For now, we'll track this through the reminder title and type
        }
    }
    
    private func generateSeasonalTasks(for plant: Plant, year: Int) -> [SeasonalTask] {
        var tasks: [SeasonalTask] = []
        
        // Spring tasks
        tasks.append(contentsOf: [
            SeasonalTask(
                type: .fertilizing,
                season: .spring,
                frequencyDays: 21,
                priority: .high,
                weatherSensitive: true
            ),
            SeasonalTask(
                type: .pruning,
                season: .spring,
                frequencyDays: 30,
                priority: .medium,
                weatherSensitive: true
            ),
            SeasonalTask(
                type: .pestControl,
                season: .spring,
                frequencyDays: 7,
                priority: .medium,
                weatherSensitive: false
            )
        ])
        
        // Summer tasks
        tasks.append(contentsOf: [
            SeasonalTask(
                type: .watering,
                season: .summer,
                frequencyDays: 2,
                priority: .high,
                weatherSensitive: true
            ),
            SeasonalTask(
                type: .pestControl,
                season: .summer,
                frequencyDays: 5,
                priority: .high,
                weatherSensitive: false
            )
        ])
        
        // Fall tasks
        tasks.append(contentsOf: [
            SeasonalTask(
                type: .harvest,
                season: .fall,
                frequencyDays: 14,
                priority: .high,
                weatherSensitive: false
            ),
            SeasonalTask(
                type: .pruning,
                season: .fall,
                frequencyDays: 45,
                priority: .medium,
                weatherSensitive: true
            )
        ])
        
        // Winter tasks
        tasks.append(contentsOf: [
            SeasonalTask(
                type: .watering,
                season: .winter,
                frequencyDays: 7,
                priority: .low,
                weatherSensitive: true
            )
        ])
        
        // Filter tasks based on plant type and characteristics
        return tasks.filter { task in
            isTaskRelevant(task, for: plant)
        }
    }
    
    private func isTaskRelevant(_ task: SeasonalTask, for plant: Plant) -> Bool {
        // Customize tasks based on plant characteristics
        switch plant.plantType {
        case .houseplant:
            // Indoor plants don't need seasonal pruning or pest checks as frequently
            return task.type != .pruning || task.season != .fall
        case .succulent:
            // Succulents need less frequent watering
            if task.type == .watering {
                return task.season != .winter
            }
            return true
        case .herb, .vegetable:
            // Most tasks are relevant for edible plants
            return true
        case .flower:
            // Flowers benefit from deadheading (pruning) during growing season
            return true
        case .fruit:
            // Fruit plants need all seasonal care
            return true
        case .tree, .shrub:
            // Trees and shrubs need all seasonal care
            return true
        }
    }
    
    // MARK: - Batch Operations
    
    public func createBatchReminders(
        for plants: [Plant],
        type: ReminderType,
        frequencyDays: Int,
        enableWeatherAdjustment: Bool = true
    ) async throws -> [PlantReminder] {
        var reminders: [PlantReminder] = []
        
        for plant in plants {
            do {
                let reminder = try await createSmartReminder(
                    for: plant,
                    type: type,
                    baseFrequencyDays: frequencyDays,
                    enableWeatherAdjustment: enableWeatherAdjustment
                )
                reminders.append(reminder)
            } catch {
                print("Failed to create reminder for plant \(plant.name): \(error)")
            }
        }
        
        return reminders
    }
    
    public func updateBatchReminders(
        _ reminders: [PlantReminder],
        newFrequencyDays: Int? = nil,
        enableWeatherAdjustment: Bool? = nil
    ) async throws {
        for reminder in reminders {
            if let newFrequency = newFrequencyDays {
                reminder.baseFrequencyDays = newFrequency
                reminder.frequency = .custom(days: newFrequency)
            }
            
            if let weatherAdjustment = enableWeatherAdjustment {
                reminder.enableWeatherAdjustment = weatherAdjustment
            }
            
            // Recalculate next due date
            if let plant = reminder.plant {
                reminder.nextDueDate = await calculateNextDueDate(
                    baseFrequencyDays: reminder.baseFrequencyDays,
                    reminderType: reminder.reminderType,
                    plant: plant,
                    enableWeatherAdjustment: reminder.enableWeatherAdjustment
                )
            }
            
            // Update notification
            try await notificationService.scheduleReminderNotification(for: reminder)
        }
    }
    
    public func completeBatchReminders(_ reminders: [PlantReminder]) async throws {
        for reminder in reminders {
            try dataService.completeReminder(reminder)
            
            // Reschedule if it's a recurring reminder
            if reminder.isRecurring {
                if let plant = reminder.plant {
                    reminder.nextDueDate = await calculateNextDueDate(
                        baseFrequencyDays: reminder.baseFrequencyDays,
                        reminderType: reminder.reminderType,
                        plant: plant,
                        enableWeatherAdjustment: reminder.enableWeatherAdjustment
                    )
                    
                    try await notificationService.scheduleReminderNotification(for: reminder)
                }
            }
        }
    }
    
    // MARK: - Smart Suggestions
    
    public func suggestReminders(for plant: Plant) async -> [ReminderSuggestion] {
        var suggestions: [ReminderSuggestion] = []
        
        // Analyze existing reminders
        let existingReminders = dataService.fetchActiveReminders().filter { $0.plant?.id == plant.id }
        let existingTypes = Set(existingReminders.map { $0.reminderType })
        
        // Suggest missing essential reminders
        let essentialTypes: [ReminderType] = [.watering, .fertilizing, .pestControl]
        
        for type in essentialTypes {
            if !existingTypes.contains(type) {
                let suggestion = ReminderSuggestion(
                    type: type,
                    plant: plant,
                    suggestedFrequencyDays: getRecommendedFrequency(for: type, plant: plant),
                    reason: generateSuggestionReason(for: type, plant: plant),
                    priority: getPriorityForType(type, plant: plant)
                )
                suggestions.append(suggestion)
            }
        }
        
        // Add seasonal suggestions based on current date
        let seasonalSuggestions = await generateSeasonalSuggestions(for: plant)
        suggestions.append(contentsOf: seasonalSuggestions)
        
        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func generateSeasonalSuggestions(for plant: Plant) async -> [ReminderSuggestion] {
        let currentSeason = getCurrentSeason()
        var suggestions: [ReminderSuggestion] = []
        
        switch currentSeason {
        case .spring:
            suggestions.append(ReminderSuggestion(
                type: .fertilizing,
                plant: plant,
                suggestedFrequencyDays: 21,
                reason: "Spring is the ideal time to start fertilizing for healthy growth",
                priority: .high
            ))
            
        case .summer:
            suggestions.append(ReminderSuggestion(
                type: .watering,
                plant: plant,
                suggestedFrequencyDays: 2,
                reason: "Summer heat requires more frequent watering",
                priority: .high
            ))
            
        case .fall:
            if plant.plantType == .vegetable || plant.plantType == .herb {
                suggestions.append(ReminderSuggestion(
                    type: .harvest,
                    plant: plant,
                    suggestedFrequencyDays: 7,
                    reason: "Fall harvest season for many edible plants",
                    priority: .high
                ))
            }
            
        case .winter:
            suggestions.append(ReminderSuggestion(
                type: .watering,
                plant: plant,
                suggestedFrequencyDays: 10,
                reason: "Reduce watering frequency during winter dormancy",
                priority: .medium
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func generateReminderTitle(type: ReminderType, plant: Plant) -> String {
        switch type {
        case .watering:
            return "Water \(plant.name)"
        case .fertilizing:
            return "Fertilize \(plant.name)"
        case .pruning:
            return "Prune \(plant.name)"
        case .pestControl:
            return "Check \(plant.name) for pests"
        case .harvest:
            return "Harvest \(plant.name)"
        case .repotting:
            return "Repot \(plant.name)"
        case .planting:
            return "Plant \(plant.name)"
        case .inspection:
            return "Inspect \(plant.name)"
        case .soilTest:
            return "Test soil for \(plant.name)"
        case .mulching:
            return "Mulch around \(plant.name)"
        case .custom:
            return "Care for \(plant.name)"
        }
    }
    
    private func generateReminderMessage(type: ReminderType, plant: Plant) -> String {
        switch type {
        case .watering:
            return "Check soil moisture and water \(plant.name) if needed. Water slowly at soil level."
        case .fertilizing:
            return "Apply appropriate fertilizer to \(plant.name) according to plant needs."
        case .pruning:
            return "Inspect \(plant.name) and prune dead, damaged, or overgrown parts."
        case .pestControl:
            return "Examine \(plant.name) leaves and stems for signs of pests or disease."
        case .harvest:
            return "Check \(plant.name) for ripe fruits, vegetables, or herbs ready to harvest."
        case .repotting:
            return "Check if \(plant.name) needs repotting - look for roots growing through drainage holes."
        case .planting:
            return "Plant \(plant.name) in prepared soil with proper spacing."
        case .inspection:
            return "Perform general health inspection of \(plant.name) for any issues."
        case .soilTest:
            return "Test soil pH and nutrients for \(plant.name)'s growing area."
        case .mulching:
            return "Apply or refresh mulch around \(plant.name) to retain moisture."
        case .custom:
            return "Perform scheduled care task for \(plant.name)."
        }
    }
    
    private func getRecommendedFrequency(for type: ReminderType, plant: Plant) -> Int {
        switch type {
        case .watering:
            if plant.plantType == .succulent {
                return 7
            } else if plant.plantType == .houseplant {
                return 5
            } else {
                return 3
            }
        case .fertilizing:
            return 28
        case .pruning:
            return 60
        case .pestControl:
            return 7
        case .harvest:
            return 14
        case .repotting:
            return 365 // Once per year
        case .planting:
            return 180 // Seasonal
        case .inspection:
            return 7 // Weekly
        case .soilTest:
            return 365 // Annual
        case .mulching:
            return 120 // 3-4 times per year
        case .custom:
            return 7
        }
    }
    
    private func generateSuggestionReason(for type: ReminderType, plant: Plant) -> String {
        switch type {
        case .watering:
            return "Regular watering schedule helps maintain consistent soil moisture"
        case .fertilizing:
            return "Monthly fertilizing supports healthy growth and flowering"
        case .pruning:
            return "Regular pruning promotes bushier growth and removes dead material"
        case .pestControl:
            return "Weekly pest checks allow for early detection and treatment"
        case .harvest:
            return "Regular harvest encourages continued production"
        case .repotting:
            return "Annual repotting ensures adequate root space and fresh soil"
        case .planting:
            return "Proper timing ensures successful plant establishment"
        case .inspection:
            return "Regular inspection allows early detection of problems"
        case .soilTest:
            return "Annual soil testing helps maintain optimal growing conditions"
        case .mulching:
            return "Mulching conserves moisture and suppresses weeds"
        case .custom:
            return "Custom care routine for optimal plant health"
        }
    }
    
    private func getPriorityForType(_ type: ReminderType, plant: Plant) -> ReminderPriority {
        switch type {
        case .watering:
            return .high
        case .fertilizing:
            return .medium
        case .pruning:
            return .low
        case .pestControl:
            return .medium
        case .harvest:
            return .high
        case .repotting:
            return .low
        case .planting:
            return .high
        case .inspection:
            return .medium
        case .soilTest:
            return .low
        case .mulching:
            return .low
        case .custom:
            return .medium
        }
    }
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5:
            return .spring
        case 6...8:
            return .summer
        case 9...11:
            return .fall
        default:
            return .winter
        }
    }
}

// MARK: - Supporting Types

public struct SeasonalTask {
    let type: ReminderType
    let season: Season
    let frequencyDays: Int
    let priority: ReminderPriority
    let weatherSensitive: Bool
    
    public init(type: ReminderType, season: Season, frequencyDays: Int, priority: ReminderPriority, weatherSensitive: Bool) {
        self.type = type
        self.season = season
        self.frequencyDays = frequencyDays
        self.priority = priority
        self.weatherSensitive = weatherSensitive
    }
}

public struct ReminderSuggestion: Identifiable {
    public let id = UUID()
    public let type: ReminderType
    public let plant: Plant
    public let suggestedFrequencyDays: Int
    public let reason: String
    public let priority: ReminderPriority
    
    public init(type: ReminderType, plant: Plant, suggestedFrequencyDays: Int, reason: String, priority: ReminderPriority) {
        self.type = type
        self.plant = plant
        self.suggestedFrequencyDays = suggestedFrequencyDays
        self.reason = reason
        self.priority = priority
    }
}

public enum Season: String, CaseIterable, Codable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"
    
    public var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall: return "Fall"
        case .winter: return "Winter"
        }
    }
}

// MARK: - Supporting Types

public enum ReminderError: Error, LocalizedError {
    case invalidReminderType
    case plantNotFound
    case notificationPermissionDenied
    case invalidFrequency
    case invalidTime
    
    public var errorDescription: String? {
        switch self {
        case .invalidReminderType:
            return "Invalid reminder type specified"
        case .plantNotFound:
            return "Plant not found for reminder"
        case .notificationPermissionDenied:
            return "Notification permission denied"
        case .invalidFrequency:
            return "Invalid reminder frequency"
        case .invalidTime:
            return "Invalid notification time"
        }
    }
}

public struct ReminderSettings {
    public var enableWateringReminders: Bool
    public var enableFertilizingReminders: Bool
    public var enablePestControlReminders: Bool
    public var enableWeatherBasedAdjustments: Bool
    public var quietHoursStart: Date?
    public var quietHoursEnd: Date?
    public var defaultNotificationTime: Date?
    
    public init(
        enableWateringReminders: Bool = true,
        enableFertilizingReminders: Bool = true,
        enablePestControlReminders: Bool = true,
        enableWeatherBasedAdjustments: Bool = true,
        quietHoursStart: Date? = nil,
        quietHoursEnd: Date? = nil,
        defaultNotificationTime: Date? = nil
    ) {
        self.enableWateringReminders = enableWateringReminders
        self.enableFertilizingReminders = enableFertilizingReminders
        self.enablePestControlReminders = enablePestControlReminders
        self.enableWeatherBasedAdjustments = enableWeatherBasedAdjustments
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.defaultNotificationTime = defaultNotificationTime
    }
}

extension ReminderService {
    
    // MARK: - Notification Settings Management
    
    public func updateNotificationSettings(
        reminderTypes: [ReminderType],
        enabled: Bool
    ) {
        for type in reminderTypes {
            UserDefaults.standard.set(enabled, forKey: "notification_\(type.rawValue)_enabled")
        }
    }
    
    public func isNotificationEnabled(for type: ReminderType) -> Bool {
        return UserDefaults.standard.bool(forKey: "notification_\(type.rawValue)_enabled")
    }
    
    public func setDefaultNotificationTime(_ time: Date) {
        UserDefaults.standard.set(time, forKey: "default_notification_time")
    }
    
    public func getDefaultNotificationTime() -> Date {
        if let time = UserDefaults.standard.object(forKey: "default_notification_time") as? Date {
            return time
        }
        
        // Default to 9:00 AM
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    // MARK: - Reminder Settings
    
    public func updateReminderSettings(_ settings: ReminderSettings) {
        UserDefaults.standard.set(settings.enableWateringReminders, forKey: "enable_watering_reminders")
        UserDefaults.standard.set(settings.enableFertilizingReminders, forKey: "enable_fertilizing_reminders")
        UserDefaults.standard.set(settings.enablePestControlReminders, forKey: "enable_pest_control_reminders")
        UserDefaults.standard.set(settings.enableWeatherBasedAdjustments, forKey: "enable_weather_adjustments")
        
        if let quietStart = settings.quietHoursStart {
            UserDefaults.standard.set(quietStart, forKey: "quiet_hours_start")
        }
        
        if let quietEnd = settings.quietHoursEnd {
            UserDefaults.standard.set(quietEnd, forKey: "quiet_hours_end")
        }
        
        if let defaultTime = settings.defaultNotificationTime {
            setDefaultNotificationTime(defaultTime)
        }
    }
    
    public func getReminderSettings() -> ReminderSettings {
        let quietStart = UserDefaults.standard.object(forKey: "quiet_hours_start") as? Date
        let quietEnd = UserDefaults.standard.object(forKey: "quiet_hours_end") as? Date
        let defaultTime = UserDefaults.standard.object(forKey: "default_notification_time") as? Date
        
        return ReminderSettings(
            enableWateringReminders: UserDefaults.standard.bool(forKey: "enable_watering_reminders"),
            enableFertilizingReminders: UserDefaults.standard.bool(forKey: "enable_fertilizing_reminders"),
            enablePestControlReminders: UserDefaults.standard.bool(forKey: "enable_pest_control_reminders"),
            enableWeatherBasedAdjustments: UserDefaults.standard.bool(forKey: "enable_weather_adjustments"),
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd,
            defaultNotificationTime: defaultTime ?? getDefaultNotificationTime()
        )
    }
    
    // MARK: - Public Notification Methods
    
    /// Schedule notification for a reminder
    public func scheduleNotification(for reminder: PlantReminder) async throws {
        try await notificationService.scheduleReminderNotification(for: reminder)
    }
    
    /// Cancel notification for a reminder
    public func cancelNotification(for reminder: PlantReminder) {
        Task {
            await notificationService.cancelReminderNotification(for: reminder.id)
        }
    }
}

// MARK: - Supporting Types


