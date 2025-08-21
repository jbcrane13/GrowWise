import SwiftUI
import UIKit
import GrowWiseModels

struct GardeningGoalsView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 50))
                        .foregroundColor(.adaptiveGreen)
                    
                    Text("What are your gardening goals?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Select all that interest you. We'll personalize your experience based on your goals.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Goals grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(GardeningGoal.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: userProfile.goals.contains(goal),
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if userProfile.goals.contains(goal) {
                                        userProfile.goals.remove(goal)
                                    } else {
                                        userProfile.goals.insert(goal)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Space and garden type selection
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What type of garden do you have?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(GardenType.allCases, id: \.self) { gardenType in
                                    GardenTypeButton(
                                        gardenType: gardenType,
                                        isSelected: userProfile.gardenType == gardenType,
                                        action: {
                                            userProfile.gardenType = gardenType
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How much space do you have?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            ForEach(SpaceSize.allCases, id: \.self) { size in
                                SpaceSizeRow(
                                    size: size,
                                    isSelected: userProfile.spaceSize == size,
                                    action: {
                                        userProfile.spaceSize = size
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Bottom spacer for navigation buttons
                Spacer(minLength: 80)
            }
            .padding()
        }
    }
}

struct GoalCard: View {
    let goal: GardeningGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .adaptiveGreen)
                
                Text(goal.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(goal.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.adaptiveSelectionBackground : Color.adaptiveCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.adaptiveGreen, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GardenTypeButton: View {
    let gardenType: GardenType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: gardenType.iconName)
                    .font(.caption)
                
                Text(gardenType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.adaptiveSelectionBackground : Color.adaptiveTertiaryBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpaceSizeRow: View {
    let size: SpaceSize
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .adaptiveGreen : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(size.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(size.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Extensions
extension GardenType {
    var iconName: String {
        switch self {
        case .outdoor: return "sun.max.fill"
        case .indoor: return "house.fill"
        case .container: return "rectangle.3.offgrid.fill"
        case .raised: return "rectangle.stack.fill"
        case .hydroponic: return "drop.circle.fill"
        case .greenhouse: return "leaf.fill"
        case .balcony: return "building.2.fill"
        case .windowsill: return "window.horizontal"
        }
    }
}

#Preview {
    GardeningGoalsView(userProfile: .constant(UserProfile()))
        .padding()
}