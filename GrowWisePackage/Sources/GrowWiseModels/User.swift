import Foundation
import SwiftData

@Model
public final class User {
    public var id: UUID = UUID() // CloudKit: made optional or with default value
    public var email: String? // CloudKit: made optional or with default value
    public var displayName: String? // CloudKit: made optional or with default value
    public var skillLevel: GardeningSkillLevel = GardeningSkillLevel.beginner // CloudKit: made optional or with default value
    
    // Onboarding preferences
    public var preferredPlantTypes: [PlantType]? // CloudKit: made optional or with default value
    public var gardeningGoals: [GardeningGoal]? // CloudKit: made optional or with default value
    public var timeCommitment: TimeCommitment = TimeCommitment.moderate // CloudKit: made optional or with default value
    public var experienceYears: Int = 0 // CloudKit: made optional or with default value
    
    // Location and climate
    public var hardinessZone: String? // CloudKit: made optional or with default value
    public var city: String? // CloudKit: made optional or with default value
    public var state: String? // CloudKit: made optional or with default value
    public var country: String? // CloudKit: made optional or with default value
    public var latitude: Double? // CloudKit: made optional or with default value
    public var longitude: Double? // CloudKit: made optional or with default value
    
    public var reminderSettings: ReminderSettings? // CloudKit: made optional or with default value
    public var measurementSystem: MeasurementSystem = MeasurementSystem.imperial // CloudKit: made optional or with default value
    public var language: String? // CloudKit: made optional or with default value
    
    // Subscription and features
    public var subscriptionTier: SubscriptionTier = SubscriptionTier.free // CloudKit: made optional or with default value
    public var subscriptionExpiry: Date? // CloudKit: made optional or with default value
    public var aiDiagnosesUsed: Int = 0 // CloudKit: made optional or with default value
    public var lastDiagnosisReset: Date? // CloudKit: made optional or with default value
    
    // Achievements and progress
    public var plantsGrown: Int = 0 // CloudKit: made optional or with default value
    public var plantsHarvested: Int = 0 // CloudKit: made optional or with default value
    public var streakDays: Int = 0 // CloudKit: made optional or with default value
    public var achievementPoints: Int = 0 // CloudKit: made optional or with default value
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
    public var completedTutorials: [String] = [] // CloudKit: made optional or with default value
    
    // Relationships
    public var gardens: [Garden]? // CloudKit: made optional or with default value
    public var reminders: [PlantReminder]? // CloudKit: made optional or with default value
    public var journalEntries: [JournalEntry]? // CloudKit: made optional or with default value
    
    // Metadata
    public var createdDate: Date = Foundation.Date() // CloudKit: made optional or with default value
    public var lastLoginDate: Date = Foundation.Date() // CloudKit: made optional or with default value
    public var lastModified: Date = Foundation.Date() // CloudKit: made optional or with default value
    
    public init(
        email: String,
        displayName: String,
        skillLevel: GardeningSkillLevel = .beginner
    ) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.skillLevel = skillLevel
        self.preferredPlantTypes = []
        self.gardeningGoals = []
        self.timeCommitment = .moderate
        self.experienceYears = 0
        self.reminderSettings = ReminderSettings()
        self.measurementSystem = .imperial
        self.language = "en"
        self.subscriptionTier = .free
        self.aiDiagnosesUsed = 0
        self.plantsGrown = 0
        self.plantsHarvested = 0
        self.streakDays = 0
        self.achievementPoints = 0
        self.completedTutorials = []
        self.gardens = []
        self.reminders = []
        self.journalEntries = []
        self.createdDate = Date()
        self.lastLoginDate = Date()
        self.lastModified = Date()
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
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
    
    public var description: String {
        switch self {
        case .beginner: return "Just starting out"
        case .intermediate: return "Some gardening experience"
        case .advanced: return "Experienced gardener"
        case .expert: return "Master gardener"
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
        case .growFood: return "Grow My Own Food"
        case .beautifySpace: return "Beautify My Space"
        case .learnSkills: return "Learn New Skills"
        case .relaxation: return "Relaxation & Therapy"
        case .sustainability: return "Environmental Sustainability"
        case .airPurification: return "Improve Air Quality"
        case .medicinalHerbs: return "Grow Medicinal Herbs"
        case .costSavings: return "Save Money on Groceries"
        case .teachChildren: return "Teach Children"
        case .communityGardening: return "Community Involvement"
        }
    }
}

public enum TimeCommitment: String, CaseIterable, Codable, Sendable {
    case minimal    // < 30 min/week
    case light      // 30-60 min/week
    case moderate   // 1-3 hours/week
    case heavy      // 3-6 hours/week
    case intensive  // > 6 hours/week
    
    public var displayName: String {
        switch self {
        case .minimal: return "Minimal (< 30 min/week)"
        case .light: return "Light (30-60 min/week)"
        case .moderate: return "Moderate (1-3 hours/week)"
        case .heavy: return "Heavy (3-6 hours/week)"
        case .intensive: return "Intensive (> 6 hours/week)"
        }
    }
    
    public var minutesPerWeek: Int {
        switch self {
        case .minimal: return 15
        case .light: return 45
        case .moderate: return 120
        case .heavy: return 270
        case .intensive: return 420
        }
    }
}

public enum MeasurementSystem: String, CaseIterable, Codable, Sendable {
    case imperial
    case metric
    
    public var displayName: String {
        switch self {
        case .imperial: return "Imperial (inches, feet, °F)"
        case .metric: return "Metric (cm, meters, °C)"
        }
    }
}

public enum SubscriptionTier: String, CaseIterable, Codable, Sendable {
    case free
    case premium
    case pro
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }
    
    public var monthlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .premium: return 4.99
        case .pro: return 9.99
        }
    }
    
    public var aiDiagnosesPerMonth: Int {
        switch self {
        case .free: return 3
        case .premium: return -1 // Unlimited
        case .pro: return -1 // Unlimited
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
    public var quietHoursEnd: Date?   // Time of day to resume notifications
    public var weekendReminders: Bool? // CloudKit: made optional or with default value
    
    public var pushNotifications: Bool? // CloudKit: made optional or with default value
    public var emailNotifications: Bool? // CloudKit: made optional or with default value
    public var inAppNotifications: Bool? // CloudKit: made optional or with default value
    
    public var user: User?
    
    public init() {
        self.enableWateringReminders = true
        self.enableFertilizingReminders = true
        self.enablePruningReminders = true
        self.enableHarvestReminders = true
        self.enableSeasonalReminders = true
        self.weekendReminders = true
        self.pushNotifications = true
        self.emailNotifications = false
        self.inAppNotifications = true
    }
}

