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
    @State private var showingAssignGarden = false

    // Care action states
    @State private var isPerformingCareAction = false
    @State private var showingCareSuccess = false
    @State private var careActionMessage = ""

    var body: some View {
        ZStack {
            CultivationTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    heroImageSection
                    plantInfoSections
                }
                .padding(.bottom, 32)
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
            .accessibilityIdentifier("plantdetail_button_menu")
        }
    }

    private var plantInfoSections: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
            basicInfoSection
            careRequirementsSection
            healthStatusSection
            actionButtonsSection
            careHistorySection
            upcomingRemindersSection
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
    }

    // MARK: - Hero Image Section

    private var heroImageSection: some View {
        ZStack(alignment: .bottom) {
            if let photoURLs = plant.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoURLs, id: \.self) { photoURL in
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 300, height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                                    .onTapGesture {
                                        selectedPhoto = photoURL
                                        showingPhotoViewer = true
                                    }
                                    .accessibilityIdentifier("plantdetail_image_photo")
                            } placeholder: {
                                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                    .fill(CultivationTheme.Colors.cardSurface)
                                    .frame(width: 300, height: 220)
                                    .overlay { ProgressView() }
                            }
                        }
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }
            } else {
                // Gradient placeholder hero with IconBubble
                ZStack {
                    LinearGradient(
                        colors: [
                            CultivationTheme.Colors.brandForest.opacity(0.25),
                            CultivationTheme.Colors.brandLeaf.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Subtle green glow orb
                    Circle()
                        .fill(CultivationTheme.Colors.heroGlow)
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)

                    VStack(spacing: 12) {
                        IconBubble(
                            systemName: plant.plantType?.iconName ?? "leaf.fill",
                            color: CultivationTheme.Colors.brandLeaf,
                            size: 80,
                            iconSize: 36
                        )

                        Text(plant.name ?? "Unknown Plant")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Basic Information")
                .sectionLabelStyle()

            VStack(alignment: .leading, spacing: 10) {
                if let scientificName = plant.scientificName {
                    DetailInfoRow(title: "Scientific Name", value: scientificName, systemImage: "leaf.fill", color: CultivationTheme.Colors.brandLeaf)
                }

                DetailInfoRow(title: "Type", value: plant.plantType?.displayName ?? "Unknown", systemImage: "tag.fill", color: CultivationTheme.Colors.brandSage)
                DetailInfoRow(title: "Difficulty", value: plant.difficultyLevel?.displayName ?? "Unknown", systemImage: "star.fill", color: CultivationTheme.Colors.brandGold)

                if let plantingDate = plant.plantingDate {
                    DetailInfoRow(title: "Planted", value: plantingDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", color: CultivationTheme.Colors.brandForest)
                }

                if let growthStage = plant.growthStage {
                    DetailInfoRow(title: "Growth Stage", value: growthStage.displayName, systemImage: "chart.line.uptrend.xyaxis", color: CultivationTheme.Colors.brandLeaf)
                }

                if let location = plant.bed?.name, !location.isEmpty {
                    DetailInfoRow(title: "Location", value: location, systemImage: "location.fill", color: CultivationTheme.Colors.brandForest)
                }

                if let containerType = plant.containerType {
                    DetailInfoRow(title: "Container", value: containerType.displayName, systemImage: "square.stack", color: CultivationTheme.Colors.brandSage)
                }

                if let notes = plant.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            IconBubble(systemName: "note.text", color: CultivationTheme.Colors.brandForest, size: 28, iconSize: 13)
                            Text("Notes")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .padding(.leading, 36)
                    }
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    // MARK: - Care Requirements Section

    private var careRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Care Requirements")
                .sectionLabelStyle()

            VStack(alignment: .leading, spacing: 10) {
                if let sunlight = plant.sunlightRequirement {
                    DetailInfoRow(title: "Sunlight", value: sunlight.displayName, systemImage: "sun.max.fill", color: CultivationTheme.Colors.brandGold)
                }

                if let watering = plant.wateringFrequency {
                    DetailInfoRow(title: "Watering", value: watering.displayName, systemImage: "drop.fill", color: Color.blue)
                }

                if let space = plant.spaceRequirement {
                    DetailInfoRow(title: "Space Needed", value: space.displayName, systemImage: "square.dashed", color: CultivationTheme.Colors.brandSage)
                }

                if let harvestDate = plant.harvestDate {
                    DetailInfoRow(title: "Expected Harvest", value: harvestDate.formatted(date: .abbreviated, time: .omitted), systemImage: "basket.fill", color: CultivationTheme.Colors.brandForest)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    // MARK: - Health Status Section

    private var healthStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health Status")
                .sectionLabelStyle()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    IconBubble(systemName: "heart.fill", color: healthStatusColor, size: 28, iconSize: 13)

                    Text("Current Health")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)

                    Spacer()

                    Text(plant.healthStatus?.displayName ?? "Unknown")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(healthStatusColor)
                }

                if let lastWatered = plant.lastWatered {
                    DetailInfoRow(title: "Last Watered", value: lastWatered.formatted(date: .abbreviated, time: .omitted), systemImage: "drop.fill", color: Color.blue)
                }

                if let lastFertilized = plant.lastFertilized {
                    DetailInfoRow(title: "Last Fertilized", value: lastFertilized.formatted(date: .abbreviated, time: .omitted), systemImage: "leaf.fill", color: CultivationTheme.Colors.brandLeaf)
                }

                if let lastPruned = plant.lastPruned {
                    DetailInfoRow(title: "Last Pruned", value: lastPruned.formatted(date: .abbreviated, time: .omitted), systemImage: "scissors", color: CultivationTheme.Colors.brandSage)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .sectionLabelStyle()

            // Primary CTA: Water Now
            Button {
                performCareAction(.watering)
            } label: {
                HStack(spacing: 8) {
                    if isPerformingCareAction {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "drop.fill")
                    }
                    Text("Water Now")
                }
            }
            .buttonStyle(GradientButtonStyle(isDisabled: isPerformingCareAction))
            .disabled(isPerformingCareAction)
            .accessibilityIdentifier("plantdetail_button_water")

            // Secondary actions
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                GlassActionButton(
                    title: "Fertilize",
                    systemImage: "leaf.fill",
                    color: CultivationTheme.Colors.brandLeaf,
                    isLoading: isPerformingCareAction,
                    accessibilityID: "plantdetail_button_fertilize"
                ) {
                    performCareAction(.fertilizing)
                }

                GlassActionButton(
                    title: "Add Entry",
                    systemImage: "plus.circle.fill",
                    color: CultivationTheme.Colors.brandSage,
                    isLoading: false,
                    accessibilityID: "plantdetail_button_addentry"
                ) {
                    showingJournalEntry = true
                }

                GlassActionButton(
                    title: "Reminder",
                    systemImage: "bell.fill",
                    color: CultivationTheme.Colors.brandGold,
                    isLoading: false,
                    accessibilityID: "plantdetail_button_setreminder"
                ) {
                    showingReminderView = true
                }
            }
        }
    }

    // MARK: - Care History Section

    private var careHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Activity")
                    .sectionLabelStyle()

                Spacer()

                Button("View All") {
                    // Navigate to full journal view
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .accessibilityIdentifier("plantdetail_button_viewallactivity")
            }

            if let journalEntries = plant.journalEntries?.prefix(5) {
                if journalEntries.isEmpty {
                    emptyStateCard(icon: "book.closed", message: "No journal entries yet")
                } else {
                    LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upcoming Reminders")
                    .sectionLabelStyle()

                Spacer()

                Button("Manage") {
                    // Navigate to reminder management
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                .accessibilityIdentifier("plantdetail_button_managereminders")
            }

            if let reminders = plant.reminders?.filter({ $0.isEnabled == true }).prefix(3) {
                if reminders.isEmpty {
                    emptyStateCard(icon: "bell.slash", message: "No active reminders")
                } else {
                    LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
                        ForEach(Array(reminders), id: \.id) { reminder in
                            ReminderRowView(reminder: reminder, reminderService: reminderService)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func emptyStateCard(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            IconBubble(systemName: icon, color: CultivationTheme.Colors.textTertiary, size: 32, iconSize: 15)
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Computed Properties

    private var healthStatusColor: Color {
        guard let healthStatus = plant.healthStatus else { return CultivationTheme.Colors.textTertiary }

        switch healthStatus {
        case .healthy: return CultivationTheme.Colors.statusHealthy
        case .needsAttention: return CultivationTheme.Colors.statusWarning
        case .sick: return CultivationTheme.Colors.statusWarning
        case .dying: return CultivationTheme.Colors.statusAlert
        case .dead: return CultivationTheme.Colors.textTertiary
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
}

// MARK: - Detail Info Row

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            IconBubble(systemName: systemImage, color: color, size: 28, iconSize: 13)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Glass Action Button

private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isLoading: Bool
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(color)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard()
        }
        .disabled(isLoading)
        .accessibilityIdentifier(accessibilityID)
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
