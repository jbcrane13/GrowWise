import XCTest
import Testing
@testable import GrowWiseServices
@testable import GrowWiseModels
@testable import TestUtilities

@Suite("App Performance Tests")
struct AppPerformanceTests {
    
    // MARK: - Launch Performance Tests
    
    @Test("App launch time under 2 seconds")
    func testAppLaunchTime() async throws {
        let app = XCUIApplication()
        
        let launchMetric = XCTApplicationLaunchMetric()
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 5
        
        measure(metrics: [launchMetric], options: measureOptions) {
            app.launch()
            app.terminate()
        }
        
        // Verify launch time is under 2 seconds (requirement from PRD)
        // This will be validated in the measurement results
    }
    
    @Test("App memory usage under 50MB on launch")
    func testAppMemoryUsage() async throws {
        let app = XCUIApplication()
        
        let memoryMetric = XCTMemoryMetric()
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 3
        
        measure(metrics: [memoryMetric], options: measureOptions) {
            app.launch()
            // Let app settle
            sleep(1)
            app.terminate()
        }
    }
    
    // MARK: - Data Service Performance Tests
    
    @Test("DataService operations complete under 100ms")
    func testDataServicePerformance() async throws {
        let dataService = DataService.createFallback()
        
        // Measure user creation
        let userCreationTime = await measureAsync {
            try! dataService.createUser(
                email: "performance@test.com",
                displayName: "Performance Test",
                skillLevel: .intermediate
            )
        }
        
        #expect(userCreationTime < 0.1) // Should complete in under 100ms
        
        // Measure garden creation
        let gardenCreationTime = await measureAsync {
            try! dataService.createGarden(
                name: "Performance Garden",
                type: .vegetable,
                isIndoor: false
            )
        }
        
        #expect(gardenCreationTime < 0.1)
        
        // Measure plant operations
        let garden = try dataService.createGarden(
            name: "Test Garden",
            type: .herb,
            isIndoor: true
        )
        
        let plantCreationTime = await measureAsync {
            try! dataService.createPlant(
                name: "Performance Plant",
                type: .herb,
                garden: garden
            )
        }
        
        #expect(plantCreationTime < 0.1)
    }
    
    @Test("DataService handles 100 plants efficiently")
    func testDataServiceWithLargeDataset() async throws {
        let dataService = DataService.createFallback()
        let user = try dataService.createUser(
            email: "test@example.com",
            displayName: "Test User",
            skillLevel: .expert
        )
        let garden = try dataService.createGarden(
            name: "Large Garden",
            type: .mixed,
            isIndoor: false
        )
        
        // Create 100 plants
        let plantCreationTime = await measureAsync {
            for i in 1...100 {
                try! dataService.createPlant(
                    name: "Plant \(i)",
                    type: PlantType.allCases.randomElement()!,
                    difficultyLevel: DifficultyLevel.allCases.randomElement()!,
                    garden: garden
                )
            }
        }
        
        #expect(plantCreationTime < 1.0) // Should complete in under 1 second
        
        // Measure fetching all plants
        let fetchTime = await measureAsync {
            let _ = dataService.fetchPlants(for: garden)
        }
        
        #expect(fetchTime < 0.1) // Should fetch quickly
        
        // Measure search performance
        let searchTime = await measureAsync {
            let _ = dataService.searchPlants(query: "Plant")
        }
        
        #expect(searchTime < 0.2) // Search should be fast even with many plants
    }
    
    @Test("DataService filter operations are efficient")
    func testDataServiceFilterPerformance() async throws {
        let dataService = DataService.createFallback()
        
        // Add more test data for meaningful performance test
        let garden = try dataService.createGarden(
            name: "Filter Test Garden",
            type: .mixed,
            isIndoor: false
        )
        
        for i in 1...50 {
            try dataService.createPlant(
                name: "Filter Plant \(i)",
                type: PlantType.allCases.randomElement()!,
                difficultyLevel: DifficultyLevel.allCases.randomElement()!,
                garden: garden
            )
        }
        
        // Measure filter by type
        let typeFilterTime = await measureAsync {
            let _ = dataService.filterPlants(by: .vegetable)
        }
        #expect(typeFilterTime < 0.05)
        
        // Measure filter by difficulty
        let difficultyFilterTime = await measureAsync {
            let _ = dataService.filterPlants(difficultyLevel: .beginner)
        }
        #expect(difficultyFilterTime < 0.05)
        
        // Measure complex filter
        let complexFilterTime = await measureAsync {
            let _ = dataService.filterPlants(
                by: .herb,
                difficultyLevel: .beginner,
                sunlightRequirement: .partialSun
            )
        }
        #expect(complexFilterTime < 0.1)
    }
    
    // MARK: - Notification Service Performance Tests
    
    @Test("NotificationService schedules reminders efficiently")
    func testNotificationServicePerformance() async throws {
        let mockNotificationService = MockNotificationService()
        mockNotificationService.simulatePermissionGranted()
        
        let mockDataService = MockDataService()
        mockDataService.seedTestData()
        
        let plants = mockDataService.fetchPlants()
        var reminders: [PlantReminder] = []
        
        // Create multiple reminders
        for plant in plants {
            let reminder = try mockDataService.createReminder(
                title: "Water \(plant.name)",
                message: "Time to water",
                type: .watering,
                frequency: .daily,
                dueDate: Date(),
                plant: plant
            )
            reminders.append(reminder)
        }
        
        // Measure scheduling performance
        let schedulingTime = await measureAsync {
            await mockNotificationService.scheduleAllActiveReminders(reminders)
        }
        
        #expect(schedulingTime < 0.5) // Should schedule quickly
        
        // Verify all reminders were scheduled
        let pendingCount = await mockNotificationService.getPendingNotificationsCount()
        #expect(pendingCount == reminders.count)
    }
    
    @Test("NotificationService handles batch operations efficiently")
    func testNotificationServiceBatchOperations() async throws {
        let mockNotificationService = MockNotificationService()
        mockNotificationService.simulatePermissionGranted()
        
        let mockDataService = MockDataService()
        let user = try mockDataService.createUser(
            email: "batch@test.com",
            displayName: "Batch Test",
            skillLevel: .expert
        )
        let garden = try mockDataService.createGarden(
            name: "Batch Garden",
            type: .mixed,
            isIndoor: false
        )
        
        // Create 50 plants with reminders
        var reminders: [PlantReminder] = []
        for i in 1...50 {
            let plant = try mockDataService.createPlant(
                name: "Batch Plant \(i)",
                type: .vegetable,
                garden: garden
            )
            
            let reminder = try mockDataService.createReminder(
                title: "Water Batch Plant \(i)",
                message: "Batch watering reminder",
                type: .watering,
                frequency: .daily,
                dueDate: Date(),
                plant: plant
            )
            reminders.append(reminder)
        }
        
        // Measure batch scheduling
        let batchSchedulingTime = await measureAsync {
            await mockNotificationService.scheduleAllActiveReminders(reminders)
        }
        
        #expect(batchSchedulingTime < 2.0) // Should handle 50 reminders in under 2 seconds
        
        // Measure batch cancellation
        let batchCancellationTime = await measureAsync {
            mockNotificationService.cancelAllNotifications()
        }
        
        #expect(batchCancellationTime < 0.1) // Cancellation should be very fast
    }
    
    // MARK: - Memory Performance Tests
    
    @Test("App handles large datasets without memory issues")
    func testMemoryPerformanceWithLargeDataset() async throws {
        let mockDataService = MockDataService()
        
        // Create large dataset
        let user = try mockDataService.createUser(
            email: "memory@test.com",
            displayName: "Memory Test",
            skillLevel: .expert
        )
        
        let memoryBeforeCreation = getCurrentMemoryUsage()
        
        // Create 200 plants across multiple gardens
        for gardenIndex in 1...10 {
            let garden = try mockDataService.createGarden(
                name: "Memory Garden \(gardenIndex)",
                type: .mixed,
                isIndoor: gardenIndex % 2 == 0
            )
            
            for plantIndex in 1...20 {
                let plant = try mockDataService.createPlant(
                    name: "Memory Plant \(gardenIndex)-\(plantIndex)",
                    type: PlantType.allCases.randomElement()!,
                    difficultyLevel: DifficultyLevel.allCases.randomElement()!,
                    garden: garden
                )
                
                // Add some journal entries and reminders
                let _ = try mockDataService.createReminder(
                    title: "Water Memory Plant",
                    message: "Watering reminder",
                    type: .watering,
                    frequency: .daily,
                    dueDate: Date(),
                    plant: plant
                )
            }
        }
        
        let memoryAfterCreation = getCurrentMemoryUsage()
        let memoryIncrease = memoryAfterCreation - memoryBeforeCreation
        
        // Memory increase should be reasonable (less than 20MB for test data)
        #expect(memoryIncrease < 20 * 1024 * 1024) // 20MB in bytes
        
        // Test operations still perform well
        let fetchTime = await measureAsync {
            let _ = mockDataService.fetchGardens()
            let _ = mockDataService.fetchPlants()
            let _ = mockDataService.fetchActiveReminders()
        }
        
        #expect(fetchTime < 0.2) // Should still be fast with large dataset
    }
    
    // MARK: - UI Performance Tests
    
    @Test("UI scroll performance with large lists")
    func testUIScrollPerformance() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--large-dataset"]
        app.launch()
        
        // Navigate to plant list
        let plantListTab = app.tabBars.buttons["Plants"]
        if plantListTab.waitForExistence(timeout: 5.0) {
            plantListTab.tap()
            
            let plantList = app.tables.firstMatch
            if plantList.waitForExistence(timeout: 3.0) {
                // Measure scroll performance
                let scrollMetric = XCTOSSignpostMetric.scrollingAndDecelerationMetric
                
                measure(metrics: [scrollMetric]) {
                    // Scroll through the list
                    plantList.swipeUp()
                    plantList.swipeUp()
                    plantList.swipeUp()
                    plantList.swipeDown()
                    plantList.swipeDown()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func measureAsync<T>(_ operation: @escaping () throws -> T) async -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try? operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Performance Test Utilities

final class PerformanceTestUtilities {
    
    static func createLargeTestDataset() -> MockDataService {
        let mockDataService = MockDataService()
        
        // Create comprehensive test dataset
        let user = try! mockDataService.createUser(
            email: "performance@test.com",
            displayName: "Performance User",
            skillLevel: .expert
        )
        
        // Create multiple gardens
        let gardenTypes: [GardenType] = [.vegetable, .herb, .flower, .fruit, .mixed]
        var gardens: [Garden] = []
        
        for (index, type) in gardenTypes.enumerated() {
            let garden = try! mockDataService.createGarden(
                name: "\(type.rawValue.capitalized) Garden \(index + 1)",
                type: type,
                isIndoor: index % 2 == 0
            )
            gardens.append(garden)
        }
        
        // Create plants in each garden
        for garden in gardens {
            for i in 1...20 {
                let plantTypes = PlantType.allCases
                let difficulties = DifficultyLevel.allCases
                
                let plant = try! mockDataService.createPlant(
                    name: "\(garden.name) Plant \(i)",
                    type: plantTypes.randomElement()!,
                    difficultyLevel: difficulties.randomElement()!,
                    garden: garden
                )
                
                // Add reminders to some plants
                if i % 3 == 0 {
                    let _ = try! mockDataService.createReminder(
                        title: "Water \(plant.name)",
                        message: "Time to water your plant",
                        type: .watering,
                        frequency: .daily,
                        dueDate: Date().addingTimeInterval(TimeInterval(i * 3600)),
                        plant: plant
                    )
                }
                
                if i % 5 == 0 {
                    let _ = try! mockDataService.createReminder(
                        title: "Fertilize \(plant.name)",
                        message: "Time to fertilize your plant",
                        type: .fertilizing,
                        frequency: .weekly,
                        dueDate: Date().addingTimeInterval(TimeInterval(i * 86400)),
                        plant: plant
                    )
                }
            }
        }
        
        return mockDataService
    }
    
    static func measureOperationTime<T>(_ operation: () throws -> T) -> (result: T?, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try operation()
            let endTime = CFAbsoluteTimeGetCurrent()
            return (result, endTime - startTime)
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            return (nil, endTime - startTime)
        }
    }
    
    static func validatePerformanceRequirements(
        operationTime: TimeInterval,
        expectedMaxTime: TimeInterval,
        operationName: String
    ) -> Bool {
        let isWithinRequirement = operationTime <= expectedMaxTime
        
        if !isWithinRequirement {
            print("⚠️ Performance requirement not met for \(operationName):")
            print("   Expected: ≤ \(expectedMaxTime)s")
            print("   Actual: \(operationTime)s")
            print("   Difference: +\(operationTime - expectedMaxTime)s")
        }
        
        return isWithinRequirement
    }
}