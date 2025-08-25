import LocalAuthentication
import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

/// BiometricAuthenticationManager handles Face ID/Touch ID authentication
@MainActor
public final class BiometricAuthenticationManager: ObservableObject, BiometricAuthenticationProtocol {
    
    // MARK: - Singleton
    
    public static let shared = BiometricAuthenticationManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var biometricType: LABiometryType = .none
    @Published public private(set) var canUseBiometrics = false
    @Published public private(set) var isAuthenticating = false
    
    // MARK: - Properties
    
    private let context = LAContext()
    private var keychainStorage: KeychainStorageProtocol?
    
    // MARK: - Error Types
    
    public enum BiometricError: LocalizedError {
        case biometricsNotAvailable
        case biometricsNotEnrolled
        case authenticationFailed
        case userCancelled
        case userFallback
        case systemCancel
        case passcodeNotSet
        case lockout
        case appCancel
        case invalidContext
        case notInteractive
        case unknown(String)
        
        public var errorDescription: String? {
            switch self {
            case .biometricsNotAvailable:
                return "Biometric authentication is not available on this device"
            case .biometricsNotEnrolled:
                return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
            case .authenticationFailed:
                return "Authentication failed. Please try again"
            case .userCancelled:
                return "Authentication was cancelled"
            case .userFallback:
                return "Please use your passcode"
            case .systemCancel:
                return "Authentication was cancelled by the system"
            case .passcodeNotSet:
                return "Device passcode is not set"
            case .lockout:
                return "Too many failed attempts. Please try again later"
            case .appCancel:
                return "Authentication was cancelled by the app"
            case .invalidContext:
                return "Invalid authentication context"
            case .notInteractive:
                return "Authentication requires user interaction"
            case .unknown(let message):
                return message
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        checkBiometricAvailability()
        setupNotifications()
        
        // Register self with dependency container after initialization
        Task { @MainActor in
            AuthenticationDependencyContainer.shared.setBiometricAuthentication(self)
            // Get keychain storage from container if available
            if let storage = try? AuthenticationDependencyContainer.shared.keychainStorage {
                self.keychainStorage = storage
            }
        }
    }
    
    // MARK: - Dependency Injection
    
    /// Set the keychain storage provider
    public func setKeychainStorage(_ storage: KeychainStorageProtocol) {
        self.keychainStorage = storage
    }
    
    // MARK: - Public Methods
    
    /// Check if biometric authentication is available
    public func checkBiometricAvailability() {
        var error: NSError?
        canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canUseBiometrics {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            
            if let error = error {
                print("Biometric availability check failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get the name of the available biometric type
    public var biometricTypeName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            if #available(iOS 17.0, *) {
                return "Optic ID"
            } else {
                return "Biometric Authentication"
            }
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Authenticate using biometrics
    public func authenticateWithBiometrics(reason: String? = nil) async throws {
        guard canUseBiometrics else {
            throw BiometricError.biometricsNotAvailable
        }
        
        guard !isAuthenticating else {
            return // Already authenticating
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        let authReason = reason ?? "Authenticate to access your secure data"
        
        do {
            let context = LAContext()
            context.localizedFallbackTitle = "Use Passcode"
            context.localizedCancelTitle = "Cancel"
            
            // Set timeout for authentication
            context.touchIDAuthenticationAllowableReuseDuration = 10
            
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: authReason
            )
            
            if success {
                await MainActor.run {
                    self.isAuthenticated = true
                }
                
                // Store authentication timestamp
                try? keychainStorage?.storeString(
                    ISO8601DateFormatter().string(from: Date()),
                    for: "last_biometric_auth"
                )
            } else {
                throw BiometricError.authenticationFailed
            }
        } catch let error as LAError {
            throw handleLAError(error)
        } catch {
            throw BiometricError.unknown(error.localizedDescription)
        }
    }
    
    /// Authenticate with device passcode as fallback
    public func authenticateWithPasscode(reason: String? = nil) async throws {
        guard !isAuthenticating else {
            return
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        let authReason = reason ?? "Enter your passcode to access secure data"
        
        do {
            let context = LAContext()
            
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: authReason
            )
            
            if success {
                await MainActor.run {
                    self.isAuthenticated = true
                }
                
                // Store authentication timestamp
                try? keychainStorage?.storeString(
                    ISO8601DateFormatter().string(from: Date()),
                    for: "last_passcode_auth"
                )
            } else {
                throw BiometricError.authenticationFailed
            }
        } catch let error as LAError {
            throw handleLAError(error)
        } catch {
            throw BiometricError.unknown(error.localizedDescription)
        }
    }
    
    /// Logout and clear authentication
    public func logout() {
        isAuthenticated = false
        try? keychainStorage?.delete(for: "last_biometric_auth")
        try? keychainStorage?.delete(for: "last_passcode_auth")
    }
    
    /// Check if user is still authenticated (with timeout)
    public func checkAuthenticationStatus(timeoutMinutes: Int = 5) -> Bool {
        guard isAuthenticated else { return false }
        
        // Check last authentication time
        if let lastAuthString = try? keychainStorage?.retrieveString(for: "last_biometric_auth"),
           let lastAuthDate = ISO8601DateFormatter().date(from: lastAuthString) {
            
            let timeSinceAuth = Date().timeIntervalSince(lastAuthDate)
            let timeoutSeconds = TimeInterval(timeoutMinutes * 60)
            
            if timeSinceAuth > timeoutSeconds {
                isAuthenticated = false
                return false
            }
        }
        
        return isAuthenticated
    }
    
    /// Request biometric authentication for sensitive operations
    public func protectOperation<T>(
        reason: String,
        operation: () async throws -> T
    ) async throws -> T {
        try await authenticateWithBiometrics(reason: reason)
        return try await operation()
    }
    
    /// Enable biometric protection for Keychain items
    public func storeWithBiometricProtection(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.growwiser.app",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: createAccessControl()
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new item with biometric protection
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw BiometricError.unknown("Failed to store in keychain: \(status)")
        }
    }
    
    /// Retrieve biometric-protected Keychain item
    public func retrieveWithBiometricProtection(for key: String) async throws -> Data {
        // First authenticate
        try await authenticateWithBiometrics(reason: "Authenticate to access secure data")
        
        // Then retrieve
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.growwiser.app",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw BiometricError.unknown("Item not found in keychain")
            }
            throw BiometricError.unknown("Failed to retrieve from keychain: \(status)")
        }
        
        guard let data = item as? Data else {
            throw BiometricError.unknown("Unexpected data format in keychain")
        }
        
        return data
    }
    
    // MARK: - Private Methods
    
    private func createAccessControl() -> SecAccessControl {
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
        return access!
    }
    
    private func handleLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometricsNotAvailable
        case .biometryNotEnrolled:
            return .biometricsNotEnrolled
        case .biometryLockout:
            return .lockout
        case .appCancel:
            return .appCancel
        case .invalidContext:
            return .invalidContext
        case .notInteractive:
            return .notInteractive
        default:
            return .unknown(error.localizedDescription)
        }
    }
    
    private func setupNotifications() {
        // Listen for app lifecycle events
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: Notification.Name("ApplicationDidEnterBackground"),
            object: nil
        )
        #endif
        
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: Notification.Name("ApplicationWillEnterForeground"),
            object: nil
        )
        #endif
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Consider logging out on background for high security
        // For now, just mark the time
        try? keychainStorage?.storeString(
            ISO8601DateFormatter().string(from: Date()),
            for: "app_backgrounded_time"
        )
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Check if we need to re-authenticate
        if isAuthenticated {
            if !checkAuthenticationStatus(timeoutMinutes: 5) {
                // Authentication expired
                Task { @MainActor in
                    isAuthenticated = false
                }
            }
        }
        
        // Refresh biometric availability
        checkBiometricAvailability()
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

public struct BiometricAuthenticationView: View {
    @StateObject private var authManager = BiometricAuthenticationManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onSuccess: () -> Void
    let onCancel: (() -> Void)?
    
    public init(onSuccess: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            // Title
            Text("Authentication Required")
                .font(.title)
                .fontWeight(.semibold)
            
            // Description
            Text("Use \(authManager.biometricTypeName) to access your secure data")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: authenticate) {
                    HStack {
                        if authManager.isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                        }
                        
                        Text("Authenticate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(authManager.isAuthenticating)
                
                if !authManager.canUseBiometrics {
                    Button(action: authenticateWithPasscode) {
                        Text("Use Passcode")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if authManager.isAuthenticated {
                onSuccess()
            } else {
                authenticate()
            }
        }
    }
    
    private func authenticate() {
        Task {
            do {
                try await authManager.authenticateWithBiometrics()
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func authenticateWithPasscode() {
        Task {
            do {
                try await authManager.authenticateWithPasscode()
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - View Modifier for Protected Content

public struct BiometricProtectionModifier: ViewModifier {
    @StateObject private var authManager = BiometricAuthenticationManager.shared
    @State private var showAuthView = false
    
    let requireAuthentication: Bool
    
    public func body(content: Content) -> some View {
        ZStack {
            if authManager.isAuthenticated || !requireAuthentication {
                content
            } else {
                BiometricAuthenticationView(
                    onSuccess: {
                        showAuthView = false
                    },
                    onCancel: nil
                )
            }
        }
        .onAppear {
            if requireAuthentication && !authManager.isAuthenticated {
                showAuthView = true
            }
        }
    }
}

extension View {
    public func requiresBiometricAuthentication(_ required: Bool = true) -> some View {
        modifier(BiometricProtectionModifier(requireAuthentication: required))
    }
}