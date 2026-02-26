import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

/// Sheet view for adding a new plant to the user's garden.
public struct AddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(CompanionPlantingService.self) private var companionService
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
    @State private var saveTask: Task<Void, Never>?
    
    // Companion planting analysis
    @State private var compatibilityAnalysis: GardenCompatibilityAnalysis?
    @State private var showCompanionDetails = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Plant Name", text: $plantName)
                        .accessibilityLabel("Plant name text field")
                        .onChange(of: plantName) { _, _ in
                            updateCompatibilityAnalysis()
                        }
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
                        .onChange(of: selectedGarden) { _, _ in
                            updateCompatibilityAnalysis()
                        }
                    }
                }
                
                // Companion Planting Section
                if let analysis = compatibilityAnalysis, !plantName.isEmpty {
                    CompanionPlantingSection(analysis: analysis, showDetails: $showCompanionDetails)
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
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask = Task {
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
            .sheet(isPresented: $showCompanionDetails) {
                if let analysis = compatibilityAnalysis {
                    CompanionDetailsSheet(analysis: analysis)
                }
            }
            .onAppear {
                loadGardens()
            }
            .accessibilityIdentifier("addPlantSheet")
            .onDisappear {
                saveTask?.cancel()
            }
        }
    }

    private func loadGardens() {
        availableGardens = dataService.fetchGardens()
    }
    
    private func updateCompatibilityAnalysis() {
        guard !plantName.isEmpty,
              companionService.isPlantKnown(plantName),
              let garden = selectedGarden,
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

            newPlant.scientificName = scientificName.isEmpty ? nil : scientificName
            newPlant.plantingDate = plantingDate
            newPlant.notes = notes.isEmpty ? nil : notes

            if !photoURLs.isEmpty {
                newPlant.photoURLs = photoURLs.map { $0.absoluteString }
            }

            newPlant.garden = selectedGarden
            modelContext.insert(newPlant)
            
            NotificationCenter.default.post(name: Notification.Name("PlantCreated"), object: nil)
        } catch {
            errorMessage = "Failed to save plant: \(error.localizedDescription)"
            showingError = true
        }

        isSaving = false
    }
}

// MARK: - Companion Planting Section

struct CompanionPlantingSection: View {
    let analysis: GardenCompatibilityAnalysis
    @Binding var showDetails: Bool
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: analysis.overallCompatibility.iconName)
                        .foregroundColor(compatibilityColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Companion Planting")
                            .font(.headline)
                        Text(analysis.overallCompatibility.displayName)
                            .font(.caption)
                            .foregroundColor(compatibilityColor)
                    }
                    
                    Spacer()
                    
                    Button("Details") {
                        showDetails = true
                    }
                    .font(.caption)
                }
                
                if analysis.hasWarnings {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(analysis.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(warning)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if !analysis.recommendedCompanions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good companions for this garden:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 4) {
                            ForEach(analysis.recommendedCompanions.prefix(5), id: \.self) { companion in
                                Text(companion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var compatibilityColor: Color {
        switch analysis.overallCompatibility {
        case .companion: return .green
        case .neutral: return .gray
        case .incompatible: return .red
        }
    }
}

// MARK: - Companion Details Sheet

struct CompanionDetailsSheet: View {
    let analysis: GardenCompatibilityAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Overall Compatibility") {
                    HStack {
                        Image(systemName: analysis.overallCompatibility.iconName)
                            .foregroundColor(compatibilityColor)
                            .font(.title2)
                        Text(analysis.overallCompatibility.displayName)
                            .font(.headline)
                    }
                }
                
                if !analysis.incompatiblePlants.isEmpty {
                    Section("Incompatible Plants") {
                        ForEach(analysis.incompatiblePlants, id: \.self) { plant in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(plant)
                            }
                        }
                    }
                }
                
                if !analysis.recommendedCompanions.isEmpty {
                    Section("Recommended Companions") {
                        ForEach(analysis.recommendedCompanions, id: \.self) { plant in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(plant)
                            }
                        }
                    }
                }
                
                if !analysis.relationships.isEmpty {
                    Section("Detailed Relationships") {
                        ForEach(analysis.relationships) { relationship in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: relationship.compatibility.iconName)
                                        .foregroundColor(relationshipColor(relationship.compatibility))
                                    Text(relationship.plantName)
                                        .font(.headline)
                                    Spacer()
                                    Text(relationship.compatibility.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(relationshipColor(relationship.compatibility))
                                }
                                Text(relationship.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Compatibility Analysis")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var compatibilityColor: Color {
        switch analysis.overallCompatibility {
        case .companion: return .green
        case .neutral: return .gray
        case .incompatible: return .red
        }
    }
    
    private func relationshipColor(_ compatibility: PlantCompatibility) -> Color {
        switch compatibility {
        case .companion: return .green
        case .neutral: return .gray
        case .incompatible: return .red
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    AddPlantSheet()
}
