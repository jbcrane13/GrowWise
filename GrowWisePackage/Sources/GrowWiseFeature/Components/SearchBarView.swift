import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSearchButtonClicked: (() -> Void)? = nil
    var onCancelButtonClicked: (() -> Void)? = nil
    
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isEditing = false
    
    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSearchButtonClicked: (() -> Void)? = nil,
        onCancelButtonClicked: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearchButtonClicked = onSearchButtonClicked
        self.onCancelButtonClicked = onCancelButtonClicked
    }
    
    public var body: some View {
        HStack {
            searchTextField
            
            if isEditing {
                cancelButton
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onChange(of: isSearchFieldFocused) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditing = newValue
            }
        }
    }
    
    private var searchTextField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField(placeholder, text: $text)
                .focused($isSearchFieldFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    // Validate search query before submission
                    let validation = ValidationService.shared.validateSearchQuery(text)
                    if validation.isValid {
                        onSearchButtonClicked?()
                    }
                }
                .onChange(of: text) { _, newValue in
                    // Sanitize input as user types
                    let sanitized = ValidationService.shared.sanitizeInput(newValue)
                    if sanitized != newValue {
                        text = sanitized
                    }
                }
            
            if !text.isEmpty {
                clearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var clearButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                text = ""
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            withAnimation(.easeInOut(duration: 0.2)) {
                text = ""
                isSearchFieldFocused = false
                isEditing = false
            }
            onCancelButtonClicked?()
        }
        .font(.system(size: 16))
        .padding(.leading, 8)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: - Specialized Search Bars

public struct PlantSearchBarView: View {
    @Binding var text: String
    @Binding var selectedFilter: PlantSearchFilter?
    var onFilterChanged: ((PlantSearchFilter?) -> Void)? = nil
    
    @State private var showingFilters = false
    
    public init(
        text: Binding<String>,
        selectedFilter: Binding<PlantSearchFilter?> = .constant(nil),
        onFilterChanged: ((PlantSearchFilter?) -> Void)? = nil
    ) {
        self._text = text
        self._selectedFilter = selectedFilter
        self.onFilterChanged = onFilterChanged
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                SearchBarView(text: $text, placeholder: "Search plants...")
                
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: selectedFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundColor(selectedFilter != nil ? .blue : .secondary)
                }
            }
            
            if let filter = selectedFilter {
                activeFilterView(filter)
            }
        }
        .sheet(isPresented: $showingFilters) {
            PlantFilterSheet(selectedFilter: $selectedFilter) { filter in
                onFilterChanged?(filter)
            }
        }
    }
    
    private func activeFilterView(_ filter: PlantSearchFilter) -> some View {
        HStack {
            Text("Filter: \(filter.displayName)")
                .font(.caption)
                .foregroundColor(.blue)
            
            Button(action: {
                selectedFilter = nil
                onFilterChanged?(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Filter Types

public enum PlantSearchFilter: CaseIterable {
    case plantType(PlantType)
    case difficulty(DifficultyLevel)
    case sunlight(SunlightLevel)
    case watering(WateringFrequency)
    case healthStatus(HealthStatus)
    
    public static var allCases: [PlantSearchFilter] {
        var cases: [PlantSearchFilter] = []
        
        // Add plant types
        cases.append(contentsOf: PlantType.allCases.map { .plantType($0) })
        
        // Add difficulty levels
        cases.append(contentsOf: DifficultyLevel.allCases.map { .difficulty($0) })
        
        // Add sunlight levels
        cases.append(contentsOf: SunlightLevel.allCases.map { .sunlight($0) })
        
        // Add watering frequencies
        cases.append(contentsOf: WateringFrequency.allCases.map { .watering($0) })
        
        // Add health statuses
        cases.append(contentsOf: HealthStatus.allCases.map { .healthStatus($0) })
        
        return cases
    }
    
    public var displayName: String {
        switch self {
        case .plantType(let type):
            return type.displayName
        case .difficulty(let level):
            return level.displayName
        case .sunlight(let level):
            return level.displayName
        case .watering(let frequency):
            return frequency.displayName
        case .healthStatus(let status):
            return status.displayName
        }
    }
    
    public var category: String {
        switch self {
        case .plantType:
            return "Plant Type"
        case .difficulty:
            return "Difficulty"
        case .sunlight:
            return "Sunlight"
        case .watering:
            return "Watering"
        case .healthStatus:
            return "Health"
        }
    }
}

// MARK: - Filter Sheet

struct PlantFilterSheet: View {
    @Binding var selectedFilter: PlantSearchFilter?
    let onFilterSelected: (PlantSearchFilter?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Plant Type") {
                    ForEach(PlantType.allCases, id: \.self) { type in
                        filterRow(for: .plantType(type))
                    }
                }
                
                Section("Difficulty Level") {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        filterRow(for: .difficulty(level))
                    }
                }
                
                Section("Sunlight Requirement") {
                    ForEach(SunlightLevel.allCases, id: \.self) { level in
                        filterRow(for: .sunlight(level))
                    }
                }
                
                Section("Watering Frequency") {
                    ForEach(WateringFrequency.allCases, id: \.self) { frequency in
                        filterRow(for: .watering(frequency))
                    }
                }
                
                Section("Health Status") {
                    ForEach(HealthStatus.allCases, id: \.self) { status in
                        filterRow(for: .healthStatus(status))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedFilter = nil
                        onFilterSelected(nil)
                    }
                    .disabled(selectedFilter == nil)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func filterRow(for filter: PlantSearchFilter) -> some View {
        Button(action: {
            if isSelected(filter) {
                selectedFilter = nil
                onFilterSelected(nil)
            } else {
                selectedFilter = filter
                onFilterSelected(filter)
            }
        }) {
            HStack {
                Text(filter.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected(filter) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func isSelected(_ filter: PlantSearchFilter) -> Bool {
        guard let selectedFilter = selectedFilter else { return false }
        
        switch (filter, selectedFilter) {
        case let (.plantType(a), .plantType(b)):
            return a == b
        case let (.difficulty(a), .difficulty(b)):
            return a == b
        case let (.sunlight(a), .sunlight(b)):
            return a == b
        case let (.watering(a), .watering(b)):
            return a == b
        case let (.healthStatus(a), .healthStatus(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Search Suggestions

public struct SearchSuggestionsView: View {
    let suggestions: [String]
    let onSuggestionTapped: (String) -> Void
    
    public init(suggestions: [String], onSuggestionTapped: @escaping (String) -> Void) {
        self.suggestions = suggestions
        self.onSuggestionTapped = onSuggestionTapped
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBarView(text: .constant(""))
        
        SearchBarView(text: .constant("Tomato"))
        
        PlantSearchBarView(text: .constant(""))
        
        SearchSuggestionsView(
            suggestions: ["Tomato", "Basil", "Rose", "Succulent"],
            onSuggestionTapped: { _ in }
        )
    }
    .padding()
}