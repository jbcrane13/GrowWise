import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppression for 1.1 plant-detail collaboration actions; splitting the view is a fast-follow refactor.
// swiftlint:disable file_length

struct PlantDetailView: View { // swiftlint:disable:this type_body_length
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

    // MARK: - State

    @State private var showingDeleteConfirmation = false
    @State private var showingReminderView = false
    @State private var showingAssignGarden = false
    @State private var showMovePlant = false
    @State private var showingDiagnostic = false
    @State private var showingLightMeter = false
    @State private var careTips: [CareTip] = []
    @State private var journalEntries: [JournalEntry] = []
    @State private var harvests: [Harvest] = []
    @State private var showingLogHarvest: Bool = false
    @State private var primaryClub: GardenClub?
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
                    PerenualEnrichmentCard(plant: plant)
                    actionButtons
                    harvestHistoryStrip
                    adviceCard
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
            harvests = dataService.fetchHarvests(for: plant)
            primaryClub = dataService.fetchPrimaryClub()
        }
        .sheet(isPresented: $showingReminderView) {
            AddReminderView(reminderService: reminderService, dataService: dataService)
        }
        .sheet(isPresented: $showingShareToClub) {
            // No feed to reload here; GardenClubFeedView reloads on .task when navigated back to.
            ClubShareComposerSheet(plant: plant, onPost: {})
                .environment(dataService)
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
        .sheet(isPresented: $showingLightMeter) {
            LightMeterView()
        }
        .sheet(isPresented: $showingLogHarvest) {
            LogHarvestSheet(plant: plant) {
                harvests = dataService.fetchHarvests(for: plant)
            }
        }
        .alert("Delete Plant", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("plantdetail_button_delete_cancel")
            Button("Delete", role: .destructive) { deletePlant() }
                .accessibilityIdentifier("plantdetail_button_delete_confirm")
        } message: {
            Text("Are you sure you want to delete \(plant.name ?? "this plant")? This action cannot be undone.")
        }
        .alert("Couldn't delete plant", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("plantdetail_button_delete_error_ok")
        } message: {
            Text(deleteError?.localizedDescription ?? "")
        }
        .accessibilityIdentifier("screen_plantDetail")
    }

    // MARK: - Hero Photo

    private var heroPhoto: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 220)

            HStack(spacing: 5) {
                Circle()
                    .fill(CultivationTheme.Colors.statusHealthy)
                    .frame(width: 6, height: 6)
                Text((plant.healthStatus ?? .healthy).displayName)
                    .font(CultivationTheme.Fonts.body(10, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
            }
            .foregroundStyle(CultivationTheme.Colors.brandSage)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(CultivationTheme.Colors.cardSurface.opacity(0.92))
            }
            .padding(12)
            .accessibilityIdentifier("plantdetail_badge_health")

            if let zone = plant.garden?.hardinessZone, !zone.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        SmartTag(label: zone)
                            .accessibilityIdentifier("plantdetail_tag_zone")
                        Spacer()
                    }
                    .padding(14)
                }
            }
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
                SmartTag(label: "Auto-identified")
                    .accessibilityIdentifier("plantdetail_tag_auto_identified")
            }
        }
        .accessibilityIdentifier("plantdetail_title_block")
    }

    // MARK: - Stat Row

    private var statRow: some View {
        HStack(spacing: 10) {
            PlantStatCard(
                title: "Sun",
                value: plant.detailSunStatLabel,
                icon: "sun.max.fill",
                tint: CultivationTheme.Colors.accentAmber
            )
            .accessibilityIdentifier("plantdetail_stat_sun")

            PlantStatCard(
                title: "Water",
                value: plant.detailWaterStatLabel,
                icon: "drop.fill",
                tint: CultivationTheme.Colors.accentSky
            )
            .accessibilityIdentifier("plantdetail_stat_water")

            PlantStatCard(
                title: "Soil",
                value: plant.detailSoilStatLabel,
                icon: "circle.lefthalf.filled",
                tint: CultivationTheme.Colors.brandLeaf
            )
            .accessibilityIdentifier("plantdetail_stat_soil")
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
                .disabled(isReadOnlySharedPlant)
                .accessibilityIdentifier("plantdetail_button_log_care")

                Button("Log harvest") {
                    showingLogHarvest = true
                }
                .buttonStyle(CoralButtonStyle())
                .disabled(isReadOnlySharedPlant)
                .accessibilityIdentifier("plantdetail_button_log_harvest")
            }

            HStack(spacing: 8) {
                Button("Get advice") {
                    showingDiagnostic = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("plantdetail_button_get_advice")

                Button {
                    showingShareToClub = true
                } label: {
                    HStack(spacing: 8) {
                        Text("✦")
                            .font(CultivationTheme.Fonts.body(13, weight: .bold))
                            .foregroundStyle(CultivationTheme.Colors.accentCoral)
                        Text("Share to \(primaryClub?.name ?? "your club")")
                            .font(CultivationTheme.Fonts.body(15, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.accentCoralDeep)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                            .fill(CultivationTheme.Colors.accentCoral.opacity(0.06))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                            .stroke(CultivationTheme.Colors.accentCoral, lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isReadOnlySharedPlant)
                .accessibilityIdentifier("plantdetail_button_share_to_club")
            }

            Button {
                showingLightMeter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                    Text("Check light here")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("plantdetail_button_check_light_here")
        }
    }

    // MARK: - Harvest History

    @ViewBuilder private var harvestHistoryStrip: some View {
        if !harvests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Harvest history")
                    .font(CultivationTheme.Fonts.body(11, weight: .bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(harvests, id: \.id) { harvest in
                            harvestChip(harvest)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .accessibilityIdentifier("plantdetail_harvest_history")
        }
    }

    private func harvestChip(_ harvest: Harvest) -> some View {
        let quantity = harvest.quantity ?? 0
        let unit = harvest.unit ?? .pieces
        let quantityText = quantity.formatted(.number.precision(.fractionLength(0 ... 1)))

        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: harvest.photoURL == nil ? "basket.fill" : "photo.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.accentCoral)

            Text("\(quantityText) \(unit.displayNamePlural)")
                .font(CultivationTheme.Fonts.display(14, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text((harvest.date ?? Date()).formatted(date: .abbreviated, time: .omitted))
                .font(CultivationTheme.Fonts.body(10))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(width: 128, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
        .accessibilityIdentifier("plantdetail_harvest_\(harvest.id?.uuidString ?? "unknown")")
    }

    // MARK: - Advice Card

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Care advice for today")
                    .font(CultivationTheme.Fonts.body(11, weight: .bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Spacer()
                SmartTag(label: "Smart suggestion")
                    .accessibilityIdentifier("plantdetail_tag_advice_smart")
            }
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
}

// MARK: - Toolbar + Actions

extension PlantDetailView {
    private var isReadOnlySharedPlant: Bool {
        plant.isReadOnlySharedPlant(for: dataService.getCurrentUser()?.id.uuidString)
    }

    @ToolbarContentBuilder var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if !isReadOnlySharedPlant, let primaryClub {
                    if plant.isSharedWithClub {
                        Button {
                            unsharePlantFromClub()
                        } label: {
                            Label("Stop sharing care", systemImage: "person.3.sequence.fill")
                        }
                        .accessibilityIdentifier("plantdetail_button_unshare_care")
                    } else {
                        Button {
                            sharePlantWithPrimaryClub(primaryClub)
                        } label: {
                            Label("Share care with \(primaryClub.name ?? "club")", systemImage: "person.3.fill")
                        }
                        .accessibilityIdentifier("plantdetail_button_share_care")
                    }

                    Divider()
                }

                if !isReadOnlySharedPlant {
                    Button("Assign to Garden") { showingAssignGarden = true }
                        .accessibilityIdentifier("plantdetail_button_assign_garden")

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
                    .accessibilityIdentifier("plantdetail_button_delete")
                } else {
                    Label("Shared read-only", systemImage: "lock.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityIdentifier("plantdetail_button_menu")
        }
    }

    func sharePlantWithPrimaryClub(_ club: GardenClub) {
        guard !isReadOnlySharedPlant else {
            return
        }
        do {
            try dataService.sharePlant(plant, withClub: club)
        } catch {
            deleteError = error
        }
    }

    func unsharePlantFromClub() {
        guard !isReadOnlySharedPlant else {
            return
        }
        do {
            try dataService.unsharePlant(plant)
        } catch {
            deleteError = error
        }
    }

    func deletePlant() {
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

private extension Plant {
    var detailSunStatLabel: String {
        guard let sun = sunlightRequirement else { return "—" }
        return switch sun {
        case .fullSun: "Full sun"
        case .partialSun: "Part sun"
        case .partialShade: "Part shade"
        case .fullShade: "Full shade"
        }
    }

    var detailWaterStatLabel: String {
        guard let frequency = wateringFrequency else { return "—" }
        return switch frequency {
        case .daily: "1x/day"
        case .everyOtherDay: "Every 2d"
        case .twiceWeekly: "2x/week"
        case .weekly: "1x/week"
        case .biweekly: "Every 2w"
        case .monthly: "Monthly"
        case .asNeeded: "As needed"
        }
    }

    var detailSoilStatLabel: String {
        let latestLog = soilLogs?
            .compactMap { log -> SoilLog? in log.logDate == nil ? nil : log }
            .max { ($0.logDate ?? .distantPast) < ($1.logDate ?? .distantPast) }
        if let status = latestLog?.phStatus {
            return status
        }
        return "Loam"
    }
}
