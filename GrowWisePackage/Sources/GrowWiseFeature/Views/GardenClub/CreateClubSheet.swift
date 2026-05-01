import GrowWiseModels
import GrowWiseServices
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct CreateClubSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((GardenClub) -> Void)?

    @State private var clubName: String = ""
    @State private var description: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdClub: GardenClub?

    private var isValid: Bool {
        !clubName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public init(onCreated: ((GardenClub) -> Void)? = nil) {
        self.onCreated = onCreated
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()

                if let club = createdClub {
                    successView(club: club)
                } else {
                    formView
                }
            }
            .navigationTitle("Create a Club")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .accessibilityIdentifier("create_club_cancel")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                // Icon
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Gradients.ctaVertical)
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)

                VStack(spacing: CultivationTheme.Spacing.rowGap) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Club Name")
                            .sectionLabelStyle()
                            .padding(.leading, 4)

                        TextField("e.g. Backyard Growers", text: $clubName)
                            .font(.system(.body, design: .rounded))
                            .padding(CultivationTheme.Spacing.cardPadding)
                            .glassCard()
                            .accessibilityIdentifier("create_club_name_field")
                    }

                    // Description field (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (optional)")
                            .sectionLabelStyle()
                            .padding(.leading, 4)

                        TextField("What does your club grow?", text: $description, axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(3 ... 6)
                            .padding(CultivationTheme.Spacing.cardPadding)
                            .glassCard()
                            .accessibilityIdentifier("create_club_description_field")
                    }
                }

                // Create button
                if isCreating {
                    ProgressView("Creating club…")
                        .padding(.top, 4)
                } else {
                    Button("Create Club") {
                        Task { await createClub() }
                    }
                    .buttonStyle(GradientButtonStyle(isDisabled: !isValid))
                    .disabled(!isValid)
                    .accessibilityIdentifier("create_club_button")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    // MARK: - Success

    private func successView(club: GardenClub) -> some View {
        VStack(spacing: CultivationTheme.Spacing.sectionGap) {
            Spacer()

            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Club Created!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("Share this code to invite members")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            // Invite code card
            VStack(spacing: 8) {
                Text(club.inviteCode ?? "------")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
                    .tracking(8)
                    .accessibilityIdentifier("create_club_invite_code")

                Text("Tap to copy")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glassCard()
            .onTapGesture {
                copyCode(club.inviteCode ?? "")
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Share button
            if let code = club.inviteCode {
                ShareLink(
                    item: ClubInviteSharing.shareItem(code: code),
                    subject: Text("Garden Club Invite"),
                    message: Text(ClubInviteSharing.shareMessage(clubName: club.name, code: code))
                ) {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CultivationTheme.Gradients.cta)
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.button))
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .accessibilityIdentifier("create_club_share_button")
            }

            Button("Done") { dismiss() }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .accessibilityIdentifier("create_club_done_button")

            Spacer()
        }
    }

    // MARK: - Action

    @MainActor
    private func createClub() async {
        let trimmed = clubName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            let club = try dataService.createClub(name: trimmed, ownerID: currentUserID)
            createdClub = club
            onCreated?(club)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    private func copyCode(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
    }
}

#Preview {
    CreateClubSheet()
}
