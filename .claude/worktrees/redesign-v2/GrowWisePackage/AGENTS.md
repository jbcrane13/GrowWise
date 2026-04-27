# GrowWisePackage - Agent Instructions

## Overview

This is the core Swift Package containing all app logic, organized into 3 library targets with a strict dependency hierarchy:

```
GrowWiseFeature  (SwiftUI views, navigation, user-facing features)
       |
       v
GrowWiseServices (business logic, persistence, security, external integrations)
       |
       v
GrowWiseModels   (SwiftData @Model classes, enums, value types)
```

## Package Configuration

- **Swift Tools Version**: 6.1
- **Platforms**: iOS 17+, macOS 14+
- **No external dependencies** - uses only Apple frameworks
- **Products**: 3 libraries (`GrowWiseFeature`, `GrowWiseModels`, `GrowWiseServices`)

## Target Details

### GrowWiseModels (no dependencies)
Pure data layer. Contains `@Model` classes for SwiftData persistence and supporting enums/structs. All model properties are optional or have defaults for CloudKit compatibility. See `Sources/GrowWiseModels/AGENTS.md`.

### GrowWiseServices (depends on GrowWiseModels)
Service layer with `@Observable` classes injected via SwiftUI `@Environment`. Covers data access, security, notifications, location, caching, and performance monitoring. See `Sources/GrowWiseServices/AGENTS.md`.

### GrowWiseFeature (depends on GrowWiseModels + GrowWiseServices)
SwiftUI views composing the user interface. Tab-based navigation with Home, Garden, Plant Guide, Journal, and Tutorials. See `Sources/GrowWiseFeature/AGENTS.md`.

## Testing

3 test targets mirror the source targets:

```bash
swift test                                    # Run all tests
swift test --filter GrowWiseModelsTests       # Model tests only
swift test --filter GrowWiseServicesTests     # Service tests (security-heavy)
swift test --filter GrowWiseFeatureTests      # Feature tests
```

See `Tests/AGENTS.md` for test conventions.

## Conventions

- **Adding a new model**: Add to `GrowWiseModels`, make properties optional for CloudKit, register in `DataService`'s Schema array, add CloudKit record type in `CloudKitSchema.swift`.
- **Adding a new service**: Add to `GrowWiseServices`, use `@Observable` + `@MainActor` if UI-bound, inject via `@Environment` in views.
- **Adding a new view**: Add to `GrowWiseFeature/Views/`, access services via `@Environment(ServiceType.self)`.
- **Import rules**: Models target imports only `Foundation` and `SwiftData`. Services imports Models. Feature imports both.
