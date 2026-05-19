import GrowWiseFeature
import GrowWiseServices
import SwiftUI

@main
struct CultivationApp: App {
    // Core services injected into environment for app-wide access
    // DataService initialized in MainAppView due to async requirements and error handling
    @State private var locationService = LocationService()
    @State private var notificationService = NotificationService()
    @State private var cloudSyncService = CloudSyncService()
    @State private var perenualAPIService = PerenualAPIService()
    @State private var perenualEnrichmentService: PerenualEnrichmentService?

    private let analyticsTracker = OnboardingAnalyticsTracker.shared

    init() {
        FontRegistration.registerIfNeeded()

        // One-shot cleanup of the removed Appearance preference (v2 forces light).
        UserDefaults.standard.removeObject(forKey: "app_appearance")

        // Initialize Sentry error tracking
        ObservabilityService.shared.configure(
            dsn: "https://739b91203930c30d55664ca51b99956e@o4510965380808704.ingest.us.sentry.io/4511185284497408",
            environment: {
                #if DEBUG
                return "debug"
                #else
                return "production"
                #endif
            }()
        )

        // Store an optional bundled Perenual API key securely on first launch.
        // Release builds must work without a bundled key; Perenual screens surface retryable errors.
        if !PerenualAPIService.hasAPIKey,
           let bundledKey = Bundle.main.object(forInfoDictionaryKey: "PERENUAL_API_KEY") as? String,
           !bundledKey.isEmpty
        {
            PerenualAPIService.storeAPIKey(bundledKey)
        }

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
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(locationService)
                .environment(notificationService)
                .environment(cloudSyncService)
                .environment(perenualAPIService)
                .environment(perenualEnrichmentService ?? PerenualEnrichmentService(api: perenualAPIService))
                .preferredColorScheme(.light)
                .onAppear {
                    if perenualEnrichmentService == nil {
                        perenualEnrichmentService = PerenualEnrichmentService(api: perenualAPIService)
                    }
                    ScenePhaseProvider.shared.startObserving()
                }
                .onChange(of: ScenePhaseProvider.shared.scenePhase) { _, newPhase in
                    if newPhase == .active {
                        analyticsTracker.checkActivationMilestones()
                    }
                }
        }
    }
}
