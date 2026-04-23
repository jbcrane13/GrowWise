# Runbook: Encryption Key Rotation Failure

**Severity:** P1 — Encrypted data may be inaccessible or in inconsistent state

## Symptoms

- `KeyRotationManager` logs show rotation failure
- Some data readable, some not (partial rotation)
- `MigrationIntegrityService` integrity check fails
- AuditLogger shows `keyRotationFailed` event

## Diagnostic Steps

### 1. Check AuditLogger for Rotation Events
```swift
// Filter AuditLogger for key rotation events
// Look for: keyRotationStarted, keyRotationCompleted, keyRotationFailed
```

### 2. Assess State
```swift
// KeyRotationManager exposes current rotation status
// Check if rotation completed atomically or was interrupted
```

### 3. Check MigrationIntegrityService
```swift
// MigrationIntegrityService.verifyIntegrity() — run on launch
// Returns integrity status for all encrypted data
```

## Recovery Procedure

### Interrupted Rotation (Partial State)
`KeyRotationManager` is designed to be idempotent — re-running rotation should complete safely.

```swift
// Trigger re-rotation from app settings or via debug flag
await keyRotationManager.rotateIfNeeded(force: true)
```

### Secure Enclave Key Invalidated Mid-Rotation
If the device's biometric enrollment changed during rotation:

1. `LegacyEncryptionMigrationService` can recover from backup encryption material
2. Walk through recovery path:
   - Decrypt with old key (from backup material)
   - Re-encrypt with new Secure Enclave key
   - Verify integrity

### Complete Key Loss (Last Resort)
If both current and backup keys are unavailable:
- Data encrypted with lost keys is **unrecoverable** (by design — AES-256-GCM)
- User must re-enter data
- File a P0 to investigate how both key copies were lost

## Prevention

- Key rotation is atomic — partial rotations roll back automatically
- Backup key material stored separately from primary key
- `MigrationIntegrityService` runs on every launch to catch issues early
- `AuditLogger` provides full forensic trail of all key operations
