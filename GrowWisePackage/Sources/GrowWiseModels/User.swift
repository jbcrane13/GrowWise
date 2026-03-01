import Foundation
import SwiftData

@Model
public final class User {
    public var id = UUID() // CloudKit: made optional or with default value
    public var email: String? // CloudKit: made optional or with default value
    public var displayName: String? // CloudKit: made optional or with default value
    public var skillLevel = GardeningSkillLevel.beginner // CloudKit: made optional or with default value

    // Onboarding preferences
    public var preferredPlantTypes: [PlantType]? // CloudKit: made optional or with default value
    public var gardeningGoals: [GardeningGoal]? // CloudKit: made optional or with default value
    public var timeCommitment = TimeCommitment.moderate // CloudKit: made optional or with default value
    public var experienceYears: Int = 0 // CloudKit: made optional or with default value

    // Location and climate
    public var hardinessZone: String? // CloudKit: made optional or with default value
    public var city: String? // CloudKit: made optional or with default value
    public var state: String? // CloudKit: made optional or with default value
    public var country: String? // CloudKit: made optional or with default value
    public var latitude: Double? // CloudKit: made optional or with default value
    public var longitude: Double? // CloudKit: made optional or with default value

    @Relationship(deleteRule: .cascade, inverse: \ReminderSettings.user)
    public var reminderSettings: ReminderSettings?
    public var measurementSystem = MeasurementSystem.imperial // CloudKit: made optional or with default value
    public var language: String? // CloudKit: made optional or with default value

    // Subscription and features
    public var subscriptionTier = SubscriptionTier.free // CloudKit: made optional or with default value
    public var subscriptionExpiry: Date? // CloudKit: made optional or with default value
    public var aiDiagnosesUsed: Int = 0 // CloudKit: made optional or with default value
    public var lastDiagnosisReset: Date? // CloudKit: made optional or with default value

    // Achievements and progress
    public var plantsGrown: Int = 0 // CloudKit: made optional or with default value
    public var plantsHarvested: Int = 0 // CloudKit: made optional or with default value
    public var streakDays: Int = 0 // CloudKit: made optional or with default value
    public var achievementPoints: Int = 0 // CloudKit: made optional or with default value
    public var completedTutorials: [String] = []

    /// Relationships
    @Relationship(deleteRule: .nullify, inverse: \Garden.user)
    public var gardens: [Garden]?
    @Relationship(deleteRule: .nullify, inverse: \PlantReminder.user)
    public var reminders: [PlantReminder]?
    @Relationship(deleteRule: .nullify, inverse: \JournalEntry.user)
    public var journalEntries: [JournalEntry]?

    // Metadata
    public var createdDate: Date = Foundation.Date() // CloudKit: made optional or with default value
    public var lastLoginDate: Date = Foundation.Date() // CloudKit: made optional or with default value
    public var lastModified: Date = Foundation.Date() // CloudKit: made optional or with default value

    public init(
        email: String,
        displayName: String,
        skillLevel: GardeningSkillLevel = .beginner
    ) {
        id = UUID()
        self.email = email
        self.displayName = displayName
        self.skillLevel = skillLevel
        preferredPlantTypes = []
        gardeningGoals = []
        timeCommitment = .moderate
        experienceYears = 0
        reminderSettings = ReminderSettings()
        measurementSystem = .imperial
        language = "en"
        subscriptionTier = .free
        aiDiagnosesUsed = 0
        plantsGrown = 0
        plantsHarvested = 0
        streakDays = 0
        achievementPoints = 0
        completedTutorials = []
        gardens = []
        reminders = []
        journalEntries = []
        createdDate = Date()
        lastLoginDate = Date()
        lastModified = Date()
    }
}

// MARK: - Supporting Types

public enum GardeningSkillLevel: String, CaseIterable, Codable, Sendable {
    case beginner
    case intermediate
    case advanced
    case expert

    public var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .expert: "Expert"
        }
    }

    public var description: String {
        switch self {
        case .beginner: "Just starting out"
        case .intermediate: "Some gardening experience"
        case .advanced: "Experienced gardener"
        case .expert: "Master gardener"
        }
    }
}

public enum GardeningGoal: String, CaseIterable, Codable, Sendable {
    case growFood
    case beautifySpace
    case learnSkills
    case relaxation
    case sustainability
    case airPurification
    case medicinalHerbs
    case costSavings
    case teachChildren
    case communityGardening

    public var displayName: String {
        switch self {
        case .growFood: "Grow My Own Food"
        case .beautifySpace: "Beautify My Space"
        case .learnSkills: "Learn New Skills"
        case .relaxation: "Relaxation & Therapy"
        case .sustainability: "Environmental Sustainability"
        case .airPurification: "Improve Air Quality"
        case .medicinalHerbs: "Grow Medicinal Herbs"
        case .costSavings: "Save Money on Groceries"
        case .teachChildren: "Teach Children"
        case .communityGardening: "Community Involvement"
        }
    }
}

public enum TimeCommitment: String, CaseIterable, Codable, Sendable {
    case minimal // < 30 min/week
    case light // 30-60 min/week
    case moderate // 1-3 hours/week
    case heavy // 3-6 hours/week
    case intensive // > 6 hours/week

    public var displayName: String {
        switch self {
        case .minimal: "Minimal (< 30 min/week)"
        case .light: "Light (30-60 min/week)"
        case .moderate: "Moderate (1-3 hours/week)"
        case .heavy: "Heavy (3-6 hours/week)"
        case .intensive: "Intensive (> 6 hours/week)"
        }
    }

    public var minutesPerWeek: Int {
        switch self {
        case .minimal: 15
        case .light: 45
        case .moderate: 120
        case .heavy: 270
        case .intensive: 420
        }
    }
}

public enum MeasurementSystem: String, CaseIterable, Codable, Sendable {
    case imperial
    case metric

    public var displayName: String {
        switch self {
        case .imperial: "Imperial (inches, feet, °F)"
        case .metric: "Metric (cm, meters, °C)"
        }
    }
}

public enum SubscriptionTier: String, CaseIterable, Codable, Sendable {
    case free
    case premium
    case pro

    public var displayName: String {
        switch self {
        case .free: "Free"
        case .premium: "Premium"
        case .pro: "Pro"
        }
    }

    public var monthlyPrice: Double {
        switch self {
        case .free: 0.0
        case .premium: 4.99
        case .pro: 9.99
        }
    }

    public var aiDiagnosesPerMonth: Int {
        switch self {
        case .free: 3
        case .premium: -1 // Unlimited
        case .pro: -1 // Unlimited
        }
    }
}

@Model
public final class ReminderSettings {
    public var enableWateringReminders: Bool? // CloudKit: made optional or with default value
    public var enableFertilizingReminders: Bool? // CloudKit: made optional or with default value
    public var enablePruningReminders: Bool? // CloudKit: made optional or with default value
    public var enableHarvestReminders: Bool? // CloudKit: made optional or with default value
    public var enableSeasonalReminders: Bool? // CloudKit: made optional or with default value

    public var quietHoursStart: Date? // Time of day to stop notifications
    public var quietHoursEnd: Date? // Time of day to resume notifications
    public var weekendReminders: Bool? // CloudKit: made optional or with default value

    public var pushNotifications: Bool? // CloudKit: made optional or with default value
    public var emailNotifications: Bool? // CloudKit: made optional or with default value
    public var inAppNotifications: Bool? // CloudKit: made optional or with default value

    public var user: User?

    public init() {
        enableWateringReminders = true
        enableFertilizingReminders = true
        enablePruningReminders = true
        enableHarvestReminders = true
        enableSeasonalReminders = true
        weekendReminders = true
        pushNotifications = true
        emailNotifications = false
        inAppNotifications = true
    }
}
