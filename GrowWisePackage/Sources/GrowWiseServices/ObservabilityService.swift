import Foundation
import os
import Sentry

// MARK: - ObservabilityService

/// Wraps Sentry for crash reporting, error tracking, and performance monitoring.
///
/// Privacy rules (see docs/security/log-scrubbing.md):
/// - No PII sent to Sentry (no email, name, or device-identifying strings)
/// - Anonymous user ID derived from a stable UUID stored in Keychain
/// - Breadcrumbs contain action names only — never user content
///
/// Configuration:
///   Set SENTRY_DSN in the Xcode scheme environment or via `ObservabilityService.configure(dsn:)`
@MainActor
@Observable
public final class ObservabilityService {
    public static let shared = ObservabilityService()

    private let logger = Logger(subsystem: "com.growwise", category: "Observability")
    private(set) var isInitialized = false

    private init() {}

    // MARK: - Setup

    /// Call once on app launch, before any other service initialization.
    /// DSN can be provided directly or via the SENTRY_DSN environment variable.
    public func configure(dsn: String? = nil, environment: String = "production") {
        guard !isInitialized else { return }

        let resolvedDSN = dsn ?? ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""
        guard !resolvedDSN.isEmpty, resolvedDSN != "YOUR_SENTRY_DSN" else {
            logger.warning("Sentry DSN not configured — error tracking disabled")
            return
        }

        SentrySDK.start { options in
            options.dsn = resolvedDSN
            options.environment = environment
            options.debug = false

            // Performance monitoring — sample 20% of transactions in production
            options.tracesSampleRate = environment == "production" ? 0.2 : 1.0

            // Privacy: strip user IP addresses
            options.sendDefaultPii = false

            // Session tracking for crash-free rate metrics
            options.enableAutoSessionTracking = true

            // Swift async/await support
            options.swiftAsyncStacktraces = true
        }

        isInitialized = true
        logger.info("Sentry initialized (environment: \(environment, privacy: .public))")
    }

    // MARK: - User Identity

    /// Sets an anonymous user identifier for grouping errors by user.
    /// Never pass real names, emails, or device identifiers.
    public func setAnonymousUser(stableID: String, subscriptionTier: String) {
        let user = SentrySDK.currentHub().scope.user ?? User()
        user.userId = stableID // Opaque UUID — not linked to real identity
        user.data = ["subscription_tier": subscriptionTier]
        SentrySDK.setUser(user)
    }

    public func clearUser() {
        SentrySDK.setUser(nil)
    }

    // MARK: - Error Capture

    /// Capture a non-fatal error with structured context.
    public func capture(error: Error, context: [String: String] = [:]) {
        SentrySDK.capture(error: error) { scope in
            if !context.isEmpty {
                scope.setContext(value: context, key: "app_context")
            }
        }
    }

    /// Capture a non-fatal message (for errors that don't throw).
    public func capture(message: String, level: SentryLevel = .error, context: [String: String] = [:]) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
            if !context.isEmpty {
                scope.setContext(value: context, key: "app_context")
            }
        }
    }

    // MARK: - Breadcrumbs

    /// Record a user action breadcrumb. Never include user content — action names only.
    public func breadcrumb(_ message: String, category: BreadcrumbCategory, data: [String: Any] = [:]) {
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.category = category.rawValue
        crumb.level = .info
        if !data.isEmpty {
            crumb.data = data
        }
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - App Context

    /// Update Sentry scope with current app state for richer crash reports.
    public func setAppContext(plantCount: Int, gardenCount: Int, hasActiveReminders: Bool) {
        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "plant_count_bucket": Self.bucket(plantCount, thresholds: [0, 5, 20, 50]),
                "garden_count": gardenCount,
                "has_active_reminders": hasActiveReminders,
            ], key: "garden_state")
        }
    }

    // MARK: - Performance Tracing

    /// Start a performance transaction for a user-visible operation.
    public func startTransaction(name: String, operation: String) -> any SentrySpan {
        SentrySDK.startTransaction(name: name, operation: operation)
    }

    // MARK: - BreadcrumbCategory

    public enum BreadcrumbCategory: String {
        case navigation
        case userAction = "user_action"
        case dataOperation = "data_operation"
        case authentication
        case sync
    }

    // MARK: - Private Helpers

    private static func bucket(_ value: Int, thresholds: [Int]) -> String {
        for threshold in thresholds.reversed() where value >= threshold {
            let next = thresholds.first(where: { $0 > threshold }) ?? threshold * 10
            return "\(threshold)-\(next)"
        }
        return "0"
    }
}
