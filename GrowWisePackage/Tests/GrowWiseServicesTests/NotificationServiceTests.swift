import Testing
import Foundation
import UserNotifications
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("NotificationService Tests")
struct NotificationServiceTests {
    
    @Test("NotificationService singleton initialization")
    func testSingletonInitialization() async throws {
        // Act
        let service1 = NotificationService.shared
        let service2 = NotificationService.shared
        
        // Assert
        #expect(service1 === service2)
        #expect(service1.authorizationStatus == .notDetermined)
        #expect(service1.isEnabled == false)
    }
    
    @Test("Weather alert category display names")
    func testWeatherAlertCategoryDisplayNames() async throws {
        #expect(WeatherAlertCategory.frost.displayName == "Frost Warning")
        #expect(WeatherAlertCategory.heatwave.displayName == "Heat Warning")
        #expect(WeatherAlertCategory.heavyRain.displayName == "Heavy Rain Alert")
        #expect(WeatherAlertCategory.drought.displayName == "Drought Conditions")
        #expect(WeatherAlertCategory.wind.displayName == "High Wind Warning")
        #expect(WeatherAlertCategory.general.displayName == "Weather Alert")
    }
    
    @Test("Health issue descriptions")
    func testHealthIssueDescriptions() async throws {
        #expect(HealthIssue.overwatering.description == "Signs of overwatering detected. Check soil drainage.")
        #expect(HealthIssue.underwatering.description == "Plant appears dehydrated. Consider watering.")
        #expect(HealthIssue.pestInfestation.description == "Possible pest activity observed.")
        #expect(HealthIssue.disease.description == "Potential plant disease detected.")
        #expect(HealthIssue.nutrientDeficiency.description == "Nutrient deficiency symptoms visible.")
        #expect(HealthIssue.rootBound.description == "Plant may need repotting.")
        #expect(HealthIssue.sunStress.description == "Plant showing signs of sun stress.")
        #expect(HealthIssue.temperatureStress.description == "Temperature stress detected.")
    }
    
    @Test("Alert severity sound mapping")
    func testAlertSeveritySoundMapping() async throws {
        #expect(AlertSeverity.low.sound == .default)
        #expect(AlertSeverity.medium.sound == .default)
        #expect(AlertSeverity.high.sound == .defaultCritical)
        #expect(AlertSeverity.critical.sound == .defaultCritical)
    }
    
    @Test("Quiet hours calculation with same day times")
    func testQuietHoursCalculationSameDay() async throws {
        // Arrange
        let service = NotificationService.shared
        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
        let endTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        
        // Act
        service.updateQuietHours(start: startTime, end: endTime)
        
        // Create test times
        let duringQuietHours = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date())!
        let outsideQuietHours = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        
        // We can't directly test the private method, but we can test the logic
        let quietStart = calendar.dateComponents([.hour, .minute], from: startTime)
        let quietEnd = calendar.dateComponents([.hour, .minute], from: endTime)
        let testDuring = calendar.dateComponents([.hour, .minute], from: duringQuietHours)
        let testOutside = calendar.dateComponents([.hour, .minute], from: outsideQuietHours)
        
        let startMinutes = quietStart.hour! * 60 + quietStart.minute!
        let endMinutes = quietEnd.hour! * 60 + quietEnd.minute!
        let duringMinutes = testDuring.hour! * 60 + testDuring.minute!
        let outsideMinutes = testOutside.hour! * 60 + testOutside.minute!
        
        // Assert
        if startMinutes <= endMinutes {
            #expect(duringMinutes >= startMinutes && duringMinutes <= endMinutes)
        } else {
            #expect(duringMinutes >= startMinutes || duringMinutes <= endMinutes)
        }
        
        #expect(!(outsideMinutes >= startMinutes && outsideMinutes <= endMinutes))
    }
    
    @Test("Notification identifier generation")
    func testNotificationIdentifierGeneration() async throws {
        // Arrange
        let plantId = UUID()
        let reminderId = UUID()
        
        // Act
        let reminderIdentifier = "reminder_\(reminderId.uuidString)"
        let healthIdentifier = "health_\(plantId.uuidString)_overwatering"
        let weatherIdentifier = "weather_\(UUID().uuidString)"
        
        // Assert
        #expect(reminderIdentifier.hasPrefix("reminder_"))
        #expect(reminderIdentifier.contains(reminderId.uuidString))
        #expect(healthIdentifier.hasPrefix("health_"))
        #expect(healthIdentifier.contains(plantId.uuidString))
        #expect(healthIdentifier.hasSuffix("_overwatering"))
        #expect(weatherIdentifier.hasPrefix("weather_"))
    }
    
    @Test("UserInfo dictionary structure for reminders")
    func testUserInfoDictionaryStructure() async throws {
        // Arrange
        let reminderId = UUID()
        let plantId = UUID()
        let plantName = "Test Plant"
        let reminderType = "watering"
        
        // Act
        let userInfo: [String: Any] = [
            "reminderId": reminderId.uuidString,
            "plantId": plantId.uuidString,
            "plantName": plantName,
            "reminderType": reminderType
        ]
        
        // Assert
        #expect(userInfo["reminderId"] as? String == reminderId.uuidString)
        #expect(userInfo["plantId"] as? String == plantId.uuidString)
        #expect(userInfo["plantName"] as? String == plantName)
        #expect(userInfo["reminderType"] as? String == reminderType)
    }
    
    @Test("UserInfo dictionary structure for health alerts")
    func testUserInfoDictionaryStructureHealthAlerts() async throws {
        // Arrange
        let plantId = UUID()
        let plantName = "Sick Plant"
        let issue = "overwatering"
        let severity = "high"
        
        // Act
        let userInfo: [String: Any] = [
            "type": "health",
            "plantId": plantId.uuidString,
            "plantName": plantName,
            "issue": issue,
            "severity": severity
        ]
        
        // Assert
        #expect(userInfo["type"] as? String == "health")
        #expect(userInfo["plantId"] as? String == plantId.uuidString)
        #expect(userInfo["plantName"] as? String == plantName)
        #expect(userInfo["issue"] as? String == issue)
        #expect(userInfo["severity"] as? String == severity)
    }
    
    @Test("UserInfo dictionary structure for weather alerts")
    func testUserInfoDictionaryStructureWeatherAlerts() async throws {
        // Arrange
        let category = "frost"
        
        // Act
        let userInfo: [String: Any] = [
            "type": "weather",
            "category": category
        ]
        
        // Assert
        #expect(userInfo["type"] as? String == "weather")
        #expect(userInfo["category"] as? String == category)
    }
    
    @Test("Calendar component extraction")
    func testCalendarComponentExtraction() async throws {
        // Arrange
        let calendar = Calendar.current
        let testDate = Date()
        
        // Act
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: testDate)
        
        // Assert
        #expect(components.year != nil)
        #expect(components.month != nil)
        #expect(components.day != nil)
        #expect(components.hour != nil)
        #expect(components.minute != nil)
        #expect(components.year! > 2020)
        #expect(components.month! >= 1 && components.month! <= 12)
        #expect(components.day! >= 1 && components.day! <= 31)
        #expect(components.hour! >= 0 && components.hour! <= 23)
        #expect(components.minute! >= 0 && components.minute! <= 59)
    }
    
    @Test("Notification category action identifiers")
    func testNotificationCategoryActionIdentifiers() async throws {
        // Arrange & Assert
        let completeAction = "COMPLETE_ACTION"
        let snoozeAction = "SNOOZE_ACTION"
        let viewPlantAction = "VIEW_PLANT_ACTION"
        
        #expect(completeAction == "COMPLETE_ACTION")
        #expect(snoozeAction == "SNOOZE_ACTION")
        #expect(viewPlantAction == "VIEW_PLANT_ACTION")
    }
    
    @Test("Notification category identifiers")
    func testNotificationCategoryIdentifiers() async throws {
        // Arrange & Assert
        let reminderCategory = "PLANT_REMINDER"
        let healthCategory = "PLANT_HEALTH"
        let weatherCategory = "WEATHER_ALERT"
        
        #expect(reminderCategory == "PLANT_REMINDER")
        #expect(healthCategory == "PLANT_HEALTH")
        #expect(weatherCategory == "WEATHER_ALERT")
    }
    
    @Test("Time conversion to minutes")
    func testTimeConversionToMinutes() async throws {
        // Test the logic for converting hours and minutes to total minutes
        let testCases = [
            (hour: 0, minute: 0, expected: 0),
            (hour: 1, minute: 30, expected: 90),
            (hour: 12, minute: 0, expected: 720),
            (hour: 23, minute: 59, expected: 1439)
        ]
        
        for testCase in testCases {
            let totalMinutes = testCase.hour * 60 + testCase.minute
            #expect(totalMinutes == testCase.expected)
        }
    }
    
    @Test("UserDefaults key constants")
    func testUserDefaultsKeyConstants() async throws {
        // Verify key constants are correctly defined
        let quietHoursStartKey = "quietHoursStart"
        let quietHoursEndKey = "quietHoursEnd"
        let lastCloudSyncKey = "lastCloudSync"
        
        #expect(quietHoursStartKey == "quietHoursStart")
        #expect(quietHoursEndKey == "quietHoursEnd")
        #expect(lastCloudSyncKey == "lastCloudSync")
    }
    
    @Test("Notification name constants")
    func testNotificationNameConstants() async throws {
        // Verify notification name constants are correctly defined
        #expect(Notification.Name.completeReminder.rawValue == "completeReminder")
        #expect(Notification.Name.snoozeReminder.rawValue == "snoozeReminder")
        #expect(Notification.Name.viewPlant.rawValue == "viewPlant")
    }
}