import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Browse and search the Perenual plant database (10K+ species).
/// Shown as a tab/section within the Plant Guide when an API key is configured.
public struct PerenualBrowseView: View {
    @Environment(PerenualAPIService.self)
    private var api
    @Environment(DataService.self)
    private var dataService

    @State private var results: [PerenualSpeciesSummary] = []
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var totalResults = 0
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var selectedDetail: PerenualSpeciesDetail?
    @State private var showingDetail = false
    @State private var loadingDetailId: Int?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if !hasLoadedOnce, isLoading {
                initialLoadingView
            } else if results.isEmpty, hasLoadedOnce {
                emptyState
            } else {
                resultsList
            }
        }
        .searchable(text: $searchText, prompt: "Search 10,000+ plants...")
        .onSubmit(of: .search) {
            Task { await search() }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task { await loadInitial() }
            }
        }
        .task {
            if !hasLoadedOnce {
                await loadInitial()
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let detail = selectedDetail {
                PerenualDetailView(detail: detail)
            }
        }
    }

    // MARK: - Views

    private var initialLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading plant database...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Plants Found", systemImage: "leaf.fill")
        } description: {
            if !searchText.isEmpty {
                Text("Try a different search term")
            } else if let error = api.lastError {
                Text(error)
            } else {
                Text("Unable to load plants")
            }
        } actions: {
            Button("Try Again") {
                Task { await searchText.isEmpty ? loadInitial() : search() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
                // Results header
                if totalResults > 0 {
                    HStack {
                        Text("\(totalResults) species")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        Spacer()
                        Text("Page \(currentPage) of \(totalPages)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 4)
                }

                ForEach(results) { species in
                    PerenualSpeciesCard(
                        species: species,
                        isLoadingDetail: loadingDetailId == species.id
                    ) {
                        Task { await loadDetail(species) }
                    }
                }

                // Pagination
                if totalPages > 1 {
                    paginationControls
                }

                // Loading indicator at bottom
                if isLoading, hasLoadedOnce {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    private var paginationControls: some View {
        HStack(spacing: 16) {
            Button {
                Task { await loadPage(currentPage - 1) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .disabled(currentPage <= 1 || isLoading)
            .accessibilityIdentifier("perenual_prev_page")

            Spacer()

            Button {
                Task { await loadPage(currentPage + 1) }
            } label: {
                HStack(spacing: 6) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .disabled(currentPage >= totalPages || isLoading)
            .accessibilityIdentifier("perenual_next_page")
        }
        .tint(CultivationTheme.Colors.brandForest)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func loadInitial() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        do {
            let response = try await api.fetchSpeciesList(page: 1)
            results = response.data
            currentPage = response.currentPage
            totalPages = response.lastPage
            totalResults = response.total
        } catch {
            // Keep existing results if any
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        do {
            let response = try await api.fetchSpeciesList(query: searchText, page: 1)
            results = response.data
            currentPage = response.currentPage
            totalPages = response.lastPage
            totalResults = response.total
        } catch {
            // Keep existing results
        }
    }

    private func loadPage(_ page: Int) async {
        guard page >= 1, page <= totalPages else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.fetchSpeciesList(
                query: searchText.isEmpty ? nil : searchText,
                page: page
            )
            results = response.data
            currentPage = response.currentPage
            totalPages = response.lastPage
            totalResults = response.total
        } catch {
            // Keep current page
        }
    }

    private func loadDetail(_ species: PerenualSpeciesSummary) async {
        loadingDetailId = species.id
        defer { loadingDetailId = nil }
        do {
            selectedDetail = try await api.fetchSpeciesDetail(id: species.id)
            showingDetail = true
        } catch {
            // Show error inline
        }
    }
}

// MARK: - Species Card

struct PerenualSpeciesCard: View {
    let species: PerenualSpeciesSummary
    var isLoadingDetail: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)

                    case .failure:
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)

                    default:
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon))
                .overlay {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(species.commonName)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if let sci = species.scientificName.first {
                        Text(sci)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            .italic()
                            .lineLimit(1)
                    }

                    if let family = species.family {
                        Text(family)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                }

                Spacer()

                if isLoadingDetail {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
        .disabled(isLoadingDetail)
        .accessibilityIdentifier("perenual_species_\(species.id)")
    }

    private var thumbnailURL: URL? {
        guard let urlString = species.defaultImage?.thumbnail ?? species.defaultImage?.smallUrl else {
            return nil
        }
        return URL(string: urlString)
    }
}

// MARK: - Detail View

struct PerenualDetailView: View { // swiftlint:disable:this type_body_length
    let detail: PerenualSpeciesDetail
    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService
    @Environment(PlantDatabaseService.self)
    private var plantDatabaseService
    @State private var showAddConfirmation = false
    @State private var availableGardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    // Hero image
                    heroImage

                    VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                        // Name & taxonomy
                        headerSection

                        // Quick facts grid
                        quickFactsGrid

                        // Description
                        if let desc = detail.description, !desc.isEmpty {
                            descriptionSection(desc)
                        }

                        // Care instructions
                        careSection

                        // Safety warnings
                        safetySection

                        gardenSelectionSection

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle(detail.commonName)
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                addToGardenOverlay
            }
            .alert("Added to Garden", isPresented: $showAddConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(detail.commonName) has been added to your plant collection.")
            }
            .alert("Couldn't add plant", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task { loadGardens() }
        }
    }

    // MARK: - Sections

    private var heroImage: some View {
        AsyncImage(url: heroImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()

            case .failure:
                ZStack {
                    CultivationTheme.Colors.backgroundSecondary
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.3))
                }
                .frame(height: 160)

            default:
                ZStack {
                    CultivationTheme.Colors.backgroundSecondary
                    ProgressView()
                }
                .frame(height: 220)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let sci = detail.scientificName.first {
                Text(sci)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .italic()
            }

            HStack(spacing: 8) {
                if let family = detail.family {
                    infoPill(family, color: CultivationTheme.Colors.brandLeaf)
                }
                if let cycle = detail.cycle {
                    infoPill(cycle, color: CultivationTheme.Colors.accentAmber)
                }
                if let type = detail.type {
                    infoPill(type.capitalized, color: CultivationTheme.Colors.brandForest)
                }
            }
        }
    }

    private var quickFactsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 10) {
            factCard(icon: "drop.fill", color: .blue, label: "Watering", value: detail.watering ?? "Unknown")
            factCard(
                icon: "sun.max.fill",
                color: .yellow,
                label: "Sunlight",
                value: detail.sunlight?.first?.capitalized ?? "Unknown"
            )
            factCard(
                icon: "gauge.medium",
                color: .purple,
                label: "Care Level",
                value: detail.careLevel ?? "Unknown"
            )
            factCard(
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                label: "Growth",
                value: detail.growthRate ?? "Unknown"
            )

            if let hardiness = detail.hardiness, let minZone = hardiness.min {
                let zoneText: String = {
                    if let maxZone = hardiness.max, maxZone != minZone {
                        return "Zones \(minZone)–\(maxZone)"
                    }
                    return "Zone \(minZone)"
                }()
                factCard(icon: "thermometer", color: CultivationTheme.Colors.accentCoral, label: "Hardiness", value: zoneText)
            }

            if let maintenance = detail.maintenance {
                factCard(
                    icon: "wrench.fill",
                    color: .orange,
                    label: "Maintenance",
                    value: maintenance
                )
            }
        }
    }

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .sectionLabelStyle()
                .padding(.leading, 4)

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .padding(CultivationTheme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        }
    }

    private var careSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Care Instructions")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(detail.mappedCareInstructions, id: \.self) { instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                            .padding(.top, 2)
                        Text(instruction)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    }
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    private var safetySection: some View {
        let warnings: [(String, String)] = {
            var collected: [(String, String)] = []
            if detail.poisonousToPets == true { collected.append(("pawprint.fill", "Toxic to pets")) }
            if detail.poisonousToHumans == true { collected.append(("person.fill.xmark", "Toxic to humans")) }
            if detail.invasive == true { collected.append(("exclamationmark.triangle.fill", "Invasive species")) }
            if detail.thorny == true { collected.append(("bolt.fill", "Has thorns")) }
            return collected
        }()

        return Group {
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Safety")
                        .sectionLabelStyle()
                        .padding(.leading, 4)

                    VStack(spacing: 8) {
                        ForEach(warnings, id: \.1) { icon, text in
                            HStack(spacing: 10) {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(CultivationTheme.Colors.statusAlert)
                                Text(text)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                Spacer()
                            }
                        }
                    }
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                }
            }
        }
    }

    private var addToGardenOverlay: some View {
        Button {
            addToGarden()
        } label: {
            Text("Add to My Garden")
        }
        .buttonStyle(GradientButtonStyle(isDisabled: selectedGarden == nil))
        .disabled(selectedGarden == nil)
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.bottom, 16)
        .background {
            LinearGradient(
                colors: [
                    CultivationTheme.Colors.background.opacity(0),
                    CultivationTheme.Colors.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
        .accessibilityIdentifier("perenual_add_to_garden")
    }

    private var gardenSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add to")
                .sectionLabelStyle()
                .padding(.leading, 4)

            if availableGardens.isEmpty {
                Text("Create a garden before adding this plant.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                Picker("Garden", selection: $selectedGarden) {
                    ForEach(availableGardens) { garden in
                        Text(garden.name ?? "Garden").tag(garden as Garden?)
                    }
                }
                .pickerStyle(.menu)
                .padding(CultivationTheme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                .accessibilityIdentifier("perenual_picker_garden")
            }
        }
    }

    // MARK: - Helpers

    private var heroImageURL: URL? {
        guard let urlString = detail.defaultImage?.bestURL else { return nil }
        return URL(string: urlString)
    }

    private func infoPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func factCard(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
    }

    private func addToGarden() {
        guard let selectedGarden else {
            errorMessage = "Create or select a garden before adding this plant."
            showingError = true
            return
        }

        do {
            let care = detail.mappedCareInstructions
            let careText = care.isEmpty ? "" : "\n\nCare Instructions:\n" + care.map { "• \($0)" }.joined(separator: "\n")
            try plantDatabaseService.insertExternalPlant(
                name: detail.commonName,
                scientificName: detail.scientificName.first,
                type: detail.mappedPlantType,
                difficulty: detail.mappedDifficultyLevel,
                sunlight: detail.mappedSunlightLevel,
                watering: detail.mappedWateringFrequency,
                space: detail.mappedSpaceRequirement,
                notes: (detail.description ?? "") + careText
            )
            try dataService.createUserPlant(from: detail, in: selectedGarden)
            showAddConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func loadGardens() {
        availableGardens = dataService.fetchGardens(limit: 50)
        if selectedGarden == nil {
            selectedGarden = availableGardens.first
        }
    }
}

// swiftlint:disable:this file_length
