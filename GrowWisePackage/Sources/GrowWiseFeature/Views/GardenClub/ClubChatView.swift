import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftUI

public struct ClubChatView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub

    @State private var messages: [ClubMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    private var currentUserName: String {
        dataService.getCurrentUser()?.displayName ?? "You"
    }

    public init(club: GardenClub) {
        self.club = club
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                messageList
                inputBar
            }
        }
        .navigationTitle("Chat")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent }
            .task { await loadMessages() }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadPhoto(from: newItem) }
            }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
                    ForEach(messages, id: \.id) { message in
                        messageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .onChange(of: messages.count) { _, newCount in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(message: ClubMessage) -> some View {
        let isCurrentUser = message.senderID == currentUserID

        return HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer() }

            if !isCurrentUser {
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Colors.brandMint)
                        .frame(width: 32, height: 32)
                    Text((message.senderName ?? "?").prefix(1).uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.brandForest)
                }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName ?? "Unknown")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }

                if let photoData = message.photoData, let uiImage = UIImage(data: photoData) {
                    #if os(iOS)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    #endif
                }

                if let text = message.text, !text.isEmpty {
                    Text(text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(isCurrentUser ? .white : CultivationTheme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if isCurrentUser {
                                    CultivationTheme.Gradients.ctaVertical
                                } else {
                                    CultivationTheme.Colors.cardSurface
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                }

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            if isCurrentUser {
                ZStack {
                    Circle()
                        .fill(CultivationTheme.Gradients.ctaVertical)
                        .frame(width: 32, height: 32)
                    Text((message.senderName ?? "?").prefix(1).uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if !isCurrentUser { Spacer() }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: CultivationTheme.Spacing.rowGap) {
            Button {
                showPhotoPicker = true
            } label: {
                Image(systemName: "photo.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("club_chat_photo_button")

            TextField("Message…", text: $newMessageText, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CultivationTheme.Colors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                #if os(iOS)
                .textInputAutocapitalization(.sentences)
                #endif

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        newMessageText.isEmpty
                            ? CultivationTheme.Colors.textTertiary
                            : CultivationTheme.Colors.brandLeaf
                    )
            }
            .buttonStyle(.plain)
            .disabled(newMessageText.isEmpty)
            .accessibilityIdentifier("club_chat_send_button")
        }
        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Text("\(club.name ?? "Club")")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let clubID = club.id else { return }
            messages = try dataService.fetchClubMessages(for: clubID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage() async {
        guard !newMessageText.isEmpty else { return }
        guard let clubID = club.id else { return }

        do {
            let message = try dataService.sendClubMessage(
                clubID: clubID,
                senderID: currentUserID,
                senderName: currentUserName,
                text: newMessageText
            )
            messages.append(message)
            newMessageText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedPhotoData = data
                // Auto-send photo
                guard let clubID = club.id else { return }
                let message = try dataService.sendClubPhoto(
                    clubID: clubID,
                    senderID: currentUserID,
                    senderName: currentUserName,
                    photoData: data
                )
                messages.append(message)
                selectedPhotoItem = nil
            }
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    let club = GardenClub(name: "Test Club", ownerID: "user1", inviteCode: "TEST42")
    NavigationStack {
        ClubChatView(club: club)
    }
}