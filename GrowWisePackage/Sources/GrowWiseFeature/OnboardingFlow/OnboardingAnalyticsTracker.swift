import Foundation
import GrowWiseServices
import os

// MARK: - OnboardingAnalyticsTracker

/// Tracks onboarding-related analytics events and manages activation milestone events.
///
/// Activation events (D1, D7, D30) are emitted on the first app launch after the
/// corresponding number of days have elapsed since onboarding completion.
/// Each activation event fires only once, stored via UserDefaults keys:
/// - `onboarding_completed_date` — the date onboarding finished
/// - `activation_d1_emitted` — whether activation_d1 has been emitted
/// - `activation_d7_emitted` — whether activation_d7 has been emitted
/// - `activation_d30_emitted` — whether activation_d30 has been emitted
@MainActor
@Observable
public final class OnboardingAnalyticsTracker {
    public static let shared = OnboardingAnalyticsTracker()

    private let analyticsService: AnalyticsService
    private let logger = Logger(subsystem: "com.growwise", category: "OnboardingAnalytics")

    private static let onboardingCompletedDateKey = "onboarding_completed_date"
    private static let activationD1EmittedKey = "activation_d1_emitted"
    private static let activationD7EmittedKey = "activation_d7_emitted"
    private static let activationD30EmittedKey = "activation_d30_emitted"

    private init(analyticsService: AnalyticsService = .shared) {
        self.analyticsService = analyticsService
    }

    // MARK: - Onboarding Step Events

    /// Track that a specific onboarding step was viewed by the user.
    public func trackStepViewed(_ stepName: String) {
        analyticsService.track(.onboardingStepViewed(stepName: stepName))
        logger.debug("Analytics: onboarding_step_viewed(step_name=\(stepName))")
    }

    /// Track that a specific onboarding step was completed by the user.
    public func trackStepCompleted(_ stepName: String) {
        analyticsService.track(.onboardingStepCompleted(stepName: stepName))
        logger.debug("Analytics: onboarding_step_completed(step_name=\(stepName))")
    }

    /// Track that a specific onboarding step was skipped by the user.
    public func trackStepSkipped(_ stepName: String) {
        analyticsService.track(.onboardingStepSkipped(stepName: stepName))
        logger.debug("Analytics: onboarding_step_skipped(step_name=\(stepName))")
    }

    /// Track that the full onboarding flow was completed.
    public func trackOnboardingCompleted() {
        let completedDate = Date()
        UserDefaults.standard.set(completedDate, forKey: Self.onboardingCompletedDateKey)
        analyticsService.track(.onboardingCompleted(daysToComplete: 0))
        logger.info("Analytics: onboarding_completed, completion_date stored")
    }

    // MARK: - Activation Milestone Events

    /// Check and emit any pending activation milestone events based on time elapsed
    /// since onboarding completion. Call this on app launch / scene activation.
    public func checkActivationMilestones() {
        guard let completedDate = UserDefaults.standard.object(forKey: Self.onboardingCompletedDateKey) as? Date else {
            logger.debug("No onboarding completion date found, skipping activation checks")
            return
        }

        let daysSinceOnboarding = Calendar.current.dateComponents([.day], from: completedDate, to: Date()).day ?? 0
        logger.debug("Days since onboarding completion: \(daysSinceOnboarding)")

        checkAndEmitD1(daysSinceOnboarding: daysSinceOnboarding)
        checkAndEmitD7(daysSinceOnboarding: daysSinceOnboarding)
        checkAndEmitD30(daysSinceOnboarding: daysSinceOnboarding)
    }

    private func checkAndEmitD1(daysSinceOnboarding: Int) {
        guard daysSinceOnboarding >= 1 else { return }
        guard !UserDefaults.standard.bool(forKey: Self.activationD1EmittedKey) else { return }

        analyticsService.track(.activationD1)
        UserDefaults.standard.set(true, forKey: Self.activationD1EmittedKey)
        logger.info("Analytics: activation_d1 emitted")
    }

    private func checkAndEmitD7(daysSinceOnboarding: Int) {
        guard daysSinceOnboarding >= 7 else { return }
        guard !UserDefaults.standard.bool(forKey: Self.activationD7EmittedKey) else { return }

        analyticsService.track(.activationD7)
        UserDefaults.standard.set(true, forKey: Self.activationD7EmittedKey)
        logger.info("Analytics: activation_d7 emitted")
    }

    private func checkAndEmitD30(daysSinceOnboarding: Int) {
        guard daysSinceOnboarding >= 30 else { return }
        guard !UserDefaults.standard.bool(forKey: Self.activationD30EmittedKey) else { return }

        analyticsService.track(.activationD30)
        UserDefaults.standard.set(true, forKey: Self.activationD30EmittedKey)
        logger.info("Analytics: activation_d30 emitted")
    }

    // MARK: - Testing / Reset Helpers

    /// Reset all onboarding analytics state (for testing only).
    public static func resetAllState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: onboardingCompletedDateKey)
        defaults.removeObject(forKey: activationD1EmittedKey)
        defaults.removeObject(forKey: activationD7EmittedKey)
        defaults.removeObject(forKey: activationD30EmittedKey)
    }

    /// Returns the stored onboarding completion date, if any.
    public static var storedCompletionDate: Date? {
        UserDefaults.standard.object(forKey: onboardingCompletedDateKey) as? Date
    }

    /// Returns true if the D1 activation event has already been emitted.
    public static var isD1Emitted: Bool {
        UserDefaults.standard.bool(forKey: activationD1EmittedKey)
    }

    /// Returns true if the D7 activation event has already been emitted.
    public static var isD7Emitted: Bool {
        UserDefaults.standard.bool(forKey: activationD7EmittedKey)
    }

    /// Returns true if the D30 activation event has already been emitted.
    public static var isD30Emitted: Bool {
        UserDefaults.standard.bool(forKey: activationD30EmittedKey)
    }
}