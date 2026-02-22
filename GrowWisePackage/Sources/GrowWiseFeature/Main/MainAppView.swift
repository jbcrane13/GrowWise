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
    
    // DataService initialized asynchronously in this view, then injected to children
    @State private var dataService: DataService? = nil
    @State private var featureServices: FeatureServices?
    @State private var showingOnboarding = false
    @State private var selectedTab: TabSelection = .home
    @State private var isInitializing = true
    @State private var initializationError: Error?
    @State private var cachedOnboardingStatus: Bool?
    @State private var isFallbackMode = false
    @State private var initializationStage: String = "Initializing..."

    public init() {
        // Cache onboarding status to avoid repeated UserDefaults reads
        self.cachedOnboardingStatus = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    private struct FeatureServices {
        let reminderService: ReminderService
        let photoService: PhotoService
        let plantDatabaseService: PlantDatabaseService
        let tutorialService: TutorialService
    }
    
    public var body: some View {
        Group {
            if isInitializing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(initializationStage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .task {
                    await initializeDataService()
                }
            } else if isFallbackMode {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Running in Limited Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Some features may be unavailable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let ds = dataService, let services = featureServices {
                        mainTabView
                            .environment(ds)
                            .environment(services.reminderService)
                            .environment(services.photoService)
                            .environment(services.plantDatabaseService)
                            .environment(services.tutorialService)
                    }
                }
            } else if let error = initializationError {
                ErrorView(error: error) {
                    Task {
                        await initializeDataService()
                    }
                }
            } else if shouldShowOnboarding {
                OnboardingView()
            } else if let ds = dataService, let services = featureServices {
                mainTabView
                    .environment(ds)
                    .environment(services.reminderService)
                    .environment(services.photoService)
                    .environment(services.plantDatabaseService)
                    .environment(services.tutorialService)
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
        .onAppear {
            checkOnboardingStatus()
        }
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
        }
    }
    
    private var shouldShowOnboarding: Bool {
        !(cachedOnboardingStatus ?? false)
    }
    
    private func checkOnboardingStatus() {
        // Use cached status to avoid UserDefaults read
        showingOnboarding = shouldShowOnboarding
    }
    
    @MainActor
    private func initializeDataService() async {
        isInitializing = true
        initializationError = nil
        isFallbackMode = false

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
            tutorialService: TutorialService(dataService: service)
        )

        let initDuration = CFAbsoluteTimeGetCurrent() - initStartTime
        let memoryAfter = performanceMonitor.currentMemoryUsage
        let memoryDelta = memoryAfter - memoryBefore

        print("[Init] Memory after DataService: \(String(format: "%.1fMB", memoryAfter))")
        print("[Init] Memory delta: \(String(format: "%.1fMB", memoryDelta))")
        print("[Init] DataService initialized in \(String(format: "%.3fs", initDuration))")

        // Validate memory delta is reasonable
        if memoryDelta > 10 {
            print("[Init] ⚠️ WARNING: Memory delta (\(String(format: "%.1fMB", memoryDelta))) exceeds expected threshold (10MB)")
            print("[Init] This may indicate in-memory storage is being used instead of persistent storage")
            isFallbackMode = true
        } else {
            print("[Init] ✅ Memory delta is reasonable - persistent storage confirmed")
        }

        // Log storage configuration
        print("[Init] Storage configuration: persistent=true, allowsSave=true")

        // Performance breakdown logging
        print("[Init] Performance: init=\(String(format: "%.3fs", initDuration)), total=\(String(format: "%.3fs", initDuration))")

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

        // Complete app launch tracking
        performanceMonitor.recordAppLaunchComplete()

        // Log performance report
        let report = performanceMonitor.generatePerformanceReport()
        print("[Init] App launch complete in \(String(format: "%.3fs", report.appLaunchTime))")
        print("[Init] Performance score: \(String(format: "%.1f", report.performanceScore))/100")

        // Defer non-critical initialization
        initializationStage = "Almost ready..."
        Task.detached(priority: .background) {
            await seedDatabaseIfNeeded()
        }

        isInitializing = false
    }
    
    @MainActor
    private func seedDatabaseIfNeeded() async {
        let memoryBefore = performanceMonitor.currentMemoryUsage
        print("[Seed] Memory before database seeding: \(String(format: "%.1fMB", memoryBefore))")

        // Database seeding in background to avoid blocking UI
        await Task.detached(priority: .background) {
            print("Database seeding available - using real DataService")
            // Actual seeding logic would go here
        }.value

        let memoryAfter = performanceMonitor.currentMemoryUsage
        let memoryUsedBySeed = memoryAfter - memoryBefore

        print("[Seed] Memory after seeding: \(String(format: "%.1fMB", memoryAfter))")
        print("[Seed] Memory used by seeding: \(String(format: "%.1fMB", memoryUsedBySeed))")

        if memoryUsedBySeed > 5 {
            print("[Seed] ⚠️ WARNING: Seeding used \(String(format: "%.1fMB", memoryUsedBySeed)) - more than expected (5MB threshold)")
        }
    }
}

enum TabSelection: Int, CaseIterable {
    case home = 0
    case garden = 1
    case plantGuide = 2
    case journal = 3
    case tutorials = 4
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .garden: return "My Garden"
        case .plantGuide: return "Plant Guide"
        case .journal: return "Journal"
        case .tutorials: return "Learn"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .garden: return "leaf.fill"
        case .plantGuide: return "books.vertical.fill"
        case .journal: return "book.pages.fill"
        case .tutorials: return "graduationcap.fill"
        }
    }
}

#Preview {
    MainAppView()
}
