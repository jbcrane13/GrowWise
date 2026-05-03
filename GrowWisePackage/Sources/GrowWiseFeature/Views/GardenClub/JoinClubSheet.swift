import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes

public struct JoinClubSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    var onJoined: ((GardenClub) -> Void)?

    @State private var inviteCode: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    private let maxCodeLength = 6
    private var isValid: Bool {
        formattedCode.count == maxCodeLength
    }

    /// Strips non-alphanumeric characters and uppercases.
    private var formattedCode: String {
        String(inviteCode.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(maxCodeLength))
    }

    public init(onJoined: ((GardenClub) -> Void)? = nil) {
        self.onJoined = onJoined
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Join a Club")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .accessibilityIdentifier("join_club_cancel")
                }
            }
            .alert("Couldn't Join Club", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: CultivationTheme.Spacing.sectionGap) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 72, height: 72)
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Enter Invite Code")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Ask your club's owner for the 6-character code.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Code input
            VStack(spacing: 10) {
                ZStack(alignment: .center) {
                    // Formatted code display
                    HStack(spacing: 10) {
                        ForEach(0 ..< maxCodeLength, id: \.self) { index in
                            let char: String = index < formattedCode.count
                                ? String(formattedCode[formattedCode.index(formattedCode.startIndex, offsetBy: index)])
                                : "_"
                            Text(char)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    index < formattedCode.count
                                        ? CultivationTheme.Colors.brandForest
                                        : CultivationTheme.Colors.textTertiary
                                )
                                .frame(width: 40)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassCard()

                    // Invisible text field over the top for input
                    TextField("", text: Binding(
                        get: { formattedCode },
                        set: { inviteCode = $0 }
                    ))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.01) // nearly invisible but still focusable
                    #if os(iOS)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                    #endif
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("join_club_code_field")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            // Error hint
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CultivationTheme.Colors.statusAlert)
                        .font(.system(size: 14))
                    Text(errorMessage)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.statusAlert)
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .transition(.opacity)
            }

            // Join button
            if isJoining {
                ProgressView("Joining…")
            } else {
                Button("Join Club") {
                    Task { await joinClub() }
                }
                .buttonStyle(GradientButtonStyle(isDisabled: !isValid))
                .disabled(!isValid)
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .accessibilityIdentifier("join_club_button")
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Action

    @MainActor
    private func joinClub() async {
        guard isValid else { return }

        isJoining = true
        errorMessage = nil
        defer { isJoining = false }

        do {
            let club = try dataService.joinClub(inviteCode: formattedCode, memberID: currentUserID)
            onJoined?(club)
            dismiss()
        } catch let error as GardenClubError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }
}

#Preview {
    JoinClubSheet()
}

// swiftlint:enable attributes
