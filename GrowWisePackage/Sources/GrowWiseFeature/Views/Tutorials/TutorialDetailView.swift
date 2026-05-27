import GrowWiseServices
import SwiftUI

public struct TutorialDetailView: View {
    let tutorial: TutorialTopic
    let tutorialService: TutorialService

    @State private var progress: TutorialProgress

    public init(tutorial: TutorialTopic, tutorialService: TutorialService) {
        self.tutorial = tutorial
        self.tutorialService = tutorialService
        _progress = State(initialValue: tutorialService.getTutorialProgress(tutorialId: tutorial.id))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                header
                stepList
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle(tutorial.title)
        .gwNavigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tutorialdetail_screen_\(tutorial.id)")
        .onAppear {
            refreshProgress()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IconBubble(
                    systemName: tutorial.category.iconName,
                    color: CultivationTheme.Colors.brandLeaf,
                    size: 46,
                    iconSize: 20
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(tutorial.title)
                        .font(CultivationTheme.Fonts.display(25, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(tutorial.subtitle)
                        .font(CultivationTheme.Fonts.body(14))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(tutorial.description)
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TutorialMetadata(
                        difficulty: tutorial.difficultyLevel,
                        duration: tutorial.estimatedDuration,
                        progress: progress
                    )

                    Spacer()

                    Text("\(progress.completedSteps)/\(progress.totalSteps)")
                        .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }

                ProgressView(value: Double(progress.completedSteps), total: Double(max(progress.totalSteps, 1)))
                    .tint(CultivationTheme.Colors.brandLeaf)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("tutorialdetail_card_header")
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("STEPS")
                .sectionLabelStyle()
                .foregroundStyle(CultivationTheme.Colors.sectionLabel)

            ForEach(Array(tutorial.steps.enumerated()), id: \.offset) { index, step in
                TutorialStepCard(
                    tutorialId: tutorial.id,
                    index: index,
                    step: step,
                    isCompleted: tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: index)
                ) {
                    tutorialService.markStepComplete(tutorialId: tutorial.id, stepIndex: index)
                    refreshProgress()
                }
            }
        }
    }

    private func refreshProgress() {
        progress = tutorialService.getTutorialProgress(tutorialId: tutorial.id)
    }
}

private struct TutorialStepCard: View {
    let tutorialId: String
    let index: Int
    let step: TutorialStep
    let isCompleted: Bool
    let completeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(CultivationTheme.Fonts.display(15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(stepNumberColor))

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(CultivationTheme.Fonts.display(18, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(step.duration) min")
                        .font(CultivationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                }
            }

            Text(step.content)
                .font(CultivationTheme.Fonts.body(14))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !step.tips.isEmpty {
                guidanceList(title: "Tips", icon: "leaf.fill", items: step.tips)
            }

            if !step.commonMistakes.isEmpty {
                guidanceList(title: "Avoid", icon: "exclamationmark.triangle.fill", items: step.commonMistakes)
            }

            Button {
                completeAction()
            } label: {
                Label(isCompleted ? "Completed" : "Mark Complete", systemImage: isCompleted ? "checkmark" : "circle")
                    .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(isCompleted ? CultivationTheme.Colors.brandLeaf : Color.white)
                    .background {
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                            .fill(isCompleted ? CultivationTheme.Colors.backgroundSecondary : CultivationTheme.Colors.brandForest)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)
            .accessibilityIdentifier("tutorialdetail_button_step_\(index)")
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .paperCard()
        .accessibilityIdentifier("tutorialdetail_card_step_\(index)")
    }

    private func guidanceList(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentCoral)
                Text(title.uppercased())
                    .font(CultivationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 7) {
                    Circle()
                        .fill(CultivationTheme.Colors.brandLeaf)
                        .frame(width: 4, height: 4)
                        .padding(.top, 7)

                    Text(item)
                        .font(CultivationTheme.Fonts.body(12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.icon)
                .fill(CultivationTheme.Colors.backgroundSecondary)
        )
    }

    private var stepNumberColor: Color {
        isCompleted ? CultivationTheme.Colors.statusHealthy : CultivationTheme.Colors.brandForest
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let tutorialService = TutorialService(dataService: dataService)
    let tutorial = TutorialContent.allTutorials[0]

    NavigationStack {
        TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)
    }
}
