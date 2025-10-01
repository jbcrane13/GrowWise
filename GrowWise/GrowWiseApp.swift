import SwiftUI
import GrowWiseFeature
import GrowWiseServices

@main
struct GrowWiseApp: App {
    // Core services injected into environment for app-wide access
    // DataService initialized in MainAppView due to async requirements and error handling
    @State private var locationService = LocationService()
    @State private var notificationService = NotificationService()
    @State private var performanceMonitor = PerformanceMonitor()
    
    init() {
        // Initialize authentication services with proper dependency injection
        Task { @MainActor in
            AuthenticationInitializer.initialize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(locationService)
                .environment(notificationService)
                .environment(performanceMonitor)
        }
    }
}
