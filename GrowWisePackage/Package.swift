// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GrowWiseFeature",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
        .package(
            url: "https://github.com/getsentry/sentry-cocoa",
            from: "9.6.0"
        ),
        .package(
            url: "https://github.com/amplitude/Amplitude-Swift",
            from: "1.10.0"
        ),
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
            dependencies: [
                "GrowWiseModels",
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "AmplitudeSwift", package: "Amplitude-Swift"),
            ],
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
                "DataServiceNilSelfTests.swift",
                "DataServiceStorageConfigurationTests.swift",
                "DataServiceTests.swift",
                "DataTransformationServiceTests.swift",
                "NotificationServiceTests.swift",
                "ValidationServiceTests.swift",
            ]
        ),
    ]
)
