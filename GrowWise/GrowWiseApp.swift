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

    // Appearance preference persisted via AppStorage
    @AppStorage("app_appearance") private var appearance: AppAppearance = .system

    init() {
        // Store Perenual API key securely on first launch
        if !PerenualAPIService.hasAPIKey {
            PerenualAPIService.storeAPIKey("sk-LSIM69d0612798a7616109")
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

    private var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
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
                .preferredColorScheme(colorScheme)
                .onAppear {
                    if perenualEnrichmentService == nil {
                        perenualEnrichmentService = PerenualEnrichmentService(api: perenualAPIService)
                    }
                }
        }
    }
}
