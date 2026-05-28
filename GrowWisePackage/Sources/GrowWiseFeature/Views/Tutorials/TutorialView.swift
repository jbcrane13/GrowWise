import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct TutorialView: View {
    public nonisolated static let learningHubTitle = "Learn & Grow"
    public nonisolated static let homeLearningCardTitle = "Learn what to plant now"

    @Environment(TutorialService.self)
    private var tutorialService
    @State private var selectedCategory: TutorialCategory = .planning
    @State private var searchText = ""
    @State private var showProgressView = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    heroSection
                    plantingGuideSection
                    beginnerPathSection
                    categorySelector
                    tutorialListSection
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle(Self.learningHubTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProgressView = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .accessibilityLabel("Learning progress")
                    .accessibilityIdentifier("tutorials_button_progress")
                }
            }
            .navigationDestination(for: TutorialTopic.self) { tutorial in
                TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)
            }
            .sheet(isPresented: $showProgressView) {
                TutorialProgressView(tutorialService: tutorialService)
            }
            .searchable(text: $searchText, prompt: "Search tutorials")
            .accessibilityIdentifier("tutorials_screen")
        }
    }

    private var heroSection: some View {
        let analytics = tutorialService.getTutorialAnalytics()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IconBubble(
                    systemName: "graduationcap.fill",
                    color: CultivationTheme.Colors.brandLeaf,
                    size: 46,
                    iconSize: 20
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(Self.learningHubTitle)
                        .font(CultivationTheme.Fonts.display(26, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text("Seasonal guidance, beginner lessons, and practical next steps for your garden.")
                        .font(CultivationTheme.Fonts.body(14))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                learningStat(
                    value: "\(analytics.completedTutorials)",
                    label: "Done",
                    icon: "checkmark.circle.fill"
                )
                learningStat(
                    value: "\(analytics.totalTutorials - analytics.completedTutorials)",
                    label: "To Learn",
                    icon: "book.closed.fill"
                )
                learningStat(
                    value: "\(Int(analytics.completionRate * 100))%",
                    label: "Progress",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("tutorials_card_hero")
    }

    private func learningStat(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.accentCoral)
            Text(value)
                .font(CultivationTheme.Fonts.display(18, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text(label)
                .font(CultivationTheme.Fonts.body(11))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
    }

    private var plantingGuideSection: some View {
        let guide = tutorialService.getPlantingGuide().prefix(6)

        return VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            HStack {
                Text("WHAT TO PLANT NOW")
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                Spacer()

                Text(currentMonthName)
                    .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            if guide.isEmpty {
                emptyPlantingGuideCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(guide), id: \.id) { item in
                            plantingGuideCard(item)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var emptyPlantingGuideCard: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: "calendar.badge.clock",
                color: CultivationTheme.Colors.textTertiary,
                size: 40,
                iconSize: 17
            )

            Text("No planting windows are highlighted for this month. Browse the beginner path for prep work.")
                .font(CultivationTheme.Fonts.body(13))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("tutorials_card_planting_empty")
    }

    private func plantingGuideCard(_ item: PlantingGuideItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconBubble(
                    systemName: item.action.icon,
                    color: item.beginnerFriendly
                        ? CultivationTheme.Colors.brandLeaf
                        : CultivationTheme.Colors.accentAmber,
                    size: 34,
                    iconSize: 15
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.plantName)
                        .font(CultivationTheme.Fonts.display(17, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(item.action.displayName)
                        .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
            }

            Text(item.whyNow)
                .font(CultivationTheme.Fonts.body(12))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.nextStep)
                .font(CultivationTheme.Fonts.body(11))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 230, alignment: .leading)
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("tutorials_card_planting_\(item.id)")
    }

    private var beginnerPathSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("BEGINNER PATH")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            LazyVStack(spacing: 10) {
                ForEach(Array(tutorialService.getBeginnerLearningPath().enumerated()), id: \.element.id) { index, tutorial in
                    NavigationLink(value: tutorial) {
                        BeginnerPathRow(index: index + 1, tutorial: tutorial, tutorialService: tutorialService)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tutorials_row_beginner_\(tutorial.id)")
                }
            }
        }
    }

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BROWSE BY TOPIC")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TutorialCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(CultivationTheme.Animation.selection) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
        }
    }

    private var tutorialListSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            HStack {
                Text(selectedCategory.displayName.uppercased())
                    .sectionLabelStyle()
                    .foregroundStyle(CultivationTheme.Colors.sectionLabel)

                Spacer()

                Text("\(filteredTutorials.count)")
                    .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            LazyVStack(spacing: 10) {
                ForEach(filteredTutorials, id: \.id) { tutorial in
                    NavigationLink(value: tutorial) {
                        TutorialRowView(tutorial: tutorial, tutorialService: tutorialService)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tutorials_row_\(tutorial.id)")
                }
            }
        }
    }

    private var filteredTutorials: [TutorialTopic] {
        let categoryTutorials = tutorialService.getAllTutorials().filter { $0.category == selectedCategory }
        guard !searchText.isEmpty else { return categoryTutorials }

        let lowercasedSearch = searchText.lowercased()
        return categoryTutorials.filter { tutorial in
            tutorial.title.lowercased().contains(lowercasedSearch) ||
                tutorial.description.lowercased().contains(lowercasedSearch) ||
                tutorial.subtitle.lowercased().contains(lowercasedSearch)
        }
    }

    private var currentMonthName: String {
        let month = Calendar.current.component(.month, from: Date())
        return Calendar.current.monthSymbols[month - 1]
    }
}

private struct CategoryChip: View {
    let category: TutorialCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.displayName)
                    .font(CultivationTheme.Fonts.body(12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : CultivationTheme.Colors.textSecondary)
            .background {
                Capsule()
                    .fill(isSelected ? CultivationTheme.Colors.brandForest : CultivationTheme.Colors.backgroundSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tutorials_button_category_\(category.rawValue)")
    }
}

private struct BeginnerPathRow: View {
    let index: Int
    let tutorial: TutorialTopic
    let tutorialService: TutorialService

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(CultivationTheme.Fonts.display(16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(CultivationTheme.Colors.brandForest))

            VStack(alignment: .leading, spacing: 5) {
                Text(tutorial.title)
                    .font(CultivationTheme.Fonts.display(16, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(tutorial.subtitle)
                    .font(CultivationTheme.Fonts.body(12))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(2)

                TutorialMetadata(
                    difficulty: tutorial.difficultyLevel,
                    duration: tutorial.estimatedDuration,
                    progress: tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                )
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
    }
}

private struct TutorialRowView: View {
    let tutorial: TutorialTopic
    let tutorialService: TutorialService

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBubble(
                systemName: tutorial.category.iconName,
                color: difficultyColor,
                size: 38,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(tutorial.title)
                        .font(CultivationTheme.Fonts.display(16, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .lineLimit(2)

                    if tutorialService.getTutorialProgress(tutorialId: tutorial.id).isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                Text(tutorial.description)
                    .font(CultivationTheme.Fonts.body(12))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(2)

                TutorialMetadata(
                    difficulty: tutorial.difficultyLevel,
                    duration: tutorial.estimatedDuration,
                    progress: tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                )
            }

            Spacer()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
    }

    private var difficultyColor: Color {
        switch tutorial.difficultyLevel {
        case .beginner: CultivationTheme.Colors.brandLeaf
        case .intermediate: CultivationTheme.Colors.accentAmber
        case .advanced: CultivationTheme.Colors.accentCoral
        }
    }
}

struct TutorialMetadata: View {
    let difficulty: DifficultyLevel
    let duration: Int
    let progress: TutorialProgress

    var body: some View {
        HStack(spacing: 10) {
            metadataPill(icon: "graduationcap.fill", text: difficulty.displayName, color: difficultyColor)
            metadataPill(icon: "clock.fill", text: "\(duration) min", color: CultivationTheme.Colors.textTertiary)

            if progress.isCompleted {
                metadataPill(icon: "checkmark.circle.fill", text: "Complete", color: CultivationTheme.Colors.statusHealthy)
            } else if progress.completedSteps > 0 {
                metadataPill(
                    icon: "clock.arrow.circlepath",
                    text: "\(progress.completedSteps)/\(progress.totalSteps)",
                    color: CultivationTheme.Colors.brandLeaf
                )
            }
        }
    }

    private func metadataPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(CultivationTheme.Fonts.body(11, weight: .medium))
        }
        .foregroundStyle(color)
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: CultivationTheme.Colors.brandLeaf
        case .intermediate: CultivationTheme.Colors.accentAmber
        case .advanced: CultivationTheme.Colors.accentCoral
        }
    }
}

extension TutorialCategory {
    var iconName: String {
        switch self {
        case .planning: "map.fill"
        case .preparation: "trowel.fill"
        case .care: "heart.fill"
        case .environment: "sun.max.fill"
        case .problemSolving: "stethoscope"
        }
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let tutorialService = TutorialService(dataService: dataService)

    TutorialView()
        .environment(tutorialService)
}
