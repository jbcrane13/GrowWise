import GrowWiseModels
import GrowWiseServices
import SwiftUI
#if canImport(UIKit)
import UIKit

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes
#endif

public struct ClubListView: View {
    @Environment(DataService.self) private var dataService

    @State private var clubs: [GardenClub] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()

                if isLoading, clubs.isEmpty {
                    ProgressView("Loading clubs…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if clubs.isEmpty {
                    emptyState
                } else {
                    clubList
                }
            }
            .navigationTitle("Garden Clubs")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCreateSheet) {
                CreateClubSheet(onCreated: { club in
                    clubs.insert(club, at: 0)
                })
                .environment(dataService)
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinClubSheet(onJoined: { club in
                    if !clubs.contains(where: { $0.id == club.id }) {
                        clubs.append(club)
                    }
                })
                .environment(dataService)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
                    .accessibilityIdentifier("club_list_button_error_dismiss")
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadClubs() }
            .refreshable { await loadClubs() }
        }
    }

    // MARK: - Subviews

    private var clubList: some View {
        ScrollView {
            LazyVStack(spacing: CultivationTheme.Spacing.rowGap) {
                ForEach(clubs, id: \.id) { club in
                    NavigationLink {
                        ClubDetailView(club: club)
                            .environment(dataService)
                    } label: {
                        ClubRowView(club: club)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("club_list_navlink_\(club.id?.uuidString ?? "unknown")")
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 80, height: 80)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("No Garden Clubs Yet")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Start or join a garden club to share your\ngardening journey with others.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Create Club") { showCreateSheet = true }
                    .buttonStyle(GradientButtonStyle())
                    .accessibilityIdentifier("club_list_button_create_empty")

                Button("Join Club") { showJoinSheet = true }
                    .buttonStyle(OutlineButtonStyle())
                    .accessibilityIdentifier("club_list_button_join_empty")
            }
        }
        .padding(CultivationTheme.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showCreateSheet = true } label: {
                    Label("Create Club", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("club_list_menu_create")
                Button { showJoinSheet = true } label: {
                    Label("Join Club", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("club_list_menu_join")
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }
            .accessibilityIdentifier("club_list_add_button")
        }
    }

    // MARK: - Data

    @MainActor
    private func loadClubs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            clubs = try dataService.fetchClubs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Club Row

private struct ClubRowView: View {
    let club: GardenClub

    private var memberCount: Int {
        (club.memberIDs ?? []).count
    }

    private var lastActive: String {
        guard let date = club.createdDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                    .fill(CultivationTheme.Gradients.ctaVertical)
                    .frame(width: 48, height: 48)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name ?? "Unnamed Club")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("\(memberCount) member\(memberCount == 1 ? "" : "s")", systemImage: "person.fill")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)

                    if !lastActive.isEmpty {
                        Text("· \(lastActive)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }
}

#Preview {
    ClubListView()
}

// swiftlint:enable attributes
