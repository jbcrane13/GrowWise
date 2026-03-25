import CloudKit
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct CommunityFeedView: View {
    @Environment(CloudSyncService.self)
    private var cloudSyncService
    @Environment(DataService.self)
    private var dataService

    @State private var gardens: [PublicGarden] = []
    @State private var sortOrder: PublicGardenSort = .newest
    @State private var cursor: CKQueryOperation.Cursor?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var errorMessage: String?
    @State private var showPublishSheet = false
    @State private var appeared = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                headerSection
                sortBar
                contentSection
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle("Community")
        .refreshable {
            await loadGardens(reset: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPublishSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                }
                .accessibilityIdentifier("community_publish_button")
            }
        }
        .sheet(isPresented: $showPublishSheet) {
            PublishGardenSheet()
                .environment(cloudSyncService)
                .environment(dataService)
        }
        .task {
            guard !appeared else { return }
            appeared = true
            await loadGardens(reset: true)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 56, height: 56)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Garden Showcase")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Discover and share gardens from the community")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PublicGardenSort.allCases, id: \.self) { sort in
                    GlassPill(
                        label: sort.displayName,
                        isSelected: sortOrder == sort,
                        accessibilityID: "community_sort_\(sort.rawValue)"
                    ) {
                        guard sortOrder != sort else { return }
                        sortOrder = sort
                        Task<Void, Never> {
                            await loadGardens(reset: true)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("community_sort_button")
    }

    // MARK: - Content

    private var contentSection: some View {
        Group {
            if isLoading, gardens.isEmpty {
                loadingState
            } else if gardens.isEmpty {
                emptyState
            } else {
                gardenList
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading gardens...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityIdentifier("community_loading")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            Text("No Gardens Yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Be the first to share your garden with the community!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showPublishSheet = true
            } label: {
                Text("Publish Your Garden")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 40)
            .accessibilityIdentifier("community_empty_publish_button")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityIdentifier("community_empty_state")
    }

    private var gardenList: some View {
        LazyVStack(spacing: CultivationTheme.Spacing.sectionGap) {
            ForEach(gardens) { garden in
                PublicGardenCardView(garden: garden) {
                    Task<Void, Never> {
                        try? await cloudSyncService.likeGarden(garden)
                    }
                }
                .onAppear {
                    Task<Void, Never> {
                        await cloudSyncService.incrementViewCount(for: garden)
                    }
                    // Load more when near the end
                    if garden.id == gardens.last?.id, hasMorePages, !isLoadingMore {
                        Task<Void, Never> {
                            await loadMore()
                        }
                    }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityIdentifier("community_loading_more")
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.statusAlert)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .accessibilityIdentifier("community_feed_list")
    }

    // MARK: - Data Loading

    private func loadGardens(reset: Bool) async {
        if reset {
            isLoading = true
            cursor = nil
            errorMessage = nil
        }

        do {
            let (fetchedGardens, newCursor) = try await cloudSyncService.fetchPublicGardens(
                sortBy: sortOrder,
                limit: 20,
                cursor: reset ? nil : cursor
            )
            if reset {
                gardens = fetchedGardens
            } else {
                gardens.append(contentsOf: fetchedGardens)
            }
            cursor = newCursor
            hasMorePages = newCursor != nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        await loadGardens(reset: false)
        isLoadingMore = false
    }
}
