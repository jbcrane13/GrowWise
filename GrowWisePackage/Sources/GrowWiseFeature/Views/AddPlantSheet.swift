import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftData
import SwiftUI

/// Sheet view for adding a new plant to the user's garden.
public struct AddPlantSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService
    @Environment(CompanionPlantingService.self)
    private var companionService
    @Environment(PlantDatabaseService.self)
    private var plantDatabaseService
    @Environment(\.modelContext)
    private var modelContext

    // Form fields
    @State private var plantName: String = ""
    @State private var scientificName: String = ""
    @State private var selectedPlantType: PlantType = .flower
    @State private var selectedDifficultyLevel: DifficultyLevel = .beginner
    @State private var plantingDate: Date = .init()
    @State private var notes: String = ""
    @State private var selectedGarden: Garden?
    @State private var selectedBed: GardenBed?

    // Photo selection
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [URL] = []

    // UI state
    @State private var availableGardens: [Garden] = []
    @State private var availableBeds: [GardenBed] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    // Autocomplete state
    @State private var suggestions: [Plant] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var nameFieldCommitted = false

    // Companion planting analysis
    @State private var compatibilityAnalysis: GardenCompatibilityAnalysis?
    @State private var showCompanionDetails = false

    // Inline creation
    @State private var showCreateGarden = false
    @State private var showCreateBed = false
    @State private var newGardenName = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                        // Drag handle
                        Capsule()
                            .fill(CultivationTheme.Colors.cardBorder)
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        // Basic Information
                        formSection(title: "Basic Information") {
                            VStack(spacing: 12) {
                                styledTextField(
                                    placeholder: "Plant Name",
                                    text: $plantName,
                                    systemImage: "leaf.fill",
                                    color: CultivationTheme.Colors.accentCoral,
                                    accessibilityID: "addplant_textfield_name"
                                )
                                .onChange(of: plantName) { _, newValue in
                                    updateCompatibilityAnalysis()
                                    // Debounced autocomplete
                                    searchTask?.cancel()
                                    nameFieldCommitted = false
                                    guard !newValue.isEmpty else {
                                        suggestions = []
                                        return
                                    }
                                    searchTask = Task {
                                        try? await Task.sleep(for: .milliseconds(300))
                                        guard !Task.isCancelled else { return }
                                        suggestions = plantDatabaseService.searchPlants(query: newValue)
                                    }
                                }

                                if !suggestions.isEmpty, !nameFieldCommitted {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(suggestions, id: \.id) { suggestion in
                                                Button {
                                                    applyTemplate(suggestion)
                                                } label: {
                                                    Text(suggestion.name ?? "")
                                                        .font(.system(.caption, weight: .medium))
                                                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background {
                                                            Capsule()
                                                                .fill(CultivationTheme.Colors.accentCoral.opacity(0.12))
                                                                .overlay {
                                                                    Capsule()
                                                                        .stroke(
                                                                            CultivationTheme.Colors.accentCoral.opacity(0.3),
                                                                            lineWidth: 1
                                                                        )
                                                                }
                                                        }
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityIdentifier("addplant_suggestion_\(suggestion.name ?? "")")
                                            }
                                        }
                                    }
                                }

                                Divider()
                                    .background(CultivationTheme.Colors.divider)

                                styledTextField(
                                    placeholder: "Scientific Name (Optional)",
                                    text: $scientificName,
                                    systemImage: "text.magnifyingglass",
                                    color: CultivationTheme.Colors.brandSage,
                                    accessibilityID: "addplant_textfield_scientificname"
                                )
                            }
                        }

                        // Plant Type — GlassPill chips
                        formSection(title: "Plant Type") {
                            VStack(alignment: .leading, spacing: 10) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(PlantType.allCases, id: \.self) { type in
                                            GlassPill(
                                                label: type.rawValue.capitalized,
                                                isSelected: selectedPlantType == type,
                                                accessibilityID: "addplant_pill_type_\(type.rawValue)"
                                            ) {
                                                selectedPlantType = type
                                            }
                                        }
                                    }
                                }

                                Divider()
                                    .background(CultivationTheme.Colors.divider)

                                // Difficulty
                                HStack {
                                    IconBubble(
                                        systemName: "star.fill",
                                        color: CultivationTheme.Colors.accentAmber,
                                        size: 28,
                                        iconSize: 13
                                    )
                                    Text("Difficulty")
                                        .font(.system(.subheadline))
                                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                    Spacer()
                                    Picker("", selection: $selectedDifficultyLevel) {
                                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                            Text(level.rawValue.capitalized).tag(level)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accessibilityIdentifier("addplant_picker_difficulty")
                                }
                            }
                        }

                        // Planting Information
                        formSection(title: "Planting Information") {
                            VStack(spacing: 12) {
                                HStack {
                                    IconBubble(
                                        systemName: "calendar",
                                        color: CultivationTheme.Colors.brandForest,
                                        size: 28,
                                        iconSize: 13
                                    )
                                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                                        .font(.system(.subheadline))
                                        .accessibilityIdentifier("addplant_datepicker_plantingdate")
                                }

                                if !availableGardens.isEmpty {
                                    Divider()
                                        .background(CultivationTheme.Colors.divider)

                                    HStack {
                                        IconBubble(
                                            systemName: "location.fill",
                                            color: CultivationTheme.Colors.accentCoral,
                                            size: 28,
                                            iconSize: 13
                                        )
                                        Picker("Garden", selection: $selectedGarden) {
                                            Text("Select Garden").tag(nil as Garden?)
                                            ForEach(availableGardens) { garden in
                                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .accessibilityIdentifier("addplant_picker_garden")
                                        .onChange(of: selectedGarden) { _, newGarden in
                                            updateCompatibilityAnalysis()
                                            loadBeds(for: newGarden)
                                            selectedBed = nil
                                        }
                                    }

                                    Divider()
                                        .background(CultivationTheme.Colors.divider)

                                    Button {
                                        showCreateGarden = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("New Garden")
                                                .font(.system(.subheadline))
                                        }
                                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("addplant_button_newgarden")

                                    if selectedGarden != nil {
                                        Divider()
                                            .background(CultivationTheme.Colors.divider)

                                        HStack {
                                            IconBubble(
                                                systemName: "square.split.2x2",
                                                color: CultivationTheme.Colors.brandSage,
                                                size: 28,
                                                iconSize: 13
                                            )
                                            Picker("Container", selection: $selectedBed) {
                                                Text("Unassigned").tag(nil as GardenBed?)
                                                ForEach(availableBeds) { bed in
                                                    Label(bed.name ?? "Unnamed", systemImage: bed.bedType?.iconName ?? "tray")
                                                        .tag(bed as GardenBed?)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .accessibilityIdentifier("addplant_picker_bed")
                                        }

                                        Divider()
                                            .background(CultivationTheme.Colors.divider)

                                        Button {
                                            showCreateBed = true
                                        } label: {
                                            HStack {
                                                Image(systemName: "plus.circle")
                                                    .font(.system(size: 14, weight: .medium))
                                                Text("New Container")
                                                    .font(.system(.subheadline))
                                            }
                                            .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("addplant_button_newcontainer")
                                    }
                                }
                            }
                        }

                        // Companion Planting (conditional)
                        if let analysis = compatibilityAnalysis, !plantName.isEmpty {
                            CompanionPlantingSection(analysis: analysis, showDetails: $showCompanionDetails)
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        }

                        // Notes
                        formSection(title: "Notes") {
                            HStack(alignment: .top, spacing: 10) {
                                IconBubble(
                                    systemName: "note.text",
                                    color: CultivationTheme.Colors.brandSage,
                                    size: 28,
                                    iconSize: 13
                                )
                                .padding(.top, 2)

                                TextEditor(text: $notes)
                                    .frame(minHeight: 80)
                                    .font(.system(.body))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .accessibilityIdentifier("addplant_texteditor_notes")
                                    .overlay(alignment: .topLeading) {
                                        if notes.isEmpty {
                                            Text("Add notes about this plant...")
                                                .font(.system(.body))
                                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                        }

                        // Photos
                        formSection(title: "Photos") {
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 5,
                                matching: .images
                            ) {
                                HStack(spacing: 10) {
                                    IconBubble(
                                        systemName: "photo.on.rectangle.angled",
                                        color: CultivationTheme.Colors.accentCoral,
                                        size: 28,
                                        iconSize: 13
                                    )
                                    Text("Add Photos")
                                        .font(.system(.subheadline))
                                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                                    Spacer()
                                    if !photoURLs.isEmpty {
                                        Text("\(photoURLs.count) selected")
                                            .font(.system(.caption))
                                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("addplant_button_addphotos")
                        }

                        // Save Button
                        Button {
                            saveTask = Task { await savePlant() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text(isSaving ? "Saving..." : "Add Plant")
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDisabled: plantName.isEmpty || isSaving))
                        .disabled(plantName.isEmpty || isSaving)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("addplant_button_save")
                        .padding(.bottom, 24)
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
                    .accessibilityIdentifier("addplant_button_cancel")
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
            .alert("New Garden", isPresented: $showCreateGarden) {
                TextField("Garden name", text: $newGardenName)
                    .accessibilityIdentifier("addplant_alert_textfield_gardenname")
                Button("Create") {
                    createGarden()
                }
                .accessibilityIdentifier("addplant_alert_button_creategarden")
                Button("Cancel", role: .cancel) {
                    newGardenName = ""
                }
            } message: {
                Text("Name your new garden")
            }
            .sheet(isPresented: $showCreateBed) {
                if let garden = selectedGarden {
                    CreateBedSheet(garden: garden) { newBed in
                        loadBeds(for: garden)
                        selectedBed = newBed
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                }
            }
            .task {
                loadGardens()
            }
            .accessibilityIdentifier("addPlantSheet")
            .onDisappear {
                saveTask?.cancel()
                searchTask?.cancel()
            }
        }
    }

    // MARK: - Form Section Builder

    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            content()
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        }
    }

    // MARK: - Styled Text Field

    private func styledTextField(
        placeholder: String,
        text: Binding<String>,
        systemImage: String,
        color: Color,
        accessibilityID: String
    ) -> some View {
        HStack(spacing: 10) {
            IconBubble(systemName: systemImage, color: color, size: 28, iconSize: 13)
            TextField(placeholder, text: text)
                .font(.system(.body))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .accessibilityIdentifier(accessibilityID)
        }
    }

    // MARK: - Data Methods

    private func loadGardens() {
        do {
            availableGardens = try dataService.gardens.fetchAll()
            if selectedGarden == nil, let first = availableGardens.first {
                selectedGarden = first
                loadBeds(for: first)
            }
        } catch {
            errorMessage = "Could not load gardens: \(error.localizedDescription)"
            showingError = true
            availableGardens = []
        }
    }

    @MainActor
    private func createGarden() {
        let name = newGardenName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let garden = Garden(name: name)
        modelContext.insert(garden)
        newGardenName = ""
        // Reload and select the new garden
        loadGardens()
        selectedGarden = availableGardens.last(where: { $0.name == name })
    }

    private func loadBeds(for garden: Garden?) {
        guard let garden else {
            availableBeds = []
            return
        }
        availableBeds = (garden.beds ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func updateCompatibilityAnalysis() {
        guard !plantName.isEmpty,
              companionService.isPlantKnown(plantName),
              let garden = selectedGarden,
              let plants = garden.plants
        else {
            compatibilityAnalysis = nil
            return
        }

        let existingPlantNames = plants.compactMap(\.name)
        compatibilityAnalysis = companionService.analyzeGardenCompatibility(
            plantName: plantName,
            existingPlants: existingPlantNames
        )
    }

    private func applyTemplate(_ plant: Plant) {
        plantName = plant.name ?? plantName
        scientificName = plant.scientificName ?? scientificName
        if let type = plant.plantType { selectedPlantType = type }
        if let diff = plant.difficultyLevel { selectedDifficultyLevel = diff }
        suggestions = []
        nameFieldCommitted = true
    }

    @MainActor
    private func savePlant() async {
        guard !plantName.isEmpty else {
            errorMessage = "Plant name is required"
            showingError = true
            return
        }

        isSaving = true

        let newPlant = Plant(
            name: plantName,
            plantType: selectedPlantType,
            difficultyLevel: selectedDifficultyLevel
        )

        newPlant.scientificName = scientificName.isEmpty ? nil : scientificName
        newPlant.plantingDate = plantingDate
        newPlant.bed = selectedBed
        newPlant.notes = notes.isEmpty ? nil : notes

        if !photoURLs.isEmpty {
            newPlant.photoURLs = photoURLs.map(\.absoluteString)
        }

        newPlant.garden = selectedGarden
        modelContext.insert(newPlant)
        dismiss()
    }
}

// MARK: - Companion Planting Section

struct CompanionPlantingSection: View {
    let analysis: GardenCompatibilityAnalysis
    @Binding var showDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Companion Planting")
                .sectionLabelStyle()

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
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    .accessibilityIdentifier("addplant_button_companiondetails")
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
                                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                            }
                        }
                    }
                }

                if !analysis.recommendedCompanions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Good companions for this garden:")
                            .font(.caption)
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)

                        FlowLayout(spacing: 4) {
                            ForEach(analysis.recommendedCompanions.prefix(5), id: \.self) { companion in
                                GlassPill(
                                    label: companion,
                                    isSelected: false,
                                    accessibilityID: "addplant_pill_companion_\(companion)"
                                ) {}
                            }
                        }
                    }
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    private var compatibilityColor: Color {
        switch analysis.overallCompatibility {
        case .companion: .green
        case .neutral: .gray
        case .incompatible: .red
        }
    }
}

// MARK: - Companion Details Sheet

struct CompanionDetailsSheet: View {
    let analysis: GardenCompatibilityAnalysis
    @Environment(\.dismiss)
    private var dismiss

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
                                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
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
                    .accessibilityIdentifier("companiondetails_button_done")
                }
            }
        }
    }

    private var compatibilityColor: Color {
        switch analysis.overallCompatibility {
        case .companion: .green
        case .neutral: .gray
        case .incompatible: .red
        }
    }

    private func relationshipColor(_ compatibility: PlantCompatibility) -> Color {
        switch compatibility {
        case .companion: .green
        case .neutral: .gray
        case .incompatible: .red
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
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
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
