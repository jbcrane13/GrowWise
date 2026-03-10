import Testing
import SwiftUI
@testable import GrowWiseFeature
@testable import GrowWiseModels

@Suite("GrowWise Feature Tests")
struct GrowWiseFeatureTests {
    
    
    @Test("MainAppView loads successfully") 
    @MainActor func testMainAppViewLoads() async throws {
        // Verify MainAppView instantiates and that its body is a non-trivial composite view.
        // MainAppView.body returns a ZStack that wraps the loading-spinner / initialized-content
        // conditional, so the type description should reference "ZStack".
        let mainAppView = MainAppView()
        let body = mainAppView.body
        let bodyDescription = String(describing: type(of: body))
        #expect(bodyDescription.contains("ZStack"), "MainAppView body should be a ZStack layout container")
    }
    
    @Test("OnboardingView loads successfully")
    @MainActor func testOnboardingViewLoads() async throws {
        // Verify OnboardingView instantiates and that its outermost view is a NavigationStack,
        // which hosts the TabView-based step carousel for the onboarding flow.
        let onboardingView = OnboardingView()
        let body = onboardingView.body
        let bodyDescription = String(describing: type(of: body))
        #expect(bodyDescription.contains("NavigationStack"), "OnboardingView body should be a NavigationStack")
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
        // NOTE: This measures struct *instantiation* time, NOT actual SwiftUI rendering.
        // init() only captures initial @State values — it does NOT trigger body evaluation,
        // layout passes, or environment resolution. For true rendering benchmarks use
        // Xcode Instruments (Time Profiler) or a UI test with XCTMetrics.
        // The 10 ms threshold guards against pathological init-time work (e.g. disk I/O in init).
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let mainAppView = MainAppView()
        let onboardingView = OnboardingView()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let renderTime = endTime - startTime
        
        #expect(mainAppView.self != nil)
        #expect(onboardingView.self != nil)
        
        // Views should instantiate very quickly (under 10ms)
        #expect(renderTime < 0.01)
    }
}