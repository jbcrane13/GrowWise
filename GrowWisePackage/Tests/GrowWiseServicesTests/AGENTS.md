# GROWWISESERVICESTESTS KNOWLEDGE BASE

## OVERVIEW
Comprehensive test suite for the `GrowWiseServices` target, heavily focused on security, data integrity, and encryption operations.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Security & Keychain | `*SecurityTests.swift`, `Keychain*Tests.swift` | Tests AES-256-GCM, access limits, and Enclave |
| JWT Validation | `JWT*Tests.swift` | Validation, claims parsing, integrations |
| Rate Limiting/Audit | `RateLimiterTests.swift`, `Audit*Tests.swift` |
| Core Data Service | `DataService*Tests.swift` | CRUD, edge cases (Nil Self), storage config |
| Migrations | `Migration*Tests.swift` | Verify data format changes |

## CONVENTIONS
- Security tests must cover both **positive** (valid input) and **negative** (attack vectors) scenarios.
- Use `in-memory` ModelConfigurations for SwiftData testing to prevent disk I/O interference.
- Mock external dependencies: Use `tests/TestUtilities/MockServices.swift` and `TestFixtures.swift`.
- Tests run asynchronously: Use `async` test methods with `await`.

## ANTI-PATTERNS
- **NEVER** use real disk persistence in DataService tests.
- **DO NOT** test external CloudKit sync directly; mock the responses.
- **NEVER** leave security tests without negative validation paths.
