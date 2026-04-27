# GrowWise Tests - Agent Instructions

## Test Targets

### GrowWiseModelsTests
- `PlantTests.swift` - Plant model creation, enum values
- `UserTests.swift` - User model creation, defaults

### GrowWiseServicesTests (most extensive)

**Security tests** (high coverage):
- `EncryptionServiceTests.swift` - AES-256-GCM encrypt/decrypt, key rotation
- `KeychainStorageServiceTests.swift` - Keychain CRUD operations
- `KeychainSecurityTests.swift` - Keychain security validation
- `KeychainManagerRateLimitingTests.swift` - Rate limiting on keychain access
- `KeychainIntegrationTests.swift` - End-to-end keychain flows
- `KeychainAuditIntegrationTests.swift` - Audit logging for keychain ops
- `KeyRotationManagerTests.swift` - Key rotation policy enforcement
- `SecureEnclaveKeyManagerTests.swift` - Secure Enclave operations
- `SecureEnclaveSecurityTests.swift` - SE security validation
- `JWTSecurityTests.swift` - JWT token security
- `JWTValidatorTests.swift` - JWT claims parsing
- `JWTValidationIntegrationTests.swift` - End-to-end JWT flows
- `SecurityTestSuite.swift` - Comprehensive security test aggregation
- `AuditLoggerTests.swift` - Audit logging
- `AuditSecurityTests.swift` - Audit trail integrity
- `BiometricAuthenticationManagerTests.swift` - Biometric auth flows
- `RateLimiterTests.swift` - Rate limiting logic
- `RateLimitingSecurityTests.swift` - Rate limit security
- `MigrationSecurityTests.swift` - Migration security verification
- `MigrationIntegrityServiceTests.swift` - Data integrity during migration
- `LegacyEncryptionMigrationServiceTests.swift` - Legacy format migration
- `TokenManagementServiceTests.swift` - Token lifecycle

**Data tests**:
- `DataServiceTests.swift` - CRUD operations, caching, pagination
- `DataServiceNilSelfTests.swift` - Nil/edge case handling
- `DataServiceStorageConfigurationTests.swift` - Storage config validation
- `DataTransformationServiceTests.swift` - Data transformations
- `ValidationServiceTests.swift` - Input validation

**Other service tests**:
- `NotificationServiceTests.swift` - Notification scheduling
- `PerformanceTests.swift` - Performance benchmarks
- `PerformanceMonitorMemoryTests.swift` - Memory tracking

### GrowWiseFeatureTests
- `GrowWiseFeatureTests.swift` - Feature integration tests

## Test Conventions

1. **Test naming**: `test_methodName_condition_expectedResult()` or `testMethodName()`
2. **No external test dependencies** - use XCTest only
3. **Mock services**: Use `tests/TestUtilities/MockServices.swift` and `TestFixtures.swift`
4. **Security tests**: Cover both positive (valid input) and negative (attack vectors) cases
5. **DataService tests**: Use in-memory `ModelConfiguration` to avoid disk I/O
6. **Async tests**: Use `async` test methods with `await`

## Running Tests

```bash
cd GrowWisePackage
swift test                                          # All tests
swift test --filter GrowWiseServicesTests            # Service tests
swift test --filter GrowWiseServicesTests.EncryptionServiceTests  # Specific suite
```

Or via Xcode: Product -> Test (Cmd+U)
