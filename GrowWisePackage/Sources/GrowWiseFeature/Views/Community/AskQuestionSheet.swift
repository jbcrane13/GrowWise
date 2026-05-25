import GrowWiseServices
import SwiftUI

/// Sheet for composing and posting a new forum question.
struct AskQuestionSheet: View {
    @Environment(ForumService.self)
    private var forumService

    @Environment(\.dismiss)
    private var dismiss

    @State private var title = ""
    @State private var questionBody = ""
    @State private var selectedTopic: ForumTopic = .general
    @State private var authorName = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var onPosted: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    // Header
                    VStack(spacing: 8) {
                        IconBubble(
                            systemName: "questionmark.bubble.fill",
                            color: CultivationTheme.Colors.accentCoral,
                            size: 56,
                            iconSize: 24
                        )
                        Text("Ask the Community")
                            .font(.system(.title2, design: .serif, weight: .regular))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        Text("Get help from fellow gardeners")
                            .font(.system(.subheadline))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                    .padding(.top, 8)

                    // Form fields
                    VStack(alignment: .leading, spacing: 14) {
                        // Author name
                        fieldSection(label: "Your Name") {
                            TextField("Enter your name", text: $authorName)
                                .font(.system(.body))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .fill(CultivationTheme.Colors.cardSurface)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                                }
                                .accessibilityIdentifier("forum_ask_author")
                        }

                        // Title
                        fieldSection(label: "Question Title") {
                            TextField("What's your gardening question?", text: $title)
                                .font(.system(.body))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .fill(CultivationTheme.Colors.cardSurface)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                                }
                                .accessibilityIdentifier("forum_ask_title")
                        }

                        // Topic picker
                        fieldSection(label: "Topic") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ForumTopic.allCases, id: \.rawValue) { topic in
                                        GlassPill(
                                            label: topic.displayName,
                                            isSelected: selectedTopic == topic,
                                            accessibilityID: "forum_ask_topic_\(topic.rawValue)"
                                        ) {
                                            selectedTopic = topic
                                        }
                                    }
                                }
                            }
                            .accessibilityIdentifier("forum_ask_topic")
                        }

                        // Body
                        fieldSection(label: "Details") {
                            TextEditor(text: $questionBody)
                                .font(.system(.body, design: .default))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .fill(CultivationTheme.Colors.cardSurface)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                                }
                                .accessibilityIdentifier("forum_ask_body")
                        }
                    }

                    // Post button
                    Button {
                        Task<Void, Never> {
                            await postQuestion()
                        }
                    } label: {
                        if forumService.isPosting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Post Question")
                        }
                    }
                    .buttonStyle(GradientButtonStyle(isDisabled: !canPost))
                    .disabled(!canPost || forumService.isPosting)
                    .accessibilityIdentifier("forum_ask_post_button")
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Ask a Question")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .accessibilityIdentifier("forum_ask_cancel")
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                        .accessibilityIdentifier("forum_ask_error_ok")
                } message: {
                    Text(errorMessage)
                }
        }
    }

    // MARK: - Field Section

    private func fieldSection(
        label: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .sectionLabelStyle()
                .padding(.leading, 4)
            content()
        }
    }

    // MARK: - Validation

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !questionBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Post

    private func postQuestion() async {
        guard canPost else { return }

        do {
            try await forumService.postQuestion(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: questionBody.trimmingCharacters(in: .whitespacesAndNewlines),
                topic: selectedTopic,
                authorName: authorName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onPosted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
