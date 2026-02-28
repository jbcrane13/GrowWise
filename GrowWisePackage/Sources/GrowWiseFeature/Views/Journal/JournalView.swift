#if canImport(UIKit)
import GrowWiseModels
import GrowWiseServices
import SwiftData
import SwiftUI

public struct JournalView: View {
    @Environment(DataService.self) private var dataService
    @Environment(PhotoService.self) private var photoService
    @State private var journalEntries: [JournalEntry] = []
    @State private var plants: [Plant] = []
    @State private var hasMoreData = true
    @State private var currentOffset = 0

    @State private var searchText = ""
    @State private var selectedPlant: Plant?
    @State private var selectedEntryType: JournalEntryType?
    @State private var showingAddEntry = false
    @State private var selectedEntry: JournalEntry?
    @State private var sortOrder = SortOrder.dateDescending
    @State private var isLoadingMore = false
    @State private var visibleEntryCount = 20
    @State private var filteredCache: [JournalEntry]?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter section
                VStack(spacing: 12) {
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
                    .pickerStyle(.segmented)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Journal entries list with pagination
                if journalEntries.isEmpty {
                    emptyJournalView
                } else {
                    List {
                        ForEach(paginatedGroupedEntries.keys.sorted(by: sortGroupsByDate), id: \.self) { date in
                            Section {
                                ForEach(paginatedGroupedEntries[date] ?? [], id: \.id) { entry in
                                    JournalEntryRow(
                                        entry: entry,
                                        photoService: photoService
                                    )
                                    .onTapGesture {
                                        selectedEntry = entry
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteEntries(at: indexSet, in: paginatedGroupedEntries[date] ?? [])
                                }
                            } header: {
                                Text(formatSectionDate(date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Load more button
                        if hasMoreData {
                            HStack {
                                Spacer()
                                if isLoadingMore {
                                    ProgressView()
                                        .padding()
                                } else {
                                    Button("Load More") {
                                        loadMoreEntries()
                                    }
                                    .padding()
                                    .foregroundColor(.accentColor)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Plant Journal")
            .gwNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
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
            // Native SwiftUI search with built-in debouncing - no manual Task management needed

            .task {
                loadInitialData()
            }
            .onChange(of: searchText) { _, _ in
                filteredCache = nil
                loadFilteredData(reset: true)
            }
            .onChange(of: selectedPlant) { _, _ in
                loadFilteredData(reset: true)
            }
            .onChange(of: selectedEntryType) { _, _ in
                loadFilteredData(reset: true)
            }
            .onChange(of: sortOrder) { _, _ in
                loadFilteredData(reset: true)
            }

            .searchable(text: $searchText, prompt: "Search journal entries...")
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var emptyJournalView: some View {
        Group {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView(
                    "Start Your Plant Journal",
                    systemImage: "book.closed",
                    description: Text("Document your plant care journey with photos and notes.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var paginatedGroupedEntries: [String: [JournalEntry]] {
        Dictionary(grouping: journalEntries) { entry in
            formatDateForGrouping(entry.entryDate)
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        do {
            plants = try dataService.plants.fetchAll()
        } catch {
            alertTitle = "Error"
            alertMessage = "Could not load plants: \(error.localizedDescription)"
            showAlert = true
            plants = []
        }
        loadFilteredData(reset: true)
    }

    private func loadFilteredData(reset: Bool = false) {
        if reset {
            currentOffset = 0
            journalEntries.removeAll()
            hasMoreData = true
        }

        guard hasMoreData else { return }

        isLoadingMore = true

        let baseEntries: [JournalEntry] = if let selectedPlant {
            dataService.fetchJournalEntries(for: selectedPlant, offset: 0, limit: 200)
        } else {
            dataService.fetchRecentJournalEntries(limit: 200)
        }

        var fetched = baseEntries
        if let selectedEntryType {
            fetched = fetched.filter { $0.entryType == selectedEntryType }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            fetched = fetched.filter {
                $0.title.lowercased().contains(query) ||
                    $0.content.lowercased().contains(query) ||
                    ($0.plant?.name?.lowercased().contains(query) ?? false)
            }
        }

        switch sortOrder {
        case .dateAscending:
            fetched.sort { $0.entryDate < $1.entryDate }
        case .dateDescending:
            fetched.sort { $0.entryDate > $1.entryDate }
        case .plantName:
            fetched.sort { ($0.plant?.name ?? "") < ($1.plant?.name ?? "") }
        case .entryType:
            fetched.sort { $0.entryType.displayName < $1.entryType.displayName }
        }

        let start = min(currentOffset, fetched.count)
        let end = min(start + visibleEntryCount, fetched.count)
        let page = start < end ? Array(fetched[start ..< end]) : []

        if page.count < visibleEntryCount {
            hasMoreData = false
        }

        // Final in-memory sort if needed
        let finalEntries = page

        journalEntries.append(contentsOf: finalEntries)
        currentOffset += finalEntries.count
        isLoadingMore = false
    }

    private func loadMoreEntries() {
        loadFilteredData(reset: false)
    }

    // MARK: - Helper Methods

    private func deleteEntries(at offsets: IndexSet, in entries: [JournalEntry]) {
        for index in offsets {
            let entry = entries[index]
            dataService.deleteJournalEntry(entry)
            journalEntries.removeAll { $0.id == entry.id }
        }
    }

    private static let groupingKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func formatSectionDate(_ dateString: String) -> String {
        guard let date = Self.groupingKeyFormatter.date(from: dateString) else {
            return dateString
        }

        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionDateFormatter.string(from: date)
        }
    }

    private func formatDateForGrouping(_ date: Date) -> String {
        Self.groupingKeyFormatter.string(from: date)
    }

    private func sortGroupsByDate(_ lhs: String, _ rhs: String) -> Bool {
        switch sortOrder {
        case .dateAscending:
            lhs < rhs
        case .dateDescending:
            lhs > rhs
        default:
            lhs > rhs // Default to newest first
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
        .buttonStyle(.plain)
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
        case .dateDescending: "Newest First"
        case .dateAscending: "Oldest First"
        case .plantName: "Plant Name"
        case .entryType: "Entry Type"
        }
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let photoService = PhotoService(dataService: dataService)

    JournalView()
        .environment(photoService)
        .modelContainer(for: [JournalEntry.self, Plant.self], inMemory: true)
}
#else
import SwiftUI

public struct JournalView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.largeTitle)
            Text("Journal is available on iOS.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Journal")
    }
}
#endif
