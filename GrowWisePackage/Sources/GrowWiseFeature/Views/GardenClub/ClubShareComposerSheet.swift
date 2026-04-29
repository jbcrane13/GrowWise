import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Sheet for composing and posting a new Garden Club activity.
///
/// Accepts an optional `plant` for pre-filling context. Calls `onPost` on
/// success so the parent can refresh its feed.
public struct ClubShareComposerSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let plant: Plant?
    var onPost: () -> Void = {}

    @State private var caption = ""
    @State private var includePlant = true
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var clubName = "Your Club"

    private var captionIsEmpty: Bool {
        caption.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var resolvedPlantName: String? {
        guard includePlant else { return nil }
        return plant?.name
    }

    public init(plant: Plant? = nil, onPost: @escaping () -> Void = {}) {
        self.plant = plant
        self.onPost = onPost
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                scrollContent
            }
            .navigationTitle("Share with \(clubName)")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Couldn't post", isPresented: $showError) {
                Button("OK") { showError = false }
                    .accessibilityIdentifier("share_composer_alert_error")
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .task { loadClubName() }
        }
        .accessibilityIdentifier("screen_share_composer")
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                captionSection
                if plant != nil {
                    plantContextSection
                }
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
            .disabled(captionIsEmpty)
            .accessibilityIdentifier("share_composer_button_post")
        }
    }

    // MARK: - Actions

    @MainActor
    private func submitPost() async {
        let trimmed = caption.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isPosting = true
        defer { isPosting = false }

        do {
            try dataService.createClubPost(
                caption: trimmed,
                activityType: "shared",
                plantName: resolvedPlantName
            )
            onPost()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadClubName() {
        if let name = dataService.fetchPrimaryClub()?.name {
            clubName = name
        }
    }
}
