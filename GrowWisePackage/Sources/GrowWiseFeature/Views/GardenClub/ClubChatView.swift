import GrowWiseModels
import GrowWiseServices
import PhotosUI
import SwiftUI
#if os(iOS)
import UIKit

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes function_body_length identifier_name
#endif

public struct ClubChatView: View { // swiftlint:disable:this type_body_length
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub

    @State private var messages: [ClubMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingMessages: [PendingChatMessage] = []

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
                    .accessibilityIdentifier("club_chat_button_error_dismiss")
            } message: {
                Text(errorMessage ?? "")
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 5,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task { await loadPhotos(from: newItems) }
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
                    ForEach(pendingMessages) { pending in
                        pendingMessageRow(pending)
                            .id(pending.id)
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .onChange(of: messages.count + pendingMessages.count) { _, _ in
                if let last = pendingMessages.last?.id ?? messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
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

                if let photoData = message.photoData {
                    #if os(iOS)
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    }
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

                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                    if isCurrentUser {
                        deliveryIndicator(for: message)
                    }
                }
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

    private func pendingMessageRow(_ pending: PendingChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let photoData = pending.photoData {
                    #if os(iOS)
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                    }
                    #endif
                }
                if !pending.text.isEmpty {
                    Text(pending.text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CultivationTheme.Gradients.ctaVertical)
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                }

                HStack(spacing: 6) {
                    deliveryIcon(pending.state)
                    if pending.state == .failed {
                        Button("Retry") {
                            Task { await retryPendingMessage(pending) }
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("club_chat_retry_\(pending.id.uuidString)")
                    }
                }
                .foregroundStyle(
                    pending.state == .failed
                        ? CultivationTheme.Colors.statusAlert
                        : CultivationTheme.Colors.textTertiary
                )
            }
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
                .accessibilityIdentifier("club_chat_textfield_message")

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
        .background(CultivationTheme.Colors.cardSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CultivationTheme.Colors.cardBorder)
                .frame(height: 1)
        }
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
            try dataService.markClubMessagesRead(for: clubID, memberID: currentUserID)
            messages = try dataService.fetchClubMessages(for: clubID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage() async {
        guard !newMessageText.isEmpty else { return }
        guard let clubID = club.id else { return }

        let draft = PendingChatMessage(text: newMessageText, photoData: nil, state: .sending)
        pendingMessages.append(draft)
        newMessageText = ""

        do {
            let message = try dataService.sendClubMessage(
                clubID: clubID,
                senderID: currentUserID,
                senderName: currentUserName,
                text: draft.text
            )
            pendingMessages.removeAll { $0.id == draft.id }
            messages.append(message)
        } catch {
            markPendingMessage(draft.id, state: .failed)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let compressed = compressedPhotoData(from: data) ?? data
                await sendPhotoData(compressed)
            } catch {
                errorMessage = "Failed to load photo: \(error.localizedDescription)"
            }
        }
        selectedPhotoItems = []
    }

    @MainActor
    private func sendPhotoData(_ data: Data, retrying pending: PendingChatMessage? = nil) async {
        guard let clubID = club.id else { return }
        let draft = pending ?? PendingChatMessage(text: "", photoData: data, state: .sending)
        if pending == nil {
            pendingMessages.append(draft)
        } else {
            markPendingMessage(draft.id, state: .sending)
        }

        do {
            let message = try dataService.sendClubPhoto(
                clubID: clubID,
                senderID: currentUserID,
                senderName: currentUserName,
                photoData: data
            )
            pendingMessages.removeAll { $0.id == draft.id }
            messages.append(message)
        } catch {
            markPendingMessage(draft.id, state: .failed)
            errorMessage = "Failed to send photo: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func retryPendingMessage(_ pending: PendingChatMessage) async {
        guard let clubID = club.id else { return }
        markPendingMessage(pending.id, state: .sending)

        do {
            let message: ClubMessage = if let photoData = pending.photoData {
                try dataService.sendClubPhoto(
                    clubID: clubID,
                    senderID: currentUserID,
                    senderName: currentUserName,
                    photoData: photoData,
                    caption: pending.text.isEmpty ? nil : pending.text
                )
            } else {
                try dataService.sendClubMessage(
                    clubID: clubID,
                    senderID: currentUserID,
                    senderName: currentUserName,
                    text: pending.text
                )
            }
            pendingMessages.removeAll { $0.id == pending.id }
            messages.append(message)
        } catch {
            markPendingMessage(pending.id, state: .failed)
            errorMessage = error.localizedDescription
        }
    }

    private func markPendingMessage(_ id: UUID, state: ClubMessageDeliveryState) {
        guard let index = pendingMessages.firstIndex(where: { $0.id == id }) else { return }
        pendingMessages[index].state = state
    }

    @ViewBuilder
    private func deliveryIndicator(for message: ClubMessage) -> some View {
        if message.isSeenByAll(memberIDs: club.memberIDs) {
            Text("Seen")
                .accessibilityIdentifier("club_chat_seen_\(message.id?.uuidString ?? "unknown")")
        } else {
            deliveryIcon(message.deliveryState)
        }
    }

    private func deliveryIcon(_ state: ClubMessageDeliveryState) -> some View {
        let symbol = switch state {
        case .sending: "clock"
        case .sent: "checkmark"
        case .failed: "exclamationmark.circle.fill"
        }
        return Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
    }

    private func compressedPhotoData(from data: Data) -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1600
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.82)
        }
        let scale = maxDimension / longestSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
        #else
        return data
        #endif
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}

private struct PendingChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let photoData: Data?
    var state: ClubMessageDeliveryState

    init(id: UUID = UUID(), text: String, photoData: Data?, state: ClubMessageDeliveryState) {
        self.id = id
        self.text = text
        self.photoData = photoData
        self.state = state
    }
}

#Preview {
    let club = GardenClub(name: "Test Club", ownerID: "user1", inviteCode: "TEST42")
    NavigationStack {
        ClubChatView(club: club)
    }
}

// swiftlint:enable attributes function_body_length identifier_name
