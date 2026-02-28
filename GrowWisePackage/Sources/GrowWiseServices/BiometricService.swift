import LocalAuthentication

/// Minimal biometric authentication wrapper.
/// Replaces the former 571-line BiometricAuthenticationManager with a thin LAContext wrapper.
@Observable
@MainActor
public final class BiometricService {

    /// Whether Face ID / Touch ID / Optic ID is available on this device.
    public var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Prompt the user for biometric authentication.
    /// Returns `true` on success, throws on failure.
    @discardableResult
    public func authenticate(reason: String = "Authenticate to continue") async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    public init() {}
}
