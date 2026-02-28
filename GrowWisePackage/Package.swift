// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GrowWiseFeature",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GrowWiseFeature",
            targets: ["GrowWiseFeature"]
        ),
        .library(
            name: "GrowWiseModels",
            targets: ["GrowWiseModels"]
        ),
        .library(
            name: "GrowWiseServices",
            targets: ["GrowWiseServices"]
        ),
    ],
    dependencies: [
        // Add dependencies if needed
    ],
    targets: [
        // Core feature module - main app views and navigation
        .target(
            name: "GrowWiseFeature",
            dependencies: ["GrowWiseModels", "GrowWiseServices"],
            exclude: ["AGENTS.md"]
        ),
        
        // Data models and SwiftData persistence
        .target(
            name: "GrowWiseModels",
            exclude: ["AGENTS.md"]
        ),
        
        // Services for external integrations
        .target(
            name: "GrowWiseServices",
            dependencies: ["GrowWiseModels"],
            exclude: ["AGENTS.md"],
            resources: [.process("Resources")]
        ),
        
        // Tests
        .testTarget(
            name: "GrowWiseFeatureTests",
            dependencies: ["GrowWiseFeature"]
        ),
        .testTarget(
            name: "GrowWiseModelsTests",
            dependencies: ["GrowWiseModels"]
        ),
        .testTarget(
            name: "GrowWiseServicesTests",
            dependencies: ["GrowWiseServices"],
            exclude: [
                "AGENTS.md",
                "AuditLoggerTests.swift",
                "AuditSecurityTests.swift",
                "BiometricAuthenticationManagerTests.swift",
                "DataServiceNilSelfTests.swift",
                "DataServiceStorageConfigurationTests.swift",
                "DataServiceTests.swift",
                "DataTransformationServiceTests.swift",
                "EncryptionServiceTests.swift",
                "JWTSecurityTests.swift",
                "JWTValidationIntegrationTests.swift",
                "JWTValidatorTests.swift",
                "KeychainAuditIntegrationTests.swift",
                "KeychainIntegrationTests.swift",
                "KeychainManagerRateLimitingTests.swift",
                "KeychainSecurityTests.swift",
                "KeychainStorageServiceTests.swift",
                "KeyRotationManagerTests.swift",
                "LegacyEncryptionMigrationServiceTests.swift",
                "MigrationIntegrityServiceTests.swift",
                "MigrationSecurityTests.swift",
                "NotificationServiceTests.swift",
                "PerformanceMonitorMemoryTests.swift",
                "PerformanceTests.swift",
                "RateLimiterTests.swift",
                "RateLimitingSecurityTests.swift",
                "SecureEnclaveKeyManagerTests.swift",
                "SecureEnclaveSecurityTests.swift",
                "SecurityTestSuite.swift",
                "TokenManagementServiceTests.swift",
                "ValidationServiceTests.swift"
            ]
        ),
    ]
)
