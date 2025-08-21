import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialProgressView: View {
    let tutorialService: TutorialService
    
    @State private var analytics: TutorialAnalytics
    @State private var selectedFilter: ProgressFilter = .all
    @Environment(\.dismiss) private var dismiss
    
    public init(tutorialService: TutorialService) {
        self.tutorialService = tutorialService
        _analytics = State(initialValue: tutorialService.getTutorialAnalytics())
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overall Progress Card
                    overallProgressCard
                    
                    // Progress Breakdown by Category
                    categoryBreakdownSection
                    
                    // Individual Tutorial Progress
                    individualProgressSection
                    
                    // Achievement Section
                    achievementSection
                }
                .padding()
            }
            .navigationTitle("Learning Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshAnalytics()
            }
        }
    }
    
    private var overallProgressCard: some View {
        VStack(spacing: 16) {
            // Main Progress Circle
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall Progress")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Keep up the great work!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        StatItem(
                            value: "\(analytics.completedTutorials)",
                            label: "Completed",
                            color: .green
                        )
                        
                        StatItem(
                            value: "\(analytics.totalTutorials - analytics.completedTutorials)",
                            label: "Remaining",
                            color: .blue
                        )
                    }
                }
                
                Spacer()
                
                LargeCircularProgressView(
                    progress: analytics.completionRate,
                    size: 100
                )
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Steps Completed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(analytics.completedSteps) / \(analytics.totalSteps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(analytics.completedSteps), total: Double(analytics.totalSteps))
                    .tint(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress by Category")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TutorialCategory.allCases, id: \.self) { category in
                    CategoryProgressCard(
                        category: category,
                        tutorialService: tutorialService
                    )
                }
            }
        }
    }
    
    private var individualProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Individual Tutorials")
                    .font(.headline)
                
                Spacer()
                
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ProgressFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(filteredTutorials, id: \.id) { tutorial in
                    TutorialProgressRow(
                        tutorial: tutorial,
                        progress: tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                    )
                }
            }
        }
    }
    
    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AchievementCard(
                    title: "First Steps",
                    description: "Complete your first tutorial",
                    isUnlocked: analytics.completedTutorials >= 1,
                    icon: "leaf.fill",
                    color: .green
                )
                
                AchievementCard(
                    title: "Getting Started",
                    description: "Complete 3 tutorials",
                    isUnlocked: analytics.completedTutorials >= 3,
                    icon: "sprout.circle",
                    color: .blue
                )
                
                AchievementCard(
                    title: "Plant Expert",
                    description: "Complete all tutorials",
                    isUnlocked: analytics.completedTutorials == analytics.totalTutorials,
                    icon: "crown.fill",
                    color: .yellow
                )
                
                AchievementCard(
                    title: "Dedicated Learner",
                    description: "Complete 50 tutorial steps",
                    isUnlocked: analytics.completedSteps >= 50,
                    icon: "star.fill",
                    color: .purple
                )
            }
        }
    }
    
    private var filteredTutorials: [TutorialTopic] {
        let allTutorials = tutorialService.getAllTutorials()
        
        switch selectedFilter {
        case .all:
            return allTutorials
        case .completed:
            return allTutorials.filter { tutorial in
                tutorialService.getTutorialProgress(tutorialId: tutorial.id).isCompleted
            }
        case .inProgress:
            return allTutorials.filter { tutorial in
                let progress = tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                return progress.completedSteps > 0 && !progress.isCompleted
            }
        case .notStarted:
            return allTutorials.filter { tutorial in
                tutorialService.getTutorialProgress(tutorialId: tutorial.id).completedSteps == 0
            }
        }
    }
    
    private func refreshAnalytics() {
        analytics = tutorialService.getTutorialAnalytics()
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct LargeCircularProgressView: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.3)
                .foregroundColor(.blue)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.easeInOut, value: progress)
            
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", min(progress, 1.0) * 100.0))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct CategoryProgressCard: View {
    let category: TutorialCategory
    let tutorialService: TutorialService
    
    private var categoryTutorials: [TutorialTopic] {
        tutorialService.getAllTutorials().filter { $0.category == category }
    }
    
    private var completedCount: Int {
        categoryTutorials.filter { tutorial in
            tutorialService.getTutorialProgress(tutorialId: tutorial.id).isCompleted
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Spacer()
                
                Text("\(completedCount)/\(categoryTutorials.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            ProgressView(
                value: Double(completedCount),
                total: Double(categoryTutorials.count)
            )
            .tint(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TutorialProgressRow: View {
    let tutorial: TutorialTopic
    let progress: TutorialProgress
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tutorial.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(tutorial.difficultyLevel.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(4)
                    
                    Text("\(tutorial.estimatedDuration) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(progress.completedSteps)/\(progress.totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                if progress.totalSteps > 0 {
                    ProgressView(
                        value: Double(progress.completedSteps),
                        total: Double(progress.totalSteps)
                    )
                    .frame(width: 60)
                    .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        if progress.isCompleted {
            return .green
        } else if progress.completedSteps > 0 {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var statusIcon: String {
        if progress.isCompleted {
            return "checkmark.circle.fill"
        } else if progress.completedSteps > 0 {
            return "clock.arrow.circlepath"
        } else {
            return "circle"
        }
    }
    
    private var difficultyColor: Color {
        switch tutorial.difficultyLevel {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct AchievementCard: View {
    let title: String
    let description: String
    let isUnlocked: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isUnlocked ? color : .gray)
                    .font(.title2)
                
                Spacer()
                
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isUnlocked ? .primary : .secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? color.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Supporting Types

enum ProgressFilter: CaseIterable {
    case all
    case completed
    case inProgress
    case notStarted
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .completed: return "Done"
        case .inProgress: return "Started"
        case .notStarted: return "New"
        }
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let tutorialService = TutorialService(dataService: dataService)
    TutorialProgressView(tutorialService: tutorialService)
}