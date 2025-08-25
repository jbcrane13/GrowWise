import Foundation

/// Initializer for setting up authentication services with proper dependency injection
@MainActor
public final class AuthenticationInitializer {
    
    /// Initialize authentication services and wire up dependencies
    public static func initialize() {
        // Get singleton instances
        let keychainManager = KeychainManager.shared
        let biometricManager = BiometricAuthenticationManager.shared
        
        // Wire up dependencies
        keychainManager.setBiometricAuthentication(biometricManager)
        biometricManager.setKeychainStorage(keychainManager)
        
        // Register with dependency container
        AuthenticationDependencyContainer.shared.setKeychainStorage(keychainManager)
        AuthenticationDependencyContainer.shared.setBiometricAuthentication(biometricManager)
        
        // Perform any migration if needed
        do {
            _ = try keychainManager.migrateFromUserDefaults()
        } catch {
            // Log migration error but don't fail initialization
            print("Warning: Migration failed - \(error.localizedDescription)")
        }
    }
}