import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

/// Sheet view for adding a new plant to the user's garden.
public struct AddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext

    // Form fields
    @State private var plantName: String = ""
    @State private var scientificName: String = ""
    @State private var selectedPlantType: PlantType = .flower
    @State private var selectedDifficultyLevel: DifficultyLevel = .beginner
    @State private var plantingDate: Date = Date()
    @State private var notes: String = ""
    @State private var selectedGarden: Garden?

    // Photo selection
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [URL] = []

    // UI state
    @State private var availableGardens: [Garden] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Plant Name", text: $plantName)
                        .accessibilityLabel("Plant name text field")
                    TextField("Scientific Name (Optional)", text: $scientificName)
                        .accessibilityLabel("Scientific name text field")
                }

                Section("Plant Details") {
                    Picker("Type", selection: $selectedPlantType) {
                        ForEach(PlantType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .accessibilityLabel("Plant type picker")

                    Picker("Difficulty", selection: $selectedDifficultyLevel) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .accessibilityLabel("Difficulty level picker")
                }

                Section("Planting Information") {
                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                        .accessibilityLabel("Planting date picker")

                    if !availableGardens.isEmpty {
                        Picker("Garden", selection: $selectedGarden) {
                            Text("Select Garden").tag(nil as Garden?)
                            ForEach(availableGardens) { garden in
                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                            }
                        }
                        .accessibilityLabel("Garden selection picker")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .accessibilityLabel("Plant notes text editor")
                }

                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .accessibilityLabel("Add plant photos button")

                    if !photoURLs.isEmpty {
                        Text("\(photoURLs.count) photo(s) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add New Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await savePlant()
                        }
                    }
                    .disabled(plantName.isEmpty || isSaving)
                    .accessibilityHint("Saves the plant to your garden")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadGardens()
            }
            .accessibilityIdentifier("addPlantSheet")
        }
    }

    private func loadGardens() {
        availableGardens = dataService.fetchGardens()
    }

    @MainActor
    private func savePlant() async {
        guard !plantName.isEmpty else {
            errorMessage = "Plant name is required"
            showingError = true
            return
        }

        isSaving = true

        do {
            let newPlant = Plant(
                name: plantName,
                plantType: selectedPlantType,
                difficultyLevel: selectedDifficultyLevel
            )

            // Assign additional metadata after initialization
            newPlant.scientificName = scientificName.isEmpty ? nil : scientificName
            newPlant.plantingDate = plantingDate
            newPlant.notes = notes.isEmpty ? nil : notes

            // Convert photoURLs to String array if needed
            if !photoURLs.isEmpty {
                newPlant.photoURLs = photoURLs.map { $0.absoluteString }
            }

            // Assign garden and insert plant
            newPlant.garden = selectedGarden
            modelContext.insert(newPlant)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save plant: \(error.localizedDescription)"
            showingError = true
        }

        isSaving = false
    }
}

#Preview {
    AddPlantSheet()
}
