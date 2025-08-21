import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

public struct MainAppView: View {
    @StateObject private var dataService: DataService = {
        do {
            return try DataService()
        } catch {
            print("Failed to create DataService: \(error)")
            print("Using fallback DataService to prevent crashes")
            return DataService.createFallback()
        }
    }()
    @StateObject private var locationService = LocationService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingOnboarding = false
    @State private var selectedTab: TabSelection = .home
    
    public init() {
        // Using real DataService with graceful fallback handling
    }
    
    public var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .onAppear {
            checkOnboardingStatus()
            seedDatabaseIfNeeded()
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
            
            JournalView()
                .tabItem {
                    Image(systemName: "book.pages.fill")
                    Text("Journal")
                }
                .tag(TabSelection.journal)
            
            TutorialsView()
                .tabItem {
                    Image(systemName: "graduationcap.fill")
                    Text("Learn")
                }
                .tag(TabSelection.tutorials)
        }
        .environmentObject(dataService)
        .environmentObject(locationService)
        .environmentObject(notificationService)
    }
    
    private var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    private func checkOnboardingStatus() {
        showingOnboarding = shouldShowOnboarding
    }
    
    private func seedDatabaseIfNeeded() {
        // Database seeding with real DataService
        print("Database seeding available - using real DataService")
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