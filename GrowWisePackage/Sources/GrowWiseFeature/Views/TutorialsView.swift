import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct TutorialsView: View {
    public init() {}
    
    public var body: some View {
        TutorialView()
    }
}

#Preview {
    let dataService = DataService.createFallback()
    let tutorialService = TutorialService(dataService: dataService)

    TutorialsView()
        .environment(tutorialService)
}
