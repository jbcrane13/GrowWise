// TestConfiguration.swift
// Shared test utilities for GrowWiseServicesTests.
//
// The primary DataService factory for tests is `DataService.makeForTesting()`, which
// creates an in-memory ModelContainer with the full model schema and sets
// `cloudContainer = nil` — avoiding the `CKContainer.default()` crash that occurs
// when tests run without a CloudKit entitlement.

import Foundation
import Testing

// MARK: - Test Tags

extension Tag {
    /// Integration / contract tests that verify external service boundaries.
    @Tag static var integration: Self
}

// This file is intentionally minimal. Add shared helpers here as the test suite grows.
