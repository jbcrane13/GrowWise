# Log Scrubbing & Data Redaction

GrowWise handles sensitive data (biometric auth, encryption keys, user garden data). All logging must
follow these redaction rules to prevent sensitive data leaks in logs, crash reports, or diagnostic outputs.

## Core Rule: Use OSLog with Privacy Annotations

Always use `OSLog` / `Logger` — never `print()`. OSLog enforces privacy at the OS level:

```swift
import OSLog

private let logger = Logger(subsystem: "com.growwise", category: "DataService")

// PUBLIC: Safe to log in production (non-sensitive identifiers)
logger.info("Plant saved: \(plant.id, privacy: .public)")
logger.info("Sync completed: \(recordCount, privacy: .public) records")

// PRIVATE: Redacted in production logs (shown only in dev with a profile)
logger.debug("Keychain query: \(queryKey, privacy: .private)")
logger.debug("User identifier: \(userID, privacy: .private)")

// SENSITIVE: Always redacted — use for any PII or secrets
logger.error("Auth failed for: \(email, privacy: .sensitive)")
```

## What Must Be Redacted

| Data Type | Privacy Level | Example |
|-----------|--------------|---------|
| Encryption keys | `.sensitive` | AES key bytes, Secure Enclave handles |
| User tokens / JWTs | `.sensitive` | Bearer tokens, session tokens |
| Email / username | `.sensitive` | User-identifying strings |
| Plant names / notes | `.private` | User-authored content |
| Location data | `.private` | GPS coordinates, place names |
| Keychain query keys | `.private` | Key identifiers |
| Record IDs (non-sensitive) | `.public` | Internal UUID references |
| Operation counts | `.public` | Sync counts, error counts |

## Prohibited Patterns

```swift
// NEVER — exposes data in system logs
print("Encryption key: \(key)")
NSLog("Token: %@", token)
logger.info("User email: \(email)")  // missing .private/.sensitive

// NEVER — Swift string interpolation without privacy annotation
// (defaults to .private in DEBUG, .redacted in RELEASE, but be explicit)
logger.debug("Query: \(sensitiveKey)")
```

## AuditLogger Usage

The `AuditLogger` service records security events for compliance. It automatically redacts sensitive
fields before writing to the audit trail:

```swift
// Security events must go through AuditLogger, not OSLog
await auditLogger.log(.keyRotation, context: ["keyID": keyID.uuidString])
await auditLogger.log(.authAttempt, context: ["result": "success"])
// Never include raw key material or tokens in audit context
```

## Crash Report Scrubbing

Sensitive data should never appear in crash reports. Ensure:

1. No secrets in global variables or `@MainActor` stored properties that crash reporters capture
2. No user content in exception messages (e.g., avoid `fatalError("Failed for \(userEmail)")`)
3. Keychain values should never be in a state where they appear in a stack frame string representation

## Verification Checklist

Before merging any PR touching logging or error handling:

- [ ] No `print()` statements in production code paths
- [ ] All `OSLog` messages use appropriate privacy annotation for interpolated values
- [ ] AuditLogger used for all security-relevant events
- [ ] No user PII in `fatalError`, `preconditionFailure`, or similar
- [ ] SwiftLint `no_print_statements` rule passes: `swiftlint lint --config .swiftlint.yml`
