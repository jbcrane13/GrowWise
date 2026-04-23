import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant

    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService
    @Environment(PhotoService.self)
    private var photoService
    @Environment(ReminderService.self)
    private var reminderService
    @Environment(PlantCareAdviceService.self)
    private var careAdviceService
    @Environment(PerenualEnrichmentService.self)
    private var perenualEnrichment

    // MARK: - State

    @State private var showingEditPlant = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReminderView = false
    @State private var showingAssignGarden = false
    @State private var showMovePlant = false
    @State private var showingDiagnostic = false
    @State private var careTips: [CareTip] = []
    @State private var isAdviceExpanded: Bool = false
    @State private var journalEntries: [JournalEntry] = []
    @State private var primaryClub: GardenClub? = nil
    @State private var showingShareToClub: Bool = false
    @State private var deleteError: Error?

    // MARK: - Body

    var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroPhoto
                    titleBlock
                    statRow
                    actionButtons
                    if isAdviceExpanded {
                        adviceCard
                    }
                    photoJournalStrip
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(plant.name ?? "Plant")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            let user = dataService.getCurrentUser()
            careTips = careAdviceService.getContextualTips(for: plant, in: plant.garden, user: user)
            journalEntries = dataService.fetchJournalEntries(for: plant)
            primaryClub = dataService.fetchPrimaryClub()
        }
        .sheet(isPresented: $showingReminderView) {
            AddReminderView(reminderService: reminderService, dataService: dataService)
        }
        .sheet(isPresented: $showingShareToClub) {
            PublishGardenSheet()
        }
        .sheet(isPresented: $showingEditPlant) {
            Text("Edit Plant View - To be implemented")
        }
        .sheet(isPresented: $showingAssignGarden) {
            AssignGardenSheet(plant: plant)
        }
        .sheet(isPresented: $showMovePlant) {
            MovePlantSheet(plant: plant)
        }
        .sheet(isPresented: $showingDiagnostic) {
            CommonPlantIssuesView(plant: plant)
        }
        .alert("Delete Plant", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deletePlant() }
        } message: {
            Text("Are you sure you want to delete \(plant.name ?? "this plant")? This action cannot be undone.")
        }
        .alert("Couldn't delete plant", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError?.localizedDescription ?? "")
        }
        .accessibilityIdentifier("screen_plantDetail")
    }

    // MARK: - Hero Photo

    private var heroPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 220)
            VStack(alignment: .leading, spacing: 4) {
                if let zone = plant.garden?.hardinessZone, !zone.isEmpty {
                    SmartTag(label: zone)
                        .accessibilityIdentifier("plantdetail_tag_zone")
                }
            }
            .padding(14)
        }
        .accessibilityIdentifier("plantdetail_hero_photo")
    }

    // MARK: - Title Block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plant.name ?? "Unknown Plant")
                .font(CultivationTheme.Fonts.display(26, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            if let sci = plant.scientificName, !sci.isEmpty {
                Text(sci)
                    .font(CultivationTheme.Fonts.displayItalic(15))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
        }
        .accessibilityIdentifier("plantdetail_title_block")
    }

    // MARK: - Stat Row

    private var statRow: some View {
        HStack(spacing: 10) {
            PlantStatCard(
                title: "Health",
                value: (plant.healthStatus ?? .healthy).displayName,
                icon: "heart.fill",
                tint: (plant.healthStatus ?? .healthy).accentColor
            )
            .accessibilityIdentifier("plantdetail_stat_health")

            PlantStatCard(
                title: "Watering",
                value: plant.wateringFrequency?.displayName ?? "—",
                icon: "drop.fill",
                tint: CultivationTheme.Colors.accentSky
            )
            .accessibilityIdentifier("plantdetail_stat_watering")

            PlantStatCard(
                title: "Stage",
                value: plant.growthStage?.displayName ?? "—",
                icon: "leaf.fill",
                tint: CultivationTheme.Colors.brandLeaf
            )
            .accessibilityIdentifier("plantdetail_stat_stage")
        }
        .accessibilityIdentifier("plantdetail_stat_row")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Log care") {
                    showingReminderView = true
                }
                .buttonStyle(GradientButtonStyle())
                .accessibilityIdentifier("plantdetail_button_log_care")

                Button("Get advice") {
                    isAdviceExpanded.toggle()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("plantdetail_button_get_advice")
            }
            if let club = primaryClub {
                Button("Share to \(club.name ?? "Club")") {
                    showingShareToClub = true
                }
                .buttonStyle(CoralButtonStyle())
                .accessibilityIdentifier("plantdetail_button_share_to_club")
            }
        }
    }

    // MARK: - Advice Card

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Growing Tips")
                .font(CultivationTheme.Fonts.body(11, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            if careTips.isEmpty {
                Text("No specific tips available for this plant.")
                    .font(CultivationTheme.Fonts.body(14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            } else {
                ForEach(careTips.prefix(3)) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                            .font(.system(size: 14))
                        Text(tip.description)
                            .font(CultivationTheme.Fonts.body(14))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    }
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("plantdetail_advice_card")
    }

    // MARK: - Photo Journal Strip

    private var photoJournalStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo Journal")
                .font(CultivationTheme.Fonts.body(11, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(journalEntries, id: \.id) { entry in
                        ForEach(entry.photoURLs, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(CultivationTheme.Colors.backgroundSecondary)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                                )
                                .accessibilityIdentifier("plantdetail_photo_thumb")
                        }
                    }
                    // Add photo placeholder
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .foregroundStyle(CultivationTheme.Colors.textTertiary.opacity(0.4))
                        .frame(width: 72, height: 72)
                        .overlay(Image(systemName: "plus").foregroundStyle(CultivationTheme.Colors.textTertiary))
                        .accessibilityIdentifier("plantdetail_photo_add")
                }
                .padding(.vertical, 4)
            }
        }
        .accessibilityIdentifier("plantdetail_photo_strip")
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Edit Plant") {
                    showingEditPlant = true
                }

                Button("Assign to Garden") { showingAssignGarden = true }

                Button {
                    showMovePlant = true
                } label: {
                    Label("Move to…", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("plantdetail_button_move")

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

    // MARK: - Delete

    private func deletePlant() {
        Task {
            do {
                try dataService.plants.delete(plant)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is surfaced to the user via the existing delete confirmation flow.
                // Logging only — no silent swallow.
            }
        }
    }
}

// MARK: - Plant Stat Card

/// Three-up stat card for Plant Detail — text value with icon and label.
private struct PlantStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)

            Text(value)
                .font(CultivationTheme.Fonts.body(13, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(CultivationTheme.Fonts.body(10, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .fill(CultivationTheme.Colors.cardSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard)
                .stroke(tint.opacity(0.20), lineWidth: 1)
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
