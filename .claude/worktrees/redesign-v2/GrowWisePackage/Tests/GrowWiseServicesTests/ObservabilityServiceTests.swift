import Testing
import Foundation
@testable import GrowWiseServices

// MARK: - ObservabilityService Tests

@Suite("ObservabilityService Tests")
@MainActor
struct ObservabilityServiceTests {

    // Reset before each test to ensure clean state
    init() {
        #if DEBUG
        ObservabilityService.shared.reset()
        #endif
    }

    // MARK: - configure() no-op guards

    @Test("configure() with empty DSN does not initialize service")
    func testConfigureEmptyDSNNoInit() {
        let service = ObservabilityService.shared
        service.configure(dsn: "")
        #expect(service.isInitialized == false)
    }

    @Test("configure() with placeholder DSN does not initialize service")
    func testConfigurePlaceholderDSNNoInit() {
        let service = ObservabilityService.shared
        service.configure(dsn: "YOUR_SENTRY_DSN")
        #expect(service.isInitialized == false)
    }

    @Test("configure() is idempotent — repeated calls with invalid DSN stay uninitialized")
    func testConfigureIdempotentInvalidDSN() {
        let service = ObservabilityService.shared
        service.configure(dsn: "")
        service.configure(dsn: "")
        #expect(service.isInitialized == false)
    }

    @Test("configure() with nil DSN and no env var does not initialize service")
    func testConfigureNilDSNWithoutEnvVar() {
        // If SENTRY_DSN is set in the test environment, this test is skipped
        // because the service will initialize with the env var value.
        let envDSN = ProcessInfo.processInfo.environment["SENTRY_DSN"]
        guard envDSN == nil || envDSN!.isEmpty else {
            // SENTRY_DSN is set, so this test would pass trivially
            // Skip by passing with a comment
            print("Skipping: SENTRY_DSN is set in environment")
            return
        }
        let service = ObservabilityService.shared
        service.configure(dsn: nil)
        #expect(service.isInitialized == false)
    }

    // MARK: - BreadcrumbCategory rawValues

    @Test("BreadcrumbCategory.navigation rawValue is 'navigation'")
    func testBreadcrumbCategoryNavigationRawValue() {
        #expect(ObservabilityService.BreadcrumbCategory.navigation.rawValue == "navigation")
    }

    @Test("BreadcrumbCategory.userAction rawValue is 'user_action'")
    func testBreadcrumbCategoryUserActionRawValue() {
        #expect(ObservabilityService.BreadcrumbCategory.userAction.rawValue == "user_action")
    }

    @Test("BreadcrumbCategory.dataOperation rawValue is 'data_operation'")
    func testBreadcrumbCategoryDataOperationRawValue() {
        #expect(ObservabilityService.BreadcrumbCategory.dataOperation.rawValue == "data_operation")
    }

    @Test("BreadcrumbCategory.authentication rawValue is 'authentication'")
    func testBreadcrumbCategoryAuthenticationRawValue() {
        #expect(ObservabilityService.BreadcrumbCategory.authentication.rawValue == "authentication")
    }

    @Test("BreadcrumbCategory.sync rawValue is 'sync'")
    func testBreadcrumbCategorySyncRawValue() {
        #expect(ObservabilityService.BreadcrumbCategory.sync.rawValue == "sync")
    }

    // MARK: - bucket() helper via setAppContext

    // `bucket(_:thresholds:)` is private static — tested indirectly through setAppContext.
    // setAppContext calls: bucket(plantCount, thresholds: [0, 5, 20, 50])
    //   plantCount 0   → "0-5"
    //   plantCount 3   → "0-5"
    //   plantCount 5   → "5-20"  (lower boundary of second bucket)
    //   plantCount 19  → "5-20"
    //   plantCount 20  → "20-50" (lower boundary of third bucket)
    //   plantCount 50  → "50-500" (lower boundary of fourth bucket)
    //   plantCount 100 → "50-500"
    // All calls verify no crash. Output is consumed by Sentry scope (not observable in unit tests).

    @Test("setAppContext does not crash with plantCount = 0 (bucket: 0–5)")
    func testSetAppContextBucket0() {
        ObservabilityService.shared.setAppContext(plantCount: 0, gardenCount: 0, hasActiveReminders: false)
    }

    @Test("setAppContext does not crash with plantCount = 3 (bucket: 0–5, mid-range)")
    func testSetAppContextBucket3() {
        ObservabilityService.shared.setAppContext(plantCount: 3, gardenCount: 1, hasActiveReminders: false)
    }

    @Test("setAppContext does not crash with plantCount = 5 (bucket boundary: 5–20)")
    func testSetAppContextBucketBoundary5() {
        ObservabilityService.shared.setAppContext(plantCount: 5, gardenCount: 1, hasActiveReminders: true)
    }

    @Test("setAppContext does not crash with plantCount = 19 (bucket: 5–20, upper edge)")
    func testSetAppContextBucket19() {
        ObservabilityService.shared.setAppContext(plantCount: 19, gardenCount: 2, hasActiveReminders: false)
    }

    @Test("setAppContext does not crash with plantCount = 20 (bucket boundary: 20–50)")
    func testSetAppContextBucketBoundary20() {
        ObservabilityService.shared.setAppContext(plantCount: 20, gardenCount: 2, hasActiveReminders: true)
    }

    @Test("setAppContext does not crash with plantCount = 50 (bucket boundary: 50–500)")
    func testSetAppContextBucketBoundary50() {
        ObservabilityService.shared.setAppContext(plantCount: 50, gardenCount: 3, hasActiveReminders: false)
    }

    @Test("setAppContext does not crash with large plantCount (bucket: 50–500)")
    func testSetAppContextBucketLarge() {
        ObservabilityService.shared.setAppContext(plantCount: 200, gardenCount: 5, hasActiveReminders: true)
    }

    // MARK: - Capture methods when uninitialized

    // The ObservabilityService calls SentrySDK methods directly without checking
    // isInitialized. Sentry is designed to no-op gracefully when not configured,
    // so these calls should not crash.

    @Test("capture(error:) does not crash when service is uninitialized")
    func testCaptureErrorNoopWhenUninitialized() {
        struct StubError: Error {}
        ObservabilityService.shared.capture(error: StubError())
    }

    @Test("capture(error:context:) with context does not crash when service is uninitialized")
    func testCaptureErrorWithContextNoopWhenUninitialized() {
        struct StubError: Error {}
        ObservabilityService.shared.capture(
            error: StubError(),
            context: ["operation": "plant_save", "garden_id": "abc123"]
        )
    }

    @Test("capture(message:) does not crash when service is uninitialized")
    func testCaptureMessageNoopWhenUninitialized() {
        ObservabilityService.shared.capture(message: "Validation failed silently")
    }

    @Test("capture(message:context:) with context does not crash when service is uninitialized")
    func testCaptureMessageWithContextNoopWhenUninitialized() {
        ObservabilityService.shared.capture(
            message: "Unexpected nil model context",
            context: ["screen": "garden", "action": "add_plant"]
        )
    }

    @Test("breadcrumb(_:category:) does not crash when service is uninitialized")
    func testBreadcrumbNoopWhenUninitialized() {
        ObservabilityService.shared.breadcrumb("User tapped Add Plant", category: .userAction)
    }

    @Test("breadcrumb(_:category:data:) with data does not crash when service is uninitialized")
    func testBreadcrumbWithDataNoopWhenUninitialized() {
        ObservabilityService.shared.breadcrumb(
            "Navigated to Garden tab",
            category: .navigation,
            data: ["from_tab": "home", "to_tab": "garden"]
        )
    }

    @Test("breadcrumb with each category does not crash when service is uninitialized")
    func testBreadcrumbAllCategoriesNoopWhenUninitialized() {
        let service = ObservabilityService.shared
        service.breadcrumb("Nav event", category: .navigation)
        service.breadcrumb("Action event", category: .userAction)
        service.breadcrumb("Data event", category: .dataOperation)
        service.breadcrumb("Auth event", category: .authentication)
        service.breadcrumb("Sync event", category: .sync)
    }
}
