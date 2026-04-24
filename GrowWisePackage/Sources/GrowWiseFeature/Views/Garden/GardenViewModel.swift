import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - PlantGroup

/// A grouping of plants by their GardenBed.
/// bed == nil means "Unassigned" (plants with no container assigned).
public struct PlantGroup: Identifiable {
    public let id: String
    /// The GardenBed this group represents, or nil for unassigned plants.
    public let bed: GardenBed?
    public var plants: [Plant]

    public var displayName: String {
        bed?.name ?? "Unassigned"
    }

    public var bedType: BedType? {
        bed?.bedType
    }

    public var iconName: String {
        bed?.bedType?.iconName ?? "tray"
    }
}

// MARK: - GardenSummary

/// Lightweight summary for each garden shown on the dashboard cards.
public struct GardenSummary: Identifiable {
    public let id: UUID
    public let garden: Garden
    public let plantCount: Int
    public let bedCount: Int
    public let alertCount: Int
}

// MARK: - GardenViewModel

/// Data layer for the Garden tab dashboard.
///
/// Responsibilities:
/// - Load all gardens and compute per-garden summaries
/// - Support creating and deleting gardens
/// - Surface aggregate stats for the dashboard header
@MainActor
@Observable
public final class GardenViewModel {
    // MARK: - Exposed State

    /// All gardens the user owns.
    public var gardens: [Garden] = []

    /// The currently selected garden; nil means "show all gardens".
    public var selectedGarden: Garden?

    /// Plants grouped by GardenBed for the selected garden.
    public var groupedPlants: [PlantGroup] = []

    /// Live search text — drives `filteredGroups`.
    public var searchText: String = ""

    /// True while the initial load is in progress.
    public var isLoading: Bool = false

    /// Non-nil when a load error occurs.
    public var error: Error?

    /// Per-garden summaries for dashboard cards.
    public var gardenSummaries: [GardenSummary] = []

    /// Display name of the current user, populated on load.
    public var userName: String = ""

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
            return PlantGroup(id: group.id, bed: group.bed, plants: matching)
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

    /// Plants currently in the flowering stage.
    /// Used by the v2 Garden summary strip.
    public var bloomingCount: Int {
        groupedPlants
            .flatMap(\.plants)
            .count(where: { ($0.growthStage ?? .seedling) == .flowering })
    }

    /// Returns `groupedPlants` filtered by the given `GardenFilter`.
    /// Empty groups are dropped.
    public func filtered(by filter: GardenFilter) -> [PlantGroup] {
        let base = groupedPlants
        switch filter {
        case .all:
            return base

        case .needsCare:
            let now = Date()
            return base.compactMap { group in
                let matching = group.plants.filter { plant in
                    (plant.reminders ?? []).contains { $0.isEnabled && $0.nextDueDate < now }
                }
                return matching.isEmpty ? nil : PlantGroup(id: group.id, bed: group.bed, plants: matching)
            }

        case .blooming:
            return base.compactMap { group in
                let matching = group.plants.filter { ($0.growthStage ?? .seedling) == .flowering }
                return matching.isEmpty ? nil : PlantGroup(id: group.id, bed: group.bed, plants: matching)
            }

        case .edible:
            return base.compactMap { group in
                let matching = group.plants.filter { $0.plantType == .vegetable || $0.plantType == .fruit }
                return matching.isEmpty ? nil : PlantGroup(id: group.id, bed: group.bed, plants: matching)
            }

        case .herbs:
            return base.compactMap { group in
                let matching = group.plants.filter { $0.plantType == .herb }
                return matching.isEmpty ? nil : PlantGroup(id: group.id, bed: group.bed, plants: matching)
            }
        }
    }

    /// Total plants across all gardens.
    public var totalPlantsAllGardens: Int {
        gardenSummaries.reduce(0) { $0 + $1.plantCount }
    }

    /// Total alerts across all gardens.
    public var totalAlertsAllGardens: Int {
        gardenSummaries.reduce(0) { $0 + $1.alertCount }
    }

    // MARK: - Private State

    private var allPlants: [Plant] = []

    // MARK: - Public API

    /// Initial load: fetch all gardens and plants, then build summaries.
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

        userName = dataService.getCurrentUser()?.displayName ?? ""
        rebuildGroups()
        rebuildSummaries()
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

    /// Delete a garden and reload data.
    public func deleteGarden(_ garden: Garden, dataService: DataService) async {
        do {
            try dataService.gardens.delete(garden)
        } catch {
            self.error = error
            return
        }

        // If we deleted the selected garden, clear selection
        if selectedGarden?.id == garden.id {
            selectedGarden = nil
        }

        await load(dataService: dataService)
    }

    // MARK: - Private Helpers

    /// Build `groupedPlants` from `allPlants` filtered to `selectedGarden`.
    private func rebuildGroups() {
        let plants: [Plant] = if let selectedGarden {
            allPlants.filter { $0.garden?.id == selectedGarden.id }
        } else {
            allPlants
        }

        // Group by bed (nil → unassigned).
        var bedMap: [String: (GardenBed, [Plant])] = [:]
        var unassigned: [Plant] = []

        for plant in plants {
            if let bed = plant.bed, let bedID = bed.id?.uuidString {
                if bedMap[bedID] == nil {
                    bedMap[bedID] = (bed, [])
                }
                bedMap[bedID]?.1.append(plant)
            } else {
                unassigned.append(plant)
            }
        }

        // Sort beds by name, then append unassigned.
        var groups: [PlantGroup] = bedMap.values
            .sorted { ($0.0.name ?? "") < ($1.0.name ?? "") }
            .map { bed, bedPlants in
                PlantGroup(
                    id: bed.id?.uuidString ?? UUID().uuidString,
                    bed: bed,
                    plants: bedPlants.sorted { ($0.name ?? "") < ($1.name ?? "") }
                )
            }

        if !unassigned.isEmpty {
            groups.append(PlantGroup(
                id: "__unassigned__",
                bed: nil,
                plants: unassigned.sorted { ($0.name ?? "") < ($1.name ?? "") }
            ))
        }

        groupedPlants = groups
    }

    /// Build per-garden summaries for dashboard cards.
    private func rebuildSummaries() {
        let now = Date()
        gardenSummaries = gardens.map { garden in
            let gardenPlants = allPlants.filter { $0.garden?.id == garden.id }
            let alerts = gardenPlants.count { plant in
                (plant.reminders ?? []).contains { $0.isEnabled && $0.nextDueDate < now }
            }
            return GardenSummary(
                id: garden.id ?? UUID(),
                garden: garden,
                plantCount: gardenPlants.count,
                bedCount: (garden.beds ?? []).count,
                alertCount: alerts
            )
        }
    }
}
