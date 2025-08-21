import SwiftUI
import SwiftData
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
                        name: garden.name,
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
                plant.name.localizedCaseInsensitiveContains(searchText) ||
                (plant.scientificName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                plant.notes.localizedCaseInsensitiveContains(searchText)
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
            plants.sort { $0.name < $1.name }
        case .dateAdded:
            plants.sort { ($0.plantingDate ?? Date.distantPast) > ($1.plantingDate ?? Date.distantPast) }
        case .healthStatus:
            plants.sort { $0.healthStatus.rawValue < $1.healthStatus.rawValue }
        case .wateringSchedule:
            plants.sort { $0.wateringFrequency.days < $1.wateringFrequency.days }
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
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Add plant to garden functionality will be implemented")
                    .padding()
                
                if let garden = selectedGarden {
                    Text("Target garden: \(garden.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlantDetailView: View {
    let plant: Plant
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plant detail view will be fully implemented")
                    .padding()
                
                Text("Plant: \(plant.name)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let scientificName = plant.scientificName {
                    Text(scientificName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.large)
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