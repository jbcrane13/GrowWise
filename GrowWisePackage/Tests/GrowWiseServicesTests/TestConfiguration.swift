/// TestConfiguration.swift
/// Shared test utilities for GrowWiseServicesTests.
///
/// The primary DataService factory for tests is `DataService.makeForTesting()`, which
/// creates an in-memory ModelContainer with the full model schema and sets
/// `cloudContainer = nil` — avoiding the `CKContainer.default()` crash that occurs
/// when tests run without a CloudKit entitlement.

import Foundation

// This file is intentionally minimal. Add shared helpers here as the test suite grows.
