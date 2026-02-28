import GrowWiseFeature
import GrowWiseServices
import SwiftUI

@main
struct CultivationApp: App {
    // Core services injected into environment for app-wide access
    // DataService initialized in MainAppView due to async requirements and error handling
    @State private var locationService = LocationService()
    @State private var notificationService = NotificationService()
    @State private var performanceMonitor = PerformanceMonitor()
    @State private var cloudSyncService = CloudSyncService()
    @State private var observability = ObservabilityService.shared
    @State private var analytics = AnalyticsService.shared

    init() {
        let launchArgs = ProcessInfo.processInfo.arguments
        let launchEnv = ProcessInfo.processInfo.environment

        // Disable all animations during UI testing so XCTest's idle detection
        // doesn't get blocked by continuous ProgressView spinner animations.
        #if canImport(UIKit)
        if launchArgs.contains("--uitesting") {
            UIView.setAnimationsEnabled(false)
        }
        #endif

        // --reset-data must run FIRST so subsequent flags can re-apply on a clean slate.
        // DataService automatically uses in-memory store when --uitesting is present,
        // so persistent store migration is never triggered during UI test runs.
        if launchArgs.contains("--reset-data") {
            if let domain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }
        }
        if launchArgs.contains("--skip-onboarding") || launchEnv["UITEST_SKIP_ONBOARDING"] == "1" {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        if launchArgs.contains("--reset-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }

        if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
            // Initialize security/encryption early to avoid compliance blocks
            CultivationApp.ensureEncryptionReady()

            // Initialize authentication services with proper dependency injection
            Task { @MainActor in
                AuthenticationInitializer.initialize()
            }

            // Initialize observability (Sentry) and analytics (Amplitude)
            // DSNs/keys are resolved from environment variables or Xcode scheme
            let isDev = launchEnv["GROWWISE_ENV"] == "development"
            let env = isDev ? "development" : "production"
            ObservabilityService.shared.configure(environment: env)
            AnalyticsService.shared.configure(isDevelopment: isDev)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(locationService)
                .environment(notificationService)
                .environment(performanceMonitor)
                .environment(cloudSyncService)
                .environment(observability)
                .environment(analytics)
        }
    }

    private static func ensureEncryptionReady() {
        // Ensure encryption keys are initialized and compliant early in app startup
        let storage = KeychainStorageService(service: "com.growwiser.audit", accessGroup: nil)
        let encryptionService = EncryptionService(storage: storage)

        Task.detached(priority: .utility) {
            if encryptionService.isKeyRotationOverdue() {
                do {
                    try await encryptionService.enforceComplianceRotation()
                    print("[AppBootstrap] Enforced compliance rotation successfully")
                    return
                } catch {
                    print("[AppBootstrap] enforceComplianceRotation failed: \(error)")
                }
            }

            if encryptionService.isKeyRotationNeeded() || encryptionService.currentKeyVersion == 0 {
                do {
                    let newVersion = try await encryptionService.rotateKey(reason: "Initial setup")
                    print("[AppBootstrap] Initial key rotation completed. Version=\(newVersion)")
                } catch {
                    print("[AppBootstrap] Initial key rotation failed: \(error)")
                }
            }
        }
    }
}
