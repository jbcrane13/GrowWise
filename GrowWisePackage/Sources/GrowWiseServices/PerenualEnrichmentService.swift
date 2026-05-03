import Foundation
import GrowWiseModels
import os

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

private let logger = Logger(subsystem: "com.growwise", category: "PerenualEnrichment")

/// Enriches local Plant objects with Perenual API data.
/// Caches results in memory keyed by scientific name to avoid redundant lookups.
@MainActor
@Observable
public final class PerenualEnrichmentService {
    private let api: PerenualAPIService

    /// In-memory cache: scientific name → detail (nil = looked up but not found)
    private var cache: [String: PerenualSpeciesDetail?] = [:]

    /// Currently in-flight lookups (prevents duplicate requests)
    private var inflight: Set<String> = []

    public init(api: PerenualAPIService) {
        self.api = api
    }

    /// Fetch enrichment data for a plant. Returns cached result instantly if available.
    /// Fires a background lookup if not cached yet.
    public func enrichment(for plant: Plant) -> PerenualSpeciesDetail? {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return nil }
        let key = sciName.lowercased()

        if let cached = cache[key] {
            return cached
        }

        // Trigger background fetch (only once per key)
        if !inflight.contains(key) {
            inflight.insert(key)
            Task { @MainActor in
                await fetchAndCache(scientificName: sciName, key: key)
            }
        }

        return nil
    }

    /// Synchronous check if enrichment is available (already cached)
    public func hasCachedEnrichment(for plant: Plant) -> Bool {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return false }
        return cache[sciName.lowercased()] != nil
    }

    /// Force a fresh lookup (bypasses cache)
    public func refresh(for plant: Plant) async -> PerenualSpeciesDetail? {
        guard let sciName = plant.scientificName, !sciName.isEmpty else { return nil }
        let key = sciName.lowercased()
        return await fetchAndCache(scientificName: sciName, key: key)
    }

    // MARK: - Private

    @discardableResult
    private func fetchAndCache(scientificName: String, key: String) async -> PerenualSpeciesDetail? {
        defer { inflight.remove(key) }

        do {
            // Search by scientific name
            let results = try await api.fetchSpeciesList(query: scientificName, page: 1)

            // Find best match — exact scientific name match preferred
            let normalizedQuery = scientificName.lowercased()
            let bestMatch = results.data.first { species in
                species.scientificName.contains { $0.lowercased() == normalizedQuery }
            } ?? results.data.first { species in
                species.scientificName.contains { $0.lowercased().contains(normalizedQuery) }
            } ?? results.data.first // Fallback to first result

            guard let match = bestMatch else {
                logger.info("[Enrich] No match for: \(scientificName, privacy: .public)")
                cache[key] = .some(nil)
                return nil
            }

            // Fetch full details
            let detail = try await api.fetchSpeciesDetail(id: match.id)
            cache[key] = detail
            logger.debug("[Enrich] Cached: \(scientificName, privacy: .public) → id=\(match.id)")
            return detail
        } catch {
            logger.error("[Enrich] Failed for \(scientificName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            cache[key] = .some(nil) // Cache the failure to avoid retrying
            return nil
        }
    }
}

// swiftlint:enable line_length
