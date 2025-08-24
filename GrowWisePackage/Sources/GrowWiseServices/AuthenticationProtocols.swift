import Foundation
import LocalAuthentication

// MARK: - Keychain Protocol

/// Protocol defining keychain storage operations
@MainActor
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
@MainActor
public protocol BiometricAuthenticationProtocol {
    var canUseBiometrics: Bool { get }
    var biometricType: LABiometryType { get }
    var isAuthenticated: Bool { get }
    
    func authenticateWithBiometrics(reason: String?) async throws
    func checkAuthenticationStatus(timeoutMinutes: Int) -> Bool
}

// MARK: - Dependency Container

/// Container for managing service dependencies
@MainActor
public final class AuthenticationDependencyContainer {
    public static let shared = AuthenticationDependencyContainer()
    
    private var _keychainStorage: KeychainStorageProtocol?
    private var _biometricAuth: BiometricAuthenticationProtocol?
    
    private init() {}
    
    public func setKeychainStorage(_ storage: KeychainStorageProtocol) {
        _keychainStorage = storage
    }
    
    public func setBiometricAuthentication(_ auth: BiometricAuthenticationProtocol) {
        _biometricAuth = auth
    }
    
    public var keychainStorage: KeychainStorageProtocol {
        guard let storage = _keychainStorage else {
            fatalError("KeychainStorage not initialized. Call setKeychainStorage first.")
        }
        return storage
    }
    
    public var biometricAuth: BiometricAuthenticationProtocol {
        guard let auth = _biometricAuth else {
            fatalError("BiometricAuthentication not initialized. Call setBiometricAuthentication first.")
        }
        return auth
    }
}