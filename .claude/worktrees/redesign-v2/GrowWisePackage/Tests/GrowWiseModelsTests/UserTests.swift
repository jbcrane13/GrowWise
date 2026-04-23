import Testing
import Foundation
@testable import GrowWiseModels

@Suite("User Model Tests")
struct UserTests {
    
    @Test("User initialization with valid data")
    func testUserInitialization() async throws {
        // Arrange
        let email = "test@example.com"
        let displayName = "Test User"
        let skillLevel = GardeningSkillLevel.beginner
        
        // Act
        let user = User(email: email, displayName: displayName, skillLevel: skillLevel)
        
        // Assert
        #expect(user.email == email)
        #expect(user.displayName == displayName)
        #expect(user.skillLevel == skillLevel)
        #expect(user.id != UUID())
        #expect(user.subscriptionTier == .free)
        #expect(user.plantsGrown == 0)
        #expect(user.streakDays == 0)
        #expect(user.gardens?.isEmpty ?? true)
        #expect(user.reminders?.isEmpty ?? true)
        #expect(user.journalEntries?.isEmpty ?? true)
        #expect(user.completedTutorials.isEmpty)
    }
    
    @Test("User skill level display names")
    func testSkillLevelDisplayNames() async throws {
        #expect(GardeningSkillLevel.beginner.displayName == "Beginner")
        #expect(GardeningSkillLevel.intermediate.displayName == "Intermediate")
        #expect(GardeningSkillLevel.advanced.displayName == "Advanced")
        #expect(GardeningSkillLevel.expert.displayName == "Expert")
    }
    
    @Test("User skill level descriptions")
    func testSkillLevelDescriptions() async throws {
        #expect(GardeningSkillLevel.beginner.description == "Just starting out")
        #expect(GardeningSkillLevel.intermediate.description == "Some gardening experience")
        #expect(GardeningSkillLevel.advanced.description == "Experienced gardener")
        #expect(GardeningSkillLevel.expert.description == "Master gardener")
    }
    
    @Test("Gardening goals display names")
    func testGardeningGoalsDisplayNames() async throws {
        #expect(GardeningGoal.growFood.displayName == "Grow My Own Food")
        #expect(GardeningGoal.beautifySpace.displayName == "Beautify My Space")
        #expect(GardeningGoal.learnSkills.displayName == "Learn New Skills")
        #expect(GardeningGoal.relaxation.displayName == "Relaxation & Therapy")
        #expect(GardeningGoal.sustainability.displayName == "Environmental Sustainability")
    }
    
    @Test("Time commitment values")
    func testTimeCommitmentValues() async throws {
        #expect(TimeCommitment.minimal.minutesPerWeek == 15)
        #expect(TimeCommitment.light.minutesPerWeek == 45)
        #expect(TimeCommitment.moderate.minutesPerWeek == 120)
        #expect(TimeCommitment.heavy.minutesPerWeek == 270)
        #expect(TimeCommitment.intensive.minutesPerWeek == 420)
    }
    
    @Test("Subscription tier pricing")
    func testSubscriptionTierPricing() async throws {
        #expect(SubscriptionTier.free.monthlyPrice == 0.0)
        #expect(SubscriptionTier.premium.monthlyPrice == 4.99)
        #expect(SubscriptionTier.pro.monthlyPrice == 9.99)
    }
    
    @Test("AI diagnoses limits per subscription tier")
    func testAIDiagnosesLimits() async throws {
        #expect(SubscriptionTier.free.aiDiagnosesPerMonth == 3)
        #expect(SubscriptionTier.premium.aiDiagnosesPerMonth == -1) // Unlimited
        #expect(SubscriptionTier.pro.aiDiagnosesPerMonth == -1) // Unlimited
    }
    
    @Test("Reminder settings default values")
    func testReminderSettingsDefaults() async throws {
        // Arrange & Act
        let settings = ReminderSettings()
        
        // Assert
        #expect(settings.enableWateringReminders == true)
        #expect(settings.enableFertilizingReminders == true)
        #expect(settings.enablePruningReminders == true)
        #expect(settings.enableHarvestReminders == true)
        #expect(settings.enableSeasonalReminders == true)
        #expect(settings.weekendReminders == true)
        #expect(settings.pushNotifications == true)
        #expect(settings.emailNotifications == false)
        #expect(settings.inAppNotifications == true)
        #expect(settings.quietHoursStart == nil)
        #expect(settings.quietHoursEnd == nil)
    }
    
    @Test("Measurement system display names")
    func testMeasurementSystemDisplayNames() async throws {
        #expect(MeasurementSystem.imperial.displayName == "Imperial (inches, feet, °F)")
        #expect(MeasurementSystem.metric.displayName == "Metric (cm, meters, °C)")
    }
    
    @Test("User initialization with all skill levels")
    func testUserInitializationWithAllSkillLevels() async throws {
        let email = "test@example.com"
        let displayName = "Test User"
        
        for skillLevel in GardeningSkillLevel.allCases {
            let user = User(email: email, displayName: displayName, skillLevel: skillLevel)
            #expect(user.skillLevel == skillLevel)
            #expect(user.email == email)
            #expect(user.displayName == displayName)
        }
    }
    
    @Test("User timestamps are set correctly")
    func testUserTimestamps() async throws {
        // Arrange
        let beforeCreation = Date()
        
        // Act
        let user = User(email: "test@example.com", displayName: "Test User")
        
        // Assert
        let afterCreation = Date()
        #expect(user.createdDate >= beforeCreation)
        #expect(user.createdDate <= afterCreation)
        #expect(user.lastLoginDate >= beforeCreation)
        #expect(user.lastLoginDate <= afterCreation)
        #expect(user.lastModified >= beforeCreation)
        #expect(user.lastModified <= afterCreation)
    }
}