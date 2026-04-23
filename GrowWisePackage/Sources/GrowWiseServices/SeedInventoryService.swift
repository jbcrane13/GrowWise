import Foundation
import GrowWiseModels
import os

// MARK: - SeedInventoryService

@MainActor
@Observable
public final class SeedInventoryService {
    private let logger = Logger(subsystem: "com.growwise.gardening", category: "SeedInventory")

    public init() {}

    // MARK: - Sun Level Ordering

    /// Numeric sun level for SunExposure (higher = more sun).
    /// artificial is treated as equivalent to fullSun.
    private func sunLevel(for exposure: SunExposure) -> Int {
        switch exposure {
        case .fullShade: 0
        case .partialShade: 1
        case .partialSun: 2
        case .fullSun, .artificial: 3
        }
    }

    /// Convert SunlightLevel to SunExposure for comparison.
    private func sunExposure(from sunlight: SunlightLevel) -> SunExposure {
        switch sunlight {
        case .fullSun: .fullSun
        case .partialSun: .partialSun
        case .partialShade: .partialShade
        case .fullShade: .fullShade
        }
    }

    // MARK: - Compatible Seeds

    /// Filter unassigned seeds by bed's parent garden sun exposure and companion planting rules.
    ///
    /// Sun compatibility: the garden must provide at least as much sun as the seed needs.
    /// Incompatible plants: seeds listing plants already in the bed are excluded.
    public func compatibleSeeds(
        for bed: GardenBed,
        unassignedSeeds: [Seed],
        plantDatabase: [Plant]
    ) -> [Seed] {
        let gardenSun = bed.garden?.sunExposure
        let existingPlantNames = Set((bed.plants ?? []).compactMap { $0.name?.lowercased() })

        return unassignedSeeds.filter { seed in
            // Sun compatibility check
            if let gardenSun {
                let gardenLevel = sunLevel(for: gardenSun)

                // Resolve the seed's sun requirement
                let seedSun: SunExposure? = seed.sunRequirement ?? {
                    guard let dbID = seed.plantDatabaseID,
                          let linked = plantDatabase.first(where: { $0.id?.uuidString == dbID }),
                          let sunlight = linked.sunlightRequirement
                    else { return nil }
                    return sunExposure(from: sunlight)
                }()

                if let seedSun {
                    let seedLevel = sunLevel(for: seedSun)
                    if gardenLevel < seedLevel {
                        return false
                    }
                }
            }

            // Incompatible plants check
            let incompatible = (seed.incompatiblePlants ?? []).map { $0.lowercased() }
            for name in incompatible {
                if existingPlantNames.contains(name) {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Ready to Plant

    /// Return seeds that are within their ideal indoor start window for the given zone.
    ///
    /// Uses estimated last frost date by USDA zone and the seed's `indoorStartWeeks` to calculate
    /// the ideal start date. Returns seeds where `currentDate` is within 1 week before/after that date.
    public func readyToPlant(seeds: [Seed], zone: String, currentDate: Date) -> [Seed] {
        guard let lastFrost = estimatedLastFrost(for: zone) else {
            logger.warning("Could not determine last frost date for zone: \(zone, privacy: .public)")
            return []
        }

        let calendar = Calendar.current

        return seeds.filter { seed in
            guard let indoorWeeks = seed.indoorStartWeeks, indoorWeeks > 0 else {
                return false
            }

            guard let idealStart = calendar.date(byAdding: .weekOfYear, value: -indoorWeeks, to: lastFrost) else {
                return false
            }

            guard let windowStart = calendar.date(byAdding: .weekOfYear, value: -1, to: idealStart),
                  let windowEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: idealStart)
            else {
                return false
            }

            return currentDate >= windowStart && currentDate <= windowEnd
        }
    }

    /// Estimated last frost date by USDA hardiness zone prefix.
    private func estimatedLastFrost(for zone: String) -> Date? {
        // Parse numeric prefix — zone may have a/b suffix like "6a"
        let digits = zone.prefix(while: { $0.isNumber })
        guard let zoneNumber = Int(digits) else { return nil }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        let month: Int
        let day: Int

        switch zoneNumber {
        case 1 ... 3:
            month = 6
            day = 1

        case 4:
            month = 5
            day = 15

        case 5:
            month = 5
            day = 1

        case 6:
            month = 4
            day = 15

        case 7:
            month = 4
            day = 1

        case 8:
            month = 3
            day = 15

        case 9:
            month = 2
            day = 15

        case 10 ... 13:
            month = 1
            day = 31

        default:
            return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    // MARK: - Suggest Plant Database Link

    /// Fuzzy match a seed's variety name against the plant database.
    ///
    /// Tries exact case-insensitive match first, then substring, then word-level overlap.
    /// Returns the matched plant's UUID string, or nil if no match found.
    public func suggestPlantDatabaseLink(for seed: Seed, plantDatabase: [Plant]) -> String? {
        guard let varietyName = seed.varietyName, !varietyName.isEmpty else {
            return nil
        }

        let lowered = varietyName.lowercased()

        // Exact match
        if let match = plantDatabase.first(where: { $0.name?.lowercased() == lowered }) {
            return match.id?.uuidString
        }

        // Substring match — seed name contains plant name or vice versa
        if let match = plantDatabase.first(where: {
            guard let name = $0.name?.lowercased() else { return false }
            return lowered.contains(name) || name.contains(lowered)
        }) {
            return match.id?.uuidString
        }

        // Word-level match — significant words (> 2 chars) overlap
        let seedWords = Set(
            lowered.split(separator: " ")
                .map { String($0) }
                .filter { $0.count > 2 }
        )

        if !seedWords.isEmpty {
            if let match = plantDatabase.first(where: {
                guard let name = $0.name?.lowercased() else { return false }
                let plantWords = Set(
                    name.split(separator: " ")
                        .map { String($0) }
                        .filter { $0.count > 2 }
                )
                return !seedWords.isDisjoint(with: plantWords)
            }) {
                return match.id?.uuidString
            }
        }

        return nil
    }
}
