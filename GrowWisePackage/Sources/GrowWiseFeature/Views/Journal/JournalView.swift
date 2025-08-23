import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

public struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    @Query private var plants: [Plant]
    
    @StateObject private var photoService = PhotoService(dataService: try! DataService())
    
    @State private var searchText = ""
    @State private var selectedPlant: Plant?
    @State private var selectedEntryType: JournalEntryType?
    @State private var showingAddEntry = false
    @State private var selectedEntry: JournalEntry?
    @State private var sortOrder = SortOrder.dateDescending
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter section
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search journal entries...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            JournalFilterChip(
                                title: "All Plants",
                                isSelected: selectedPlant == nil,
                                action: { selectedPlant = nil }
                            )
                            
                            ForEach(plants.filter { $0.isUserPlant ?? false }) { plant in
                                JournalFilterChip(
                                    title: plant.name ?? "Unknown Plant",
                                    isSelected: selectedPlant?.id == plant.id,
                                    action: { selectedPlant = plant }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            JournalFilterChip(
                                title: "All Types",
                                isSelected: selectedEntryType == nil,
                                action: { selectedEntryType = nil }
                            )
                            
                            ForEach(JournalEntryType.allCases, id: \.self) { type in
                                JournalFilterChip(
                                    title: type.displayName,
                                    isSelected: selectedEntryType == type,
                                    action: { selectedEntryType = type }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                
                // Sort picker
                HStack {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Journal entries list
                if filteredEntries.isEmpty {
                    EmptyJournalView(hasEntries: !journalEntries.isEmpty)
                } else {
                    List {
                        ForEach(groupedEntries.keys.sorted(by: sortGroupsByDate), id: \.self) { date in
                            Section {
                                ForEach(groupedEntries[date] ?? []) { entry in
                                    JournalEntryRow(
                                        entry: entry,
                                        photoService: photoService
                                    )
                                    .onTapGesture {
                                        selectedEntry = entry
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteEntries(at: indexSet, in: groupedEntries[date] ?? [])
                                }
                            } header: {
                                Text(formatSectionDate(date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Plant Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddJournalEntryView(photoService: photoService)
            }
            .sheet(item: $selectedEntry) { entry in
                JournalEntryDetailView(
                    entry: entry,
                    photoService: photoService
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [JournalEntry] {
        var entries = journalEntries
        
        // Filter by search text
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                (entry.plant?.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Filter by plant
        if let selectedPlant = selectedPlant {
            entries = entries.filter { $0.plant?.id == selectedPlant.id }
        }
        
        // Filter by entry type
        if let selectedEntryType = selectedEntryType {
            entries = entries.filter { $0.entryType == selectedEntryType }
        }
        
        // Sort entries
        switch sortOrder {
        case .dateAscending:
            entries.sort { $0.entryDate < $1.entryDate }
        case .dateDescending:
            entries.sort { $0.entryDate > $1.entryDate }
        case .plantName:
            entries.sort { ($0.plant?.name ?? "") < ($1.plant?.name ?? "") }
        case .entryType:
            entries.sort { $0.entryType.displayName < $1.entryType.displayName }
        }
        
        return entries
    }
    
    private var groupedEntries: [String: [JournalEntry]] {
        Dictionary(grouping: filteredEntries) { entry in
            formatDateForGrouping(entry.entryDate)
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteEntries(at offsets: IndexSet, in entries: [JournalEntry]) {
        for index in offsets {
            let entry = entries[index]
            modelContext.delete(entry)
        }
    }
    
    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatDateForGrouping(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func sortGroupsByDate(_ lhs: String, _ rhs: String) -> Bool {
        switch sortOrder {
        case .dateAscending:
            return lhs < rhs
        case .dateDescending:
            return lhs > rhs
        default:
            return lhs > rhs // Default to newest first
        }
    }
}

// MARK: - Supporting Views

private struct JournalFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct EmptyJournalView: View {
    let hasEntries: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasEntries ? "magnifyingglass" : "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(hasEntries ? "No entries found" : "Start Your Plant Journal")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(hasEntries ? 
                     "Try adjusting your search or filters to find entries." :
                     "Document your plant care journey with photos and notes."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }
            
            if !hasEntries {
                Button("Add Your First Entry") {
                    // This will be handled by the parent view
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Supporting Types

private enum SortOrder: String, CaseIterable {
    case dateDescending = "date_desc"
    case dateAscending = "date_asc" 
    case plantName = "plant_name"
    case entryType = "entry_type"
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .plantName: return "Plant Name"
        case .entryType: return "Entry Type"
        }
    }
}

#Preview {
    JournalView()
        .modelContainer(for: [JournalEntry.self, Plant.self], inMemory: true)
}