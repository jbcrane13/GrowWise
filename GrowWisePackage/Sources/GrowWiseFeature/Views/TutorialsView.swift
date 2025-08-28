import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialsView: View {
    @State private var dataService: DataService?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var cachedTutorials: [TutorialData] = []
    @State private var visibleTutorialCount = 10
    
    public init() {}
    
    public var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading tutorials...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await loadDataService()
                }
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Failed to load tutorials")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadDataService()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let dataService = dataService {
                TutorialView(dataService: dataService)
                    .onAppear {
                        // Preload tutorial metadata in background
                        Task.detached(priority: .background) {
                            await preloadTutorialData()
                        }
                    }
            }
        }
    }
    
    @MainActor
    private func loadDataService() async {
        isLoading = true
        loadError = nil
        
        // Try async initialization in background
        await Task.detached(priority: .userInitiated) {
            do {
                let service = try await DataService(isAsync: true)
                await MainActor.run {
                    self.dataService = service
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                    // Use fallback as last resort
                    self.dataService = DataService.createFallback()
                }
            }
        }.value
    }
    
    private func preloadTutorialData() async {
        // Simulate tutorial metadata loading
        // In real implementation, this would fetch from dataService
        await Task.sleep(100_000_000) // 100ms
        
        await MainActor.run {
            // Cache tutorial summaries for quick display
            cachedTutorials = [
                TutorialData(id: "1", title: "Getting Started", progress: 0.0),
                TutorialData(id: "2", title: "Plant Care Basics", progress: 0.25),
                TutorialData(id: "3", title: "Advanced Techniques", progress: 0.0)
            ]
        }
    }
}

#Preview {
    TutorialsView()
}