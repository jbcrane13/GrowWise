import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

struct AddPlantToGardenSheet: View {
    let selectedGarden: Garden?
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(PlantDatabaseService.self) private var plantDatabaseService
    
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
    
    private enum PlantAdditionTab: String, CaseIterable {
        case newPlant = "New Plant"
        case fromDatabase = "From Database"
    }
    
    var body: some View {
        NavigationStack {
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
                .gwPagingTabStyle(indexDisplayMode: .never)
            }
            .navigationTitle("Add Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .primaryAction) {
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
            if availableGardens.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No gardens yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Create a Garden") {
                            // Dismiss this sheet and trigger create garden flow via notification
                            NotificationCenter.default.post(name: Notification.Name("ShowCreateGardenFromAddPlant"), object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
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
                TextField("Name", text: $plantName)
                    .autocorrectionDisabled()

                TextField("Scientific Name (Optional)", text: $scientificName)
                    .autocorrectionDisabled()
                    .gwTextInputAutocapitalization(.none)
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
        .task {
            await loadDatabasePlants()
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
            return !plantName.isEmpty
        case .fromDatabase:
            return false // Saving happens through customization sheet
        }
    }
    
    private func setupInitialState() {
        targetGarden = selectedGarden
        availableGardens = dataService.fetchGardens()
    }
    
    @MainActor
    private func loadDatabasePlants() async {
        isLoading = true

        // Ensure database is seeded (non-critical — database may already be populated)
        do {
            try await plantDatabaseService.seedPlantDatabase()
        } catch {
            // Seed failure is non-critical if database was previously seeded.
            // Show error only if database is empty after the attempt.
        }

        databasePlants = dataService.fetchPlantDatabase()
        filteredPlants = databasePlants

        if databasePlants.isEmpty {
            errorMessage = "Unable to load plant database. Please try again later."
            showingError = true
        }

        isLoading = false
    }
    
    private func filterPlants() {
        if searchText.isEmpty {
            filteredPlants = databasePlants
        } else {
            filteredPlants = plantDatabaseService.searchPlants(query: searchText)
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
                if (try? await item.loadTransferable(type: Data.self)) != nil {
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
            
            NotificationCenter.default.post(name: Notification.Name("PlantCreated"), object: nil)
            
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
    @State private var showingError = false
    @State private var errorMessage = ""

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
        NavigationStack {
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
                        .gwTextInputAutocapitalization(.none)
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
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add to Garden") {
                        Task {
                            await saveCustomizedPlant()
                        }
                    }
                    .disabled(customPlantName.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
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
                if (try? await item.loadTransferable(type: Data.self)) != nil {
                    let photoURL = "photo_\(UUID().uuidString)"
                    processedPhotoURLs.append(photoURL)
                }
            }
            customizedPlant.photoURLs = processedPhotoURLs
            
            // Save the customized plant
            try dataService.updatePlant(customizedPlant)
            
            onSave(customizedPlant)
            
        } catch {
            errorMessage = "Failed to save plant: \(error.localizedDescription)"
            showingError = true
        }
    }
}
