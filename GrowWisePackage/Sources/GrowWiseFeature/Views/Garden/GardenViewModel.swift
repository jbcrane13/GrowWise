import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - PlantGroup

/// A grouping of plants by their garden location string.
/// Since the data model has no GardenBed SwiftData entity, plants are grouped
/// by Plant.gardenLocation (a free-text field). Plants with nil/empty
/// gardenLocation fall into the "Ungrouped" group (locationKey == nil).
public struct PlantGroup: Identifiable {
    public let id: String
    /// The raw gardenLocation string, or nil for ungrouped plants.
    public let locationKey: String?
    /// Display name shown in the UI section header.
    public var displayName: String {
        locationKey ?? "Ungrouped"
    }

    public var plants: [Plant]
}

// MARK: - GardenViewModel

/// Data layer for the Garden tab grouped plant list (Task 6 hero screen).
///
/// Responsibilities:
/// - Load all gardens via DataService
/// - Default-select the first garden
/// - Group the selected garden's plants by gardenLocation
/// - Expose search-filtered groups for the list view
/// - Surface aggregate counts for the hero header (total plants, alert count)
@MainActor
@Observable
public final class GardenViewModel {
    // MARK: - Exposed State

    /// All gardens the user owns.
    public var gardens: [Garden] = []

    /// The currently selected garden; nil means "show all gardens".
    public var selectedGarden: Garden?

    /// Plants grouped by gardenLocation for the selected garden.
    public var groupedPlants: [PlantGroup] = []

    /// Live search text — drives `filteredGroups`.
    public var searchText: String = ""

    /// True while the initial load is in progress.
    public var isLoading: Bool = false

    /// Non-nil when a load error occurs.
    public var error: Error?

    // MARK: - Computed Properties

    /// Groups filtered by `searchText`. Empty groups are dropped.
    public var filteredGroups: [PlantGroup] {
        guard !searchText.isEmpty else { return groupedPlants }
        let query = searchText.lowercased()
        return groupedPlants.compactMap { group in
            let matching = group.plants.filter { plant in
                (plant.name ?? "").lowercased().contains(query) ||
                    (plant.scientificName ?? "").lowercased().contains(query) ||
                    (plant.notes ?? "").lowercased().contains(query)
            }
            guard !matching.isEmpty else { return nil }
            return PlantGroup(id: group.id, locationKey: group.locationKey, plants: matching)
        }
    }

    /// Total number of plants in the current grouping (before search filter).
    public var totalPlantCount: Int {
        groupedPlants.reduce(0) { $0 + $1.plants.count }
    }

    /// Plants with at least one overdue, enabled reminder.
    /// Used by the hero header alert badge.
    public var alertCount: Int {
        let now = Date()
        return groupedPlants
            .flatMap(\.plants)
            .count(where: { plant in
                (plant.reminders ?? []).contains { reminder in
                    reminder.isEnabled && reminder.nextDueDate < now
                }
            })
    }

    // MARK: - Private State

    private var allPlants: [Plant] = []

    // MARK: - Public API

    /// Initial load: fetch all gardens and plants, then group.
    public func load(dataService: DataService) async {
        isLoading = true
        error = nil

        do {
            gardens = try dataService.gardens.fetchAll()
        } catch {
            self.error = error
            gardens = []
        }

        do {
            allPlants = try dataService.plants.fetchAll()
        } catch {
            self.error = error
            allPlants = []
        }

        // Auto-select the first garden if none is selected yet.
        if selectedGarden == nil {
            selectedGarden = gardens.first
        }

        rebuildGroups()
        isLoading = false
    }

    /// Switch the active garden and rebuild the grouped list.
    public func selectGarden(_ garden: Garden?, dataService: DataService) async {
        selectedGarden = garden
        // Reload plants in case data changed since last load.
        do {
            allPlants = try dataService.plants.fetchAll()
        } catch {
            self.error = error
        }
        rebuildGroups()
    }

    // MARK: - Private Helpers

    /// Build `groupedPlants` from `allPlants` filtered to `selectedGarden`.
    private func rebuildGroups() {
        // Filter to the selected garden (nil = all gardens combined).
        let plants: [Plant] = if let selectedGarden {
            allPlants.filter { $0.garden?.id == selectedGarden.id }
        } else {
            allPlants
        }

        // Group by gardenLocation (nil/empty → ungrouped).
        var locationMap: [String: [Plant]] = [:]
        var ungrouped: [Plant] = []

        for plant in plants {
            let loc = plant.gardenLocation?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let loc, !loc.isEmpty {
                locationMap[loc, default: []].append(plant)
            } else {
                ungrouped.append(plant)
            }
        }

        // Build ordered groups: named locations first (sorted), then ungrouped.
        var groups: [PlantGroup] = locationMap.keys.sorted().map { key in
            PlantGroup(
                id: key,
                locationKey: key,
                plants: locationMap[key]?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
            )
        }

        if !ungrouped.isEmpty {
            let sorted = ungrouped.sorted { ($0.name ?? "") < ($1.name ?? "") }
            groups.append(PlantGroup(id: "__ungrouped__", locationKey: nil, plants: sorted))
        }

        groupedPlants = groups
    }
}
