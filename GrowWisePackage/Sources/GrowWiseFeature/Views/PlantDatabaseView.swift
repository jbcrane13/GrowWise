import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

public struct PlantDatabaseView: View {
    @Environment(DataService.self) private var dataService
    @Environment(PerenualAPIService.self) private var perenualAPI
    @State private var databasePlants: [Plant] = []
    @State private var searchText = ""
    @State private var selectedPlantType: PlantType?
    @State private var selectedDifficulty: DifficultyLevel?
    @State private var selectedSunlight: SunlightLevel?
    @State private var showingFilters = false
    @State private var isLoading = true
    @State private var selectedSortOption: DatabaseSortOption = .name
    @State private var showingPlantDetail: Plant?
    @State private var selectedTab: PlantDatabaseTab = .local

    private enum PlantDatabaseTab { case local, perenual }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source picker — Local (52 plants) vs Perenual (10K+)
                Picker("Source", selection: $selectedTab) {
                    Text("My Library").tag(PlantDatabaseTab.local)
                    Text("Perenual (10K+)").tag(PlantDatabaseTab.perenual)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, 10)

                if selectedTab == .local {
                    // Filter Tags (when active)
                    if hasActiveFilters {
                        activeFiltersSection
                    }
                    // Plant Database Content
                    plantDatabaseContent
                } else {
                    PerenualBrowseView()
                }
            }
            .navigationTitle("Plant Guide")
            .toolbar {
                if selectedTab == .local {
                    ToolbarItemGroup(placement: .primaryAction) {
                        sortMenuButton
                        filterButton
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                DatabaseFiltersSheet(
                    selectedPlantType: $selectedPlantType,
                    selectedDifficulty: $selectedDifficulty,
                    selectedSunlight: $selectedSunlight
                )
            }
            .sheet(item: $showingPlantDetail) { plant in
                PlantDatabaseDetailView(plant: plant)
            }
            .refreshable {
                await loadDatabasePlants()
            }
            // Using .task for automatic cancellation when view disappears
            .task {
                await loadDatabasePlants()
            }
        }
        // Native SwiftUI search bar with built-in debouncing
        .searchable(text: $searchText, prompt: "Search plants...")
    }

    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                if let type = selectedPlantType {
                    FilterTag(title: type.displayName, color: .blue) {
                        selectedPlantType = nil
                    }
                    .accessibilityIdentifier("plant_database_filter_tag_plant_type")
                }

                if let difficulty = selectedDifficulty {
                    FilterTag(title: difficulty.displayName, color: .orange) {
                        selectedDifficulty = nil
                    }
                    .accessibilityIdentifier("plant_database_filter_tag_difficulty")
                }

                if let sunlight = selectedSunlight {
                    FilterTag(title: sunlight.displayName, color: .yellow) {
                        selectedSunlight = nil
                    }
                    .accessibilityIdentifier("plant_database_filter_tag_sunlight")
                }

                Button("Clear All") {
                    clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .accessibilityIdentifier("plant_database_button_clear_all_filters")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var plantDatabaseContent: some View {
        Group {
            if isLoading {
                loadingView
            } else if filteredPlants.isEmpty {
                emptyStateView
            } else {
                plantsListView
            }
        }
    }

    private var plantsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredPlants, id: \.id) { plant in
                    DatabasePlantCardView(plant: plant) {
                        showingPlantDetail = plant
                    }
                    .accessibilityIdentifier("plant_database_card_\(plant.id)")
                }
            }
            .padding()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading plant database...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        Group {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView(
                    "No Plants Found",
                    systemImage: "magnifyingglass.circle",
                    description: Text("Try adjusting your filters to find plants.")
                )
            }
        }
    }

    private var sortMenuButton: some View {
        Menu {
            ForEach(DatabaseSortOption.allCases, id: \.self) { option in
                Button {
                    selectedSortOption = option
                } label: {
                    HStack {
                        Text(option.displayName)
                        if selectedSortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("plant_database_button_sort")
    }

    private var filterButton: some View {
        Button(action: { showingFilters = true }) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundColor(hasActiveFilters ? .blue : .gray)
        }
        .accessibilityIdentifier("plant_database_button_filter")
    }

    private var hasActiveFilters: Bool {
        selectedPlantType != nil || selectedDifficulty != nil || selectedSunlight != nil
    }

    private var filteredPlants: [Plant] {
        var filtered: [Plant]

            // Use DataService.searchPlants for search queries (with caching)
            = if !searchText.isEmpty
        {
            dataService.searchPlants(query: searchText)
        } else {
            // No search query - use all database plants
            databasePlants
        }

        // Layer additional filter criteria on top of search results
        // Filter by plant type
        if let selectedType = selectedPlantType {
            filtered = filtered.filter { $0.plantType == selectedType }
        }

        // Filter by difficulty
        if let selectedDifficulty {
            filtered = filtered.filter { $0.difficultyLevel == selectedDifficulty }
        }

        // Filter by sunlight requirement
        if let selectedSunlight {
            filtered = filtered.filter { $0.sunlightRequirement == selectedSunlight }
        }

        // Sort filtered results
        return sortPlants(filtered)
    }

    private func sortPlants(_ plants: [Plant]) -> [Plant] {
        switch selectedSortOption {
        case .name:
            plants.sorted { ($0.name ?? "") < ($1.name ?? "") }

        case .difficulty:
            plants.sorted {
                if $0.difficultyLevel != $1.difficultyLevel {
                    return ($0.difficultyLevel?.rawValue ?? "") < ($1.difficultyLevel?.rawValue ?? "")
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }

        case .plantType:
            plants.sorted {
                if $0.plantType != $1.plantType {
                    return ($0.plantType?.rawValue ?? "") < ($1.plantType?.rawValue ?? "")
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }

        case .sunlightRequirement:
            plants.sorted {
                if $0.sunlightRequirement != $1.sunlightRequirement {
                    return ($0.sunlightRequirement?.rawValue ?? "") < ($1.sunlightRequirement?.rawValue ?? "")
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        }
    }

    private func clearAllFilters() {
        selectedPlantType = nil
        selectedDifficulty = nil
        selectedSunlight = nil
    }

    @MainActor
    private func loadDatabasePlants() async {
        isLoading = true

        // Load database plants (not user plants)
        databasePlants = dataService.fetchPlantDatabase()

        isLoading = false
    }
}

// MARK: - Supporting Views

struct DatabasePlantCardView: View {
    let plant: Plant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plant.name ?? "Unknown Plant")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let scientificName = plant.scientificName {
                            Text(scientificName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let difficultyLevel = plant.difficultyLevel {
                            DifficultyBadge(level: difficultyLevel)
                        }
                        if let plantType = plant.plantType {
                            PlantTypeBadge(type: plantType)
                        }
                    }
                }

                // Plant requirements
                HStack {
                    RequirementIcon(
                        icon: "sun.max.fill",
                        text: plant.sunlightRequirement != nil ? sunlightShorthand(plant.sunlightRequirement!) : "Unknown",
                        color: .yellow
                    )

                    RequirementIcon(
                        icon: "drop.fill",
                        text: plant.wateringFrequency != nil ? wateringShorthand(plant.wateringFrequency!) : "Unknown",
                        color: .blue
                    )

                    RequirementIcon(
                        icon: "square.grid.3x3.fill",
                        text: plant.spaceRequirement != nil ? spaceShorthand(plant.spaceRequirement!) : "Unknown",
                        color: .green
                    )

                    Spacer()
                }

                // Description preview
                if !(plant.notes?.isEmpty ?? true) {
                    Text(descriptionPreview(plant.notes ?? ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func sunlightShorthand(_ sunlight: SunlightLevel) -> String {
        switch sunlight {
        case .fullSun: "Full Sun"
        case .partialSun: "Part Sun"
        case .partialShade: "Part Shade"
        case .fullShade: "Full Shade"
        }
    }

    private func wateringShorthand(_ watering: WateringFrequency) -> String {
        switch watering {
        case .daily: "Daily"
        case .everyOtherDay: "3-4x/week"
        case .twiceWeekly: "2x/week"
        case .weekly: "Weekly"
        case .biweekly: "Bi-weekly"
        case .monthly: "Monthly"
        case .asNeeded: "As needed"
        }
    }

    private func spaceShorthand(_ space: SpaceRequirement) -> String {
        switch space {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "X-Large"
        }
    }

    private func descriptionPreview(_ notes: String) -> String {
        let lines = notes.components(separatedBy: .newlines)
        if let firstLine = lines.first, !firstLine.isEmpty {
            return firstLine
        }
        return notes
    }
}

struct RequirementIcon: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// Badge declarations moved to PlantCardView.swift to avoid duplicates

struct FilterTag: View {
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DatabaseFiltersSheet: View {
    @Binding var selectedPlantType: PlantType?
    @Binding var selectedDifficulty: DifficultyLevel?
    @Binding var selectedSunlight: SunlightLevel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Plant Type") {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedPlantType != nil {
                            Button("Clear Plant Type") {
                                selectedPlantType = nil
                            }
                            .foregroundColor(.red)
                            .accessibilityIdentifier("database_filters_button_clear_plant_type")
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(PlantType.allCases, id: \.self) { type in
                                FilterChip(
                                    title: type.displayName,
                                    isSelected: selectedPlantType == type
                                ) {
                                    selectedPlantType = selectedPlantType == type ? nil : type
                                }
                            }
                        }
                    }
                }

                Section("Difficulty Level") {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedDifficulty != nil {
                            Button("Clear Difficulty") {
                                selectedDifficulty = nil
                            }
                            .foregroundColor(.red)
                            .accessibilityIdentifier("database_filters_button_clear_difficulty")
                        }

                        VStack(spacing: 8) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                                FilterChip(
                                    title: difficulty.displayName,
                                    isSelected: selectedDifficulty == difficulty
                                ) {
                                    selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                                }
                            }
                        }
                    }
                }

                Section("Sunlight Requirement") {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedSunlight != nil {
                            Button("Clear Sunlight") {
                                selectedSunlight = nil
                            }
                            .foregroundColor(.red)
                            .accessibilityIdentifier("database_filters_button_clear_sunlight")
                        }

                        VStack(spacing: 8) {
                            ForEach(SunlightLevel.allCases, id: \.self) { sunlight in
                                FilterChip(
                                    title: sunlight.displayName,
                                    isSelected: selectedSunlight == sunlight
                                ) {
                                    selectedSunlight = selectedSunlight == sunlight ? nil : sunlight
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Database Filters")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("database_filters_button_done")
                }
            }
        }
    }
}

struct PlantDatabaseDetailView: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @State private var showingAddToGarden = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    plantHeaderSection

                    // Quick Requirements
                    requirementsSection

                    // Description and Care Instructions
                    descriptionSection

                    // Care Details
                    careDetailsSection

                    Spacer(minLength: 100) // Space for floating button
                }
                .padding()
            }
            .navigationTitle(plant.name ?? "Unknown Plant")
            .gwNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("plant_detail_button_close")
                }
            }
            .overlay(alignment: .bottom) {
                addToGardenButton
            }
            .sheet(isPresented: $showingAddToGarden) {
                AddPlantToGardenFromDatabaseSheet(plant: plant)
            }
        }
    }

    private var plantHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let scientificName = plant.scientificName {
                Text(scientificName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }

            HStack {
                if let difficultyLevel = plant.difficultyLevel {
                    DifficultyBadge(level: difficultyLevel)
                }
                if let plantType = plant.plantType {
                    PlantTypeBadge(type: plantType)
                }
                Spacer()
            }
        }
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Growing Requirements")
                .font(.headline)

            HStack(spacing: 20) {
                RequirementDetail(
                    icon: "sun.max.fill",
                    title: "Sunlight",
                    value: plant.sunlightRequirement?.displayName ?? "Unknown",
                    color: .yellow
                )

                RequirementDetail(
                    icon: "drop.fill",
                    title: "Watering",
                    value: plant.wateringFrequency?.displayName ?? "Unknown",
                    color: .blue
                )
            }

            HStack(spacing: 20) {
                RequirementDetail(
                    icon: "square.grid.3x3.fill",
                    title: "Space",
                    value: plant.spaceRequirement?.displayName ?? "Unknown",
                    color: .green
                )

                RequirementDetail(
                    icon: "graduationcap.fill",
                    title: "Difficulty",
                    value: plant.difficultyLevel?.description ?? "Unknown",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Plant")
                .font(.headline)

            Text(extractDescription(from: plant.notes ?? ""))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var careDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care Instructions")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(extractCareInstructions(from: plant.notes ?? ""), id: \.self) { instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 2)

                        Text(instruction)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var addToGardenButton: some View {
        Button("Add to My Garden") {
            showingAddToGarden = true
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .background(Color(.systemBackground))
        .accessibilityIdentifier("plant_detail_button_add_to_garden")
    }

    private func extractDescription(from notes: String) -> String {
        let lines = notes.components(separatedBy: .newlines)
        if let firstLine = lines.first, !firstLine.contains("Care Instructions:") {
            return firstLine
        }
        return "A wonderful plant to grow in your garden."
    }

    private func extractCareInstructions(from notes: String) -> [String] {
        let lines = notes.components(separatedBy: .newlines)
        var instructions: [String] = []
        var foundCareSection = false

        for line in lines {
            if line.contains("Care Instructions:") {
                foundCareSection = true
                continue
            }

            if foundCareSection {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let cleaned = trimmed.replacingOccurrences(of: "• ", with: "")
                    if !cleaned.isEmpty {
                        instructions.append(cleaned)
                    }
                }
            }
        }

        if instructions.isEmpty {
            instructions = [
                "Provide appropriate sunlight conditions",
                "Water according to the plant's needs",
                "Ensure proper drainage",
                "Monitor for pests and diseases",
                "Fertilize during growing season",
            ]
        }

        return instructions
    }
}

struct RequirementDetail: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlantTypeIcon: View {
    let plantType: PlantType

    var body: some View {
        Image(systemName: plantType.iconName)
            .foregroundColor(plantType.color)
            .font(.title2)
    }
}

enum GrowWiseError: LocalizedError {
    case dataServiceError

    var errorDescription: String? {
        switch self {
        case .dataServiceError:
            "Data service is not available"
        }
    }
}

// MARK: - Sort Options

enum DatabaseSortOption: CaseIterable {
    case name
    case difficulty
    case plantType
    case sunlightRequirement

    var displayName: String {
        switch self {
        case .name: "Name"
        case .difficulty: "Difficulty"
        case .plantType: "Plant Type"
        case .sunlightRequirement: "Sunlight Needs"
        }
    }
}

#Preview {
    PlantDatabaseView()
        .environment(DataService.createFallback())
}
