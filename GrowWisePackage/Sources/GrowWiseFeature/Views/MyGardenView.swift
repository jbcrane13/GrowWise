import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

public struct MyGardenView: View {
    @Environment(DataService.self) private var dataService
    @State private var plants: [Plant] = []
    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var searchText = ""
    @State private var selectedPlantType: PlantType?
    @State private var selectedDifficulty: DifficultyLevel?
    @State private var showingFilters = false
    @State private var showingAddPlant = false
    @State private var isLoading = true
    @State private var selectedSortOption: SortOption = .name
    @State private var showingCreateGarden = false // Added per instruction
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Garden Selector (if multiple gardens)
                if gardens.count > 1 {
                    gardenSelectorSection
                }

                // Plants Grid/List
                plantsSection
            }
            .navigationTitle("My Garden")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    sortMenuButton
                    filterButton
                    addPlantButton
                    Button(action: { showingCreateGarden = true }) {
                        Image(systemName: "leaf.fill")
                    }
                    .accessibilityLabel("New Garden")
                }
            }
            .sheet(isPresented: $showingFilters) {
                FiltersSheet(
                    selectedPlantType: $selectedPlantType,
                    selectedDifficulty: $selectedDifficulty
                )
            }
            .sheet(isPresented: $showingAddPlant) {
                AddPlantToGardenSheet(selectedGarden: selectedGarden)
            }
            .sheet(isPresented: $showingCreateGarden) {
                CreateGardenSheet()
            }
            .refreshable {
                await loadData()
            }
            // Using .task for automatic cancellation when view disappears
            .task {
                await loadData()
            }
            // Native SwiftUI search with built-in debouncing
            .searchable(text: $searchText, prompt: "Search your plants...")
            .onChange(of: searchText) { _, _ in
                filterPlants()
            }
            .onChange(of: selectedPlantType) { _, _ in
                filterPlants()
            }
            .onChange(of: selectedDifficulty) { _, _ in
                filterPlants()
            }
            .onChange(of: selectedGarden) { _, _ in
                filterPlants()
            }
            .onChange(of: selectedSortOption) { _, _ in
                sortPlants()
            }
            .onChange(of: showingCreateGarden) { _, isShowing in
                if !isShowing { Task { await loadData() } }
            }
            .onChange(of: showingAddPlant) { _, isShowing in
                if !isShowing { Task { await loadData() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCreateGardenFromAddPlant"))) { _ in
                showingAddPlant = false
                showingCreateGarden = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GardenCreated"))) { _ in
                Task { await loadData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PlantCreated"))) { _ in
            }
        }
    }
    
    private var gardenSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                GardenChip(
                    name: "All Gardens",
                    isSelected: selectedGarden == nil
                ) {
                    selectedGarden = nil
                }
                
                ForEach(gardens, id: \.id) { garden in
                    GardenChip(
                        name: garden.name ?? "Unknown Garden",
                        isSelected: selectedGarden?.id == garden.id
                    ) {
                        selectedGarden = garden
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var plantsSection: some View {
        Group {
            if isLoading {
                loadingView
            } else if filteredPlants.isEmpty {
                emptyStateView
            } else {
                plantsGrid
            }
        }
    }
    
    private var plantsGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(filteredPlants, id: \.id) { plant in
                    NavigationLink(value: plant) {
                        PlantCardView(plant: plant)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your garden...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Your First Plant") {
                showingAddPlant = true
            }
            .buttonStyle(.borderedProminent)
            
            Button("Create Garden") {
                showingCreateGarden = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sortMenuButton: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
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

    private var addPlantButton: some View {
        Button(action: { showingAddPlant = true }) {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add")
    }
    
    private var hasActiveFilters: Bool {
        selectedPlantType != nil || selectedDifficulty != nil
    }
    
    private var filteredPlants: [Plant] {
        var filtered = plants
        
        // Filter by garden
        if let selectedGarden = selectedGarden {
            filtered = filtered.filter { $0.garden?.id == selectedGarden.id }
        }
        
        // Filter by search text (using lowercased for in-memory filtering)
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            filtered = filtered.filter { plant in
                (plant.name ?? "").lowercased().contains(lowercasedSearch) ||
                (plant.scientificName?.lowercased().contains(lowercasedSearch) ?? false) ||
                (plant.notes ?? "").lowercased().contains(lowercasedSearch)
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
        
        return filtered
    }
    
    private var emptyStateTitle: String {
        if hasActiveFilters || !searchText.isEmpty {
            return "No Plants Found"
        } else if selectedGarden != nil {
            return "This Garden is Empty"
        } else {
            return "Start Your Garden Journey"
        }
    }
    
    private var emptyStateMessage: String {
        if hasActiveFilters || !searchText.isEmpty {
            return "Try adjusting your search or filters to find your plants."
        } else if selectedGarden != nil {
            return "Add some plants to this garden to get started."
        } else {
            return "Add your first plant and begin tracking your gardening adventure!"
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        // Load gardens
        gardens = dataService.fetchGardens()
        
        // Load all user plants
        plants = dataService.fetchPlants()
        
        // Sort plants
        sortPlants()
        
        isLoading = false
    }
    
    private func filterPlants() {
        // The filteredPlants computed property handles filtering
        // This method can be used for any additional filtering logic
    }
    
    private func sortPlants() {
        switch selectedSortOption {
        case .name:
            plants.sort { ($0.name ?? "") < ($1.name ?? "") }
        case .dateAdded:
            plants.sort { ($0.plantingDate ?? Date.distantPast) > ($1.plantingDate ?? Date.distantPast) }
        case .healthStatus:
            plants.sort { (plant1, plant2) in
                let health1 = plant1.healthStatus?.rawValue ?? "zzz"
                let health2 = plant2.healthStatus?.rawValue ?? "zzz"
                return health1 < health2
            }
        case .wateringSchedule:
            plants.sort { ($0.wateringFrequency?.days ?? 0) < ($1.wateringFrequency?.days ?? 0) }
        }
    }
}

// MARK: - Supporting Views

struct GardenChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct FiltersSheet: View {
    @Binding var selectedPlantType: PlantType?
    @Binding var selectedDifficulty: DifficultyLevel?
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
            }
            .navigationTitle("Filters")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

struct CreateGardenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @State private var name: String = ""
    @State private var type: GardenType = .outdoor
    @State private var isIndoor: Bool = false
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String = ""
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Garden Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(GardenType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    Toggle("Indoor Garden", isOn: $isIndoor)
                }
            }
            .navigationTitle("Create Garden")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveTask = Task { await saveGarden() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onDisappear { saveTask?.cancel() }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func saveGarden() async {
        isSaving = true
        do {
            _ = try dataService.createGarden(name: name.trimmingCharacters(in: .whitespacesAndNewlines), type: type, isIndoor: isIndoor)
            NotificationCenter.default.post(name: Notification.Name("GardenCreated"), object: nil)
            dismiss()
        } catch {
            errorMessage = "Failed to create garden: \(error.localizedDescription)"
            showingError = true
        }
        isSaving = false
    }
}

// MARK: - Assign Garden Sheet

struct AssignGardenSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Garden") {
                    Picker("Garden", selection: $selectedGarden) {
                        Text("None").tag(nil as Garden?)
                        ForEach(gardens, id: \.id) { garden in
                            Text(garden.name ?? "Unnamed").tag(garden as Garden?)
                        }
                    }
                }
            }
            .navigationTitle("Assign Garden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveTask = Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .task { load() }
            .onDisappear { saveTask?.cancel() }
        }
    }

    private func load() {
        gardens = dataService.fetchGardens()
        selectedGarden = plant.garden
    }

    @MainActor
    private func save() async {
        isSaving = true
        plant.garden = selectedGarden
        if let selectedGarden = selectedGarden {
            selectedGarden.plants = (selectedGarden.plants ?? []) + [plant]
        }
        do {
            try dataService.updatePlant(plant)
            dismiss()
        } catch {
            // Silent failure handler - could show alert if desired
            dismiss()
        }
        isSaving = false
    }
}

#Preview {
    let dataService = try! DataService()
    let notificationService = NotificationService()
    let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
    let photoService = PhotoService(dataService: dataService)
    let plantDatabaseService = PlantDatabaseService(dataService: dataService)

    MyGardenView()
        .environment(dataService)
        .environment(notificationService)
        .environment(reminderService)
        .environment(photoService)
        .environment(plantDatabaseService)
}
