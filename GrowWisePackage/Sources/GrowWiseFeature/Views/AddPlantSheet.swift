import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftData
import SwiftUI

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
    @State private var plantingDate: Date = .init()
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
                                    color: CultivationTheme.Colors.brandLeaf,
                                    accessibilityID: "addplant_textfield_name"
                                )
                                .onChange(of: plantName) { _, _ in
                                    updateCompatibilityAnalysis()
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
                                    IconBubble(systemName: "star.fill", color: CultivationTheme.Colors.brandGold, size: 28, iconSize: 13)
                                    Text("Difficulty")
                                        .font(.system(.subheadline, design: .rounded))
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
                                    IconBubble(systemName: "calendar", color: CultivationTheme.Colors.brandForest, size: 28, iconSize: 13)
                                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                                        .font(.system(.subheadline, design: .rounded))
                                        .accessibilityIdentifier("addplant_datepicker_plantingdate")
                                }

                                if !availableGardens.isEmpty {
                                    Divider()
                                        .background(CultivationTheme.Colors.divider)

                                    HStack {
                                        IconBubble(systemName: "location.fill", color: CultivationTheme.Colors.brandLeaf, size: 28, iconSize: 13)
                                        Picker("Garden", selection: $selectedGarden) {
                                            Text("Select Garden").tag(nil as Garden?)
                                            ForEach(availableGardens) { garden in
                                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .accessibilityIdentifier("addplant_picker_garden")
                                        .onChange(of: selectedGarden) { _, _ in
                                            updateCompatibilityAnalysis()
                                        }
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
                                IconBubble(systemName: "note.text", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
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
                                    IconBubble(systemName: "photo.on.rectangle.angled", color: CultivationTheme.Colors.brandLeaf, size: 28, iconSize: 13)
                                    Text("Add Photos")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                                    Spacer()
                                    if !photoURLs.isEmpty {
                                        Text("\(photoURLs.count) selected")
                                            .font(.system(.caption, design: .rounded))
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
            .task {
                loadGardens()
            }
            .accessibilityIdentifier("addPlantSheet")
            .onDisappear {
                saveTask?.cancel()
            }
        }
    }

    // MARK: - Form Section Builder

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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

    @ViewBuilder
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
        } catch {
            errorMessage = "Could not load gardens: \(error.localizedDescription)"
            showingError = true
            availableGardens = []
        }
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
                newPlant.photoURLs = photoURLs.map(\.absoluteString)
            }

            newPlant.garden = selectedGarden
            modelContext.insert(newPlant)
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
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
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
