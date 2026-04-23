# Runbook: Keychain Data Loss / Access Errors

**Severity:** P0/P1 — User cannot access their encrypted data

## Symptoms

- App launches but shows authentication error immediately
- `KeychainManager` logs: `errSecItemNotFound`, `errSecAuthFailed`, `errSecInteractionNotAllowed`
- User reinstalled app and data is gone
- Biometric auth prompt not appearing

## Diagnostic Steps

### 1. Identify the Error Code
Check `AuditLogger` output for the specific `OSStatus` error code:

| Code | Meaning |
|------|---------|
| `-25300` | `errSecItemNotFound` — key does not exist in Keychain |
| `-25293` | `errSecAuthFailed` — wrong authentication / biometric mismatch |
| `-25308` | `errSecInteractionNotAllowed` — device locked when access attempted |
| `-34018` | `errSecMissingEntitlement` — missing Keychain entitlement (build issue) |

### 2. Check Keychain Access Group
```bash
# In Xcode → Signing & Capabilities → Keychain Sharing
# Verify: com.growwise.keychain is listed
```

### 3. Check Secure Enclave Key Status
`SecureEnclaveKeyManager` creates a key tied to biometrics. If the user re-enrolled Face ID/Touch ID, the old key is invalidated.

**Code reference:** `SecureEnclaveKeyManager.swift` — `createOrRetrieveKey()`

## Common Causes & Fixes

### App Reinstall (Expected)
**Cause:** iOS removes Keychain items when app is deleted (unless using Keychain Access Groups with iCloud Keychain enabled).

**Fix:** This is expected iOS behavior. Ensure onboarding flow handles first-launch gracefully — `DataService` multi-level fallback should catch this.

**Verify:** `DataService.swift` — `init_minimal` fallback path executes without crash.

### Biometric Re-enrollment Invalidated Secure Enclave Key
**Cause:** User added/removed a fingerprint or Face ID. Secure Enclave keys with `kSecAccessControlBiometryCurrentSet` are automatically invalidated.

**Fix:**
1. `KeyRotationManager` should detect this and trigger re-encryption with a new key
2. If stuck: `LegacyEncryptionMigrationService` handles re-keying from backup material

**Code reference:** `KeyRotationManager.swift` — `checkForInvalidatedKeys()`

### errSecMissingEntitlement (-34018)
**Cause:** Build misconfiguration — Keychain entitlements missing from provisioning profile.

**Fix:**
1. In Xcode: Signing & Capabilities → Keychain Sharing → verify entitlement exists
2. Re-build with correct provisioning profile
3. This should never appear in production — flag as P0 if it does

## Recovery Procedure

If user data is genuinely inaccessible:
1. Check if backup encryption keys exist via `MigrationIntegrityService`
2. If `LegacyEncryptionMigrationService` can recover: guide user through in-app recovery flow
3. Last resort: user must re-enter data manually (no silent data corruption)

## Prevention

- All Keychain access wrapped in `KeychainStorageService` with proper error handling
- `AuditLogger` captures all Keychain operations for forensics
- `MigrationIntegrityService` verifies data integrity on each launch
