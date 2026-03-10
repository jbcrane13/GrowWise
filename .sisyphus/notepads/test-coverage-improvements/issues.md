
## 2026-03-10 — Pre-existing swift test compilation failure

`swift test` fails on mac-mini with:
```
error: 'navigationBarHidden' is unavailable in macOS
  GardenView.swift:59    .navigationBarHidden(true)
  HomeView.swift:109     .navigationBarHidden(true)
```

**Root cause**: `GrowWiseFeature` uses `.navigationBarHidden(true)` which is unavailable on macOS 14+.
When `swift test` runs, it compiles ALL test targets. `GrowWiseFeatureTests` imports `@testable import GrowWiseFeature`,
causing the macOS-unavailable API to fail compilation.

**NOT caused by our changes** — affects all `swift test` invocations regardless.

**Workaround verified**: `swift build --target GrowWiseServicesTests` succeeds (21/21 files including ModelContainerFactoryTests.swift).

**Fix needed (out of scope)**: Replace `.navigationBarHidden(true)` with `.toolbar(.hidden, for: .navigationBar)` in GardenView.swift and HomeView.swift.

## DataTransformationServiceTests.swift is excluded from build

In Package.swift (line 79), `DataTransformationServiceTests.swift` is in the exclude list for GrowWiseServicesTests.
This means changes to that file don't affect compilation. The file requires `KEYCHAIN_TESTS_ENABLED=1` env var to run.
