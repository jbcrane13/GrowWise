import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialDetailView: View {
    let tutorial: TutorialTopic
    let tutorialService: TutorialService
    
    @State private var currentStepIndex = 0
    @State private var showAllSteps = false
    @State private var tutorialProgress: TutorialProgress
    
    public init(tutorial: TutorialTopic, tutorialService: TutorialService) {
        self.tutorial = tutorial
        self.tutorialService = tutorialService
        _tutorialProgress = State(initialValue: tutorialService.getTutorialProgress(tutorialId: tutorial.id))
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                // Progress Overview
                progressSection
                
                // Tutorial Description
                descriptionSection
                
                // Steps Section
                if showAllSteps {
                    allStepsSection
                } else {
                    currentStepSection
                }
                
                // Navigation Controls
                navigationSection
            }
            .padding()
        }
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshProgress()
            // Start at first incomplete step
            if let firstIncompleteIndex = tutorial.steps.enumerated().first(where: { index, _ in
                !tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: index)
            })?.offset {
                currentStepIndex = firstIncompleteIndex
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tutorial.subtitle)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                TutorialMetadata(
                    difficulty: tutorial.difficultyLevel,
                    duration: tutorial.estimatedDuration,
                    progress: tutorialProgress
                )
                
                Spacer()
                
                if tutorialProgress.isCompleted {
                    VStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title)
                        Text("Complete!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                
                Spacer()
                
                Button(showAllSteps ? "Show Current Step" : "Show All Steps") {
                    withAnimation {
                        showAllSteps.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(tutorialProgress.completedSteps) of \(tutorialProgress.totalSteps) steps completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", tutorialProgress.progressPercentage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: Double(tutorialProgress.completedSteps), total: Double(tutorialProgress.totalSteps))
                    .tint(.blue)
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About This Tutorial")
                .font(.headline)
            
            Text(tutorial.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var currentStepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step \(currentStepIndex + 1) of \(tutorial.steps.count)")
                    .font(.headline)
                
                Spacer()
                
                if tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: currentStepIndex) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            if currentStepIndex < tutorial.steps.count {
                TutorialStepCard(
                    step: tutorial.steps[currentStepIndex],
                    stepIndex: currentStepIndex,
                    isCompleted: tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: currentStepIndex),
                    onComplete: {
                        markStepComplete(currentStepIndex)
                    }
                )
            }
        }
    }
    
    private var allStepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Steps")
                .font(.headline)
            
            ForEach(Array(tutorial.steps.enumerated()), id: \.offset) { index, step in
                TutorialStepCard(
                    step: step,
                    stepIndex: index,
                    isCompleted: tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: index),
                    isCollapsed: true,
                    onComplete: {
                        markStepComplete(index)
                    },
                    onTap: {
                        withAnimation {
                            currentStepIndex = index
                            showAllSteps = false
                        }
                    }
                )
            }
        }
    }
    
    private var navigationSection: some View {
        HStack(spacing: 16) {
            // Previous Step
            Button {
                if currentStepIndex > 0 {
                    currentStepIndex -= 1
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(currentStepIndex > 0 ? Color.blue : Color(.systemGray4))
                .foregroundColor(currentStepIndex > 0 ? .white : .gray)
                .cornerRadius(10)
            }
            .disabled(currentStepIndex <= 0)
            
            // Next Step / Complete
            Button {
                if currentStepIndex < tutorial.steps.count - 1 {
                    currentStepIndex += 1
                } else {
                    // Tutorial completed
                    if !tutorialProgress.isCompleted {
                        // Mark all remaining steps as complete if not already
                        for i in 0..<tutorial.steps.count {
                            if !tutorialService.isStepCompleted(tutorialId: tutorial.id, stepIndex: i) {
                                tutorialService.markStepComplete(tutorialId: tutorial.id, stepIndex: i)
                            }
                        }
                        refreshProgress()
                    }
                }
            } label: {
                HStack {
                    Text(currentStepIndex < tutorial.steps.count - 1 ? "Next" : "Complete Tutorial")
                    if currentStepIndex < tutorial.steps.count - 1 {
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.top)
    }
    
    private func markStepComplete(_ stepIndex: Int) {
        tutorialService.markStepComplete(tutorialId: tutorial.id, stepIndex: stepIndex)
        refreshProgress()
        
        // Auto-advance to next step if not on last step
        if stepIndex == currentStepIndex && currentStepIndex < tutorial.steps.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    currentStepIndex += 1
                }
            }
        }
    }
    
    private func refreshProgress() {
        tutorialProgress = tutorialService.getTutorialProgress(tutorialId: tutorial.id)
    }
}

struct TutorialStepCard: View {
    let step: TutorialStep
    let stepIndex: Int
    let isCompleted: Bool
    var isCollapsed: Bool = false
    let onComplete: () -> Void
    var onTap: (() -> Void)? = nil
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step Header
            HStack {
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(step.duration) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        if isCompleted {
                            // Could add functionality to uncomplete if needed
                        } else {
                            onComplete()
                        }
                    } label: {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? .green : .gray)
                            .font(.title3)
                    }
                }
            }
            
            if !isCollapsed || isExpanded {
                // Step Content
                Text(step.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Tips Section
                if !step.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Tips")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        ForEach(step.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Common Mistakes Section
                if !step.commonMistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Common Mistakes to Avoid")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        ForEach(step.commonMistakes, id: \.self) { mistake in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.orange)
                                Text(mistake)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            } else if isCollapsed {
                // Collapsed preview
                Text(step.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Button("Tap to expand") {
                    if let onTap = onTap {
                        onTap()
                    } else {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            if let onTap = onTap {
                onTap()
            }
        }
    }
}

#Preview {
    do {
        let dataService = try DataService()
        let tutorialService = TutorialService(dataService: dataService)
        let tutorial = tutorialService.getAllTutorials().first!
        
        return NavigationView {
            TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)
        }
    } catch {
        let fallbackService = DataService.createFallback()
        let tutorialService = TutorialService(dataService: fallbackService)
        let tutorial = tutorialService.getAllTutorials().first!
        
        return NavigationView {
            TutorialDetailView(tutorial: tutorial, tutorialService: tutorialService)
        }
    }
}