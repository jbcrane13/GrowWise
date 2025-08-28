import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

public struct MainAppView: View {
    @State private var dataService: DataService? = nil
    @StateObject private var locationService = LocationService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingOnboarding = false
    @State private var selectedTab: TabSelection = .home
    @State private var isInitializing = true
    @State private var initializationError: Error?
    @State private var cachedOnboardingStatus: Bool?
    
    public init() {
        // Cache onboarding status to avoid repeated UserDefaults reads
        self.cachedOnboardingStatus = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    public var body: some View {
        Group {
            if isInitializing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading GrowWise...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .task {
                    await initializeDataService()
                }
            } else if let error = initializationError {
                ErrorView(error: error) {
                    Task {
                        await initializeDataService()
                    }
                }
            } else if shouldShowOnboarding {
                OnboardingView()
            } else if let ds = dataService {
                mainTabView
                    .environmentObject(ds)
                    .environmentObject(locationService)
                    .environmentObject(notificationService)
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
            
            if let ds = dataService {
                JournalView(photoService: PhotoService(dataService: ds))
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
        
        do {
            self.dataService = try await DataService()
            
            // Defer non-critical initialization
            Task.detached(priority: .background) {
                await seedDatabaseIfNeeded()
            }
        } catch {
            print("Failed to create DataService: \(error)")
            initializationError = error
            // Use fallback
            self.dataService = DataService.createFallback
        }
        
        isInitializing = false
    }
    
    @MainActor
    private func seedDatabaseIfNeeded() async {
        // Database seeding in background to avoid blocking UI
        await Task.detached(priority: .background) {
            print("Database seeding available - using real DataService")
            // Actual seeding logic would go here
        }.value
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
