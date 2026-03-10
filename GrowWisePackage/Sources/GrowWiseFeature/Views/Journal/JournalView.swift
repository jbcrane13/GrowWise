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

    /// New design-system filter state
    @State private var selectedFilter: JournalFilter = .all

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Journal entries grouped by date
                    if journalEntries.isEmpty {
                        emptyJournalView
                    } else {
                        ForEach(sortedGroupKeys, id: \.self) { dateKey in
                            // Section header
                            Text(formatSectionDate(dateKey))
                                .sectionLabelStyle()
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .padding(.top, CultivationTheme.Spacing.sectionGap)
                                .padding(.bottom, 8)

                            // Entry rows
                            ForEach(paginatedGroupedEntries[dateKey] ?? [], id: \.id) { entry in
                                JournalEntryRow(
                                    entry: entry,
                                    photoService: photoService
                                )
                                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                                .padding(.bottom, CultivationTheme.Spacing.rowGap)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                                .accessibilityIdentifier("journal_cell_entry_\(entry.id)")
                            }
                        }

                        // Load more
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
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                                    .padding()
                                    .accessibilityIdentifier("journal_button_loadmore")
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                journalHeader
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddEntry) {
                AddJournalEntryView(photoService: photoService)
            }
            .sheet(item: $selectedEntry) { entry in
                JournalEntryDetailView(
                    entry: entry,
                    photoService: photoService
                )
            }
            .searchable(text: $searchText, prompt: "Search journal entries...")
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
            .onChange(of: selectedFilter) { _, _ in
                // Map design-system filter to the existing entry type filter
                selectedEntryType = selectedFilter.entryType
                loadFilteredData(reset: true)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Header

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack {
                Text("Journal")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Spacer()

                Button {
                    showingAddEntry = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(CultivationTheme.Gradients.ctaVertical)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("journal_button_add")
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Filter pills — All, Watering, Photos, Notes, Harvested
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(JournalFilter.allCases, id: \.self) { filter in
                        GlassPill(
                            label: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            accessibilityID: "journal_pill_\(filter.rawValue.lowercased())",
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(CultivationTheme.Colors.background.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Divider()
                .foregroundStyle(CultivationTheme.Colors.divider)
        }
    }

    // MARK: - Empty State

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
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Computed Properties

    private var sortedGroupKeys: [String] {
        paginatedGroupedEntries.keys.sorted(by: sortGroupsByDate)
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
        // Photos filter: only entries that have at least one photo
        if selectedFilter == .photos {
            fetched = fetched.filter { !$0.photoURLs.isEmpty }
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

        let finalEntries = page

        journalEntries.append(contentsOf: finalEntries)
        currentOffset += finalEntries.count
        isLoadingMore = false
    }

    private func loadMoreEntries() {
        loadFilteredData(reset: false)
    }

    // MARK: - Helper Methods

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
            lhs > rhs
        }
    }
}

// MARK: - Journal Filter

/// Design-system filter tabs shown as GlassPill chips in the header.
private enum JournalFilter: String, CaseIterable {
    case all = "All"
    case watering = "Watering"
    case photos = "Photos"
    case notes = "Notes"
    case harvested = "Harvested"

    /// Maps the filter pill selection to the underlying JournalEntryType filter.
    /// Returns nil for `.all` and `.photos` (photos are filtered client-side via photoURLs).
    var entryType: JournalEntryType? {
        switch self {
        case .all: nil
        case .watering: .watering
        case .photos: nil // filtered via photoURLs presence below
        case .notes: .note
        case .harvested: .harvest
        }
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
        .environment(dataService)
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
