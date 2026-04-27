---
name: run-tests
description: Run GrowWise tests. Always use swift test on the GrowWisePackage — never xcodebuild test without -skip-testing:GrowWiseUITests (causes 10+ crash dialogs every 20 seconds).
---

# Run Tests — GrowWise

## Standard test run (safe on any machine)

```bash
cd ~/Projects/GrowWise
swift test --package-path GrowWisePackage
```

Baseline: **663 tests, 0 failures** (as of 2026-02-28)

## Filter by target

```bash
swift test --package-path GrowWisePackage --filter GrowWiseServicesTests
swift test --package-path GrowWisePackage --filter GrowWiseModelsTests
swift test --package-path GrowWisePackage --filter GrowWiseFeatureTests
```

## Coverage report (use llvm-cov — NOT grep on raw output)

```bash
cd ~/Projects/GrowWise
swift test --package-path GrowWisePackage --enable-code-coverage
xcrun llvm-cov report \
  $(find GrowWisePackage/.build/debug -name '*PackageTests' -type f 2>/dev/null | head -1) \
  -instr-profile $(find GrowWisePackage/.build/debug -name 'default.profdata' 2>/dev/null | head -1) \
  --ignore-filename-regex='.build|Tests' \
  --summary-only
```

Target: **80% on GrowWisePackage** (enforced in CI once infra branch merges).

## ⚠️ NEVER do this

```bash
# DANGEROUS — causes 10+ crash dialogs every 20 seconds
xcodebuild test -scheme GrowWise -destination '...'

# SAFE if you must use xcodebuild
xcodebuild test -scheme GrowWise -destination '...' -skip-testing:GrowWiseUITests
```

## Framework
Swift Testing (`@Test`, `#expect`, `#require`). Never use `XCTAssert*` in new tests.
