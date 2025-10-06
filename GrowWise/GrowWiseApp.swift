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
        // Initialize security/encryption early to avoid compliance blocks
        GrowWiseApp.ensureEncryptionReady()

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
