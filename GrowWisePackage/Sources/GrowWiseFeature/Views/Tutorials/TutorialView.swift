import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialView: View {
    @State private var tutorialService: TutorialService
    @State private var selectedCategory: TutorialCategory = .planning
    @State private var searchText = ""
    @State private var showProgressView = false
    
    public init(dataService: DataService) {
        _tutorialService = State(initialValue: TutorialService(dataService: dataService))
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Selector
                categorySelector
                
                // Tutorials Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Featured Tutorial Section
                        if selectedCategory == .planning {
                            featuredTutorialSection
                        }
                        
                        // Quick Progress Summary
                        progressSummaryCard
                        
                        // Tutorial List
                        tutorialListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Learn & Grow")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProgressView = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $showProgressView) {
                TutorialProgressView(tutorialService: tutorialService)
            }
        }
        .searchable(text: $searchText, prompt: "Search tutorials...")
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(TutorialCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var featuredTutorialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Here")
                .font(.headline)
                .foregroundColor(.primary)
            
            let featuredTutorial = tutorialService.getAllTutorials().first(where: { $0.id == "getting-started-indoor-plants" })
            
            if let tutorial = featuredTutorial {
                FeaturedTutorialCard(tutorial: tutorial, tutorialService: tutorialService)
            }
        }
    }
    
    private var progressSummaryCard: some View {
        let analytics = tutorialService.getTutorialAnalytics()
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(analytics.completedTutorials) of \(analytics.totalTutorials) tutorials completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            CircularProgressView(
                progress: analytics.totalTutorials > 0 ? Double(analytics.completedTutorials) / Double(analytics.totalTutorials) : 0
            )
            .frame(width: 50, height: 50)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var tutorialListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedCategory.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredTutorials.count) tutorials")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(filteredTutorials, id: \.id) { tutorial in
                    NavigationLink(destination: TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)) {
                        TutorialRowView(tutorial: tutorial, tutorialService: tutorialService)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var filteredTutorials: [TutorialTopic] {
        let categoryTutorials = tutorialService.getAllTutorials().filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryTutorials
        }
        
        return categoryTutorials.filter { tutorial in
            tutorial.title.localizedCaseInsensitiveContains(searchText) ||
            tutorial.description.localizedCaseInsensitiveContains(searchText) ||
            tutorial.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let category: TutorialCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// Add extension for TutorialCategory iconName
extension TutorialCategory {
    var iconName: String {
        switch self {
        case .planning: return "map"
        case .preparation: return "wrench"
        case .care: return "heart.fill"
        case .environment: return "sun.max.fill"
        case .problemSolving: return "stethoscope"
        }
    }
}

struct FeaturedTutorialCard: View {
    let tutorial: TutorialTopic
    let tutorialService: TutorialService
    
    var body: some View {
        NavigationLink(destination: TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tutorial.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(tutorial.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                
                HStack {
                    TutorialMetadata(
                        difficulty: tutorial.difficultyLevel,
                        duration: tutorial.estimatedDuration,
                        progress: tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                    )
                    
                    Spacer()
                    
                    Text("RECOMMENDED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.mint.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TutorialRowView: View {
    let tutorial: TutorialTopic
    let tutorialService: TutorialService
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Difficulty indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(difficultyColor)
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tutorial.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if tutorialService.getTutorialProgress(tutorialId: tutorial.id).isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                
                Text(tutorial.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                TutorialMetadata(
                    difficulty: tutorial.difficultyLevel,
                    duration: tutorial.estimatedDuration,
                    progress: tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                )
                
                // Progress bar
                let progress = tutorialService.getTutorialProgress(tutorialId: tutorial.id)
                if progress.totalSteps > 0 {
                    ProgressView(value: Double(progress.completedSteps), total: Double(progress.totalSteps))
                        .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var difficultyColor: Color {
        switch tutorial.difficultyLevel {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct TutorialMetadata: View {
    let difficulty: DifficultyLevel
    let duration: Int
    let progress: TutorialProgress
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
                Text(difficulty.displayName)
                    .font(.caption2)
            }
            .foregroundColor(difficultyColor)
            
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("\(duration) min")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
            if progress.isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Completed")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            } else if progress.completedSteps > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("\(progress.completedSteps)/\(progress.totalSteps)")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.3)
                .foregroundColor(.blue)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            Text(String(format: "%.0f%%", min(progress, 1.0) * 100.0))
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    do {
        let dataService = try DataService()
        return TutorialView(dataService: dataService)
    } catch {
        let fallbackService = DataService.createFallback()
        return TutorialView(dataService: fallbackService)
    }
}