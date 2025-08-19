// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GrowWiseFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
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
            dependencies: ["GrowWiseModels", "GrowWiseServices"]
        ),
        
        // Data models and SwiftData persistence
        .target(
            name: "GrowWiseModels"
        ),
        
        // Services for external integrations
        .target(
            name: "GrowWiseServices",
            dependencies: ["GrowWiseModels"]
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
            dependencies: ["GrowWiseServices"]
        ),
    ]
)
