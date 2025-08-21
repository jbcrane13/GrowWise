import SwiftUI
import GrowWiseModels

struct SkillAssessmentView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.adaptiveGreen)
                    
                    Text("What's your gardening experience?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This helps us personalize your experience and recommend the right plants for you.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Skill level options
                VStack(spacing: 16) {
                    ForEach(GardeningSkillLevel.allCases, id: \.self) { level in
                        SkillLevelCard(
                            level: level,
                            isSelected: userProfile.skillLevel == level,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    userProfile.skillLevel = level
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Additional interests
                if userProfile.skillLevel != .beginner {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What interests you most?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(PlantType.allCases, id: \.self) { plantType in
                                InterestTag(
                                    plantType: plantType,
                                    isSelected: userProfile.interests.contains(plantType),
                                    action: {
                                        if userProfile.interests.contains(plantType) {
                                            userProfile.interests.remove(plantType)
                                        } else {
                                            userProfile.interests.insert(plantType)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Bottom spacer for navigation buttons
                Spacer(minLength: 80)
            }
            .padding()
        }
        .animation(.easeInOut, value: userProfile.skillLevel)
    }
}

struct SkillLevelCard: View {
    let level: GardeningSkillLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: level.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .adaptiveGreen)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(level.description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.adaptiveSelectionBackground : Color.adaptiveCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.adaptiveGreen, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InterestTag: View {
    let plantType: PlantType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: plantType.iconName)
                    .font(.caption2)
                
                Text(plantType.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.adaptiveSelectionBackground : Color.adaptiveTertiaryBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Flexible layout for tags
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
        // Rough estimation for tag width
        if let plantType = element as? PlantType {
            return CGFloat(plantType.displayName.count * 8) + 40 // Icon + padding
        }
        return 100 // Default fallback
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

// Extensions for skill level and plant type
extension GardeningSkillLevel {
    var iconName: String {
        switch self {
        case .beginner: return "sprout.circle"
        case .intermediate: return "leaf"
        case .advanced: return "tree"
        case .expert: return "tree.fill"
        }
    }
}

extension PlantType {
    var iconName: String {
        switch self {
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .flower: return "sparkles"
        case .houseplant: return "house.fill"
        case .fruit: return "apple.logo"
        case .succulent: return "circle.grid.3x3.fill"
        case .tree: return "tree.fill"
        case .shrub: return "tree.fill"
        }
    }
}

#Preview {
    SkillAssessmentView(userProfile: .constant(UserProfile()))
        .padding()
}