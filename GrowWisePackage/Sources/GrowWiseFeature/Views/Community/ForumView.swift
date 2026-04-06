import GrowWiseServices
import SwiftUI

/// Main community Q&A forum view with topic filters, search, and question list.
public struct ForumView: View {
    @Environment(ForumService.self)
    private var forumService

    @State private var selectedTopic: ForumTopic?
    @State private var searchText = ""
    @State private var sortOrder: ForumSortOrder = .newest
    @State private var showAskQuestion = false
    @State private var hasMorePages = false
    @State private var showError = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    // Search bar
                    searchBar

                    // Topic filter chips
                    topicFilters

                    // Sort toggle
                    sortPicker

                    // Question list
                    questionList

                    // Load more
                    if hasMorePages {
                        loadMoreButton
                    }
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Q&A Forum")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAskQuestion = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    }
                    .accessibilityIdentifier("forum_ask_button")
                }
            }
            .sheet(isPresented: $showAskQuestion) {
                AskQuestionSheet(onPosted: {
                    Task<Void, Never> {
                        await refreshQuestions()
                    }
                })
            }
            .alert("Error", isPresented: $showError, presenting: forumService.errorMessage) { _ in
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("forum_button_error_dismiss")
            } message: { message in
                Text(message)
            }
            .refreshable {
                await refreshQuestions()
            }
            .task {
                await refreshQuestions()
            }
            .accessibilityIdentifier("forum_list")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            TextField("Search questions...", text: $searchText)
                .font(.system(.body))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .submitLabel(.search)
                .onSubmit {
                    Task<Void, Never> {
                        await refreshQuestions()
                    }
                }
                .accessibilityIdentifier("forum_search")
        }
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
    }

    // MARK: - Topic Filters

    private var topicFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GlassPill(
                    label: "All",
                    isSelected: selectedTopic == nil,
                    accessibilityID: "forum_topic_all"
                ) {
                    selectedTopic = nil
                    Task<Void, Never> { await refreshQuestions() }
                }

                ForEach(ForumTopic.allCases, id: \.rawValue) { topic in
                    GlassPill(
                        label: topic.displayName,
                        isSelected: selectedTopic == topic,
                        accessibilityID: "forum_topic_\(topic.rawValue)"
                    ) {
                        selectedTopic = topic
                        Task<Void, Never> { await refreshQuestions() }
                    }
                }
            }
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by")
                .sectionLabelStyle()

            Spacer()

            Picker("Sort", selection: $sortOrder) {
                ForEach(ForumSortOrder.allCases, id: \.rawValue) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .accessibilityIdentifier("forum_sort_picker")
            .onChange(of: sortOrder) {
                Task<Void, Never> { await refreshQuestions() }
            }
        }
    }

    // MARK: - Question List

    private var questionList: some View {
        LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
            if forumService.isLoadingQuestions, forumService.questions.isEmpty {
                ForEach(0 ..< 3, id: \.self) { _ in
                    questionPlaceholder
                }
            } else if forumService.questions.isEmpty {
                emptyState
            } else {
                ForEach(forumService.questions) { question in
                    NavigationLink {
                        QuestionDetailView(question: question)
                    } label: {
                        questionCard(question)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("forum_question_card_\(question.id.uuidString)")
                }
            }
        }
    }

    // MARK: - Question Card

    private func questionCard(_ question: ForumQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Meta row
            HStack(spacing: 14) {
                // Votes
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(CultivationTheme.Colors.accentAmber)
                    Text("\(question.voteCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                // Answers
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    Text("\(question.answerCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()

                // Author + time
                Text("\(question.authorName) \(Self.timeAgo(question.createdDate))")
                    .font(.system(size: 11))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            IconBubble(
                systemName: "bubble.left.and.bubble.right",
                color: CultivationTheme.Colors.accentCoral,
                size: 56,
                iconSize: 24
            )

            Text("No questions yet")
                .font(.system(.headline, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Be the first to ask the community!")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)

            Button {
                showAskQuestion = true
            } label: {
                Text("Ask a Question")
            }
            .buttonStyle(GradientButtonStyle())
            .frame(width: 200)
            .accessibilityIdentifier("forum_empty_ask_button")
        }
        .padding(.vertical, 40)
    }

    // MARK: - Placeholder

    private var questionPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(CultivationTheme.Colors.cardSurface)
                .frame(width: 80, height: 20)
            RoundedRectangle(cornerRadius: 6)
                .fill(CultivationTheme.Colors.cardSurface)
                .frame(height: 18)
            RoundedRectangle(cornerRadius: 6)
                .fill(CultivationTheme.Colors.cardSurface)
                .frame(width: 200, height: 14)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .redacted(reason: .placeholder)
    }

    // MARK: - Load More

    private var loadMoreButton: some View {
        Button {
            Task<Void, Never> {
                do {
                    try await forumService.loadMoreQuestions(
                        topic: selectedTopic,
                        searchQuery: searchText.isEmpty ? nil : searchText,
                        sortOrder: sortOrder
                    )
                } catch {
                    showError = true
                }
            }
        } label: {
            if forumService.isLoadingQuestions {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Load More")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .glassCard()
        .accessibilityIdentifier("forum_load_more")
    }

    // MARK: - Helpers

    private func refreshQuestions() async {
        do {
            let result = try await forumService.fetchQuestions(
                topic: selectedTopic,
                searchQuery: searchText.isEmpty ? nil : searchText,
                sortOrder: sortOrder
            )
            hasMorePages = result.cursor != nil
        } catch {
            showError = true
        }
    }

    /// Returns a human-readable relative time string.
    static func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
