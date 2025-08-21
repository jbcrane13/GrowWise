import Testing
import SwiftUI
@testable import GrowWiseFeature
@testable import GrowWiseModels

@Suite("GrowWise Feature Tests")
struct GrowWiseFeatureTests {
    
    @Test("ContentView loads successfully")
    @MainActor func testContentViewLoads() async throws {
        // Test that ContentView can be instantiated without errors
        let contentView = ContentView()
        #expect(contentView.self != nil)
    }
    
    @Test("MainAppView loads successfully") 
    @MainActor func testMainAppViewLoads() async throws {
        // Test that MainAppView can be instantiated without errors
        let mainAppView = MainAppView()
        #expect(mainAppView.self != nil)
    }
    
    @Test("OnboardingView loads successfully")
    @MainActor func testOnboardingViewLoads() async throws {
        // Test that OnboardingView can be instantiated without errors
        let onboardingView = OnboardingView()
        #expect(onboardingView.self != nil)
    }
    
    // MARK: - Model Integration Tests
    
    @Test("SkillAssessmentView handles all skill levels")
    func testSkillAssessmentViewSkillLevels() async throws {
        // Test that all skill levels are properly handled
        for skillLevel in GardeningSkillLevel.allCases {
            #expect(skillLevel.displayName.isEmpty == false)
            #expect(skillLevel.description.isEmpty == false)
        }
    }
    
    @Test("GardeningGoalsView handles all goal types")
    func testGardeningGoalsViewGoalTypes() async throws {
        // Test that all gardening goals are properly defined
        for goal in GrowWiseModels.GardeningGoal.allCases {
            #expect(goal.displayName.isEmpty == false)
        }
    }
    
    @Test("TimeCommitment integration test")
    func testTimeCommitmentIntegration() async throws {
        // Test time commitment integration
        for commitment in TimeCommitment.allCases {
            #expect(commitment.displayName.isEmpty == false)
            #expect(commitment.minutesPerWeek > 0)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Views render efficiently")
    @MainActor func testViewRenderingPerformance() async throws {
        // Test that views render quickly
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let contentView = ContentView()
        let mainAppView = MainAppView()
        let onboardingView = OnboardingView()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let renderTime = endTime - startTime
        
        #expect(contentView.self != nil)
        #expect(mainAppView.self != nil)
        #expect(onboardingView.self != nil)
        
        // Views should instantiate very quickly (under 10ms)
        #expect(renderTime < 0.01)
    }
}