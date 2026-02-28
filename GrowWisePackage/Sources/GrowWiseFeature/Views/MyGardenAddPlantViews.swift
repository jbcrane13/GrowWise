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
    @Environment(CompanionPlantingService.self) private var companionService

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

    // Companion planting analysis
    @State private var compatibilityAnalysis: GardenCompatibilityAnalysis?
    @State private var showCompanionDetails = false

    // UI state
    @State private var availableGardens: [Garden] = []
    @State private var targetGarden: Garden?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var showingCreateGarden = false

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
            .sheet(isPresented: $showCompanionDetails) {
                if let analysis = compatibilityAnalysis {
                    CompanionDetailsSheet(analysis: analysis)
                }
            }
            .task {
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
        .sheet(isPresented: $showingCreateGarden, onDismiss: {
            setupInitialState()
        }) {
            CreateGardenSheet()
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
                            showingCreateGarden = true
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
                    .onChange(of: targetGarden) { _, _ in
                        updateCompatibilityAnalysis()
                    }
                }
            }

            // Basic Information Section
            Section("Basic Information") {
                TextField("Name", text: $plantName)
                    .autocorrectionDisabled()
                    .onChange(of: plantName) { _, _ in
                        updateCompatibilityAnalysis()
                    }

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

            // Companion Planting Section
            if let analysis = compatibilityAnalysis, !plantName.isEmpty {
                CompanionPlantingSection(analysis: analysis, showDetails: $showCompanionDetails)
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
                    ContentUnavailableView.search(text: searchText)
                        .background(Color(.systemGroupedBackground))
                } else if filteredPlants.isEmpty {
                    ContentUnavailableView(
                        "Plant Database Empty",
                        systemImage: "books.vertical",
                        description: Text("The plant database needs to be populated first.")
                    )
                    .background(Color(.systemGroupedBackground))
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
        do {
            availableGardens = try dataService.gardens.fetchAll()
        } catch {
            errorMessage = "Could not load gardens: \(error.localizedDescription)"
            showingError = true
            availableGardens = []
        }
    }

    private func updateCompatibilityAnalysis() {
        let garden = selectedGarden ?? targetGarden
        guard !plantName.isEmpty,
              companionService.isPlantKnown(plantName),
              let garden,
              let plants = garden.plants else {
            compatibilityAnalysis = nil
            return
        }

        let existingPlantNames = plants.compactMap { $0.name }
        compatibilityAnalysis = companionService.analyzeGardenCompatibility(
            plantName: plantName,
            existingPlants: existingPlantNames
        )
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
            let newPlant = Plant(name: plantName, plantType: selectedPlantType, difficultyLevel: selectedDifficultyLevel, isUserPlant: true)
            newPlant.garden = selectedGarden ?? targetGarden
            try dataService.plants.add(newPlant)
            let plant = newPlant

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
