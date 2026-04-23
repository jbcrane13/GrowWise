
## 2026-03-10 — ModelContainerFactoryTests approach

Used Swift Testing (`@Test`, `#expect`) to match the project's modern testing standard (per AGENTS.md).
Used `@MainActor` on tests that create `ModelContext` since `ModelContext` must be used on MainActor.
Tests call `ModelContainerFactory.makeForTesting()` which is `nonisolated` — safe to call from any context.
Two containers created independently verify isolation (insert into A, verify B is empty).
`sharedSchema` test uses `@MainActor` because `sharedSchema` is `@MainActor`-isolated in `ModelContainerFactory`.

## 2026-03-10 — DataTransformationServiceTests async fix

Used `withTaskGroup(of: Void.self)` to replace `DispatchQueue.concurrentPerform`. 
`withTaskGroup` child tasks still capture `self` but since `XCTestCase` inherits NSObject (ObjC)
and the file is excluded from build, Swift 6 sendability checks don't surface as build errors here.
`wait(for:timeout:)` → `await fulfillment(of:timeout:)` (XCTest async API).
