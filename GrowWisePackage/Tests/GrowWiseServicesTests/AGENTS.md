# GROWWISESERVICESTESTS KNOWLEDGE BASE

## OVERVIEW
Core business logic and security hotspot with 50+ test suites covering encryption, persistence, and domain services.

## WHERE TO LOOK
| Domain | Key Files | Focus |
|--------|-----------|-------|
| **Security Hotspot** | `Encryption*`, `Keychain*`, `SecureEnclave*`, `JWT*` | AES-256-GCM, rate limiting, biometric auth, token validation. |
| **Data Integrity** | `DataService*`, `Migration*`, `DataTransformation*` | In-memory CRUD, schema migrations, edge cases (nil self). |
| **Domain Logic** | `ReminderService*`, `LocationService*`, `Plant*` | Weather-aware reminders, hardiness zones, diagnostics. |
| **System Services** | `BackgroundTask*`, `Cache*`, `Notification*`, `RateLimiter*` | Lifecycle management, caching strategies, local notifications. |
| **Performance** | `Performance*` | Memory tracking, threshold validation, benchmarks. |

## TEST SUITE ORGANIZATION
With 50+ files, the suite follows a strict naming convention to distinguish test types:
- `*Tests.swift`: Standard unit tests for a single service.
- `*IntegrationTests.swift`: Tests involving multiple services (e.g., Keychain + Audit).
- `*SecurityTests.swift`: Focused specifically on security boundaries and attack vectors.
- `*CoverageTests.swift`: Exhaustive branch testing for complex logic.
- `*ExtendedTests.swift`: Edge cases and large data set validation.

## CONVENTIONS
- **Data Isolation**: Use `DataService.makeForTesting()` (defined in `TestConfiguration.swift`). This ensures an in-memory `ModelContainer` and prevents CloudKit entitlement crashes by nullifying the container.
- **Mocking Strategy**:
    - **CloudKit**: Mock all `CKContainer` interactions. Use `CloudSyncServiceContractTests` as the reference for mock behavior.
    - **External APIs**: Location, Weather, and Notifications must use protocol-based mocks from `TestUtilities`.
- **Security Rigor**: Beyond basic validation, tests must simulate active attack vectors (e.g., token replay, brute-force rate limit tripping, keychain tampering).
- **Async Testing**: Prefer Swift 6 `async/await` over legacy `XCTestExpectation`.
- **Exhaustive Coverage**: Services with complex logic (e.g., `ReminderService`) utilize `*CoverageTests.swift` for 100% branch coverage.

## ANTI-PATTERNS
- **Disk Persistence**: NEVER allow tests to write to the real app sandbox or documents directory.
- **Network Side-Effects**: DO NOT trigger real network requests; use `URLProtocol` or service mocks.
- **Entitlement Reliance**: Avoid tests that fail without specific provisioning profiles (CloudKit, Push).
- **Shared State Leakage**: Do not rely on `UserDefaults.standard` or shared singletons without resetting in `tearDown()`.
