import Foundation
import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices
#if canImport(UIKit)
import UIKit
#endif

public struct MainAppView: View {
    // Services injected from GrowWiseApp via environment
    @Environment(LocationService.self) private var locationService
    @Environment(NotificationService.self) private var notificationService  
    @Environment(PerformanceMonitor.self) private var performanceMonitor
    @Environment(CloudSyncService.self) private var cloudSyncService
    
    // DataService initialized asynchronously in this view, then injected to children
    @State private var dataService: DataService? = nil
    @State private var featureServices: FeatureServices?
    @State private var selectedTab: TabSelection = .home
    @State private var isInitializing = true
    @State private var initializationError: Error?
    @State private var cachedOnboardingStatus: Bool?
    @State private var initializationStage: String = "Initializing..."

    public init() {
        let launchArgs = ProcessInfo.processInfo.arguments
        let launchEnv = ProcessInfo.processInfo.environment
        let initialOnboardingStatus: Bool
        if launchArgs.contains("--skip-onboarding") || launchEnv["UITEST_SKIP_ONBOARDING"] == "1" {
            initialOnboardingStatus = true
        } else {
            initialOnboardingStatus = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
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
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(TabSelection.home)
            
            MyGardenView()
                .tabItem {
                    Image(systemName: "leaf.fill")
                    Text("My Garden")
                }
                .tag(TabSelection.garden)
            
            PlantDatabaseView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Plant Guide")
                }
                .tag(TabSelection.plantGuide)
            
            if dataService != nil {
                JournalView()
                    .tabItem {
                        Image(systemName: "book.pages.fill")
                        Text("Journal")
                    }
                    .tag(TabSelection.journal)
            }
            
            TutorialsView()
                .tabItem {
                    Image(systemName: "graduationcap.fill")
                    Text("Learn")
                }
                .tag(TabSelection.tutorials)

            PlantScannerView()
                .tabItem {
                    Image(systemName: "camera.macro")
                    Text("Scanner")
                }
                .tag(TabSelection.scanner)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .tag(TabSelection.profile)
        }
    }
    
    private var shouldShowOnboarding: Bool {
        !(cachedOnboardingStatus ?? false)
    }

    @MainActor
    private func initializeDataService() async {
        isInitializing = true
        initializationError = nil

        // Fast path for UI testing — skip performance monitoring and background work
        // to allow XCTest quiescence detection to succeed.
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let service = await DataService.makeAsync()
            self.dataService = service
            self.featureServices = FeatureServices(
                reminderService: ReminderService(dataService: service, notificationService: notificationService),
                photoService: PhotoService(dataService: service),
                plantDatabaseService: PlantDatabaseService(dataService: service),
                tutorialService: TutorialService(dataService: service),
                subscriptionService: SubscriptionService(),
                companionPlantingService: CompanionPlantingService()
            )
            isInitializing = false
            return
        }

        // Start tracking app launch
        performanceMonitor.recordAppLaunchStart()

        // Log memory state before initialization
        let memoryBefore = performanceMonitor.currentMemoryUsage
        let pressureBefore = performanceMonitor.memoryPressureLevel
        print("[Init] Memory before DataService: \(String(format: "%.1fMB", memoryBefore))")
        print("[Init] Memory pressure: \(pressureBefore.description)")

        initializationStage = "Initializing database..."
        let initStartTime = CFAbsoluteTimeGetCurrent()

        print("[Init] Using async background initialization...")
        let service = await DataService.makeAsync()
        self.dataService = service
        self.featureServices = FeatureServices(
            reminderService: ReminderService(dataService: service, notificationService: notificationService),
            photoService: PhotoService(dataService: service),
            plantDatabaseService: PlantDatabaseService(dataService: service),
            tutorialService: TutorialService(dataService: service),
            subscriptionService: SubscriptionService(),
            companionPlantingService: CompanionPlantingService()
        )
        cloudSyncService.attach(dataService: service)

        if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
            Task {
                await featureServices?.reminderService.synchronizePendingNotifications()
            }
        }

        let initDuration = CFAbsoluteTimeGetCurrent() - initStartTime
        let memoryAfter = performanceMonitor.currentMemoryUsage
        let memoryDelta = memoryAfter - memoryBefore

        print("[Init] Memory after DataService: \(String(format: "%.1fMB", memoryAfter))")
        print("[Init] Memory delta: \(String(format: "%.1fMB", memoryDelta))")
        print("[Init] DataService initialized in \(String(format: "%.3fs", initDuration))")

        // Log storage configuration
        print("[Init] Storage configuration: persistent=true, allowsSave=true")

        // Performance breakdown logging
        print("[Init] Performance: init=\(String(format: "%.3fs", initDuration)), total=\(String(format: "%.3fs", initDuration))")

        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        if !isUITesting {
            // Warm cache in background
            initializationStage = "Loading data..."
            Task.detached(priority: .utility) { [service] in
                await MainActor.run {
                    print("[Init] Starting cache warming...")
                }
                let warmingStart = CFAbsoluteTimeGetCurrent()

                await service.warmCache()

                let warmingDuration = CFAbsoluteTimeGetCurrent() - warmingStart
                await MainActor.run {
                    let stats = service.getCacheStats()
                    print("[Init] Cache warming completed in \(String(format: "%.3fs", warmingDuration))")
                    print("[Init] Cache ready: \(stats.size) entries preloaded")
                }
            }
        }

        // Complete app launch tracking
        performanceMonitor.recordAppLaunchComplete()

        // Log performance report
        let report = performanceMonitor.generatePerformanceReport()
        print("[Init] App launch complete in \(String(format: "%.3fs", report.appLaunchTime))")
        print("[Init] Performance score: \(String(format: "%.1f", report.performanceScore))/100")

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
            print("[Seed] PlantDatabaseService not available, skipping seeding")
            return
        }

        let memoryBefore = performanceMonitor.currentMemoryUsage
        print("[Seed] Memory before database seeding: \(String(format: "%.1fMB", memoryBefore))")

        do {
            try await plantDatabaseService.seedPlantDatabase()
        } catch {
            print("[Seed] Seeding encountered errors: \(error.localizedDescription)")
        }

        let memoryAfter = performanceMonitor.currentMemoryUsage
        let memoryUsedBySeed = memoryAfter - memoryBefore

        print("[Seed] Memory after seeding: \(String(format: "%.1fMB", memoryAfter))")
        print("[Seed] Memory used by seeding: \(String(format: "%.1fMB", memoryUsedBySeed))")

        if memoryUsedBySeed > 5 {
            print("[Seed] WARNING: Seeding used \(String(format: "%.1fMB", memoryUsedBySeed)) - more than expected (5MB threshold)")
        }
    }
}

enum TabSelection: Int, CaseIterable {
    case home = 0
    case garden = 1
    case plantGuide = 2
    case journal = 3
    case tutorials = 4
    case scanner = 5
    case profile = 6

    var title: String {
        switch self {
        case .home: return "Home"
        case .garden: return "My Garden"
        case .plantGuide: return "Plant Guide"
        case .journal: return "Journal"
        case .tutorials: return "Learn"
        case .scanner: return "Scanner"
        case .profile: return "Profile"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .garden: return "leaf.fill"
        case .plantGuide: return "books.vertical.fill"
        case .journal: return "book.pages.fill"
        case .tutorials: return "graduationcap.fill"
        case .scanner: return "camera.macro"
        case .profile: return "person.circle.fill"
        }
    }
}

#Preview {
    MainAppView()
}
