import CloudKit
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable function_body_length type_body_length

/// Detail view for a forum question showing the full body, answers, and interaction controls.
struct QuestionDetailView: View {
    @Environment(ForumService.self)
    private var forumService

    let question: ForumQuestion

    @State private var answers: [ForumAnswer] = []
    @State private var answerText = ""
    @State private var authorName = ""
    @State private var isPostingAnswer = false
    @State private var showReportConfirmation = false
    @State private var reportRecordID: CKRecord.ID?
    @State private var hasUpvotedQuestion = false
    @State private var showUpvoteError = false
    @State private var upvoteErrorMessage: String?

    /// Track upvoted answer IDs to prevent double-voting in the session
    @State private var upvotedAnswerIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                // Question section
                questionSection

                // Divider
                Rectangle()
                    .fill(CultivationTheme.Colors.divider)
                    .frame(height: 1)

                // Answers header
                HStack {
                    Text("Answers (\(answers.count))")
                        .sectionLabelStyle()
                    Spacer()
                }

                // Answer list
                answerList

                // Post answer section
                postAnswerSection
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle("Question")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let recordID = question.recordID {
                            Button(role: .destructive) {
                                reportRecordID = recordID
                                showReportConfirmation = true
                            } label: {
                                Label("Report Question", systemImage: "flag")
                            }
                            .accessibilityIdentifier("forum_report_question")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                    .accessibilityIdentifier("forum_question_menu")
                }
            }
            .alert("Vote Failed", isPresented: $showUpvoteError) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("forum_button_upvote_error_dismiss")
            } message: {
                Text(upvoteErrorMessage ?? "Could not register your vote. Please try again.")
            }
            .alert("Report Content", isPresented: $showReportConfirmation) {
                Button("Report", role: .destructive) {
                    if let recordID = reportRecordID {
                        Task<Void, Never> {
                            try? await forumService.reportContent(recordID: recordID, reason: "Inappropriate content")
                        }
                    }
                }
                .accessibilityIdentifier("forum_button_report_confirm")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("forum_button_report_cancel")
            } message: {
                Text("Are you sure you want to report this content as inappropriate?")
            }
            .task {
                await loadAnswers()
            }
            .accessibilityIdentifier("forum_question_detail")
    }

    // MARK: - Question Section

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Topic tag
            HStack(spacing: 6) {
                Image(systemName: question.topic.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(question.topic.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(CultivationTheme.Colors.accentCoral)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(CultivationTheme.Colors.accentCoral.opacity(0.12))
            }

            // Title
            Text(question.title)
                .font(.system(.title2, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            // Author + date
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text(question.authorName)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)

                Text(ForumView.timeAgo(question.createdDate))
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            // Body
            Text(question.body)
                .font(.system(.body, design: .default))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Upvote button
            HStack(spacing: 16) {
                Button {
                    guard !hasUpvotedQuestion else { return }
                    hasUpvotedQuestion = true
                    Task<Void, Never> {
                        do {
                            try await forumService.upvoteQuestion(question)
                        } catch {
                            hasUpvotedQuestion = false
                            upvoteErrorMessage = error.localizedDescription
                            showUpvoteError = true
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasUpvotedQuestion ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .font(.system(size: 18, weight: .medium))
                        Text("\(question.voteCount + (hasUpvotedQuestion ? 1 : 0))")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(
                        hasUpvotedQuestion
                            ? CultivationTheme.Colors.accentAmber
                            : CultivationTheme.Colors.textSecondary
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(
                            hasUpvotedQuestion
                                ? CultivationTheme.Colors.accentAmber.opacity(0.12)
                                : CultivationTheme.Colors.cardSurface
                        )
                    }
                    .overlay {
                        Capsule().stroke(
                            hasUpvotedQuestion
                                ? CultivationTheme.Colors.accentAmber.opacity(0.3)
                                : CultivationTheme.Colors.cardBorder,
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
                .disabled(hasUpvotedQuestion)
                .accessibilityIdentifier("forum_upvote_question")

                // Answer count badge
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                    Text("\(answers.count) answers")
                        .font(.system(.subheadline))
                }
                .foregroundStyle(CultivationTheme.Colors.textSecondary)

                Spacer()
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Answer List

    private var answerList: some View {
        LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
            if forumService.isLoadingAnswers {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if answers.isEmpty {
                VStack(spacing: 8) {
                    Text("No answers yet")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Text("Be the first to help!")
                        .font(.system(.caption))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(answers) { answer in
                    answerCard(answer)
                        .accessibilityIdentifier("forum_answer_\(answer.id.uuidString)")
                }
            }
        }
    }

    // MARK: - Answer Card

    private func answerCard(_ answer: ForumAnswer) -> some View {
        let hasUpvoted = upvotedAnswerIDs.contains(answer.id)

        return VStack(alignment: .leading, spacing: 10) {
            // Accepted badge
            if answer.isAccepted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                    Text("Accepted Answer")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(CultivationTheme.Colors.statusHealthy)
            }

            // Answer body
            Text(answer.body)
                .font(.system(.body, design: .default))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Meta row
            HStack(spacing: 12) {
                // Upvote
                Button {
                    guard !hasUpvoted else { return }
                    upvotedAnswerIDs.insert(answer.id)
                    Task<Void, Never> {
                        do {
                            try await forumService.upvoteAnswer(answer)
                        } catch {
                            upvotedAnswerIDs.remove(answer.id)
                            upvoteErrorMessage = error.localizedDescription
                            showUpvoteError = true
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasUpvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .font(.system(size: 15, weight: .medium))
                        Text("\(answer.voteCount + (hasUpvoted ? 1 : 0))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(
                        hasUpvoted
                            ? CultivationTheme.Colors.accentAmber
                            : CultivationTheme.Colors.textSecondary
                    )
                }
                .buttonStyle(.plain)
                .disabled(hasUpvoted)
                .accessibilityIdentifier("forum_upvote_answer_\(answer.id.uuidString)")

                Spacer()

                // Author + time
                Text("\(answer.authorName) \(ForumView.timeAgo(answer.createdDate))")
                    .font(.system(size: 11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)

                // Report menu
                if let recordID = answer.recordID {
                    Menu {
                        Button(role: .destructive) {
                            reportRecordID = recordID
                            showReportConfirmation = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                        .accessibilityIdentifier("forum_report_answer_\(answer.id.uuidString)")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            .frame(width: 24, height: 24)
                    }
                    .accessibilityIdentifier("forum_answer_menu_\(answer.id.uuidString)")
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .background {
            if answer.isAccepted {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(CultivationTheme.Colors.statusHealthy.opacity(0.04))
            }
        }
        .glassCard()
    }

    // MARK: - Post Answer Section

    private var postAnswerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Answer")
                .sectionLabelStyle()
                .padding(.leading, 4)

            TextField("Your name", text: $authorName)
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
                .accessibilityIdentifier("forum_answer_author_name")

            TextEditor(text: $answerText)
                .font(.system(.body, design: .default))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .fill(CultivationTheme.Colors.cardSurface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                }
                .accessibilityIdentifier("forum_answer_body")

            Button {
                Task<Void, Never> {
                    await postAnswer()
                }
            } label: {
                if isPostingAnswer {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Post Answer")
                }
            }
            .buttonStyle(GradientButtonStyle(isDisabled: !canPostAnswer))
            .disabled(!canPostAnswer || isPostingAnswer)
            .accessibilityIdentifier("forum_post_answer")
        }
    }

    // MARK: - Helpers

    private var canPostAnswer: Bool {
        !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadAnswers() async {
        do {
            answers = try await forumService.fetchAnswers(for: question)
        } catch {
            upvoteErrorMessage = error.localizedDescription
            showUpvoteError = true
        }
    }

    private func postAnswer() async {
        guard canPostAnswer else { return }
        isPostingAnswer = true
        defer { isPostingAnswer = false }

        do {
            try await forumService.postAnswer(
                body: answerText.trimmingCharacters(in: .whitespacesAndNewlines),
                authorName: authorName.trimmingCharacters(in: .whitespacesAndNewlines),
                for: question
            )
            answerText = ""
            await loadAnswers()
        } catch {
            upvoteErrorMessage = error.localizedDescription
            showUpvoteError = true
        }
    }
}

// swiftlint:enable function_body_length type_body_length
