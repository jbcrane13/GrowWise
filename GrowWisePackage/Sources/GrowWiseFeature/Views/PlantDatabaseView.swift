import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

public struct PlantDatabaseView: View {
    @EnvironmentObject private var dataService: DataService
    @State private var databasePlants: [Plant] = []
    @State private var searchText = ""
    @State private var selectedPlantType: PlantType?
    @State private var selectedDifficulty: DifficultyLevel?
    @State private var selectedSunlight: SunlightLevel?
    @State private var showingFilters = false
    @State private var isLoading = true
    @State private var selectedSortOption: DatabaseSortOption = .name
    @State private var showingPlantDetail: Plant?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Section
                searchAndFilterSection
                
                // Filter Tags (when active)
                if hasActiveFilters {
                    activeFiltersSection
                }
                
                // Plant Database Content
                plantDatabaseContent
            }
            .navigationTitle("Plant Database")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    sortMenuButton
                    filterButton
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
            .onAppear {
                Task {
                    await loadDatabasePlants()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search plants...")
        .onChange(of: searchText) { _, _ in
            filterAndSortPlants()
        }
        .onChange(of: selectedPlantType) { _, _ in
            filterAndSortPlants()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            filterAndSortPlants()
        }
        .onChange(of: selectedSunlight) { _, _ in
            filterAndSortPlants()
        }
        .onChange(of: selectedSortOption) { _, _ in
            filterAndSortPlants()
        }
    }
    
    private var searchAndFilterSection: some View {
        HStack {
            SearchBarView(text: $searchText)
            filterButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                if let type = selectedPlantType {
                    FilterTag(title: type.displayName, color: .blue) {
                        selectedPlantType = nil
                    }
                }
                
                if let difficulty = selectedDifficulty {
                    FilterTag(title: difficulty.displayName, color: .orange) {
                        selectedDifficulty = nil
                    }
                }
                
                if let sunlight = selectedSunlight {
                    FilterTag(title: sunlight.displayName, color: .yellow) {
                        selectedSunlight = nil
                    }
                }
                
                Button("Clear All") {
                    clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
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
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Plants Found")
                    .font(.headline)
                
                Text("Try adjusting your search or filters to find plants.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if hasActiveFilters {
                Button("Clear Filters") {
                    clearAllFilters()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
    
    private var filterButton: some View {
        Button(action: { showingFilters = true }) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundColor(hasActiveFilters ? .blue : .gray)
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedPlantType != nil || selectedDifficulty != nil || selectedSunlight != nil
    }
    
    private var filteredPlants: [Plant] {
        var filtered = databasePlants
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { plant in
                (plant.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (plant.scientificName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (plant.notes ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by plant type
        if let selectedType = selectedPlantType {
            filtered = filtered.filter { $0.plantType == selectedType }
        }
        
        // Filter by difficulty
        if let selectedDifficulty = selectedDifficulty {
            filtered = filtered.filter { $0.difficultyLevel == selectedDifficulty }
        }
        
        // Filter by sunlight requirement
        if let selectedSunlight = selectedSunlight {
            filtered = filtered.filter { $0.sunlightRequirement == selectedSunlight }
        }
        
        // Sort filtered results
        return sortPlants(filtered)
    }
    
    private func sortPlants(_ plants: [Plant]) -> [Plant] {
        switch selectedSortOption {
        case .name:
            return plants.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .difficulty:
            return plants.sorted { 
                if $0.difficultyLevel != $1.difficultyLevel {
                    return ($0.difficultyLevel?.rawValue ?? "") < ($1.difficultyLevel?.rawValue ?? "")
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        case .plantType:
            return plants.sorted { 
                if $0.plantType != $1.plantType {
                    return ($0.plantType?.rawValue ?? "") < ($1.plantType?.rawValue ?? "")
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        case .sunlightRequirement:
            return plants.sorted { 
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
    
    private func filterAndSortPlants() {
        // The filteredPlants computed property handles this
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
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sunlightShorthand(_ sunlight: SunlightLevel) -> String {
        switch sunlight {
        case .fullSun: return "Full Sun"
        case .partialSun: return "Part Sun"
        case .partialShade: return "Part Shade"
        case .fullShade: return "Full Shade"
        }
    }
    
    private func wateringShorthand(_ watering: WateringFrequency) -> String {
        switch watering {
        case .daily: return "Daily"
        case .everyOtherDay: return "2x/week"
        case .twiceWeekly: return "2x/week"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .asNeeded: return "As needed"
        }
    }
    
    private func spaceShorthand(_ space: SpaceRequirement) -> String {
        switch space {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "X-Large"
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
        .cornerRadius(12)
    }
}

struct DatabaseFiltersSheet: View {
    @Binding var selectedPlantType: PlantType?
    @Binding var selectedDifficulty: DifficultyLevel?
    @Binding var selectedSunlight: SunlightLevel?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Plant Type") {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedPlantType != nil {
                            Button("Clear Plant Type") {
                                selectedPlantType = nil
                            }
                            .foregroundColor(.red)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlantDatabaseDetailView: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataService: DataService
    @State private var showingAddToGarden = false
    
    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
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
        .cornerRadius(12)
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
        .cornerRadius(12)
        .padding()
        .background(Color(.systemBackground))
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
                "Fertilize during growing season"
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

struct AddPlantToGardenFromDatabaseSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @State private var dataService: DataService?
    
    // Customization fields
    @State private var selectedGarden: Garden?
    @State private var location: String = ""
    @State private var plantingDate = Date()
    @State private var healthStatus: HealthStatus = .healthy
    @State private var notes: String = ""
    @State private var availableGardens: [Garden] = []
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Plant Info Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plant.name ?? "Unknown Plant")
                                .font(.headline)
                            if let scientificName = plant.scientificName {
                                Text(scientificName)
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        PlantTypeIcon(plantType: plant.plantType ?? .houseplant)
                    }
                    
                    if let description = plant.notes, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                } header: {
                    Text("Plant Information")
                }
                
                // Garden Selection
                if !availableGardens.isEmpty {
                    Section {
                        Picker("Select Garden", selection: $selectedGarden) {
                            Text("No Garden").tag(nil as Garden?)
                            ForEach(availableGardens, id: \.id) { garden in
                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } header: {
                        Text("Garden")
                    } footer: {
                        Text("Choose which garden to add this plant to")
                    }
                }
                
                // Location & Planting
                Section {
                    TextField("Location in Garden", text: $location)
                        .textInputAutocapitalization(.words)
                    
                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                } header: {
                    Text("Planting Details")
                }
                
                // Health Status
                Section {
                    Picker("Initial Health Status", selection: $healthStatus) {
                        ForEach(HealthStatus.allCases, id: \.self) { status in
                            Label(status.displayName, systemImage: status.iconName)
                                .tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("Health Status")
                }
                
                // Care Requirements Preview
                Section {
                    if let sunlight = plant.sunlightRequirement {
                        HStack {
                            Label("Sunlight", systemImage: "sun.max.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text(sunlight.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let watering = plant.wateringFrequency {
                        HStack {
                            Label("Watering", systemImage: "drop.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Text("Every \(watering.days) days")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let difficulty = plant.difficultyLevel {
                        HStack {
                            Label("Difficulty", systemImage: "star.fill")
                                .foregroundColor(.yellow)
                            Spacer()
                            Text(difficulty.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Care Requirements")
                }
                
                // Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add any specific notes about this plant")
                }
            }
            .navigationTitle("Add to Garden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveToGarden()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Adding to garden...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private func loadData() {
        do {
            dataService = try DataService()
            availableGardens = dataService?.fetchGardens() ?? []
            
            // Auto-select first garden if only one exists
            if availableGardens.count == 1 {
                selectedGarden = availableGardens.first
            }
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    @MainActor
    private func saveToGarden() async {
        isLoading = true
        
        do {
            guard let dataService = dataService else {
                throw GrowWiseError.dataServiceError
            }
            
            // Create a user instance of the database plant
            let userPlant = try dataService.createPlant(
                name: plant.name ?? "Unknown Plant",
                type: plant.plantType ?? .houseplant,
                difficultyLevel: plant.difficultyLevel ?? .beginner,
                garden: selectedGarden
            )
            
            // Copy properties from database plant
            userPlant.scientificName = plant.scientificName
            userPlant.sunlightRequirement = plant.sunlightRequirement
            userPlant.wateringFrequency = plant.wateringFrequency
            
            // Set customized properties
            userPlant.plantingDate = plantingDate
            userPlant.healthStatus = healthStatus
            userPlant.notes = notes.isEmpty ? plant.notes : notes
            userPlant.isUserPlant = true
            
            // Save the plant
            try dataService.updatePlant(userPlant)
            
            // Create a journal entry for planting
            let journalEntry = try dataService.createJournalEntry(
                title: "Added \(userPlant.name ?? "plant") to garden",
                content: "Added from plant database. Location: \(location.isEmpty ? "Not specified" : location)",
                type: .planting,
                plant: userPlant
            )
            
            isLoading = false
            dismiss()
            
        } catch {
            isLoading = false
            errorMessage = "Failed to add plant: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Supporting Types

extension HealthStatus {
    var iconName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .sick: return "xmark.octagon.fill"
        case .dying: return "exclamationmark.octagon.fill"
        case .dead: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .needsAttention: return .orange
        case .sick: return .red
        case .dying: return .red
        case .dead: return .gray
        }
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

// PlantType extension removed - already defined in SkillAssessmentView.swift
extension PlantType {
    var color: Color {
        switch self {
        case .houseplant: return .green
        case .succulent: return .mint
        case .flower: return .pink
        case .vegetable: return .orange
        case .herb: return .green
        case .tree: return .brown
        case .shrub: return .green
        case .fruit: return .red
        }
    }
}

enum GrowWiseError: LocalizedError {
    case dataServiceError
    
    var errorDescription: String? {
        switch self {
        case .dataServiceError:
            return "Data service is not available"
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
        case .name: return "Name"
        case .difficulty: return "Difficulty"
        case .plantType: return "Plant Type"
        case .sunlightRequirement: return "Sunlight Needs"
        }
    }
}

#Preview {
    PlantDatabaseView()
        .environmentObject(try! DataService())
}