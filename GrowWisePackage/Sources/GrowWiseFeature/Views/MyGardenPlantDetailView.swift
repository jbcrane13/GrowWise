import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant

    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(PhotoService.self) private var photoService
    @Environment(ReminderService.self) private var reminderService
    @State private var showingEditPlant = false
    @State private var showingDeleteConfirmation = false
    @State private var showingJournalEntry = false
    @State private var showingReminderView = false
    @State private var selectedPhoto: String?
    @State private var showingPhotoViewer = false
    @State private var showingAssignGarden = false // Added per instruction

    // Care action states
    @State private var isPerformingCareAction = false
    @State private var showingCareSuccess = false
    @State private var careActionMessage = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                heroImageSection
                plantInfoSections
            }
        }
        .navigationTitle(plant.name ?? "Unknown Plant")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Delete Plant", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePlant()
            }
        } message: {
            Text("Are you sure you want to delete \(plant.name ?? "this plant")? This action cannot be undone.")
        }
        .alert("Care Action Completed", isPresented: $showingCareSuccess) {
            Button("OK") {}
        } message: {
            Text(careActionMessage)
        }
        .sheet(isPresented: $showingEditPlant) {
            Text("Edit Plant View - To be implemented")
        }
        .sheet(isPresented: $showingJournalEntry) {
            NavigationStack {
                AddJournalEntryView(photoService: photoService)
            }
        }
        .sheet(isPresented: $showingReminderView) {
            AddReminderView(reminderService: reminderService, dataService: dataService)
        }
        .sheet(isPresented: $showingAssignGarden) {
            AssignGardenSheet(plant: plant)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Edit Plant") {
                    showingEditPlant = true
                }

                Button("Assign to Garden") { showingAssignGarden = true }

                Divider()

                Button("Delete Plant", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    private var plantInfoSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            basicInfoSection
            careRequirementsSection
            healthStatusSection
            actionButtonsSection
            careHistorySection
            upcomingRemindersSection
        }
        .padding(.horizontal)
    }

    // MARK: - Hero Image Section

    private var heroImageSection: some View {
        VStack {
            if let photoURLs = plant.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoURLs, id: \.self) { photoURL in
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 300, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        selectedPhoto = photoURL
                                        showingPhotoViewer = true
                                    }
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 300, height: 200)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Placeholder when no photos
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No photos yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.title2)
                .fontWeight(.semibold)

            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let scientificName = plant.scientificName {
                        InfoRow(title: "Scientific Name", value: scientificName, systemImage: "leaf.fill")
                    }

                    InfoRow(title: "Type", value: plant.plantType?.displayName ?? "Unknown", systemImage: "tag.fill")
                    InfoRow(title: "Difficulty", value: plant.difficultyLevel?.displayName ?? "Unknown", systemImage: "star.fill")

                    if let plantingDate = plant.plantingDate {
                        InfoRow(title: "Planted", value: plantingDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    }

                    if let growthStage = plant.growthStage {
                        InfoRow(title: "Growth Stage", value: growthStage.displayName, systemImage: "chart.line.uptrend.xyaxis")
                    }

                    if let location = plant.gardenLocation, !location.isEmpty {
                        InfoRow(title: "Location", value: location, systemImage: "location.fill")
                    }

                    if let containerType = plant.containerType {
                        InfoRow(title: "Container", value: containerType.displayName, systemImage: "square.stack")
                    }

                    if let notes = plant.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text(notes)
                                .font(.body)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Care Requirements Section

    private var careRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care Requirements")
                .font(.title2)
                .fontWeight(.semibold)

            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let sunlight = plant.sunlightRequirement {
                        InfoRow(title: "Sunlight", value: sunlight.displayName, systemImage: "sun.max.fill")
                    }

                    if let watering = plant.wateringFrequency {
                        InfoRow(title: "Watering", value: watering.displayName, systemImage: "drop.fill")
                    }

                    if let space = plant.spaceRequirement {
                        InfoRow(title: "Space Needed", value: space.displayName, systemImage: "square.dashed")
                    }

                    if let harvestDate = plant.harvestDate {
                        InfoRow(title: "Expected Harvest", value: harvestDate.formatted(date: .abbreviated, time: .omitted), systemImage: "basket.fill")
                    }
                }
            }
        }
    }

    // MARK: - Health Status Section

    private var healthStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Status")
                .font(.title2)
                .fontWeight(.semibold)

            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(healthStatusColor)
                            .frame(width: 20)
                        Text("Current Health")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(plant.healthStatus?.displayName ?? "Unknown")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(healthStatusColor)
                    }

                    if let lastWatered = plant.lastWatered {
                        InfoRow(title: "Last Watered", value: lastWatered.formatted(date: .abbreviated, time: .omitted), systemImage: "drop.fill")
                    }

                    if let lastFertilized = plant.lastFertilized {
                        InfoRow(title: "Last Fertilized", value: lastFertilized.formatted(date: .abbreviated, time: .omitted), systemImage: "leaf.fill")
                    }

                    if let lastPruned = plant.lastPruned {
                        InfoRow(title: "Last Pruned", value: lastPruned.formatted(date: .abbreviated, time: .omitted), systemImage: "scissors")
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                ActionButton(
                    title: "Water",
                    systemImage: "drop.fill",
                    color: .blue,
                    isLoading: isPerformingCareAction
                ) {
                    performCareAction(.watering)
                }

                ActionButton(
                    title: "Fertilize",
                    systemImage: "leaf.fill",
                    color: .green,
                    isLoading: isPerformingCareAction
                ) {
                    performCareAction(.fertilizing)
                }

                ActionButton(
                    title: "Add Entry",
                    systemImage: "plus.circle.fill",
                    color: .purple,
                    isLoading: false
                ) {
                    showingJournalEntry = true
                }

                ActionButton(
                    title: "Set Reminder",
                    systemImage: "bell.fill",
                    color: .orange,
                    isLoading: false
                ) {
                    showingReminderView = true
                }
            }
        }
    }

    // MARK: - Care History Section

    private var careHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("View All") {
                    // Navigate to full journal view
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            if let journalEntries = plant.journalEntries?.prefix(5) {
                if journalEntries.isEmpty {
                    InfoCard {
                        HStack {
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                            Text("No journal entries yet")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(journalEntries), id: \.id) { entry in
                            JournalEntryRow(entry: entry, photoService: photoService)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Upcoming Reminders Section

    private var upcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Reminders")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Manage") {
                    // Navigate to reminder management
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            if let reminders = plant.reminders?.filter({ $0.isEnabled == true }).prefix(3) {
                if reminders.isEmpty {
                    InfoCard {
                        HStack {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.gray)
                            Text("No active reminders")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(reminders), id: \.id) { reminder in
                            ReminderRowView(reminder: reminder, reminderService: reminderService)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private struct InfoCard<Content: View>: View {
        let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            VStack {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct InfoRow: View {
        let title: String
        let value: String
        let systemImage: String

        var body: some View {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.body)
            }
        }
    }

    private struct ActionButton: View {
        let title: String
        let systemImage: String
        let color: Color
        let isLoading: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 20))
                    }

                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Computed Properties

    private var healthStatusColor: Color {
        guard let healthStatus = plant.healthStatus else { return .gray }

        switch healthStatus {
        case .healthy: return .green
        case .needsAttention: return .yellow
        case .sick: return .orange
        case .dying: return .red
        case .dead: return .gray
        }
    }

    // MARK: - Helper Functions

    private func performCareAction(_ type: JournalEntryType) {
        guard !isPerformingCareAction else { return }

        isPerformingCareAction = true

        Task {
            do {
                // Update plant's care dates
                let currentDate = Date()

                switch type {
                case .watering:
                    plant.lastWatered = currentDate
                    careActionMessage = "Watering recorded for \(plant.name ?? "your plant")!"

                case .fertilizing:
                    plant.lastFertilized = currentDate
                    careActionMessage = "Fertilizing recorded for \(plant.name ?? "your plant")!"

                default:
                    break
                }

                // Create a journal entry
                let journalEntry = JournalEntry(
                    title: type.displayName,
                    content: "Quick action: \(type.displayName.lowercased())",
                    entryType: type,
                    plant: plant
                )

                // Save to data service
                try dataService.addJournalEntry(journalEntry)

                await MainActor.run {
                    isPerformingCareAction = false
                    showingCareSuccess = true
                }
            } catch {
                await MainActor.run {
                    isPerformingCareAction = false
                    careActionMessage = "Failed to record \(type.displayName.lowercased()). Please try again."
                    showingCareSuccess = true
                }
            }
        }
    }

    private func deletePlant() {
        Task {
            do {
                try dataService.plants.delete(plant)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    careActionMessage = "Failed to delete plant: \(error.localizedDescription)"
                    showingCareSuccess = true
                }
            }
        }
    }

    // MARK: - Simple Fallback Views

    private struct SimpleJournalEntryRow: View {
        let entry: JournalEntry

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: entry.entryType.iconName)
                    .font(.title3)
                    .foregroundColor(Color(entry.entryType.color))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? entry.entryType.displayName : entry.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(entry.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(entry.entryDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private struct SimpleReminderRow: View {
        let reminder: PlantReminder

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: reminder.reminderType.iconName)
                    .font(.title3)
                    .foregroundColor(Color(reminder.priority.color))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(reminder.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text("Due: \(reminder.nextDueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if reminder.isEnabled {
                    Circle()
                        .fill(Color(reminder.priority.color))
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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
        case .name: "Name"
        case .dateAdded: "Date Added"
        case .healthStatus: "Health Status"
        case .wateringSchedule: "Watering Schedule"
        }
    }
}

// MARK: - Create Garden Sheet
