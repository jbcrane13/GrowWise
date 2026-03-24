import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftUI

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

    init(
        plant: Plant,
        targetGarden: Garden?,
        dataService: DataService,
        onSave: @escaping (Plant) -> Void,
        onCancel: @escaping () -> Void
    ) {
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
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var plantTypeIcon: String {
        switch plant.plantType {
        case .vegetable: "carrot.fill"
        case .herb: "leaf.fill"
        case .flower: "rosette"
        case .houseplant: "house.fill"
        case .fruit: "apple.whole.fill"
        case .succulent: "circle.grid.3x3.fill"
        case .tree: "tree.fill"
        case .shrub: "leaf.circle.fill"
        case .none: "questionmark.circle.fill"
        }
    }

    @MainActor
    private func saveCustomizedPlant() async {
        do {
            // Create a new plant based on the database plant
            let newPlant = Plant(
                name: customPlantName,
                plantType: plant.plantType ?? .vegetable,
                difficultyLevel: plant.difficultyLevel ?? .beginner,
                isUserPlant: true
            )
            newPlant.garden = targetGarden
            try dataService.plants.add(newPlant)
            let customizedPlant = newPlant

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
            for item in selectedPhotos where await (try? item.loadTransferable(type: Data.self)) != nil {
                let photoURL = "photo_\(UUID().uuidString)"
                processedPhotoURLs.append(photoURL)
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
