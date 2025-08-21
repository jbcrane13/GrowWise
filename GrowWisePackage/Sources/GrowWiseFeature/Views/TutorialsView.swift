import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialsView: View {
    @State private var dataService: DataService?
    
    public init() {}
    
    public var body: some View {
        Group {
            if let dataService = dataService {
                TutorialView(dataService: dataService)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading tutorials...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            if dataService == nil {
                do {
                    dataService = try DataService()
                } catch {
                    print("Failed to initialize DataService: \(error)")
                    print("Using fallback DataService to prevent crashes")
                    dataService = DataService.createFallback()
                }
            }
        }
    }
}

#Preview {
    TutorialsView()
}