import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

public struct MyGardenView: View {
    @EnvironmentObject private var dataService: DataService
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
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterSection
                
                // Garden Selector (if multiple gardens)
                if gardens.count > 1 {
                    gardenSelectorSection
                }
                
                // Plants Grid/List
                plantsSection
            }
            .navigationTitle("My Garden")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    sortMenuButton
                    addPlantButton
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
            .refreshable {
                await loadData()
            }
            .onAppear {
                Task {
                    await loadData()
                }
            }
        }
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
    }
    
    private var searchAndFilterSection: some View {
        HStack {
            SearchBarView(text: $searchText)
            
            Button(action: { showingFilters = true }) {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(hasActiveFilters ? .blue : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
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
                    NavigationLink(destination: PlantDetailView(plant: plant)) {
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
    
    private var addPlantButton: some View {
        Button(action: { showingAddPlant = true }) {
            Image(systemName: "plus")
        }
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
            }
            .navigationTitle("Filters")
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

struct AddPlantToGardenSheet: View {
    let selectedGarden: Garden?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataService: DataService
    
    // Tab Selection
    @State private var selectedTab: PlantAdditionTab = .newPlant
    
    // New Plant Form fields
    @State private var plantName = ""
    @State private var scientificName = ""
    @State private var selectedPlantType = PlantType.vegetable
    @State private var selectedDifficultyLevel = DifficultyLevel.beginner
    @State private var plantingDate = Date()
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [String] = []
    
    // Database Plants search and selection
    @State private var searchText = ""
    @State private var databasePlants: [Plant] = []
    @State private var filteredPlants: [Plant] = []
    @State private var selectedDatabasePlant: Plant?
    @State private var showingPlantCustomization = false
    
    // UI state
    @State private var availableGardens: [Garden] = []
    @State private var targetGarden: Garden?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var plantDatabaseService: PlantDatabaseService?
    
    private enum PlantAdditionTab: String, CaseIterable {
        case newPlant = "New Plant"
        case fromDatabase = "From Database"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                tabPickerSection
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    newPlantTab
                        .tag(PlantAdditionTab.newPlant)
                    
                    fromDatabaseTab
                        .tag(PlantAdditionTab.fromDatabase)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePlant()
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                setupInitialState()
            }
        }
        .sheet(isPresented: $showingPlantCustomization) {
            if let plant = selectedDatabasePlant {
                DatabasePlantCustomizationSheet(
                    plant: plant,
                    targetGarden: targetGarden,
                    dataService: dataService,
                    onSave: { customizedPlant in
                        Task {
                            await saveCustomizedDatabasePlant(customizedPlant)
                        }
                    },
                    onCancel: {
                        selectedDatabasePlant = nil
                        showingPlantCustomization = false
                    }
                )
            }
        }
    }
    
    private var tabPickerSection: some View {
        HStack {
            ForEach(PlantAdditionTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
    
    private var newPlantTab: some View {
        Form {
            // Target Garden Section
            if !availableGardens.isEmpty {
                Section("Target Garden") {
                    Picker("Garden", selection: $targetGarden) {
                        if let selectedGarden = selectedGarden {
                            Text(selectedGarden.name ?? "Selected Garden").tag(selectedGarden as Garden?)
                        } else {
                            Text("Choose Garden").tag(nil as Garden?)
                            ForEach(availableGardens, id: \.id) { garden in
                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                            }
                        }
                    }
                    .disabled(selectedGarden != nil)
                }
            }
            
            // Basic Information Section
            Section("Basic Information") {
                TextField("Plant Name", text: $plantName)
                    .autocorrectionDisabled()
                
                TextField("Scientific Name (Optional)", text: $scientificName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            // Plant Type and Difficulty Section
            Section("Plant Details") {
                Picker("Plant Type", selection: $selectedPlantType) {
                    ForEach(PlantType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                
                Picker("Difficulty Level", selection: $selectedDifficultyLevel) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        HStack {
                            Text(level.displayName)
                            Spacer()
                            Text("(\(level.description))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .tag(level)
                    }
                }
            }
            
            // Planting Information Section
            Section("Planting Information") {
                DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
            }
            
            // Notes Section
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }
            
            // Photo Section
            Section("Photos") {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Add Photos")
                    }
                    .foregroundColor(.blue)
                }
                
                if !selectedPhotos.isEmpty {
                    Text("\(selectedPhotos.count) photo(s) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var fromDatabaseTab: some View {
        VStack(spacing: 0) {
            // Search Bar
            VStack(spacing: 8) {
                SearchBarView(text: $searchText, placeholder: "Search plant database...")
                    .padding(.horizontal)
                
                if let garden = selectedGarden ?? targetGarden {
                    Text("Adding to: \(garden.name ?? "Selected Garden")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .background(Color(.systemGroupedBackground))
            
            // Plants List
            Group {
                if isLoading {
                    loadingView
                } else if filteredPlants.isEmpty && !searchText.isEmpty {
                    emptySearchView
                } else if filteredPlants.isEmpty {
                    emptyDatabaseView
                } else {
                    plantsListView
                }
            }
        }
        .onAppear {
            loadDatabasePlants()
        }
        .onChange(of: searchText) { _, _ in
            filterPlants()
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
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Plants Found")
                .font(.headline)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyDatabaseView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Plant Database Empty")
                .font(.headline)
            
            Text("The plant database needs to be populated first")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var plantsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPlants, id: \.id) { plant in
                    DatabasePlantRowView(
                        plant: plant,
                        onSelect: {
                            selectedDatabasePlant = plant
                            showingPlantCustomization = true
                        }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var canSave: Bool {
        switch selectedTab {
        case .newPlant:
            return !plantName.isEmpty && (selectedGarden != nil || targetGarden != nil)
        case .fromDatabase:
            return false // Saving happens through customization sheet
        }
    }
    
    private func setupInitialState() {
        targetGarden = selectedGarden
        availableGardens = dataService.fetchGardens()
        plantDatabaseService = PlantDatabaseService(dataService: dataService)
    }
    
    private func loadDatabasePlants() {
        isLoading = true
        
        Task {
            // Ensure database is seeded
            if let service = plantDatabaseService {
                try? await service.seedPlantDatabase()
            }
            
            await MainActor.run {
                databasePlants = dataService.fetchPlantDatabase()
                filteredPlants = databasePlants
                isLoading = false
            }
        }
    }
    
    private func filterPlants() {
        if searchText.isEmpty {
            filteredPlants = databasePlants
        } else {
            filteredPlants = plantDatabaseService?.searchPlants(query: searchText) ?? []
        }
    }
    
    @MainActor
    private func savePlant() async {
        guard selectedTab == .newPlant, !plantName.isEmpty else { return }
        
        isSaving = true
        
        do {
            // Process selected photos
            var processedPhotoURLs: [String] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let photoURL = "photo_\(UUID().uuidString)"
                    processedPhotoURLs.append(photoURL)
                }
            }
            
            // Create the plant using DataService
            let plant = try dataService.createPlant(
                name: plantName,
                type: selectedPlantType,
                difficultyLevel: selectedDifficultyLevel,
                garden: selectedGarden ?? targetGarden
            )
            
            // Update additional plant properties
            plant.scientificName = scientificName.isEmpty ? nil : scientificName
            plant.plantingDate = plantingDate
            plant.notes = notes.isEmpty ? nil : notes
            plant.photoURLs = processedPhotoURLs
            plant.isUserPlant = true
            
            // Save the updated plant
            try dataService.updatePlant(plant)
            
            dismiss()
            
        } catch {
            errorMessage = "Failed to save plant: \(error.localizedDescription)"
            showingError = true
            isSaving = false
        }
    }
    
    @MainActor
    private func saveCustomizedDatabasePlant(_ customizedPlant: Plant) async {
        do {
            // Set the garden association
            customizedPlant.garden = selectedGarden ?? targetGarden
            customizedPlant.isUserPlant = true
            customizedPlant.plantingDate = customizedPlant.plantingDate ?? Date()
            
            // Save the customized plant
            try dataService.updatePlant(customizedPlant)
            
            selectedDatabasePlant = nil
            showingPlantCustomization = false
            dismiss()
            
        } catch {
            errorMessage = "Failed to save plant: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Database Plant Row View

struct DatabasePlantRowView: View {
    let plant: Plant
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Plant icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: plantTypeIcon)
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                // Plant info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name ?? "Unknown Plant")
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    
                    if let scientificName = plant.scientificName, !scientificName.isEmpty {
                        Text(scientificName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    HStack(spacing: 8) {
                        if let plantType = plant.plantType {
                            PlantTypeBadge(type: plantType)
                        }
                        if let difficultyLevel = plant.difficultyLevel {
                            DifficultyBadge(level: difficultyLevel)
                        }
                        Spacer()
                    }
                    
                    if let notes = plant.notes, !notes.isEmpty {
                        Text(notes.prefix(100) + (notes.count > 100 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var plantTypeIcon: String {
        switch plant.plantType {
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .flower: return "rosette"
        case .houseplant: return "house.fill"
        case .fruit: return "apple.whole.fill"
        case .succulent: return "circle.grid.3x3.fill"
        case .tree: return "tree.fill"
        case .shrub: return "leaf.circle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Database Plant Customization Sheet

struct DatabasePlantCustomizationSheet: View {
    let plant: Plant
    let targetGarden: Garden?
    let dataService: DataService
    let onSave: (Plant) -> Void
    let onCancel: () -> Void
    
    @State private var customPlantName: String
    @State private var customScientificName: String
    @State private var customNotes: String
    @State private var plantingDate = Date()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    init(plant: Plant, targetGarden: Garden?, dataService: DataService, onSave: @escaping (Plant) -> Void, onCancel: @escaping () -> Void) {
        self.plant = plant
        self.targetGarden = targetGarden
        self.dataService = dataService
        self.onSave = onSave
        self.onCancel = onCancel
        self._customPlantName = State(initialValue: plant.name ?? "")
        self._customScientificName = State(initialValue: plant.scientificName ?? "")
        self._customNotes = State(initialValue: plant.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Plant Preview Section
                Section("Plant Information") {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: plantTypeIcon)
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plant.name ?? "Unknown Plant")
                                .font(.headline)
                            
                            if let scientificName = plant.scientificName, !scientificName.isEmpty {
                                Text(scientificName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            
                            HStack(spacing: 8) {
                                if let plantType = plant.plantType {
                                    PlantTypeBadge(type: plantType)
                                }
                                if let difficultyLevel = plant.difficultyLevel {
                                    DifficultyBadge(level: difficultyLevel)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Customization Section
                Section("Customize Your Plant") {
                    TextField("Plant Name", text: $customPlantName)
                        .autocorrectionDisabled()
                    
                    TextField("Scientific Name", text: $customScientificName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundColor(.secondary)
                    
                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                }
                
                // Notes Section
                Section("Additional Notes") {
                    TextEditor(text: $customNotes)
                        .frame(minHeight: 100)
                }
                
                // Photo Section
                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Add Photos")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) photo(s) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Garden Info Section
                if let garden = targetGarden {
                    Section("Garden") {
                        HStack {
                            Image(systemName: "leaf.circle")
                                .foregroundColor(.green)
                            Text("Adding to: \(garden.name ?? "Selected Garden")")
                        }
                    }
                }
            }
            .navigationTitle("Customize Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add to Garden") {
                        Task {
                            await saveCustomizedPlant()
                        }
                    }
                    .disabled(customPlantName.isEmpty)
                }
            }
        }
    }
    
    private var plantTypeIcon: String {
        switch plant.plantType {
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .flower: return "rosette"
        case .houseplant: return "house.fill"
        case .fruit: return "apple.whole.fill"
        case .succulent: return "circle.grid.3x3.fill"
        case .tree: return "tree.fill"
        case .shrub: return "leaf.circle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }
    
    @MainActor
    private func saveCustomizedPlant() async {
        do {
            // Create a new plant based on the database plant
            let customizedPlant = try dataService.createPlant(
                name: customPlantName,
                type: plant.plantType ?? .vegetable,
                difficultyLevel: plant.difficultyLevel ?? .beginner,
                garden: targetGarden
            )
            
            // Copy relevant properties from database plant
            customizedPlant.scientificName = customScientificName.isEmpty ? plant.scientificName : customScientificName
            customizedPlant.sunlightRequirement = plant.sunlightRequirement
            customizedPlant.wateringFrequency = plant.wateringFrequency
            customizedPlant.spaceRequirement = plant.spaceRequirement
            customizedPlant.plantingDate = plantingDate
            customizedPlant.notes = customNotes.isEmpty ? plant.notes : customNotes
            customizedPlant.isUserPlant = true
            
            // Process photos
            var processedPhotoURLs: [String] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let photoURL = "photo_\(UUID().uuidString)"
                    processedPhotoURLs.append(photoURL)
                }
            }
            customizedPlant.photoURLs = processedPhotoURLs
            
            // Save the customized plant
            try dataService.updatePlant(customizedPlant)
            
            onSave(customizedPlant)
            
        } catch {
            print("Failed to save customized plant: \(error)")
        }
    }
}

struct PlantDetailView: View {
    let plant: Plant
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditPlant = false
    @State private var showingDeleteConfirmation = false
    @State private var showingJournalEntry = false
    @State private var showingReminderView = false
    @State private var selectedPhoto: String?
    @State private var showingPhotoViewer = false
    @State private var dataService: DataService?
    @State private var photoService: PhotoService?
    @State private var reminderService: ReminderService?
    
    // Care action states
    @State private var isPerformingCareAction = false
    @State private var showingCareSuccess = false
    @State private var careActionMessage = ""
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                heroImageSection
                plantInfoSections
            }
        }
        .navigationTitle(plant.name ?? "Unknown Plant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Delete Plant", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePlant()
            }
        } message: {
            Text("Are you sure you want to delete \(plant.name ?? "this plant")? This action cannot be undone.")
        }
        .alert("Care Action Completed", isPresented: $showingCareSuccess) {
            Button("OK") { }
        } message: {
            Text(careActionMessage)
        }
        .sheet(isPresented: $showingEditPlant) {
            Text("Edit Plant View - To be implemented")
        }
        .sheet(isPresented: $showingJournalEntry) {
            if let photoService = photoService {
                NavigationView {
                    AddJournalEntryView(photoService: photoService)
                }
            } else {
                Text("Photo service not available")
            }
        }
        .sheet(isPresented: $showingReminderView) {
            if let reminderService = reminderService, let dataService = dataService {
                AddReminderView(reminderService: reminderService, dataService: dataService)
            } else {
                Text("Services not available")
            }
        }
        .onAppear {
            setupServices()
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Edit Plant") {
                    showingEditPlant = true
                }
                
                Divider()
                
                Button("Delete Plant", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
    
    private var plantInfoSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            basicInfoSection
            careRequirementsSection
            healthStatusSection
            actionButtonsSection
            careHistorySection
            upcomingRemindersSection
        }
        .padding(.horizontal)
    }
    
    // MARK: - Hero Image Section
    
    private var heroImageSection: some View {
        VStack {
            if let photoURLs = plant.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoURLs, id: \.self) { photoURL in
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 300, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        selectedPhoto = photoURL
                                        showingPhotoViewer = true
                                    }
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 300, height: 200)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Placeholder when no photos
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No photos yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let scientificName = plant.scientificName {
                        InfoRow(title: "Scientific Name", value: scientificName, systemImage: "leaf.fill")
                    }
                    
                    InfoRow(title: "Type", value: plant.plantType?.displayName ?? "Unknown", systemImage: "tag.fill")
                    InfoRow(title: "Difficulty", value: plant.difficultyLevel?.displayName ?? "Unknown", systemImage: "star.fill")
                    
                    if let plantingDate = plant.plantingDate {
                        InfoRow(title: "Planted", value: plantingDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    }
                    
                    if let growthStage = plant.growthStage {
                        InfoRow(title: "Growth Stage", value: growthStage.displayName, systemImage: "chart.line.uptrend.xyaxis")
                    }
                    
                    if let location = plant.gardenLocation, !location.isEmpty {
                        InfoRow(title: "Location", value: location, systemImage: "location.fill")
                    }
                    
                    if let containerType = plant.containerType {
                        InfoRow(title: "Container", value: containerType.displayName, systemImage: "square.stack")
                    }
                    
                    if let notes = plant.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text(notes)
                                .font(.body)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Care Requirements Section
    
    private var careRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care Requirements")
                .font(.title2)
                .fontWeight(.semibold)
            
            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let sunlight = plant.sunlightRequirement {
                        InfoRow(title: "Sunlight", value: sunlight.displayName, systemImage: "sun.max.fill")
                    }
                    
                    if let watering = plant.wateringFrequency {
                        InfoRow(title: "Watering", value: watering.displayName, systemImage: "drop.fill")
                    }
                    
                    if let space = plant.spaceRequirement {
                        InfoRow(title: "Space Needed", value: space.displayName, systemImage: "square.dashed")
                    }
                    
                    if let harvestDate = plant.harvestDate {
                        InfoRow(title: "Expected Harvest", value: harvestDate.formatted(date: .abbreviated, time: .omitted), systemImage: "basket.fill")
                    }
                }
            }
        }
    }
    
    // MARK: - Health Status Section
    
    private var healthStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Status")
                .font(.title2)
                .fontWeight(.semibold)
            
            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(healthStatusColor)
                            .frame(width: 20)
                        Text("Current Health")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(plant.healthStatus?.displayName ?? "Unknown")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(healthStatusColor)
                    }
                    
                    if let lastWatered = plant.lastWatered {
                        InfoRow(title: "Last Watered", value: lastWatered.formatted(date: .abbreviated, time: .omitted), systemImage: "drop.fill")
                    }
                    
                    if let lastFertilized = plant.lastFertilized {
                        InfoRow(title: "Last Fertilized", value: lastFertilized.formatted(date: .abbreviated, time: .omitted), systemImage: "leaf.fill")
                    }
                    
                    if let lastPruned = plant.lastPruned {
                        InfoRow(title: "Last Pruned", value: lastPruned.formatted(date: .abbreviated, time: .omitted), systemImage: "scissors")
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActionButton(
                    title: "Water",
                    systemImage: "drop.fill",
                    color: .blue,
                    isLoading: isPerformingCareAction
                ) {
                    performCareAction(.watering)
                }
                
                ActionButton(
                    title: "Fertilize",
                    systemImage: "leaf.fill",
                    color: .green,
                    isLoading: isPerformingCareAction
                ) {
                    performCareAction(.fertilizing)
                }
                
                ActionButton(
                    title: "Add Entry",
                    systemImage: "plus.circle.fill",
                    color: .purple,
                    isLoading: false
                ) {
                    showingJournalEntry = true
                }
                
                ActionButton(
                    title: "Set Reminder",
                    systemImage: "bell.fill",
                    color: .orange,
                    isLoading: false
                ) {
                    showingReminderView = true
                }
            }
        }
    }
    
    // MARK: - Care History Section
    
    private var careHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full journal view
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let journalEntries = plant.journalEntries?.prefix(5) {
                if journalEntries.isEmpty {
                    InfoCard {
                        HStack {
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                            Text("No journal entries yet")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(journalEntries), id: \.id) { entry in
                            if let photoService = photoService {
                                JournalEntryRow(entry: entry, photoService: photoService)
                            } else {
                                SimpleJournalEntryRow(entry: entry)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Upcoming Reminders Section
    
    private var upcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Reminders")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Manage") {
                    // Navigate to reminder management
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let reminders = plant.reminders?.filter({ $0.isEnabled == true }).prefix(3) {
                if reminders.isEmpty {
                    InfoCard {
                        HStack {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.gray)
                            Text("No active reminders")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(reminders), id: \.id) { reminder in
                            if let reminderService = reminderService {
                                ReminderRowView(reminder: reminder, reminderService: reminderService)
                            } else {
                                SimpleReminderRow(reminder: reminder)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct InfoCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            VStack {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private struct InfoRow: View {
        let title: String
        let value: String
        let systemImage: String
        
        var body: some View {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.body)
            }
        }
    }
    
    private struct ActionButton: View {
        let title: String
        let systemImage: String
        let color: Color
        let isLoading: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 20))
                    }
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Computed Properties
    
    private var healthStatusColor: Color {
        guard let healthStatus = plant.healthStatus else { return .gray }
        
        switch healthStatus {
        case .healthy: return .green
        case .needsAttention: return .yellow
        case .sick: return .orange
        case .dying: return .red
        case .dead: return .gray
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupServices() {
        do {
            dataService = try DataService()
            if let dataService = dataService {
                photoService = PhotoService(dataService: dataService)
                let notificationService = NotificationService.shared
                reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
            }
        } catch {
            print("Failed to setup services: \(error)")
        }
    }
    
    private func performCareAction(_ type: JournalEntryType) {
        guard !isPerformingCareAction else { return }
        
        isPerformingCareAction = true
        
        Task {
            do {
                // Update plant's care dates
                let currentDate = Date()
                
                switch type {
                case .watering:
                    plant.lastWatered = currentDate
                    careActionMessage = "Watering recorded for \(plant.name ?? "your plant")!"
                case .fertilizing:
                    plant.lastFertilized = currentDate
                    careActionMessage = "Fertilizing recorded for \(plant.name ?? "your plant")!"
                default:
                    break
                }
                
                // Create a journal entry
                let journalEntry = JournalEntry(
                    title: type.displayName,
                    content: "Quick action: \(type.displayName.lowercased())",
                    entryType: type,
                    plant: plant
                )
                
                // Save to data service
                try dataService?.addJournalEntry(journalEntry)
                
                await MainActor.run {
                    isPerformingCareAction = false
                    showingCareSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isPerformingCareAction = false
                    careActionMessage = "Failed to record \(type.displayName.lowercased()). Please try again."
                    showingCareSuccess = true
                }
                print("Failed to perform care action: \(error)")
            }
        }
    }
    
    private func deletePlant() {
        Task {
            do {
                try dataService?.deletePlant(plant)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to delete plant: \(error)")
            }
        }
    }
    
    // MARK: - Simple Fallback Views
    
    private struct SimpleJournalEntryRow: View {
        let entry: JournalEntry
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: entry.entryType.iconName)
                    .font(.title3)
                    .foregroundColor(Color(entry.entryType.color))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? entry.entryType.displayName : entry.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(entry.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(entry.entryDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private struct SimpleReminderRow: View {
        let reminder: PlantReminder
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: reminder.reminderType.iconName)
                    .font(.title3)
                    .foregroundColor(Color(reminder.priority.color))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(reminder.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text("Due: \(reminder.nextDueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if reminder.isEnabled {
                    Circle()
                        .fill(Color(reminder.priority.color))
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Sort Options

enum SortOption: CaseIterable {
    case name
    case dateAdded
    case healthStatus
    case wateringSchedule
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateAdded: return "Date Added"
        case .healthStatus: return "Health Status"
        case .wateringSchedule: return "Watering Schedule"
        }
    }
}

#Preview {
    MyGardenView()
        .environmentObject(try! DataService())
}