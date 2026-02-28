import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

struct AddPlantToGardenFromDatabaseSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService

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
        NavigationStack {
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
                        .pickerStyle(.menu)
                    } header: {
                        Text("Garden")
                    } footer: {
                        Text("Choose which garden to add this plant to")
                    }
                }

                // Location & Planting
                Section {
                    TextField("Location in Garden", text: $location)
                        .gwTextInputAutocapitalization(.words)

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
                    .pickerStyle(.segmented)
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
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .primaryAction) {
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 5)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .task {
                loadData()
            }
        }
    }

    private func loadData() {
        do {
            availableGardens = try dataService.gardens.fetchAll()
        } catch {
            errorMessage = "Could not load gardens: \(error.localizedDescription)"
            showingError = true
            availableGardens = []
        }
        if availableGardens.count == 1 {
            selectedGarden = availableGardens.first
        }
    }

    @MainActor
    private func saveToGarden() async {
        isLoading = true

        do {
            // Create a user instance of the database plant
            let newPlant = Plant(name: plant.name ?? "Unknown Plant", plantType: plant.plantType ?? .houseplant, difficultyLevel: plant.difficultyLevel ?? .beginner, isUserPlant: true)
            newPlant.garden = selectedGarden
            try dataService.plants.add(newPlant)
            let userPlant = newPlant

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
            _ = try dataService.createJournalEntry(
                title: "Added \(userPlant.name ?? "plant") to garden",
                content: "Added from plant database. Location: \(location.isEmpty ? "Not specified" : location)",
                type: .planting,
                plant: userPlant
            )

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
        case .healthy: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .sick: "xmark.octagon.fill"
        case .dying: "exclamationmark.octagon.fill"
        case .dead: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .healthy: .green
        case .needsAttention: .orange
        case .sick: .red
        case .dying: .red
        case .dead: .gray
        }
    }
}
