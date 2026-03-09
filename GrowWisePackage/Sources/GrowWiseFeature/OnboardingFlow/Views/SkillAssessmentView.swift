import GrowWiseModels
import SwiftUI

struct SkillAssessmentView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                OnboardingStepHeader(
                    icon: "graduationcap.fill",
                    iconColor: Color.botanicalForest,
                    title: "What's your experience?",
                    subtitle: "We'll personalize your plant recommendations\nand care guides to match your skill level."
                )

                // Skill level cards
                VStack(spacing: 12) {
                    ForEach(GardeningSkillLevel.allCases, id: \.self) { level in
                        SkillLevelCard(
                            level: level,
                            isSelected: userProfile.skillLevel == level,
                            action: {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    userProfile.skillLevel = level
                                }
                            }
                        )
                        .accessibilityIdentifier("onboarding_skill_\(level.rawValue)")
                    }
                }
                .padding(.horizontal, 24)

                // Interest tags — shown for intermediate and above
                if userProfile.skillLevel != .beginner {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What interests you most?")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.botanicalForest)
                            .padding(.horizontal, 24)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                            spacing: 10
                        ) {
                            ForEach(PlantType.allCases, id: \.self) { plantType in
                                InterestTag(
                                    plantType: plantType,
                                    isSelected: userProfile.interests.contains(plantType),
                                    action: {
                                        withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
                                            if userProfile.interests.contains(plantType) {
                                                userProfile.interests.remove(plantType)
                                            } else {
                                                userProfile.interests.insert(plantType)
                                            }
                                        }
                                    }
                                )
                                .accessibilityIdentifier("onboarding_interest_\(plantType.rawValue)")
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .animation(.spring(duration: 0.4), value: userProfile.skillLevel)
    }
}

// MARK: - Skill Level Card

struct SkillLevelCard: View {
    let level: GardeningSkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.botanicalMint.opacity(0.35))
                        .frame(width: 52, height: 52)

                    Image(systemName: level.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.botanicalForest)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : Color.botanicalForest)

                    Text(level.description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.82) : Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection badge
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? Color.white.opacity(0.6) : Color.botanicalSage.opacity(0.5),
                                    lineWidth: 1.5
                                )
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [Color.botanicalForest, Color.botanicalLeaf.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white, Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? Color.botanicalForest.opacity(0.30)
                            : Color.black.opacity(0.06),
                        radius: isSelected ? 12 : 8,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Color.clear : Color.botanicalSage.opacity(0.20),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.displayName)
    }
}

// MARK: - Interest Tag

struct InterestTag: View {
    let plantType: PlantType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: plantType.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.botanicalForest)

                Text(plantType.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color.botanicalForest)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                            ? Color.botanicalForest
                            : Color.white
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.clear : Color.botanicalSage.opacity(0.30),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(plantType.displayName)
    }
}

// MARK: - Skill Level Extensions

extension GardeningSkillLevel {
    var iconName: String {
        switch self {
        case .beginner: "sprout.fill"
        case .intermediate: "leaf.fill"
        case .advanced: "tree"
        case .expert: "tree.fill"
        }
    }
}

// MARK: - Flexible View (unchanged utility)

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            FlexibleViewLayout(
                data: data,
                spacing: spacing,
                availableWidth: availableWidth,
                content: content
            )
        }
    }
}

struct FlexibleViewLayout<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let availableWidth: CGFloat
    let content: (Data.Element) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { rowData in
                HStack(spacing: spacing) {
                    ForEach(rowData, id: \.self, content: content)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var currentRow: [Data.Element] = []
        var currentWidth: CGFloat = 0

        for element in data {
            let elementWidth = estimateWidth(for: element)

            if currentWidth + elementWidth + spacing <= availableWidth || currentRow.isEmpty {
                currentRow.append(element)
                currentWidth += elementWidth + (currentRow.count > 1 ? spacing : 0)
            } else {
                rows.append(currentRow)
                currentRow = [element]
                currentWidth = elementWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    func estimateWidth(for element: Data.Element) -> CGFloat {
        if let plantType = element as? PlantType {
            return CGFloat(plantType.displayName.count * 8) + 40
        }
        return 100
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        SkillAssessmentView(userProfile: .constant(UserProfile()))
    }
}
