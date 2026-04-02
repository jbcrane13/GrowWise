import Foundation
import GrowWiseModels
import GrowWiseServices
import os
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "com.growwise", category: "MainAppView")

public struct MainAppView: View {
    /// Services injected from GrowWiseApp via environment
    @Environment(LocationService.self)
    private var locationService
    @Environment(NotificationService.self)
    private var notificationService
    @Environment(CloudSyncService.self)
    private var cloudSyncService

    // DataService initialized asynchronously in this view, then injected to children
    @State private var dataService: DataService?
    @State private var featureServices: FeatureServices?
    @State private var selectedTab: TabSelection = .home
    @State private var isInitializing = true
    @State private var initializationError: Error?
    @State private var cachedOnboardingStatus: Bool?
    @State private var initializationStage: String = "Initializing..."

    public init() {
        let launchArgs = ProcessInfo.processInfo.arguments
        let launchEnv = ProcessInfo.processInfo.environment
        let skipOnboarding = launchArgs.contains("--skip-onboarding")
            || launchEnv["UITEST_SKIP_ONBOARDING"] == "1"
        let initialOnboardingStatus: Bool = if skipOnboarding {
            true
        } else {
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }

        _cachedOnboardingStatus = State(initialValue: initialOnboardingStatus)
    }

    private struct FeatureServices {
        let reminderService: ReminderService
        let photoService: PhotoService
        let plantDatabaseService: PlantDatabaseService
        let tutorialService: TutorialService
        let subscriptionService: SubscriptionService
        let companionPlantingService: CompanionPlantingService
        let plantCareAdviceService: PlantCareAdviceService
    }

    public var body: some View {
        ZStack {
            if isInitializing {
                VStack(spacing: 16) {
                    if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    Text(initializationStage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .task {
                    await initializeDataService()
                }
            } else if let error = initializationError {
                ErrorView(error: error) {
                    Task {
                        await initializeDataService()
                    }
                }
            } else if shouldShowOnboarding, let ds = dataService {
                OnboardingView {
                    cachedOnboardingStatus = true
                }
                .environment(ds)
            } else if let ds = dataService, let services = featureServices {
                mainTabView
                    .environment(ds)
                    .environment(services.reminderService)
                    .environment(services.photoService)
                    .environment(services.plantDatabaseService)
                    .environment(services.tutorialService)
                    .environment(services.subscriptionService)
                    .environment(services.companionPlantingService)
                    .environment(services.plantCareAdviceService)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Preparing services...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("MainAppView")
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(TabSelection.home)
                .accessibilityIdentifier("tab_home")

            GardenView()
                .tabItem {
                    Label("Garden", systemImage: "leaf.fill")
                }
                .tag(TabSelection.garden)
                .accessibilityIdentifier("tab_garden")

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(TabSelection.journal)
                .accessibilityIdentifier("tab_journal")

            NavigationStack {
                RemindersListView()
            }
            .tabItem {
                Label("Reminders", systemImage: "bell.fill")
            }
            .tag(TabSelection.reminders)
            .accessibilityIdentifier("tab_reminders")

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(TabSelection.profile)
                .accessibilityIdentifier("tab_profile")
        }
        .tint(CultivationTheme.Colors.accentCoral)
    }

    private var shouldShowOnboarding: Bool {
        !(cachedOnboardingStatus ?? false)
    }

    @MainActor
    private func initializeDataService() async {
        isInitializing = true
        initializationError = nil

        // Fast path for UI testing
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let service = await DataService.makeAsync()
            self.dataService = service
            self.featureServices = FeatureServices(
                reminderService: ReminderService(dataService: service, notificationService: notificationService),
                photoService: PhotoService(dataService: service),
                plantDatabaseService: PlantDatabaseService(dataService: service),
                tutorialService: TutorialService(dataService: service),
                subscriptionService: SubscriptionService(),
                companionPlantingService: CompanionPlantingService(),
                plantCareAdviceService: PlantCareAdviceService()
            )
            isInitializing = false
            return
        }

        initializationStage = "Initializing database..."
        let initStartTime = CFAbsoluteTimeGetCurrent()

        let service = await DataService.makeAsync()
        self.dataService = service
        self.featureServices = FeatureServices(
            reminderService: ReminderService(dataService: service, notificationService: notificationService),
            photoService: PhotoService(dataService: service),
            plantDatabaseService: PlantDatabaseService(dataService: service),
            tutorialService: TutorialService(dataService: service),
            subscriptionService: SubscriptionService(),
            companionPlantingService: CompanionPlantingService(),
            plantCareAdviceService: PlantCareAdviceService()
        )
        cloudSyncService.attach(dataService: service)

        if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
            Task {
                await featureServices?.reminderService.synchronizePendingNotifications()
            }
        }

        let initDuration = CFAbsoluteTimeGetCurrent() - initStartTime
        logger.info("[Init] DataService initialized in \(String(format: "%.3fs", initDuration), privacy: .public)")

        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        if !isUITesting {
            // Warm cache in background
            initializationStage = "Loading data..."
            Task.detached(priority: .utility) { [service] in
                let warmingStart = CFAbsoluteTimeGetCurrent()
                await service.warmCache()
                let warmingDuration = CFAbsoluteTimeGetCurrent() - warmingStart
                await MainActor.run {
                    let stats = service.getCacheStats()
                    logger.info("[Init] Cache warming completed in \(String(format: "%.3fs", warmingDuration), privacy: .public)")
                    logger.info("[Init] Cache ready: \(stats.size) entries preloaded")
                }
            }
        }

        if !isUITesting {
            // Defer non-critical initialization
            initializationStage = "Almost ready..."
            Task(priority: .background) {
                await seedDatabaseIfNeeded()
            }
        }

        isInitializing = false
    }

    @MainActor
    private func seedDatabaseIfNeeded() async {
        guard let plantDatabaseService = featureServices?.plantDatabaseService else {
            logger.info("[Seed] PlantDatabaseService not available, skipping seeding")
            return
        }

        do {
            try await plantDatabaseService.seedPlantDatabase()
        } catch {
            logger.error("[Seed] Seeding encountered errors: \(error.localizedDescription, privacy: .public)")
        }
    }
}

public enum TabSelection: String, CaseIterable {
    case home
    case garden
    case journal
    case reminders
    case profile
}

#Preview {
    MainAppView()
}
