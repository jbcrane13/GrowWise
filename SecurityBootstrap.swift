import Foundation
import GrowWiseServices

/// Security bootstrap to ensure encryption keys are initialized and compliant early in app startup.
/// This prevents onboarding and other flows from failing due to missing/overdue key rotation.
enum SecurityBootstrap {
    /// Ensures encryption is ready by enforcing rotation if overdue, or performing an initial rotation.
    /// Runs asynchronously without blocking the main thread.
    static func ensureEncryptionReady() {
        // Use the same service identifier used by AuditLogger/EncryptionService storage
        let storage = KeychainStorageService(service: "com.growwiser.audit", accessGroup: nil)
        let encryptionService = EncryptionService(storage: storage)

        Task.detached(priority: .utility) {
            // If rotation is overdue (or no key exists), enforce compliance rotation first
            if encryptionService.isKeyRotationOverdue() {
                do {
                    try await encryptionService.enforceComplianceRotation()
                    print("[SecurityBootstrap] Enforced compliance rotation successfully")
                    return
                } catch {
                    print("[SecurityBootstrap] enforceComplianceRotation failed: \(error)")
                }
            }

            // If still no key or rotation needed, attempt a manual initial rotation
            if encryptionService.isKeyRotationNeeded() || encryptionService.currentKeyVersion == 0 {
                do {
                    let newVersion = try await encryptionService.rotateKey(reason: "Initial setup")
                    print("[SecurityBootstrap] Initial key rotation completed. Version=\(newVersion)")
                } catch {
                    // Do not crash the app; log and continue. Downstream code should surface errors if needed.
                    print("[SecurityBootstrap] Initial key rotation failed: \(error)")
                }
            }
        }
    }
}
