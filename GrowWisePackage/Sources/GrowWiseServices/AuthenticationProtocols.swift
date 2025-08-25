import Foundation
import LocalAuthentication

// MARK: - Keychain Protocol

/// Protocol defining keychain storage operations
/// Note: Thread safety is handled by the implementing class
public protocol KeychainStorageProtocol {
    func store(_ data: Data, for key: String) throws
    func storeString(_ string: String, for key: String) throws
    func retrieve(for key: String) throws -> Data
    func retrieveString(for key: String) throws -> String
    func delete(for key: String) throws
    func exists(for key: String) -> Bool
}

// MARK: - Biometric Authentication Protocol

/// Protocol defining biometric authentication capabilities
/// Note: Implementations must be isolated to MainActor due to UI responsibilities
@MainActor
public protocol BiometricAuthenticationProtocol {
    var canUseBiometrics: Bool { get }
    var biometricType: LABiometryType { get }
    var isAuthenticated: Bool { get }
    
    func authenticateWithBiometrics(reason: String?) async throws
    func checkAuthenticationStatus(timeoutMinutes: Int) -> Bool
}

// MARK: - Dependency Container

/// Container for managing service dependencies with thread-safe access
@MainActor
public final class AuthenticationDependencyContainer {
    public static let shared = AuthenticationDependencyContainer()
    
    private var _keychainStorage: KeychainStorageProtocol?
    private var _biometricAuth: BiometricAuthenticationProtocol?
    
    private init() {}
    
    /// Set keychain storage implementation
    /// - Parameter storage: The keychain storage implementation to use
    public func setKeychainStorage(_ storage: KeychainStorageProtocol) {
        _keychainStorage = storage
    }
    
    /// Set biometric authentication implementation
    /// - Parameter auth: The biometric authentication implementation to use
    public func setBiometricAuthentication(_ auth: BiometricAuthenticationProtocol) {
        _biometricAuth = auth
    }
    
    /// Get the configured keychain storage
    /// - Returns: The keychain storage implementation
    /// - Note: Will fatal error if not initialized. Call setKeychainStorage first.
    public var keychainStorage: KeychainStorageProtocol {
        guard let storage = _keychainStorage else {
            fatalError("KeychainStorage not initialized. Call setKeychainStorage first.")
        }
        return storage
    }
    
    /// Get the configured biometric authentication
    /// - Returns: The biometric authentication implementation
    /// - Note: Will fatal error if not initialized. Call setBiometricAuthentication first.
    public var biometricAuth: BiometricAuthenticationProtocol {
        guard let auth = _biometricAuth else {
            fatalError("BiometricAuthentication not initialized. Call setBiometricAuthentication first.")
        }
        return auth
    }
}