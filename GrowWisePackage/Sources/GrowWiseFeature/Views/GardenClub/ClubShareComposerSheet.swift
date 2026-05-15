import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes

/// Sheet for composing and posting a new Garden Club activity.
///
/// Accepts an optional `plant` for pre-filling context. Calls `onPost` on
/// success so the parent can refresh its feed.
public struct ClubShareComposerSheet: View { // swiftlint:disable:this type_body_length
    @Environment(DataService.self) private var dataService
    @Environment(PhotoService.self) private var photoService
    @Environment(ClubCloudKitService.self) private var clubCloudKitService
    @Environment(\.dismiss) private var dismiss

    let plant: Plant?
    let club: GardenClub?
    let initialCaption: String?
    var onPost: () -> Void = {}

    @State private var caption = ""
    @State private var includePlant = true
    @State private var availableClubs: [GardenClub] = []
    @State private var selectedClubID: UUID?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var offlineMessage: String?
    @State private var showOfflineNotice = false

    private var captionIsEmpty: Bool {
        caption.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedClub: GardenClub? {
        if let club { return club }
        guard let selectedClubID else { return availableClubs.first }
        return availableClubs.first { $0.id == selectedClubID } ?? availableClubs.first
    }

    private var selectedClubName: String {
        selectedClub?.name ?? "Garden Club"
    }

    private var resolvedPlantName: String? {
        guard includePlant else { return nil }
        return plant?.name
    }

    private var resolvedGardenName: String? {
        guard includePlant else { return nil }
        return plant?.garden?.name ?? plant?.bed?.garden?.name
    }

    public init(
        plant: Plant? = nil,
        club: GardenClub? = nil,
        initialCaption: String? = nil,
        onPost: @escaping () -> Void = {}
    ) {
        self.plant = plant
        self.club = club
        self.initialCaption = initialCaption
        self.onPost = onPost
        if let ic = initialCaption {
            _caption = State(initialValue: ic)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                scrollContent
            }
            .navigationTitle("Share with \(selectedClubName)")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Couldn't post", isPresented: $showError) {
                Button("OK") { showError = false }
                    .accessibilityIdentifier("share_composer_alert_error")
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .alert("Saved locally", isPresented: $showOfflineNotice) {
                Button("OK") { dismiss() }
                    .accessibilityIdentifier("share_composer_alert_offline")
            } message: {
                Text(offlineMessage ?? "Your post is visible locally and will be ready to retry when iCloud is available.")
            }
            .task { loadClubs() }
        }
        .accessibilityIdentifier("screen_share_composer")
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                if club == nil {
                    clubSelectionSection
                }
                captionSection
                if plant != nil {
                    plantContextSection
                }
                photoSection
                postFooterHint
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, CultivationTheme.Spacing.sectionGap)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Caption section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's growing?")
                .sectionLabelStyle()
                .padding(.leading, 4)

            TextField(
                "Share an update, tip, or harvest story…",
                text: $caption,
                axis: .vertical
            )
            .font(CultivationTheme.Fonts.body(15))
            .foregroundStyle(CultivationTheme.Colors.textPrimary)
            .lineLimit(5 ... 12)
            .frame(minHeight: 120, alignment: .topLeading)
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .accessibilityIdentifier("share_composer_textfield_caption")
        }
    }

    // MARK: - Plant context chip

    private var clubSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Club")
                .sectionLabelStyle()
                .padding(.leading, 4)

            if availableClubs.isEmpty {
                Text("Join or create a club before posting.")
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .accessibilityIdentifier("share_composer_text_no_club")
            } else {
                Picker("Club", selection: $selectedClubID) {
                    ForEach(availableClubs, id: \.id) { club in
                        Text(club.name ?? "Garden Club")
                            .tag(club.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(CultivationTheme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                .accessibilityIdentifier("share_composer_picker_club")
            }
        }
    }

    private var plantContextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Plant context")
                .sectionLabelStyle()
                .padding(.leading, 4)

            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandSage)

                Text(plant?.name ?? "")
                    .font(CultivationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandSage)

                if let resolvedGardenName {
                    Text("· \(resolvedGardenName)")
                        .font(CultivationTheme.Fonts.body(12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("share_composer_text_garden_context")
                }

                Spacer()

                Button {
                    withAnimation(CultivationTheme.Animation.selection) {
                        includePlant.toggle()
                    }
                } label: {
                    Image(systemName: includePlant ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            includePlant
                                ? CultivationTheme.Colors.textTertiary
                                : CultivationTheme.Colors.brandSage
                        )
                }
                .accessibilityLabel(includePlant ? "Remove plant context" : "Add plant context")
                .accessibilityIdentifier("share_composer_button_plant_toggle")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.pill)
                    .fill(
                        includePlant
                            ? CultivationTheme.Colors.smartTagBackground
                            : CultivationTheme.Colors.backgroundSecondary
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.pill)
                    .stroke(
                        includePlant
                            ? CultivationTheme.Colors.brandLeaf.opacity(0.4)
                            : CultivationTheme.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
            .accessibilityIdentifier("share_composer_chip_plant")
        }
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photo")
                .sectionLabelStyle()
                .padding(.leading, 4)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: selectedPhotoData == nil ? "photo.badge.plus" : "photo.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    Text(selectedPhotoData == nil ? "Add Photo" : "Photo attached")
                        .font(CultivationTheme.Fonts.body(13, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    if selectedPhotoData != nil {
                        Button {
                            selectedPhotoData = nil
                            selectedPhotoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                        .accessibilityLabel("Remove attached photo")
                        .accessibilityIdentifier("share_composer_button_remove_photo")
                    }
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .fill(CultivationTheme.Colors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                )
            }
            .accessibilityIdentifier("share_composer_button_add_photo")
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task<Void, Never> { await loadSelectedPhoto(newValue) }
            }
        }
    }

    // MARK: - Footer hint

    private var postFooterHint: some View {
        Text("Your post will be visible to club members.")
            .font(CultivationTheme.Fonts.body(12))
            .foregroundStyle(CultivationTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .accessibilityIdentifier("share_composer_button_cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            postButton
        }
    }

    @ViewBuilder
    private var postButton: some View {
        if isPosting {
            ProgressView()
                .tint(CultivationTheme.Colors.accentCoral)
        } else {
            Button("Post") {
                Task<Void, Never> { await submitPost() }
            }
            .fontWeight(.semibold)
            .foregroundStyle(
                captionIsEmpty
                    ? CultivationTheme.Colors.textTertiary
                    : CultivationTheme.Colors.accentCoral
            )
            .disabled(captionIsEmpty || selectedClub == nil)
            .accessibilityIdentifier("share_composer_button_post")
        }
    }

    // MARK: - Actions

    @MainActor
    private func submitPost() async {
        let trimmed = caption.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let selectedClub else {
            errorMessage = CreateClubPostError.noClub.localizedDescription
            showError = true
            return
        }

        isPosting = true
        defer { isPosting = false }

        do {
            let photoURL = try await saveSelectedPhotoIfNeeded()
            let activity = try dataService.createClubPost(
                caption: trimmed,
                activityType: "shared",
                plantName: resolvedPlantName,
                gardenName: resolvedGardenName,
                club: selectedClub,
                photoURL: photoURL
            )
            onPost()
            do {
                try await clubCloudKitService.publishActivity(activity, club: selectedClub)
                dismiss()
            } catch {
                offlineMessage = [
                    "Your post is visible locally.",
                    "iCloud sync is unavailable right now, so open the club again later to retry syncing.",
                ].joined(separator: " ")
                showOfflineNotice = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadClubs() {
        do {
            availableClubs = try dataService.fetchClubs()
            if selectedClubID == nil {
                selectedClubID = club?.id ?? availableClubs.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            selectedPhotoData = try await item.loadTransferable(type: Data.self)
        } catch {
            errorMessage = "Couldn't load that photo. Please try another image."
            showError = true
        }
    }

    private func saveSelectedPhotoIfNeeded() async throws -> String? {
        guard let selectedPhotoData else { return nil }
        return try await photoService.saveClubPostPhotoData(selectedPhotoData)
    }
}

// swiftlint:enable attributes
