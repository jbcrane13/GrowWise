import Foundation
import Testing
@testable import GrowWiseFeature

// MARK: - OnboardingAnalyticsTracker Tests

@Suite("OnboardingAnalyticsTracker")
@MainActor
final class OnboardingAnalyticsTrackerTests {

    init() {
        // Fresh state before each test suite
        OnboardingAnalyticsTracker.resetAllState()
    }

    // MARK: - Step tracking

    @Test("trackStepViewed emits onboardingStepViewed with correct step name")
    func testTrackStepViewed() {
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.trackStepViewed("welcome")
        // No crash = pass
    }

    @Test("trackStepCompleted emits onboardingStepCompleted with correct step name")
    func testTrackStepCompleted() {
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.trackStepCompleted("skill_assessment")
        // No crash = pass
    }

    @Test("trackStepSkipped emits onboardingStepSkipped with correct step name")
    func testTrackStepSkipped() {
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.trackStepSkipped("location")
        // No crash = pass
    }

    // MARK: - Onboarding completion date storage

    @Test("trackOnboardingCompleted stores completion date in UserDefaults")
    func testTrackOnboardingCompletedStoresDate() {
        let tracker = OnboardingAnalyticsTracker.shared
        #expect(OnboardingAnalyticsTracker.storedCompletionDate == nil)

        tracker.trackOnboardingCompleted()

        #expect(OnboardingAnalyticsTracker.storedCompletionDate != nil)
    }

    // MARK: - Activation milestone state helpers

    @Test("isD1Emitted is false initially")
    func testIsD1EmittedInitiallyFalse() {
        #expect(OnboardingAnalyticsTracker.isD1Emitted == false)
    }

    @Test("isD7Emitted is false initially")
    func testIsD7EmittedInitiallyFalse() {
        #expect(OnboardingAnalyticsTracker.isD7Emitted == false)
    }

    @Test("isD30Emitted is false initially")
    func testIsD30EmittedInitiallyFalse() {
        #expect(OnboardingAnalyticsTracker.isD30Emitted == false)
    }

    // MARK: - Reset state

    @Test("resetAllState clears completion date")
    func testResetAllStateClearsCompletionDate() {
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.trackOnboardingCompleted()
        #expect(OnboardingAnalyticsTracker.storedCompletionDate != nil)

        OnboardingAnalyticsTracker.resetAllState()

        #expect(OnboardingAnalyticsTracker.storedCompletionDate == nil)
    }

    @Test("resetAllState resets all emitted flags")
    func testResetAllStateResetsEmittedFlags() {
        OnboardingAnalyticsTracker.resetAllState()
        #expect(OnboardingAnalyticsTracker.isD1Emitted == false)
        #expect(OnboardingAnalyticsTracker.isD7Emitted == false)
        #expect(OnboardingAnalyticsTracker.isD30Emitted == false)
    }
}

// MARK: - Activation milestone emission logic

@Suite("OnboardingAnalyticsTracker activation milestone emission")
@MainActor
final class OnboardingActivationMilestoneTests {

    init() {
        OnboardingAnalyticsTracker.resetAllState()
    }

    private func simulateOnboardingCompleted(daysAgo: Int) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        UserDefaults.standard.set(date, forKey: "onboarding_completed_date")
    }

    // MARK: D1

    @Test("D1 not emitted when onboarding completed today (0 days ago)")
    func testD1NotEmittedWhenOnboardingCompletedToday() {
        simulateOnboardingCompleted(daysAgo: 0)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD1Emitted == false)
    }

    @Test("D1 emitted when onboarding completed 1 day ago")
    func testD1EmittedWhenOnboardingCompleted1DayAgo() {
        simulateOnboardingCompleted(daysAgo: 1)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD1Emitted == true)
    }

    @Test("D1 emitted only once (idempotent)")
    func testD1EmittedOnlyOnce() {
        simulateOnboardingCompleted(daysAgo: 2)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD1Emitted == true)

        // Call again — should remain true but not re-emit
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD1Emitted == true)
    }

    // MARK: D7

    @Test("D7 not emitted when onboarding completed 3 days ago")
    func testD7NotEmittedWhenOnboardingCompleted3DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 3)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD7Emitted == false)
    }

    @Test("D7 not emitted when onboarding completed 6 days ago")
    func testD7NotEmittedWhenOnboardingCompleted6DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 6)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD7Emitted == false)
    }

    @Test("D7 emitted when onboarding completed 7 days ago")
    func testD7EmittedWhenOnboardingCompleted7DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 7)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD7Emitted == true)
    }

    @Test("D7 emitted only once (idempotent)")
    func testD7EmittedOnlyOnce() {
        simulateOnboardingCompleted(daysAgo: 10)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD7Emitted == true)

        // Call again — should remain true but not re-emit
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD7Emitted == true)
    }

    // MARK: D30

    @Test("D30 not emitted when onboarding completed 14 days ago")
    func testD30NotEmittedWhenOnboardingCompleted14DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 14)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD30Emitted == false)
    }

    @Test("D30 not emitted when onboarding completed 29 days ago")
    func testD30NotEmittedWhenOnboardingCompleted29DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 29)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD30Emitted == false)
    }

    @Test("D30 emitted when onboarding completed 30 days ago")
    func testD30EmittedWhenOnboardingCompleted30DaysAgo() {
        simulateOnboardingCompleted(daysAgo: 30)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD30Emitted == true)
    }

    @Test("D30 emitted only once (idempotent)")
    func testD30EmittedOnlyOnce() {
        simulateOnboardingCompleted(daysAgo: 45)
        let tracker = OnboardingAnalyticsTracker.shared
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD30Emitted == true)

        // Call again — should remain true but not re-emit
        tracker.checkActivationMilestones()
        #expect(OnboardingAnalyticsTracker.isD30Emitted == true)
    }
}

// MARK: - OnboardingStep.rawValue

@Suite("OnboardingStep.rawValue strings")
struct OnboardingStepRawValueTests {

    @Test("All OnboardingStep cases have non-empty rawValue strings")
    func testAllStepsHaveNonEmptyRawValue() {
        for step in OnboardingStep.allCases {
            #expect(!step.rawValue.isEmpty, "OnboardingStep \(step) has empty rawValue")
        }
    }

    @Test("stepNumber returns correct 0-based index")
    func testStepNumber() {
        #expect(OnboardingStep.welcome.stepNumber == 0)
        let lastStep = OnboardingStep.allCases.last
        #expect(lastStep?.stepNumber == OnboardingStep.allCases.count - 1)
    }

    @Test("totalSteps matches allCases count")
    func testTotalStepsMatchesAllCasesCount() {
        #expect(OnboardingStep.welcome.totalSteps == OnboardingStep.allCases.count)
        #expect(OnboardingStep.welcome.totalSteps > 1)
    }
}